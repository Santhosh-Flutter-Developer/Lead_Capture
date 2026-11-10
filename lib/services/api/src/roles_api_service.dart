import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// roles.php
class RolesApiService {
  RolesApiService._();
  static final _c = ApiClient.instance;
  static Future<ApiResponse> list() => _c.post(ApiEndpoints.roles, action: 'list', body: {});
  static Future<ApiResponse> get(String uid) => _c.post(ApiEndpoints.roles, action: 'get', body: {'uid': uid});
  /// permissions: [{page, can_view, can_create, can_edit, can_delete, can_export, can_import}]
  static Future<ApiResponse> create({required String name, String? description, required List<Map<String, dynamic>> permissions}) =>
      _c.post(ApiEndpoints.roles, action: 'create', body: {'name': name, 'description': description ?? '', 'permissions': permissions});
  static Future<ApiResponse> update({required String uid, required String name, String? description, required List<Map<String, dynamic>> permissions}) =>
      _c.post(ApiEndpoints.roles, action: 'update', body: {'uid': uid, 'name': name, 'description': description ?? '', 'permissions': permissions});
  static Future<ApiResponse> restore(String uid) => _c.post(ApiEndpoints.roles, action: 'restore', body: {'uid': uid});
  static Future<ApiResponse> delete(String uid) => _c.post(ApiEndpoints.roles, action: 'delete', body: {'uid': uid});
}
