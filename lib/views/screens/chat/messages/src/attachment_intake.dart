part of 'chat_messages.dart';

/// Turns things that arrive from the clipboard (screenshots, copied images,
/// copied files) or from drag & drop into [PlatformFile]s, which is what the
/// chat input already knows how to preview and upload:
///  * web              -> `bytes` is filled (no file system)
///  * windows/android/ios -> the data is streamed into a temp file and `path`
///    is filled (large videos never have to fit in memory).
class AttachmentIntake {
  AttachmentIntake._();

  /// Web keeps the whole file in memory, so stay reasonable there.
  static const int maxWebBytes = 100 * 1024 * 1024;

  static const String _tempFolder = 'chat_attachments';
  static int _seq = 0;

  /// Image formats, in the order we prefer them, with the extension to use
  /// when the source gives no file name (e.g. a screenshot).
  static final List<(FileFormat, String)> _imageFormats = [
    (Formats.png, 'png'),
    (Formats.jpeg, 'jpg'),
    (Formats.gif, 'gif'),
    (Formats.webp, 'webp'),
    (Formats.bmp, 'bmp'),
    (Formats.tiff, 'tiff'),
  ];

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Reads everything the system clipboard holds that should become an
  /// attachment. Returns an empty result when the clipboard only holds text
  /// (the caller then lets the normal text paste happen).
  static Future<AttachmentImport> fromSystemClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return const AttachmentImport();
    final reader = await clipboard.read();
    return fromClipboardReader(reader);
  }

  /// Same, for a reader we already have (web paste event).
  static Future<AttachmentImport> fromClipboardReader(
    ClipboardReader reader,
  ) async {
    final hasFileUri = reader.canProvide(Formats.fileUri);
    final hasText = reader.canProvide(Formats.plainText);
    final hasImage = _imageFormats.any((e) => reader.canProvide(e.$1));
    final hasHtml = reader.canProvide(Formats.htmlText);

    // Decide whether this clipboard is "a file/image" or "text":
    //  * copied files (Explorer / Finder)            -> files
    //  * text present (Excel, Word, a web page...)   -> text wins
    //  * image only (screenshot, "copy image")       -> image
    //  * something else binary and not text/html     -> try it as a file
    final bool wantsFiles;
    if (hasFileUri) {
      wantsFiles = true;
    } else if (hasText) {
      wantsFiles = false;
    } else if (hasImage) {
      wantsFiles = true;
    } else {
      wantsFiles =
          !hasHtml && reader.items.any((i) => i.platformFormats.isNotEmpty);
    }
    if (!wantsFiles) return const AttachmentImport();

    // Every read must be *started* before we await anything.
    final pending = [for (final item in reader.items) _readItem(item)];
    return _collect(pending);
  }

  /// Reads the dropped items. Must be called synchronously from the drop
  /// callback: the readers are only valid until that callback returns, so all
  /// reads are kicked off here before the first `await`.
  static Future<AttachmentImport> fromDroppedReaders(
    Iterable<DataReader> readers,
  ) {
    final pending = [for (final r in readers) _readItem(r)];
    return _collect(pending);
  }

  /// Wraps raw bytes (e.g. an image inserted by an Android keyboard).
  static Future<PlatformFile?> fromBytes(
    Uint8List bytes, {
    String? name,
    String? mimeType,
  }) async {
    final ext = _extFromMime(mimeType) ?? _sniffExtension(bytes);
    final fileName = _finalName(name, ext);
    if (kIsWeb) {
      return PlatformFile(name: fileName, size: bytes.length, bytes: bytes);
    }
    final dir = await _tempDir();
    final path = '${dir.path}/${_uniquePrefix()}_$fileName';
    await File(path).writeAsBytes(bytes, flush: true);
    return PlatformFile(name: fileName, size: bytes.length, path: path);
  }

  /// Deletes the temp copy made for [file] (no-op for files we didn't create).
  static Future<void> discard(PlatformFile file) async {
    final p = file.path;
    if (kIsWeb || p == null || !p.contains(_tempFolder)) return;
    try {
      final f = File(p);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // One item -> one PlatformFile
  // -------------------------------------------------------------------------

  /// NOTE: no `await` before `reader.getFile` - see [fromDroppedReaders].
  static Future<PlatformFile?> _readItem(DataReader reader) {
    // Real files (copied/dropped from the OS) keep their own name and bytes.
    // Otherwise prefer an explicit image format: that is what lets e.g. a
    // Windows DIB screenshot come out as a proper PNG.
    FileFormat? format;
    String? imageExt;
    if (!reader.canProvide(Formats.fileUri)) {
      for (final e in _imageFormats) {
        if (reader.canProvide(e.$1)) {
          format = e.$1;
          imageExt = e.$2;
          break;
        }
      }
    }

    // Never leaves an unhandled error behind if the reader can't name it.
    final suggestedName = reader.getSuggestedName().then<String?>(
      (v) => v,
      onError: (_) => null,
    );
    final done = Completer<PlatformFile?>();

    final progress = reader.getFile(
      format,
      (file) async {
        try {
          done.complete(await _materialize(file, suggestedName, imageExt));
        } catch (e) {
          if (!done.isCompleted) done.completeError(e);
        }
      },
      onError: (e) {
        if (!done.isCompleted) done.completeError(e);
      },
    );
    if (progress == null) return Future.value(null); // nothing to read
    return done.future;
  }

  static Future<PlatformFile?> _materialize(
    DataReaderFile file,
    Future<String?> suggestedName,
    String? imageExt,
  ) async {
    final knownSize = file.fileSize;

    if (kIsWeb) {
      if (knownSize != null && knownSize > maxWebBytes) {
        file.close();
        throw const AttachmentTooLarge();
      }
      final bytes = await file.readAll(); // requested first, see readAll docs
      if (bytes.length > maxWebBytes) throw const AttachmentTooLarge();
      final name = await _bestName(file.fileName, suggestedName);
      final ext = imageExt ?? _sniffExtension(bytes);
      final finalName = _finalName(name, ext);
      return PlatformFile(name: finalName, size: bytes.length, bytes: bytes);
    }

    // Native: stream straight to a temp file.
    final stream = file.getStream(); // must be requested before any await
    final dir = await _tempDir();
    final tmp = File('${dir.path}/${_uniquePrefix()}.part');
    final sink = tmp.openWrite();
    Uint8List? head;
    var size = 0;
    try {
      await sink.addStream(
        stream.map((chunk) {
          head ??= Uint8List.fromList(
            chunk.length > 16 ? chunk.sublist(0, 16) : chunk,
          );
          size += chunk.length;
          return chunk;
        }),
      );
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (size == 0) {
      // Folders / empty items end up here.
      try {
        await tmp.delete();
      } catch (_) {}
      throw const AttachmentUnreadable();
    }

    final name = await _bestName(file.fileName, suggestedName);
    final ext = imageExt ?? _sniffExtension(head);
    final finalName = _finalName(name, ext);
    final target = '${dir.path}/${_uniquePrefix()}_$finalName';
    await tmp.rename(target);
    return PlatformFile(name: finalName, size: size, path: target);
  }

  static Future<AttachmentImport> _collect(
    List<Future<PlatformFile?>> pending,
  ) async {
    final files = <PlatformFile>[];
    var tooLarge = 0;
    var failed = 0;
    for (final p in pending) {
      try {
        final f = await p;
        if (f != null) files.add(f);
      } on AttachmentTooLarge {
        tooLarge++;
      } catch (_) {
        failed++;
      }
    }
    return AttachmentImport(files: files, tooLarge: tooLarge, failed: failed);
  }

  // -------------------------------------------------------------------------
  // Names / types
  // -------------------------------------------------------------------------

  static Future<String?> _bestName(
    String? fileName,
    Future<String?> suggested,
  ) async {
    if (fileName != null && fileName.trim().isNotEmpty) return fileName;
    try {
      return await suggested;
    } catch (_) {
      return null;
    }
  }

  /// Safe file name that always has an extension. Unnamed items (screenshots)
  /// become "pasted_image_20261027_132530.png".
  static String _finalName(String? name, String? ext) {
    var n = (name ?? '').trim();
    // Keep only the file name part and drop characters that break paths.
    n = n.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[:*?"<>|]'), '_');

    final hasExt = RegExp(r'\.[A-Za-z0-9]{1,6}$').hasMatch(n);
    if (n.isEmpty) {
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}_'
          '${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final kind = (ext != null && _isImageExt(ext)) ? 'image' : 'file';
      n = 'pasted_${kind}_$stamp${_seq > 0 ? '_$_seq' : ''}';
      return ext == null ? n : '$n.$ext';
    }
    if (!hasExt && ext != null) return '$n.$ext';
    return n;
  }

  static bool _isImageExt(String e) =>
      const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'tiff'].contains(e);

  static String _uniquePrefix() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_seq++}';

  static String? _extFromMime(String? mime) {
    switch (mime?.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/bmp':
        return 'bmp';
    }
    return null;
  }

  /// Best-effort extension from the first bytes.
  static String? _sniffExtension(Uint8List? b) {
    if (b == null || b.length < 4) return null;
    bool starts(List<int> sig) {
      if (b.length < sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (b[i] != sig[i]) return false;
      }
      return true;
    }

    if (starts([0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (starts([0xFF, 0xD8, 0xFF])) return 'jpg';
    if (starts([0x47, 0x49, 0x46, 0x38])) return 'gif';
    if (starts([0x25, 0x50, 0x44, 0x46])) return 'pdf';
    if (starts([0x42, 0x4D])) return 'bmp';
    if (b.length >= 12 &&
        starts([0x52, 0x49, 0x46, 0x46]) &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  static Future<Directory> _tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/$_tempFolder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

/// Result of reading the clipboard / a drop.
class AttachmentImport {
  final List<PlatformFile> files;

  /// Items skipped because they were too big (web only).
  final int tooLarge;

  /// Items that could not be read (e.g. a dropped folder).
  final int failed;

  const AttachmentImport({
    this.files = const [],
    this.tooLarge = 0,
    this.failed = 0,
  });

  bool get isEmpty => files.isEmpty && tooLarge == 0 && failed == 0;
}

class AttachmentTooLarge implements Exception {
  const AttachmentTooLarge();
}

class AttachmentUnreadable implements Exception {
  const AttachmentUnreadable();
}

// ===========================================================================
// Drop zone
// ===========================================================================

/// Makes [child] (the whole conversation pane) a drop target for files and
/// images. While something is dragged over it a "Drop to attach" overlay is
/// shown. Works wherever the platform supports drops: web, Windows, macOS,
/// Linux, Android (multi-window) and iPadOS/iOS.
class ChatDropZone extends StatefulWidget {
  final Widget child;

  /// Whether the chat accepts attachments right now (e.g. false in a
  /// read-only channel).
  final bool Function() canAccept;

  /// Receives the imported files.
  final void Function(AttachmentImport result) onImported;

  const ChatDropZone({
    super.key,
    required this.child,
    required this.canAccept,
    required this.onImported,
  });

  @override
  State<ChatDropZone> createState() => _ChatDropZoneState();
}

class _ChatDropZoneState extends State<ChatDropZone> {
  bool _dragging = false;

  void _setDragging(bool v) {
    if (_dragging != v && mounted) setState(() => _dragging = v);
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) {
        if (!widget.canAccept()) return DropOperation.none;
        return event.session.allowedOperations.contains(DropOperation.copy)
            ? DropOperation.copy
            : DropOperation.none;
      },
      onDropEnter: (_) => _setDragging(true),
      onDropLeave: (_) => _setDragging(false),
      onDropEnded: (_) => _setDragging(false),
      onPerformDrop: (event) async {
        _setDragging(false);
        if (!widget.canAccept()) return;
        final readers = <DataReader>[
          for (final item in event.session.items)
            if (item.dataReader != null) item.dataReader!,
        ];
        if (readers.isEmpty) return;
        // Started synchronously (see AttachmentIntake.fromDroppedReaders);
        // the results are delivered whenever the reads finish.
        AttachmentIntake.fromDroppedReaders(readers).then((result) {
          if (mounted) widget.onImported(result);
        });
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging) const Positioned.fill(child: _DropOverlay()),
        ],
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.primary, width: 2),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.18),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.document_upload, size: 34, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  'Drop to attach',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Images, videos, documents and other files',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}