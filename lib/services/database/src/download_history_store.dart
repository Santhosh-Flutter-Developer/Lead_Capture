import 'package:flutter/foundation.dart';
import '/models/src/download_model.dart';
import '/services/api/api.dart';

/// Download history, stored on the server (downloads.php): each finished
/// download is logged with `log`, the Downloads screen reads it with `list`.
/// Names are kept from the old local store so callers don't change.
class DownloadHistoryStore {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Logs a download for the logged-in user (the server takes the user from
  /// the token). Throws on failure; callers treat history as best-effort.
  static Future<void> add(DownloadHistoryModel m) async {
    final url = m.url.isNotEmpty ? m.url : m.filePath;
    (await DownloadsApiService.log(
      fileName: m.fileName,
      url: url,
      filePath: m.filePath,
      fileSize: m.fileSize,
      isSuccess: m.isSuccess,
    ))
        .ensureSuccess();
    changes.value++;
  }

  static Future<List<DownloadHistoryModel>> load({String? search}) async {
    final res = (await DownloadsApiService.list(search: search)).ensureSuccess();
    return res.dataList.map((r) {
      final m = Js.m(r);
      return DownloadHistoryModel(
        uid: Js.opt(m['uid']),
        fileName: Js.s(m['file_name']),
        filePath: Js.s(m['file_path']),
        url: Js.s(m['url']),
        fileSize: Js.i(m['file_size']) ?? 0,
        downloadedAt: Js.dt(m['downloaded_at'] ?? m['created_at']) ?? DateTime.now(),
        isSuccess: Js.b(m['is_success']),
        userId: Js.s(m['user_uid']),
      );
    }).toList();
  }

  /// Removes one history row (server soft-delete).
  static Future<void> delete(String uid) async {
    (await DownloadsApiService.delete(uid)).ensureSuccess();
    changes.value++;
  }

  /// Clears the current user's whole history (server soft-delete).
  static Future<void> clear() async {
    (await DownloadsApiService.clear()).ensureSuccess();
    changes.value++;
  }
}