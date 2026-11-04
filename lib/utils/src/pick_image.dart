import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/constants/constants.dart';
import 'platform.dart';

// Single conditional import provides BOTH rotateXFile() AND nativeUploadFromPath()
// from the correct platform file. Both files define both functions.
import 'pick_image_io.dart'
    if (dart.library.html) 'pick_image_web.dart'
    show rotateXFile, nativeUploadFromPath;

class PickImage {
  static final ImagePicker _picker = ImagePicker();

  /// Returns XFile? — works on both web and native.
  /// Native callers: File(xfile.path)
  /// Web callers:    xfile.readAsBytes()
  static Future<XFile?> selectImage(context) async {
    if (kIsWeb) {
      return _pickImageGallery();
    }
    var pickOption = await Sheet.showSheet(
      context,
      widget: const PickOption(),
      size: 0.2,
    );
    if (pickOption == null) return null;
    return pickOption == 1 ? captureImage() : _pickImageGallery();
  }

  /// Opens the gallery directly without showing the camera/gallery sheet.
  static Future<XFile?> pickFromGallery() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Select a photo',
      );
      if (result == null || result.files.isEmpty) return null;
      final pf = result.files.single;
      if (pf.bytes == null) return null;
      return XFile.fromData(pf.bytes!, name: pf.name);
    }
    if (kIsWindows) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        dialogTitle: 'Select a photo',
      );
      if (result == null || result.files.isEmpty) return null;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return null;
      return XFile(pickedPath);
    }
    return _pickImageGallery();
  }

  static Future<XFile?> captureImage() async {
    try {
      final XFile? tmp = await _picker.pickImage(source: ImageSource.camera);
      if (tmp == null) return null;
      return rotateXFile(tmp);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('${e.toString()}, ${st.toString()}');
      throw e.toString();
    }
  }

  static Future<XFile?> _pickImageGallery() async {
    try {
      final XFile? tmp = await _picker.pickImage(source: ImageSource.gallery);
      if (tmp == null) return null;
      if (kIsWeb) return tmp;
      return rotateXFile(tmp);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('${e.toString()}, ${st.toString()}');
      throw e.toString();
    }
  }

  static Future<List<XFile>> pickMultipleImages() async {
    try {
      final List<XFile> tmpImages = await _picker.pickMultiImage();
      if (tmpImages.isEmpty) return [];
      if (kIsWeb) return tmpImages;
      final List<XFile> rotated = [];
      for (final img in tmpImages) {
        rotated.add(await rotateXFile(img));
      }
      return rotated;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('${e.toString()}, ${st.toString()}');
      throw e.toString();
    }
  }
}

/// Uploads an XFile to Firebase Storage on both web (bytes) and native (File).
/// Returns the download URL.
Future<String> xFileToUploadUrl(XFile xfile, StorageFolder folder) async {
  if (kIsWeb) {
    final Uint8List bytes = await xfile.readAsBytes();
    return StorageService.uploadImageBytes(bytes: bytes, folder: folder);
  }
  return nativeUploadFromPath(xfile.path, folder);
}
