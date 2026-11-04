// download_io.dart — native filesystem implementation
// Only compiled on non-web (conditional import in download.dart).
// Freely uses dart:io since web never loads this file.
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:leadcapture/models/src/download_model.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '/services/services.dart' show ErrorService, Spdb;
import '/theme/theme.dart';
import '/views/views.dart';
import '/utils/utils.dart';

/// Saves [bytes] to the platform Downloads folder and returns the file path.
Future<String> saveFileToDownloads(Uint8List bytes, {String? fileName}) async {
  Directory? dir;

  if (Platform.isAndroid) {
    final baseDir = await getExternalStorageDirectory();
    if (baseDir == null) throw Exception('Could not get external storage directory.');
    dir = Directory('${baseDir.path}/Download');
    if (!await dir.exists()) await dir.create(recursive: true);
  } else if (Platform.isIOS) {
    dir = await getApplicationDocumentsDirectory();
  } else if (Platform.isWindows) {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } else if (Platform.isMacOS || Platform.isLinux) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      dir = downloads;
    } else {
      final home = Platform.environment['HOME'];
      dir = home != null
          ? Directory('$home/Downloads')
          : await getApplicationDocumentsDirectory();
    }
  } else {
    dir = await getApplicationDocumentsDirectory();
  }

  final safeFileName =
      (fileName == null || fileName.isEmpty) ? const Uuid().v4() : fileName;
  final file = File('${dir.path}/$safeFileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Returns a path inside [dir] that does not exist yet ("a.m4a",
/// "a (1).m4a", ...). Overwriting a file that is still open in a player
/// fails on Windows (file locked), which broke the second download.
Future<String> _uniquePath(String dir, String fileName) async {
  var candidate = path.join(dir, fileName);
  if (!await File(candidate).exists()) return candidate;
  final ext = path.extension(fileName);
  final stem = path.basenameWithoutExtension(fileName);
  for (var i = 1; i < 200; i++) {
    candidate = path.join(dir, '$stem ($i)$ext');
    if (!await File(candidate).exists()) return candidate;
  }
  return path.join(
    dir,
    '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
}

/// Best-effort history entry (never fails the download).
Future<void> _logNativeDownload({
  required String fileName,
  required String filePath,
  required String url,
  required int fileSize,
  required bool ok,
}) async {
  try {
    await FirebaseFirestore.instance.collection('download_history').add(
          DownloadHistoryModel(
            fileName: fileName,
            filePath: filePath,
            url: url,
            fileSize: fileSize,
            downloadedAt: DateTime.now(),
            isSuccess: ok,
            userId: await Spdb.getUid() ?? '',
          ).toMap(),
        );
  } catch (e) {
    debugPrint('download_history not saved: $e');
  }
}

/// Performs an HTTP download, saves to filesystem, opens the file.
/// Called only from _NativeUrlDownloader.run() under !kIsWeb.
///
/// Hardened so the progress overlay is removed exactly once on EVERY path
/// (it used to stay on screen forever / be removed twice when the history
/// write or a directory lookup threw).
Future<void> runNativeUrlDownload(
    BuildContext context, String url, String? name) async {
  final String fileName = deriveDownloadFileName(name, url);
  final ValueNotifier<int> progress = ValueNotifier<int>(0);

  OverlayEntry? overlayEntry;
  bool removed = false;
  void removeEntry() {
    if (overlayEntry != null && !removed) {
      removed = true;
      overlayEntry!.remove();
    }
  }

  String? savePath;
  try {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState != null) {
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<int>(
              valueListenable: progress,
              builder: (_, value, _) => _NativeProgressWidget(progress: value),
            ),
          ),
        ),
      );
      overlayState.insert(overlayEntry);
    }

    Directory directory = await getApplicationDocumentsDirectory();
    if (Platform.isWindows) {
      directory = await getDownloadsDirectory() ?? directory;
    }
    savePath = await _uniquePath(directory.path, fileName);

    await Dio().download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = (received / total * 100).toInt();
      },
    );

    final fileSize = await File(savePath).length();
    removeEntry();

    if (context.mounted) {
      FlushBar.show(context, "Download Completed", isSuccess: true);
      openfile(savePath, context);
    }
    await _logNativeDownload(
      fileName: fileName,
      filePath: savePath,
      url: url,
      fileSize: fileSize,
      ok: true,
    );
  } catch (e, st) {
    debugPrint("${e.toString()}, ${st.toString()}");
    try {
      await ErrorService.recordError(e, st);
    } catch (_) {}
    // Don't leave a half-written file behind.
    try {
      if (savePath != null) {
        final f = File(savePath);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    removeEntry();
    if (context.mounted) {
      FlushBar.show(context, "Download Failed",
          isSuccess: false, error: e, stackTrace: st);
    }
    await _logNativeDownload(
      fileName: fileName,
      filePath: '',
      url: url,
      fileSize: 0,
      ok: false,
    );
  } finally {
    removeEntry();
  }
}

class _NativeProgressWidget extends StatelessWidget {
  final int progress;
  const _NativeProgressWidget({required this.progress});
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