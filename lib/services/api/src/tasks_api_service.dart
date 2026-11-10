import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// tasks.php: list, get, create, update, delete, bulk_delete, update_status, add_comment, export.
class TasksApiService {
  TasksApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.tasks, action: action, body: body ?? {});
}
