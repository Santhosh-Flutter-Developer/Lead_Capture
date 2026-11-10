import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_client.dart';
import 'api_config.dart';
import 'api_constants.dart';
import 'api_exception.dart';

/// Result of upload.php (`id, file_name, file_url, file_size, file_type`).
class UploadedFile {
  final int? id;
  final String fileName;
  final String fileUrl; // as returned (relative path)
  final int fileSize;
  final String fileType;
  const UploadedFile({this.id, required this.fileName, required this.fileUrl, required this.fileSize, required this.fileType});

  /// Absolute, displayable URL.
  String get absoluteUrl => ApiConfig.resolveFileUrl(fileUrl);

  factory UploadedFile.fromMap(Map<String, dynamic> m) => UploadedFile(
        id: int.tryParse('${m['id']}'),
        fileName: (m['file_name'] ?? '').toString(),
        fileUrl: (m['file_url'] ?? '').toString(),
        fileSize: int.tryParse('${m['file_size']}') ?? 0,
        fileType: (m['file_type'] ?? '').toString(),
      );
}

/// Replacement for Firebase Storage. upload.php has NO delete endpoint, so
/// there is intentionally no delete method here.
class StorageApiService {
  StorageApiService._();

  static Future<UploadedFile> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String module,
    void Function(double)? onProgress,
  }) async {
    final res = await ApiClient.instance.multipart(
      ApiEndpoints.upload,
      fields: {'module': module},
      files: [ApiUploadFile(field: 'file', fileName: fileName, bytes: bytes)],
      onProgress: onProgress,
    );
    if (!res.status) {
      throw ApiException(res.message.isEmpty ? 'Upload failed' : res.message, type: ApiErrorType.validation);
    }
    return UploadedFile.fromMap(res.dataMap);
  }

  /// Native only (dart:io). On web use [uploadBytes].
  static Future<UploadedFile> uploadFile({
    required File file,
    required String module,
    void Function(double)? onProgress,
  }) async {
    assert(!kIsWeb, 'Use uploadBytes on web');
    final bytes = await file.readAsBytes();
    final name = file.path.split(RegExp(r'[\\/]')).last;
    return uploadBytes(bytes: bytes, fileName: name, module: module, onProgress: onProgress);
  }
}
