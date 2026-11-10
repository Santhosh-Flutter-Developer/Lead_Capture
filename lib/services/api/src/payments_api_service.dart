import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// payments.php: list, get, get_by_project, create, save / save_batch, delete,
/// delete_project, export.
class PaymentsApiService {
  PaymentsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.payments, action: action, body: body ?? {});
}
