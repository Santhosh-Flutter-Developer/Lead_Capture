import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// tickets.php: list, get, create, update, delete, bulk_delete, update_status, add_comment, export.
class TicketsApiService {
  TicketsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.tickets, action: action, body: body ?? {});
}
