import 'package:cloud_firestore/cloud_firestore.dart';

class DownloadHistoryModel {
  final String fileName;
  final String filePath;
  final String url;
  final int fileSize;
  final DateTime downloadedAt;
  final bool isSuccess;
  final String userId;

  DownloadHistoryModel({
    required this.fileName,
    required this.filePath,
    required this.url,
    required this.fileSize,
    required this.downloadedAt,
    required this.isSuccess,
    required this.userId,
  });

  factory DownloadHistoryModel.fromMap(Map<String, dynamic> map) {
    return DownloadHistoryModel(
      fileName: map['fileName'] ?? '',
      filePath: map['filePath'] ?? '',
      url: map['url'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      downloadedAt: (map['downloadedAt'] as Timestamp).toDate(),
      isSuccess: map['isSuccess'] ?? true,
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'filePath': filePath,
      'url': url,
      'fileSize': fileSize,
      'downloadedAt': Timestamp.fromDate(downloadedAt),
      'isSuccess': isSuccess,
      'userId': userId,
    };
  }
}
