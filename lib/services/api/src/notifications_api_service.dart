import 'api_client.dart';
import 'api_response.dart';

/// notifications.php: list, create, delete, restore, mark_read, mark_all_read,
/// register_fcm_token (fcm_token, device_type).
class NotificationsApiService {
  NotificationsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post('notifications.php', action: action, body: body ?? {});

  /// Stores this device's FCM token so the server can push to it.
  static Future<ApiResponse> registerFcmToken({
    required String token,
    required String deviceType,
  }) =>
      call('register_fcm_token', {'fcm_token': token, 'device_type': deviceType});
}