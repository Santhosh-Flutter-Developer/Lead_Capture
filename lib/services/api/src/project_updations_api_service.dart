import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// project_updations.php: list, get, create, update, delete, bulk_delete,
/// update_status, kanban, deals_by_client, delete_attachment, export.
class ProjectUpdationsApiService {
  ProjectUpdationsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.projectUpdations, action: action, body: body ?? {});
}
