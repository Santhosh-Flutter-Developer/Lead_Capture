// ─────────────────────────────────────────────────────────────────────────────
// storage_service.dart
// CHANGED:
//   • Added `uploadBytes()` method that accepts raw Uint8List + filename.
//     Use this on web (image_picker / file_picker return bytes, not File paths).
//   • Original `uploadFile(file: File, ...)` kept unchanged for native.
//   • `uploadImage()` now also has `uploadImageBytes()` for web.
//   • `uploadFilesInBatch()` kept for native; added `uploadBytesInBatch()` for web.
//   • `dart:io` import kept — it is only used in methods that receive File
//     objects (always called from !kIsWeb paths).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as dp;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '/services/services.dart';
import '/constants/constants.dart';

class StorageService {
  static final storage = FirebaseStorage.instance.ref();

  // ── NATIVE: upload from File (unchanged) ─────────────────────────────────
  static Future<String> uploadFile({
    required File file,
    required StorageFolder folder,
  }) async {
    var cid = await Spdb.getCid();
    var uid = const Uuid().v1();
    String downloadLink;
    final ext = file.path.split('.').last;
    final uploadDir = storage.child("$cid/${folder.name}/$uid.$ext");

    try {
      final metadata = SettableMetadata(contentType: _mimeFromExt(ext));
      final fileBytes = await file.readAsBytes();
      UploadTask uploadTask = uploadDir.putData(
        Uint8List.fromList(fileBytes),
        metadata,
      );
      TaskSnapshot taskSnapshot = await uploadTask;
      downloadLink = await taskSnapshot.ref.getDownloadURL();
      return downloadLink;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  // ── WEB / UNIVERSAL: upload from bytes ───────────────────────────────────
  /// Use this on web where image_picker / file_picker give you Uint8List bytes
  /// instead of a file path.
  ///
  /// [fileName] is used to determine the extension, e.g. "photo.jpg".
  static Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required StorageFolder folder,
    String? collectionId,
  }) async {
    final cid = collectionId ?? await Spdb.getCid() ?? '';
    final uid = const Uuid().v1();
    final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final uploadDir = storage.child("$cid/${folder.name}/$uid.$ext");

    try {
      final metadata = SettableMetadata(
        contentType: _mimeFromExt(ext),
      );
      UploadTask uploadTask = uploadDir.putData(bytes, metadata);
      TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint("uploadBytes error: ${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  // ── PROGRESS UPLOADS (used by chat) ──────────────────────────────────────
  /// Streams a [File] to Storage (no full read into memory) and reports
  /// progress as a 0.0 – 1.0 fraction. Native only.
  static Future<String> uploadFileWithProgress({
    required File file,
    required StorageFolder folder,
    void Function(double progress)? onProgress,
    String? collectionId,
  }) async {
    final cid = collectionId ?? await Spdb.getCid() ?? '';
    final ext = file.path.contains('.') ? file.path.split('.').last : 'bin';
    final ref = storage.child("$cid/${folder.name}/${const Uuid().v1()}.$ext");
    try {
      final task = ref.putFile(
        file,
        SettableMetadata(contentType: _mimeFromExt(ext)),
      );
      return await _finishUpload(task, onProgress);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint("uploadFileWithProgress error: $e, $st");
      throw e.toString();
    }
  }

  /// Same as [uploadFileWithProgress] but for raw bytes (web / no path).
  static Future<String> uploadBytesWithProgress({
    required Uint8List bytes,
    required String fileName,
    required StorageFolder folder,
    void Function(double progress)? onProgress,
    String? collectionId,
  }) async {
    final cid = collectionId ?? await Spdb.getCid() ?? '';
    final ext = fileName.contains('.') ? fileName.split('.').last : 'bin';
    final ref = storage.child("$cid/${folder.name}/${const Uuid().v1()}.$ext");
    try {
      final task = ref.putData(
        bytes,
        SettableMetadata(contentType: _mimeFromExt(ext)),
      );
      return await _finishUpload(task, onProgress);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint("uploadBytesWithProgress error: $e, $st");
      throw e.toString();
    }
  }

  static Future<String> _finishUpload(
    UploadTask task,
    void Function(double progress)? onProgress,
  ) async {
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      final snap = await task;
      onProgress?.call(1.0);
      return await snap.ref.getDownloadURL();
    } finally {
      await sub.cancel();
    }
  }

  // ── NATIVE: upload image from File ───────────────────────────────────────
  static Future<String> uploadImage({
    required File file,
    required StorageFolder folder,
    String? collectionId,
  }) async {
    String cid = collectionId ?? await Spdb.getCid() ?? '';
    var uid = const Uuid().v1();
    String downloadLink;
    final uploadDir = storage.child("$cid/${folder.name}/$uid.webp");

    try {
      final originalImageBytes = await file.readAsBytes();
      UploadTask uploadTask = uploadDir.putData(
        Uint8List.fromList(originalImageBytes),
      );
      TaskSnapshot taskSnapshot = await uploadTask;
      downloadLink = await taskSnapshot.ref.getDownloadURL();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
    return downloadLink;
  }

  // ── WEB: upload image from bytes ─────────────────────────────────────────
  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required StorageFolder folder,
    String? collectionId,
  }) async {
    return uploadBytes(
      bytes: bytes,
      fileName: 'image.webp',
      folder: folder,
      collectionId: collectionId,
    );
  }

  // ── NATIVE: batch upload from File list ──────────────────────────────────
  static Future<List<String>> uploadFilesInBatch({
    required List<File> files,
    required StorageFolder folder,
    String? collectionId,
  }) async {
    String cid = collectionId ?? await Spdb.getCid() ?? '';
    List<Future<String>> uploadTasks = files.map((file) async {
      try {
        var uid = const Uuid().v1();
        final ext = file.path.split('.').last;
        final uploadDir = storage.child("$cid/${folder.name}/$uid.$ext");
        final metadata = SettableMetadata(contentType: _mimeFromExt(ext));
        final fileBytes = await file.readAsBytes();
        UploadTask uploadTask = uploadDir.putData(
          Uint8List.fromList(fileBytes),
          metadata,
        );
        TaskSnapshot taskSnapshot = await uploadTask;
        return await taskSnapshot.ref.getDownloadURL();
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        dp.debugPrint("${e.toString()}, ${st.toString()}");
        throw "Error uploading file ${file.path}: ${e.toString()}";
      }
    }).toList();
    return await Future.wait(uploadTasks);
  }

  // ── WEB: batch upload from bytes list ────────────────────────────────────
  static Future<List<String>> uploadBytesInBatch({
    required List<({Uint8List bytes, String fileName})> files,
    required StorageFolder folder,
    String? collectionId,
  }) async {
    return Future.wait(
      files.map((f) => uploadBytes(
            bytes: f.bytes,
            fileName: f.fileName,
            folder: folder,
            collectionId: collectionId,
          )),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(imageUrl);
        await storageRef.delete();
        return true;
      }
      return false;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint("${e.toString()}, ${st.toString()}");
      if (e is FirebaseException && e.code == 'object-not-found') {
        return false;
      }
      throw e.toString();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
        return 'image/tiff';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'htm':
      case 'html':
        return 'text/html';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}