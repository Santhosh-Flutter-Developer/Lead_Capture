import 'package:flutter/material.dart';
import '/services/services.dart';
import '/views/views.dart';

// dart:io imports — only used inside !kIsWeb branches
// ignore: avoid_web_libraries_in_flutter
import 'open_file_io.dart'
    if (dart.library.html) 'open_file_web.dart'
    show platformLaunchFile, platformSaveFile, platformOpenFile;

class FileHelper {
  static Future launchFile({
    required List<int> bt,
    required String fn,
    required bool nf,
    String? name,
  }) async {
    return platformLaunchFile(bt: bt, fn: fn, nf: nf, name: name);
  }

  static Future<String> saveFile({
    required List<int> bt,
    required String fn,
  }) async {
    return platformSaveFile(bt: bt, fn: fn);
  }
}

void openfile(String path, BuildContext context) async {
  try {
    await platformOpenFile(path);
  } catch (e, st) {
    debugPrint('${e.toString()}, ${st.toString()}');
    await ErrorService.recordError(e, st);
    if (context.mounted) {
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}
