import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// deals.php. Actions in the deployed source: list, get, create, update,
/// delete, update_status, toggle_lock, kanban, add_comment, delete_comment,
/// add_activity, delete_attachment, export.
class DealsApiService {
  DealsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.deals, action: action, body: body ?? {});
}
