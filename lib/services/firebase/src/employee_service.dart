import 'package:flutter/material.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Employees – backed by employees.php (user_type = employee). No Firestore.
class EmployeeService {
  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e, $st');
    if (e is ApiException) throw e.message;
    throw '$prefix: $e';
  }

  static Future<List<Map<String, dynamic>>> _userRows({String userType = ''}) async {
    final res = (await EmployeesApiService.list(userType: userType)).ensureSuccess();
    return res.dataList.map(Js.m).toList();
  }

  static Future<Map<String, dynamic>?> _userRow(String uid) async {
    final res = await EmployeesApiService.get(uid);
    if (!res.status) return null;
    return res.dataMap;
  }

  static Future<String> generateEmployeeId() async {
    try {
      int maxId = 0;
      final idRegExp = RegExp(r'\d+');
      for (final r in await _userRows(userType: 'employee')) {
        final m = idRegExp.firstMatch(Js.s(r['employee_id']));
        final v = int.tryParse(m?.group(0) ?? '');
        if (v != null && v > maxId) maxId = v;
      }
      return 'EMP${(maxId + 1).toString().padLeft(3, '0')}';
    } catch (e, st) {
      ErrorService.recordError(e, st);
      debugPrint('Error generating next employee ID: $e');
      return 'EMP001';
    }
  }

  /// Duplicate check against the current company's users (the API only
  /// exposes the caller's company; the server also re-validates on save).
  static Future<String?> checkEmployeeExists({
    required String employeeId,
    required String email,
    required String mobileNumber,
    String? excludeUid,
  }) async {
    try {
      final rows = await _userRows();
      for (final r in rows) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['employee_id']).toLowerCase() == employeeId.trim().toLowerCase() &&
            employeeId.trim().isNotEmpty) {
          return 'Employee ID already exists';
        }
      }
      return _contactCheck(rows, email, mobileNumber, excludeUid);
    } catch (e, st) {
      _fail('Error checking employee', e, st);
    }
  }

  static Future<String?> checkContactExists({
    required String email,
    required String mobileNumber,
    String? excludeUid,
  }) async {
    try {
      return _contactCheck(await _userRows(), email, mobileNumber, excludeUid);
    } catch (e, st) {
      _fail('Error checking contact details', e, st);
    }
  }

  static String? _contactCheck(List<Map<String, dynamic>> rows, String email, String mobile, String? excludeUid) {
    final e = email.trim().toLowerCase();
    final m = mobile.trim();
    for (final r in rows) {
      if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
      if (e.isNotEmpty && Js.s(r['email']).toLowerCase() == e) return 'Email already exists';
    }
    for (final r in rows) {
      if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
      if (m.isNotEmpty && Js.s(r['mobile_number']).trim() == m) return 'Mobile number already exists';
    }
    return null;
  }

  static List<String> duplicateKeysFor({String? employeeId, String? email, String? mobileNumber}) {
    final normId = (employeeId ?? '').trim().toLowerCase();
    final normEmail = (email ?? '').trim().toLowerCase();
    final normMobile = (mobileNumber ?? '').trim();
    final keys = <String>[];
    if (normId.isNotEmpty) keys.add('employeeId:$normId');
    if (normEmail.isNotEmpty) keys.add('email:$normEmail');
    if (normMobile.isNotEmpty) keys.add('mobile:$normMobile');
    return keys;
  }

  static List<String> duplicateKeysForEmployee(EmployeeModel employee) => duplicateKeysFor(
        employeeId: employee.employeeId,
        email: employee.email,
        mobileNumber: employee.mobileNumber,
      );

  static List<String> duplicateContactKeysForEmployee(EmployeeModel employee) =>
      duplicateKeysFor(email: employee.email, mobileNumber: employee.mobileNumber);

  static List<String> duplicateContactKeysForAdmin(AdminModel admin) =>
      duplicateKeysFor(email: admin.email, mobileNumber: admin.mobileNumber);

  static Future<List<EmployeeModel>> getAllEmployeesForDuplicateCheck() async {
    try {
      await ApiLookup.ensure();
      return (await _userRows(userType: 'employee')).map(ApiMappers.employee).toList();
    } catch (e, st) {
      _fail('Error fetching employees', e, st);
    }
  }

  /// The API only exposes the caller's own company, so "global" == company.
  static Future<List<EmployeeModel>> getAllEmployeesGlobalForDuplicateCheck() =>
      getAllEmployeesForDuplicateCheck();

  static Future<List<AdminModel>> getAllAdminsGlobalForDuplicateCheck() async {
    try {
      return (await _userRows(userType: 'admin')).map(ApiMappers.admin).toList();
    } catch (e, st) {
      _fail('Error fetching admins', e, st);
    }
  }

  static Future<void> createEmployee({required EmployeeModel employee}) async {
    try {
      await ApiLookup.ensure();
      (await EmployeesApiService.create(ApiMappers.employeeBody(employee))).ensureSuccess();
      ApiLive.changed({'employee', 'role'});
    } catch (e, st) {
      _fail('Error creating employee', e, st);
    }
  }

  static Future<void> editEmployee({
    required String uid,
    required EmployeeModel employee,
  }) async {
    try {
      await ApiLookup.ensure();
      (await EmployeesApiService.update(uid, ApiMappers.employeeBody(employee))).ensureSuccess();
      ApiLive.changed({'employee', 'role'});
    } catch (e, st) {
      _fail('Error updating employee', e, st);
    }
  }

  static Future<EmployeeModel?> getEmployee({required String uid}) async {
    try {
      if (uid.isEmpty) return null;
      final row = await _userRow(uid);
      if (row == null || ApiMappers.isAdminRow(row)) return null;
      await ApiLookup.ensure();
      return ApiMappers.employee(row);
    } catch (e, st) {
      _fail('Error getting employee', e, st);
    }
  }

  static Future<List<EmployeeModel>> getAllEmployees({bool? excludeCurrentUser}) async {
    try {
      await ApiLookup.ensure();
      final me = (excludeCurrentUser ?? false) ? await Spdb.getUid() : null;
      final list = (await _userRows(userType: 'employee'))
          .where((r) => Js.b(r['is_active'], true) && (me == null || Js.s(r['uid']) != me))
          .map(ApiMappers.employee)
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e, st) {
      _fail('Error fetching employees', e, st);
    }
  }

  /// The API can only replace a photo with another path; "removing" sets the
  /// default avatar. The old file stays on the server (upload.php has no
  /// delete endpoint).
  static Future<void> deleteEmployeeImage({required String uid}) async {
    try {
      final me = await Spdb.getUid();
      if (uid == me) {
        (await AuthApiService.removeMyAvatar()).ensureSuccess();
      } else {
        final row = await _userRow(uid);
        if (row == null) return;
        (await EmployeesApiService.update(uid, ApiMappers.rowToUpdateBody(row, profileImage: 'assets/images/user.png'))).ensureSuccess();
      }
      ApiLive.changed('employee');
    } catch (e, st) {
      _fail('Error deleting employee image', e, st);
    }
  }

  static Future<List<String>> getEmployeeWorkflow() async {
    try {
      final workflow = <String>[];
      final currentUid = await Spdb.getUid();
      String? uid = currentUid;
      final visited = <String>{};
      while (uid != null && uid.isNotEmpty) {
        if (!visited.add(uid)) break;
        final employee = await getEmployee(uid: uid);
        if (employee == null) break;
        if (employee.reportingTo != null && employee.reportingTo!.isNotEmpty) {
          workflow.addAll(employee.reportingTo!);
          uid = employee.reportingTo!.first;
        } else {
          uid = null;
        }
      }
      workflow.remove(currentUid);
      return workflow;
    } catch (e, st) {
      _fail('Error creating employee workflow', e, st);
    }
  }

  static Future<List<String>> getUserWorkflow({String? userId}) async {
    try {
      final workflow = <String>[];
      final currentUid = await Spdb.getUid();
      String? uid = userId ?? currentUid;
      final visited = <String>{};
      while (uid != null && uid.isNotEmpty) {
        if (!visited.add(uid)) break;
        final row = await _userRow(uid);
        if (row == null || ApiMappers.isAdminRow(row)) break;
        final rt = Js.strList(row['reporting_to']);
        if (rt.isEmpty) break;
        workflow.addAll(rt);
        uid = rt.first;
      }
      workflow.remove(currentUid);
      return workflow;
    } catch (e, st) {
      _fail('Error creating workflow', e, st);
    }
  }

  static Future<String?> getEmployeeById({required String employeeId}) async {
    try {
      for (final r in await _userRows(userType: 'employee')) {
        if (Js.s(r['employee_id']) == employeeId) return Js.s(r['uid']);
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      throw e is ApiException ? e.message : e.toString();
    }
  }

  /// True if the employee is tied to leads/deals/projects/tasks/chats.
  static Future<bool> isEmployeeAssigned(String employeeUid) async {
    try {
      final res = (await EmployeesApiService.checkAssigned(uid: employeeUid)).ensureSuccess();
      return Js.b(res.dataMap['assigned']);
    } catch (e, st) {
      ErrorService.recordError(e, st);
      debugPrint('Error checking employee assignment: $e\n$st');
      return false;
    }
  }

  static Future<void> deleteEmployee({required String uid}) async {
    try {
      (await EmployeesApiService.delete(uid)).ensureSuccess();
      ApiLive.changed({'employee', 'role'});
    } catch (e, st) {
      ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw e.toString();
    }
  }

  /// employees.php has a `restore` action (used by the trash screen).
  static Future<void> restoreEmployee(EmployeeModel employee) async {
    final uid = employee.uid;
    if (uid == null || uid.isEmpty) throw Exception('UID missing');
    try {
      (await EmployeesApiService.restore(uid)).ensureSuccess();
      ApiLive.changed({'employee', 'role'});
    } catch (e, st) {
      _fail('Error restoring employee', e, st);
    }
  }

  static Future<List<EmployeeModel>> getEmployeesByDepartment({required String depId}) async {
    try {
      await ApiLookup.ensure();
      final id = ApiLookup.idOf(ApiLookup.kDepartment, depId);
      final list = (await _userRows(userType: 'employee'))
          .where((r) => Js.i(r['department_id']) == id)
          .map(ApiMappers.employee)
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e, st) {
      _fail('Error fetching employees by department', e, st);
    }
  }
}
