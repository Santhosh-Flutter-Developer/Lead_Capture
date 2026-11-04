import 'dart:io';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:open_file/open_file.dart' as open_file;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:url_launcher/url_launcher.dart';
import '/services/firebase/src/download_service.dart';

Future<void> platformLaunchFile({
  required List<int> bt,
  required String fn,
  required bool nf,
  String? name,
}) async {
  try {
    String? path;
    if (Platform.isAndroid || Platform.isIOS) {
      final Directory directory = await getDownloadDirectory();
      path = directory.path;
    } else if (Platform.isWindows || Platform.isLinux) {
      final Directory directory =
          await path_provider.getDownloadsDirectory() ??
          await path_provider.getApplicationCacheDirectory();
      path = directory.path;
    } else {
      path = (await path_provider.getApplicationSupportDirectory()).path;
    }

    final String fileLocation =
        Platform.isWindows ? '$path\\$fn' : '$path/$fn';
    final File file = File(fileLocation);
    await file.writeAsBytes(bt, flush: true);

    if (Platform.isAndroid || Platform.isIOS) {
      await DownloadService.setDownload(
        data: {
          'file_name': fn,
          'location': fileLocation,
          'file_type': fn.split('.').last,
          'created': DateTime.now().toString(),
        },
      );
      await open_file.OpenFile.open(fileLocation);
    } else if (Platform.isWindows) {
      if (!file.existsSync()) throw Exception('${file.uri} does not exist!');
      if (!await launchUrl(file.uri)) {
        throw Exception('Could not launch ${file.uri}');
      }
    } else if (Platform.isMacOS) {
      await Process.run('open', [fileLocation], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [fileLocation], runInShell: true);
    }
  } catch (e) {
    throw e.toString();
  }
}

Future<String> platformSaveFile({
  required List<int> bt,
  required String fn,
}) async {
  try {
    String? path;
    if (Platform.isAndroid || Platform.isIOS) {
      final Directory directory = await getDownloadDirectory();
      path = directory.path;
    } else if (Platform.isWindows || Platform.isLinux) {
      final Directory directory =
          await path_provider.getDownloadsDirectory() ??
          await path_provider.getApplicationCacheDirectory();
      path = directory.path;
    } else {
      path = (await path_provider.getApplicationSupportDirectory()).path;
    }

    final String fileLocation =
        Platform.isWindows ? '$path\\$fn' : '$path/$fn';
    final File file = File(fileLocation);
    await file.writeAsBytes(bt, flush: true);
    return file.path;
  } catch (e) {
    throw e.toString();
  }
}

Future<void> platformOpenFile(String path) async {
  await open_file.OpenFile.open(path);
}
