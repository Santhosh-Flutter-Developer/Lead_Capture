import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// masters.php – departments, sub-departments, designations and lookups.
/// `type` must be one of [MasterTypes].
class MastersApiService {
  MastersApiService._();
  static final _c = ApiClient.instance;

  static Future<ApiResponse> list(String type) =>
      _c.post(ApiEndpoints.masters, action: 'list', query: {'type': type}, body: {'type': type});

  static Future<ApiResponse> create(String type, Map<String, dynamic> fields) =>
      _c.post(ApiEndpoints.masters, action: 'create', query: {'type': type}, body: {'type': type, ...fields});

  static Future<ApiResponse> update(String type, String uid, Map<String, dynamic> fields) =>
      _c.post(ApiEndpoints.masters, action: 'update', query: {'type': type}, body: {'type': type, 'uid': uid, ...fields});

  static Future<ApiResponse> delete(String type, String uid) =>
      _c.post(ApiEndpoints.masters, action: 'delete', query: {'type': type}, body: {'type': type, 'uid': uid});
}
