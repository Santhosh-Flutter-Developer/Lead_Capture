import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// downloads.php – per-user download history.
/// list (`search`, admin-only `all`), log (`file_name`, `url`, `file_path`,
/// `file_size`, `is_success`), delete (`uid`), clear (all of the user's rows).
class DownloadsApiService {
  DownloadsApiService._();
  static final _c = ApiClient.instance;

  static Future<ApiResponse> list({String? search}) => _c.post(
        ApiEndpoints.downloads,
        action: 'list',
        body: {if (search != null && search.isNotEmpty) 'search': search},
      );

  static Future<ApiResponse> log({
    required String fileName,
    required String url,
    String? filePath,
    int fileSize = 0,
    bool isSuccess = true,
  }) =>
      _c.post(ApiEndpoints.downloads, action: 'log', body: {
        'file_name': fileName,
        'url': url,
        'file_path': filePath ?? '',
        'file_size': fileSize,
        'is_success': isSuccess ? 1 : 0,
      });

  static Future<ApiResponse> delete(String uid) =>
      _c.post(ApiEndpoints.downloads, action: 'delete', body: {'uid': uid});

  static Future<ApiResponse> clear() =>
      _c.post(ApiEndpoints.downloads, action: 'clear', body: {});
}