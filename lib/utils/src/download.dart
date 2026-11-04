import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:leadcapture/models/src/download_model.dart';
import 'package:path/path.dart' as path;
import '/services/services.dart' show ErrorService, Spdb;
import '/theme/theme.dart';
import '/views/views.dart';
import '/utils/utils.dart';

// Conditional import: on web → dart:html blob download.
//                    on native → dart:io filesystem save.
import 'download_io.dart'
    if (dart.library.html) 'download_web.dart' show saveFileToDownloads, runNativeUrlDownload;

/// Builds a safe local file name for a download.
///
/// The old code used `path.basename(url)` when no name was given. For a
/// Firebase Storage URL that is e.g. `voice.m4a?alt=media&token=...`, and
/// `?` / `:` / `"` are illegal in Windows file names, so saving failed.
/// Also strips any folder part and characters no OS accepts.
String deriveDownloadFileName(String? name, String url) {
  var base = (name ?? '').trim();
  if (base.isEmpty) {
    try {
      final segs = Uri.parse(url).pathSegments; // already percent-decoded
      if (segs.isNotEmpty) base = segs.last;
    } catch (_) {}
  }
  base = path.basename(base.replaceAll('\\', '/'));
  base = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  if (base.isEmpty) {
    base = 'download_${DateTime.now().millisecondsSinceEpoch}';
  }
  return base;
}

class Download {
  /// Download with a blocking loading dialog that is ALWAYS closed again
  /// (success, failure or exception) — the old copy-pasted
  /// `futureLoading(); await download; Navigator.pop();` left the spinner on
  /// screen forever when the download threw, and could pop the wrong route.
  static Future<void> downloadWithLoading(
    BuildContext context,
    String url,
    String? name,
  ) async {
    if (url.isEmpty) {
      FlushBar.show(context, 'Invalid file URL', isSuccess: false);
      return;
    }
    // showDialog() uses the ROOT navigator, so close it on the same one.
    final navigator = Navigator.of(context, rootNavigator: true);
    futureLoading(context);
    try {
      await downloadFromUrl(context, url, name);
    } catch (e, st) {
      debugPrint('${e.toString()}, ${st.toString()}');
      await ErrorService.recordError(e, st);
      if (context.mounted) {
        FlushBar.show(
          context,
          'Download Failed',
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    } finally {
      if (navigator.mounted && navigator.canPop()) navigator.pop();
    }
  }

  /// Best-effort history entry: a failure here (Firestore rules, offline)
  /// must never turn a finished download into an error / stuck spinner.
  static Future<void> _logHistory(DownloadHistoryModel model) async {
    try {
      await FirebaseFirestore.instance
          .collection('download_history')
          .add(model.toMap());
    } catch (e) {
      debugPrint('download_history not saved: $e');
    }
  }

  // ── URL download ──────────────────────────────────────────────────────────
  static Future<void> downloadFromUrl(
    BuildContext context,
    String url,
    String? name,
  ) async {
    if (kIsWeb) {
      await _webDownloadFromUrl(context, url, name);
    } else {
      await _nativeDownloadFromUrl(context, url, name);
    }
  }

  // Web: fetch via Dio bytes + trigger browser download
  static Future<void> _webDownloadFromUrl(
    BuildContext context,
    String url,
    String? name,
  ) async {
    final String fileName = deriveDownloadFileName(name, url);
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data != null) {
        final bytes = Uint8List.fromList(response.data!);
        await saveFileToDownloads(bytes, fileName: fileName);
      }
      if (context.mounted) {
        FlushBar.show(context, "Download Completed", isSuccess: true);
      }
      await _logHistory(
        DownloadHistoryModel(
          fileName: fileName,
          filePath: url,
          url: url,
          fileSize: response.data?.length ?? 0,
          downloadedAt: DateTime.now(),
          isSuccess: true,
          userId: await Spdb.getUid() ?? '',
        ),
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      if (context.mounted) {
        FlushBar.show(context, "Download Failed",
            isSuccess: false, error: e, stackTrace: st);
      }
    }
  }

  // Native: Dio HTTP download → save to filesystem → open
  static Future<void> _nativeDownloadFromUrl(
    BuildContext context,
    String url,
    String? name,
  ) async {
    await _NativeUrlDownloader.run(context, url, name);
  }

  // ── Asset download ────────────────────────────────────────────────────────
  static Future<void> downloadFromAsset(
    BuildContext context,
    String assetPath,
    String fileName,
  ) async {
    int progress = 0;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    OverlayEntry? overlayEntry;
    bool removed = false;
    void removeEntry() {
      if (overlayEntry != null && !removed) {
        removed = true;
        overlayEntry!.remove();
      }
    }

    if (overlayState != null) {
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _DownloadProgressIndicator(progress: progress),
          ),
        ),
      );
      overlayState.insert(overlayEntry);
    }

    try {
      final ByteData data = await rootBundle.load(assetPath);
      progress = 50;
      overlayEntry?.markNeedsBuild();

      final Uint8List bytes = data.buffer.asUint8List();
      // saveFileToDownloads is resolved by the conditional import above:
      //   web    → dart:html blob download (returns fileName as pseudo-path)
      //   native → writes to filesystem (returns real file path)
      final String savePath =
          await saveFileToDownloads(bytes, fileName: fileName);

      progress = 100;
      overlayEntry?.markNeedsBuild();
      removeEntry();

      if (context.mounted) {
        FlushBar.show(context, "Download Completed", isSuccess: true);
        // On native, open the saved file; on web the browser already downloaded it.
        if (!kIsWeb) openfile(savePath, context);
      }
      await _logHistory(
        DownloadHistoryModel(
          fileName: fileName,
          filePath: savePath,
          url: assetPath,
          fileSize: bytes.length,
          downloadedAt: DateTime.now(),
          isSuccess: true,
          userId: await Spdb.getUid() ?? '',
        ),
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      removeEntry();
      if (context.mounted) {
        FlushBar.show(context, "Download Failed",
            isSuccess: false, error: e, stackTrace: st);
      }
    } finally {
      removeEntry();
    }
  }
}

// ─── Progress indicator widget (unchanged) ────────────────────────────────────
class _DownloadProgressIndicator extends StatelessWidget {
  final int progress;
  const _DownloadProgressIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress / 100),
            const SizedBox(width: 10),
            Text(
              'Downloading... $progress%',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Native URL downloader (private — only instantiated under !kIsWeb) ────────
// Kept as a private class so dart:io imports stay in download_io.dart only.
// This class itself does NOT import dart:io — it delegates to download_io.dart.
class _NativeUrlDownloader {
  static Future<void> run(
      BuildContext context, String url, String? name) async {
    await runNativeUrlDownload(context, url, name);
  }
}

// Forward declaration resolved by the conditional import at the top of this file.
// download_io.dart   exports `_runNativeUrlDownload` for native.
// download_web.dart  exports a no-op for web (never called due to kIsWeb check).