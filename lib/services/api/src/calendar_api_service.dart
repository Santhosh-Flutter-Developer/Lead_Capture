import 'api_client.dart';
import 'api_response.dart';

/// calendar.php: list (events + tasks + leads + deals + tickets + unified
/// items), get, create, update, delete.
class CalendarApiService {
  CalendarApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post('calendar.php', action: action, body: body ?? {});
}
