import 'dart:io';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:image_picker/image_picker.dart';
import '/constants/constants.dart';
import '/services/services.dart';

/// Applies EXIF rotation to [xfile] on Android/iOS.
Future<XFile> rotateXFile(XFile xfile) async {
  final File rotated =
      await FlutterExifRotation.rotateImage(path: xfile.path);
  return XFile(rotated.path);
}

/// Uploads the image at [path] to Firebase Storage and returns the download URL.
Future<String> nativeUploadFromPath(String path, StorageFolder folder) async {
  return StorageService.uploadImage(file: File(path), folder: folder);
}
