import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// leads.php. Actions in the deployed source: list, get, create, update,
/// delete, bulk_delete, update_status, convert_to_deal, kanban, import,
/// restore, add_comment, delete_comment, add_activity, delete_attachment, export.
class LeadsApiService {
  LeadsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.leads, action: action, body: body ?? {});
}
