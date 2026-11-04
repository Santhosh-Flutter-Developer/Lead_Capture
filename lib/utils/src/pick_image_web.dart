import 'package:image_picker/image_picker.dart';
import '/constants/constants.dart';

/// No-op on web — returns [xfile] unchanged (no EXIF rotation needed).
Future<XFile> rotateXFile(XFile xfile) async => xfile;

/// Should never be called on web — xFileToUploadUrl() uses the kIsWeb
/// bytes branch instead. Throws if accidentally reached.
Future<String> nativeUploadFromPath(String path, StorageFolder folder) async {
  throw UnsupportedError(
    'nativeUploadFromPath must not be called on web. '
    'Use xFileToUploadUrl() which handles web via bytes.',
  );
}
