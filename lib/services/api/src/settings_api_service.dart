import 'api_client.dart';
import 'api_response.dart';

/// settings.php: get, update, update_preference, save_geofence, manual_backup,
/// trash_list, trash_restore, trash_delete_permanent, clear_cache.
class SettingsApiService {
  SettingsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post('settings.php', action: action, body: body ?? {});
}
