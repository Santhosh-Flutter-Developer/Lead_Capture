import 'api_client.dart';
import 'api_response.dart';

/// notifications.php: list, create, delete, restore, mark_read, mark_all_read.
class NotificationsApiService {
  NotificationsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post('notifications.php', action: action, body: body ?? {});
}
