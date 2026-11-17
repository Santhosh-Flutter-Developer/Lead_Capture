import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import '/services/services.dart' show ApiConfig;
import '/views/views.dart' show FlushBar;

import 'file_picker_io.dart'
    if (dart.library.html) 'file_picker_web.dart' show readBytesFromPath;

export 'package:file_picker/file_picker.dart' show PlatformFile, FileType;

/// Drops files above the 30 MB server upload limit and tells the user, so a
/// too-large file is never added to a form / upload list.
List<PlatformFile> limitUploadSize(dynamic context, List<PlatformFile> files) {
  final ok = <PlatformFile>[];
  final rejected = <String>[];
  for (final f in files) {
    if (ApiConfig.exceedsUploadLimit(f.size)) {
      rejected.add(f.name);
    } else {
      ok.add(f);
    }
  }
  if (rejected.isNotEmpty && context is BuildContext && context.mounted) {
    FlushBar.show(
      context,
      rejected.length == 1
          ? ApiConfig.uploadTooLargeMessage(rejected.first)
          : '${rejected.length} files are larger than ${ApiConfig.maxUploadLabel} and were not added.',
      isSuccess: false,
    );
  }
  return ok;
}

class FilePick {
  /// Picks multiple files. Returns a list of [PlatformFile].
  /// On native: use pf.path → File(pf.path!)
  /// On web:    use pf.bytes directly.
  static Future<List<PlatformFile>?> pickFiles(context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    return result == null ? null : limitUploadSize(context, result.files);
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
    final f = result?.files.firstOrNull;
    if (f == null) return null;
    return limitUploadSize(context, [f]).firstOrNull;
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
    return result == null ? null : limitUploadSize(context, result.files);
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