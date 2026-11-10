// storage_service.dart
// Same public API as the old Firebase Storage facade, now backed by the
// PHP upload.php endpoint (StorageApiService). Every method returns the
// ABSOLUTE file URL (so existing Image.network / launchUrl callers keep
// working); write paths strip it back to the relative path the API stores.
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' as dp;
import '/services/services.dart';
import '/constants/constants.dart';

class StorageService {
  /// upload.php `module` for each logical folder. Modules the server records
  /// in lead_capture_attachments: lead, deal, task, ticket, updation,
  /// payment, feed, chat. Anything else is stored under "general"/"profile".
  static String _module(StorageFolder f) {
    switch (f) {
      case StorageFolder.leadAttachments:
        return UploadModules.lead;
      case StorageFolder.dealAttachments:
        return UploadModules.deal;
      case StorageFolder.taskAttachments:
        return UploadModules.task;
      case StorageFolder.ticketAttachments:
        return UploadModules.ticket;
      case StorageFolder.updationAttachments:
        return UploadModules.updation;
      case StorageFolder.paymentAttachments:
        return UploadModules.payment;
      case StorageFolder.feedAttachments:
        return 'feed';
      case StorageFolder.chats:
        return 'chat';
      case StorageFolder.userPhotos:
      case StorageFolder.adminProfile:
        return UploadModules.profile;
      case StorageFolder.companyLogo:
      case StorageFolder.clientPhotos:
      case StorageFolder.clientCompanyLogos:
        return 'general';
    }
  }

  static Future<String> _bytes(
    Uint8List bytes,
    String fileName,
    StorageFolder folder, [
    void Function(double)? onProgress,
  ]) async {
    try {
      final up = await StorageApiService.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        module: _module(folder),
        onProgress: onProgress,
      );
      onProgress?.call(1.0);
      ApiAttachments.register(up.absoluteUrl, up.id);
      if (folder == StorageFolder.chats) {
        ChatService.cacheUploadBytes(up.absoluteUrl, bytes);
      }
      return up.absoluteUrl;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      dp.debugPrint('upload error: $e, $st');
      throw e.toString();
    }
  }

  static String _name(File f) => f.path.split(RegExp(r'[\\/]')).last;

  static Future<String> uploadFile({
    required File file,
    required StorageFolder folder,
  }) async => _bytes(await file.readAsBytes(), _name(file), folder);

  static Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required StorageFolder folder,
    String? collectionId,
  }) => _bytes(bytes, fileName, folder);

  static Future<String> uploadFileWithProgress({
    required File file,
    required StorageFolder folder,
    void Function(double progress)? onProgress,
    String? collectionId,
  }) async => _bytes(await file.readAsBytes(), _name(file), folder, onProgress);

  static Future<String> uploadBytesWithProgress({
    required Uint8List bytes,
    required String fileName,
    required StorageFolder folder,
    void Function(double progress)? onProgress,
    String? collectionId,
  }) => _bytes(bytes, fileName, folder, onProgress);

  static Future<String> uploadImage({
    required File file,
    required StorageFolder folder,
    String? collectionId,
  }) async => _bytes(await file.readAsBytes(), _name(file), folder);

  static Future<String> uploadImageBytes({
    required Uint8List bytes,
    required StorageFolder folder,
    String? collectionId,
  }) => _bytes(bytes, 'image.webp', folder);

  static Future<List<String>> uploadFilesInBatch({
    required List<File> files,
    required StorageFolder folder,
    String? collectionId,
  }) => Future.wait(files.map((f) => uploadFile(file: f, folder: folder)));

  static Future<List<String>> uploadBytesInBatch({
    required List<({Uint8List bytes, String fileName})> files,
    required StorageFolder folder,
    String? collectionId,
  }) => Future.wait(
    files.map((f) => uploadBytes(bytes: f.bytes, fileName: f.fileName, folder: folder)),
  );

  /// upload.php has no delete endpoint (see MISSING_API_REQUIREMENTS.md).
  /// The file stays on the server; callers drop the reference from the
  /// record on their next update. Returns false (nothing deleted).
  static Future<bool> deleteImage(String imageUrl) async => false;
}
