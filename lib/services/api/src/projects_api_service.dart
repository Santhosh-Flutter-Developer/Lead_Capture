import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// projects.php: list, get, create, update, delete, bulk_delete, export.
class ProjectsApiService {
  ProjectsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.projects, action: action, body: body ?? {});
}
