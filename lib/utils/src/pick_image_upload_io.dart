// ─────────────────────────────────────────────────────────────────────────────
// pick_image_upload_io.dart  — NEW FILE
// Native upload helper used by xFileToUploadUrl() in pick_image.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import '/services/services.dart';
import '/constants/constants.dart';

Future<String> _nativeUpload(String path, StorageFolder folder) async {
  return StorageService.uploadImage(
    file: File(path),
    folder: folder,
  );
}
