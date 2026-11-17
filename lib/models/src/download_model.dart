import '/models/src/timestamp.dart';

class DownloadHistoryModel {
  final String? uid; // server id (downloads.php), null for a not-yet-logged entry
  final String fileName;
  final String filePath;
  final String url;
  final int fileSize;
  final DateTime downloadedAt;
  final bool isSuccess;
  final String userId;

  DownloadHistoryModel({
    this.uid,
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
      uid: map['uid'] as String?,
      fileName: map['fileName'] ?? '',
      filePath: map['filePath'] ?? '',
      url: map['url'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      downloadedAt: anyToDate(map['downloadedAt']),
      isSuccess: map['isSuccess'] ?? true,
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (uid != null) 'uid': uid,
      'fileName': fileName,
      'filePath': filePath,
      'url': url,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.millisecondsSinceEpoch,
      'isSuccess': isSuccess,
      'userId': userId,
    };
  }
}