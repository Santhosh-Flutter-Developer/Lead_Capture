// ─────────────────────────────────────────────────────────────────────────────
// pick_image_upload_web.dart  — NEW FILE
// Web stub — _nativeUpload() should never be called on web because
// xFileToUploadUrl() uses the kIsWeb branch (bytes) instead.
// ─────────────────────────────────────────────────────────────────────────────
import '/constants/constants.dart';

Future<String> _nativeUpload(String path, StorageFolder folder) async {
  throw UnsupportedError(
      '_nativeUpload must not be called on web. Use uploadImageBytes() instead.');
}
