import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';

/// employees.php
class EmployeesApiService {
  EmployeesApiService._();
  static final _c = ApiClient.instance;
  static Future<ApiResponse> list({String search = '', String userType = '', String departmentId = '', String status = ''}) =>
      _c.post(ApiEndpoints.employees, action: 'list',
          body: {'search': search, 'user_type': userType, 'department_id': departmentId, 'status': status});
  static Future<ApiResponse> get(String uid) => _c.post(ApiEndpoints.employees, action: 'get', body: {'uid': uid});
  static Future<ApiResponse> create(Map<String, dynamic> f) => _c.post(ApiEndpoints.employees, action: 'create', body: f);
  static Future<ApiResponse> update(String uid, Map<String, dynamic> f) =>
      _c.post(ApiEndpoints.employees, action: 'update', body: {'uid': uid, ...f});
  static Future<ApiResponse> checkAssigned({required String uid, String? employeeId}) =>
      _c.post(ApiEndpoints.employees, action: 'check_assigned', body: {'uid': uid, if (employeeId != null) 'employee_id': employeeId});
  static Future<ApiResponse> block(String uid) => _c.post(ApiEndpoints.employees, action: 'block', body: {'uid': uid});
  static Future<ApiResponse> unblock(String uid) => _c.post(ApiEndpoints.employees, action: 'unblock', body: {'uid': uid});
  static Future<ApiResponse> restore(String uid) => _c.post(ApiEndpoints.employees, action: 'restore', body: {'uid': uid});
  static Future<ApiResponse> delete(String uid) => _c.post(ApiEndpoints.employees, action: 'delete', body: {'uid': uid});
}
