import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'file_picker_io.dart'
    if (dart.library.html) 'file_picker_web.dart' show readBytesFromPath;

export 'package:file_picker/file_picker.dart' show PlatformFile, FileType;

class FilePick {
  /// Picks multiple files. Returns a list of [PlatformFile].
  /// On native: use pf.path → File(pf.path!)
  /// On web:    use pf.bytes directly.
  static Future<List<PlatformFile>?> pickFiles(context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    return result?.files;
  }

  /// Picks a single file.
  static Future<PlatformFile?> pickFile(
    context, {
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: allowedExtensions,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      withData: true,
    );
    return result?.files.firstOrNull;
  }

  /// Picks multiple files with extension filter.
  static Future<List<PlatformFile>?> pickFileWithExtensions(
    context, {
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: allowedExtensions,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowMultiple: true,
      withData: true,
    );
    return result?.files;
  }
}

/// Returns bytes for a [PlatformFile] on both web and native.
Future<Uint8List> platformFileToBytes(PlatformFile pf) async {
  if (kIsWeb) {
    assert(pf.bytes != null, 'bytes is null — withData was not set to true');
    return pf.bytes!;
  }
  return readBytesFromPath(pf.path!);
}
