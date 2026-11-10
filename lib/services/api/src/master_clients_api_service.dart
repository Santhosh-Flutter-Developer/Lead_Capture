import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// master_clients.php: list, get, check_duplicate, create, update, delete,
/// bulk_delete, restore, import, export.  master_companies.php: list, get,
/// create, update, delete, export.
class MasterClientsApiService {
  MasterClientsApiService._();
  static Future<ApiResponse> call(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.masterClients, action: action, body: body ?? {});
  static Future<ApiResponse> companies(String action, [Map<String, dynamic>? body]) =>
      ApiClient.instance.post(ApiEndpoints.masterCompanies, action: action, body: body ?? {});
}
