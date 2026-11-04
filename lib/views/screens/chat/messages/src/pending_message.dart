part of 'chat_messages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Optimistic ("pending") chat messages
//
// When the user taps send we immediately add a PendingMessage to the store.
// The chat list renders it right away (local previews + upload progress) while
// the files upload and the Firestore document is written in the background.
// The upload lives in the store, not in a widget, so it keeps running even if
// the user leaves the chat screen.
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kImageExt = [
  'png',
  'jpg',
  'jpeg',
  'webp',
  'bmp',
  'gif',
  'tiff',
];
const List<String> _kVideoExt = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
const List<String> _kAudioExt = ['mp3', 'wav', 'aac', 'm4a'];

String _chatMimeType(String ext) {
  ext = ext.toLowerCase();
  if (_kImageExt.contains(ext)) return 'image/${ext == 'jpg' ? 'jpeg' : ext}';
  if (_kVideoExt.contains(ext)) return 'video/$ext';
  if (ext == 'm4a') return 'audio/mp4';
  if (_kAudioExt.contains(ext)) return 'audio/$ext';

  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    default:
      return 'application/octet-stream';
  }
}

/// Max width of the media grid / file cards inside a chat message.
double _chatMediaWidth(BuildContext context) {
  final w = MediaQuery.of(context).size.width * 0.7;
  return w > 280 ? 280 : w;
}

enum PendingStatus { sending, failed }

class PendingAttachment {
  PendingAttachment(this.file)
    : ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';

  final PlatformFile file;
  final String ext;

  /// 0.0 – 1.0 upload progress for this file.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Set once the file is uploaded (so a retry does not re-upload it).
  FileModel? uploaded;

  bool get isImage => _kImageExt.contains(ext);
  bool get isVideo => _kVideoExt.contains(ext);
  bool get isAudio => _kAudioExt.contains(ext);
  bool get isMedia => isImage || isVideo;
}

class PendingMessage extends ChangeNotifier {
  PendingMessage({
    required this.id,
    required this.chatId,
    required this.message,
    required this.attachments,
    required this.participants,
    this.threadId,
    this.replyFor,
    this.mentions = const [],
  }) : timestamp = DateTime.now();

  final String id;
  final String chatId;
  final String? threadId;
  final String message;
  final String? replyFor;
  final List<MentionModel> mentions;
  final List<String> participants;
  final List<PendingAttachment> attachments;
  final DateTime timestamp;

  PendingStatus status = PendingStatus.sending;

  void _setStatus(PendingStatus value) {
    status = value;
    notifyListeners();
  }
}

class PendingMessageStore extends ChangeNotifier {
  PendingMessageStore._();
  static final PendingMessageStore instance = PendingMessageStore._();

  final List<PendingMessage> _items = [];

  int get length => _items.length;

  /// Pending messages for one chat (or one thread), newest first.
  List<PendingMessage> forChat(String chatId, {String? threadId}) {
    return _items
        .where((m) => m.chatId == chatId && m.threadId == threadId)
        .toList()
        .reversed
        .toList();
  }

  /// Adds the message to the UI instantly and starts uploading / sending it.
  void send({
    required String chatId,
    required String message,
    required List<PlatformFile> files,
    required List<String> participants,
    String? threadId,
    String? replyFor,
    List<MentionModel> mentions = const [],
  }) {
    final pending = PendingMessage(
      id: const Uuid().v4(),
      chatId: chatId,
      message: message,
      attachments: files.map(PendingAttachment.new).toList(),
      participants: participants,
      threadId: threadId,
      replyFor: replyFor,
      mentions: mentions,
    );
    _items.add(pending);
    notifyListeners();
    _run(pending);
  }

  void retry(PendingMessage pending) {
    if (pending.status == PendingStatus.sending) return;
    pending._setStatus(PendingStatus.sending);
    _run(pending);
  }

  void discard(PendingMessage pending) {
    _items.remove(pending);
    notifyListeners();
    _discardTemp(pending);
  }

  /// Deletes temp copies made by paste / drag-drop (no-op for other files).
  void _discardTemp(PendingMessage p) {
    for (final a in p.attachments) {
      AttachmentIntake.discard(a.file);
    }
  }

  Future<void> _run(PendingMessage p) async {
    try {
      // Upload all files in parallel, each reporting its own progress.
      final uploaded = await Future.wait(p.attachments.map(_uploadOne));

      await ChatService.sendChatMessage(
        chatId: p.chatId,
        message: p.message,
        attachments: uploaded,
        replyFor: p.replyFor,
        mentions: p.mentions,
        threadId: p.threadId,
        messageId: p.id,
        timestamp: p.timestamp,
        participants: p.participants,
      );

      _items.remove(p);
      notifyListeners();
      _discardTemp(p);

      ChatService.sendNotification(
        chatId: p.chatId,
        message: p.message,
        isChat: true,
      );
    } catch (e, st) {
      debugPrint('Send message error: $e\n$st');
      p._setStatus(PendingStatus.failed);
    }
  }

  Future<FileModel> _uploadOne(PendingAttachment a) async {
    if (a.uploaded != null) return a.uploaded!;

    final pf = a.file;
    final String url;
    int size = pf.size;

    if (!kIsWeb && pf.path != null) {
      final file = File(pf.path!);
      if (size == 0) size = await file.length();
      url = await StorageService.uploadFileWithProgress(
        file: file,
        folder: StorageFolder.chats,
        onProgress: (v) => a.progress.value = v,
      );
    } else if (pf.bytes != null) {
      url = await StorageService.uploadBytesWithProgress(
        bytes: pf.bytes!,
        fileName: pf.name,
        folder: StorageFolder.chats,
        onProgress: (v) => a.progress.value = v,
      );
    } else {
      throw 'Could not read "${pf.name}"';
    }

    final model = FileModel(
      url: url,
      name: pf.name,
      size: (size / 1024).round(),
      extension: a.ext,
      mimeType: _chatMimeType(a.ext),
      createdAt: DateTime.now(),
    );
    a.uploaded = model;
    return model;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI
// ─────────────────────────────────────────────────────────────────────────────

/// A message that is still uploading / sending. Looks like a normal sent
/// bubble, with local previews and a progress ring on every file.
class PendingChatBubble extends StatelessWidget {
  final PendingMessage message;
  const PendingChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: message,
      builder: (context, _) {
        final failed = message.status == PendingStatus.failed;
        final media = message.attachments.where((a) => a.isMedia).toList();
        final others = message.attachments.where((a) => !a.isMedia).toList();
        final width = _chatMediaWidth(context);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.message.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0052D4),
                          Color(0xFF4364F7),
                          Color(0xFF6FB1FC),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Text(
                      message.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                if (media.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: message.message.isNotEmpty ? 4 : 0,
                    ),
                    child: MediaGridLayout(
                      count: media.length,
                      width: width,
                      tileBuilder: (context, i) =>
                          _PendingMediaTile(file: media[i], failed: failed),
                    ),
                  ),
                for (final a in others)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _PendingFileCard(
                      file: a,
                      width: width,
                      failed: failed,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: failed
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 14,
                              color: scheme.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Not sent',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  PendingMessageStore.instance.retry(message),
                              child: Text(
                                'Retry',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  PendingMessageStore.instance.discard(message),
                              child: Text(
                                'Delete',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('hh:mm a').format(message.timestamp),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.schedule, size: 12, color: scheme.outline),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Image / video tile with a local preview and an upload progress overlay.
class _PendingMediaTile extends StatelessWidget {
  final PendingAttachment file;
  final bool failed;
  const _PendingMediaTile({required this.file, required this.failed});

  @override
  Widget build(BuildContext context) {
    final pf = file.file;

    // NOTE: PlatformFile.path throws on web, so always check kIsWeb first.
    ImageProvider? provider;
    if (file.isImage) {
      if (!kIsWeb && pf.path != null) {
        provider = FileImage(File(pf.path!));
      } else if (pf.bytes != null) {
        provider = MemoryImage(pf.bytes!);
      }
    }

    final Widget preview = provider != null
        ? Image(
            image: ResizeImage(provider, width: 600),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          )
        : Container(
            color: Colors.black87,
            child: Center(
              child: Icon(
                file.isVideo ? Icons.videocam : Icons.image_outlined,
                color: Colors.white70,
                size: 36,
              ),
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        ValueListenableBuilder<double>(
          valueListenable: file.progress,
          builder: (context, value, _) {
            if (file.uploaded != null || value >= 1) {
              return const SizedBox.shrink();
            }
            return Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: failed
                  ? const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 32,
                    )
                  : _ProgressRing(value: value),
            );
          },
        ),
      ],
    );
  }
}

/// Document / audio row with upload progress.
class _PendingFileCard extends StatelessWidget {
  final PendingAttachment file;
  final double width;
  final bool failed;
  const _PendingFileCard({
    required this.file,
    required this.width,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sizeKb = (file.file.size / 1024).round();

    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: file.ext.getColorForFile,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              file.ext.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeKb > 0)
                  Text(
                    '$sizeKb KB',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<double>(
            valueListenable: file.progress,
            builder: (context, value, _) {
              if (file.uploaded != null || value >= 1) {
                return Icon(Icons.check_circle, size: 22, color: scheme.primary);
              }
              if (failed) {
                return Icon(Icons.error_outline, size: 22, color: scheme.error);
              }
              return _ProgressRing(
                value: value,
                size: 28,
                color: scheme.primary,
                showPercent: false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final Color color;
  final bool showPercent;
  const _ProgressRing({
    required this.value,
    this.size = 44,
    this.color = Colors.white,
    this.showPercent = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            // Indeterminate until the first progress event arrives.
            value: value > 0 ? value : null,
            strokeWidth: 3,
            color: color,
            backgroundColor: color.withValues(alpha: 0.25),
          ),
          if (showPercent && value > 0)
            Text(
              '${(value * 100).round()}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// WhatsApp-style media layout: 1 big, 2 side by side, 3 = 1 + 2,
/// 4+ = 2×2 grid with a "+N" overlay on the last tile. Never scrolls
/// horizontally.
class MediaGridLayout extends StatelessWidget {
  final int count;
  final double width;
  final Widget Function(BuildContext context, int index) tileBuilder;
  final int maxVisible;

  const MediaGridLayout({
    super.key,
    required this.count,
    required this.width,
    required this.tileBuilder,
    this.maxVisible = 4,
  });

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final visible = count > maxVisible ? maxVisible : count;
    final extra = count - visible;
    final half = (width - _gap) / 2;

    Widget tile(int i, double w, double h) {
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            tileBuilder(context, i),
            if (extra > 0 && i == visible - 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text(
                      '+$extra',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget content;
    if (visible <= 1) {
      content = tile(0, width, width * 0.8);
    } else if (visible == 2) {
      content = Row(
        children: [
          tile(0, half, half * 1.3),
          const SizedBox(width: _gap),
          tile(1, half, half * 1.3),
        ],
      );
    } else if (visible == 3) {
      content = Column(
        children: [
          tile(0, width, width * 0.6),
          const SizedBox(height: _gap),
          Row(
            children: [
              tile(1, half, half * 0.9),
              const SizedBox(width: _gap),
              tile(2, half, half * 0.9),
            ],
          ),
        ],
      );
    } else {
      content = Column(
        children: [
          Row(
            children: [
              tile(0, half, half),
              const SizedBox(width: _gap),
              tile(1, half, half),
            ],
          ),
          const SizedBox(height: _gap),
          Row(
            children: [
              tile(2, half, half),
              const SizedBox(width: _gap),
              tile(3, half, half),
            ],
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: width, child: content),
    );
  }
}