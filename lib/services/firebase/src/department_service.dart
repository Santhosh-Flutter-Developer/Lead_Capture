import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Department master – backed by masters.php?type=department (no Firestore).
class DepartmentService {
  static const String _type = MasterTypes.department;

  static Future<List<Map<String, dynamic>>> _rows() async {
    final res = (await MastersApiService.list(_type)).ensureSuccess();
    return res.dataList.map(Js.m).toList();
  }

  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint("$e, $st");
    if (e is ApiException) throw e.message;
    throw '$prefix: $e';
  }

  static Future<void> createDepartment({required DepartmentModel department}) async {
    try {
      (await MastersApiService.create(_type, {'name': department.name, 'description': department.description})).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail('Error creating department', e, st);
    }
  }

  static Future<void> editDepartment({
    required String uid,
    required DepartmentModel department,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, {'name': department.name, 'description': department.description})).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail('Error updating department', e, st);
    }
  }

  static Future<DepartmentModel> getDepartment({required String uid}) async {
    try {
      final row = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (row.isEmpty) throw 'Department not found';
      return ApiMappers.department(row.first);
    } catch (e, st) {
      _fail('Error getting department', e, st);
    }
  }

  static Future<List<DepartmentModel>> getAllDepartments() async {
    try {
      return (await _rows()).map(ApiMappers.department).toList();
    } catch (e, st) {
      _fail('Error fetching departments', e, st);
    }
  }

  /// Returns a user-facing message if this department cannot be deleted
  /// (still assigned to an employee), otherwise null.
  static Future<String?> getDepartmentDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;
      await ApiLookup.ensure();
      final id = ApiLookup.idOf(ApiLookup.kDepartment, uid);
      if (id == null) return null;
      final emps = (await EmployeesApiService.list()).ensureSuccess().dataList.map(Js.m);
      if (emps.any((e) => Js.i(e['department_id']) == id)) {
        return 'This department is already mapped to an employee. Please reassign or update that employee before deleting this department.';
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> deleteDepartment({required String uid}) async {
    try {
      final blocker = await getDepartmentDeletionBlocker(uid);
      if (blocker != null) throw blocker;
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw e.toString();
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restoreDepartment(DepartmentModel department) async {
    throw 'Restoring a deleted department is not supported by the server yet.';
  }

  static Future<String> getDepartmentByNameOrCreateDepartment({
    required String name,
  }) async {
    try {
      final rows = await _rows();
      for (final r in rows) {
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return Js.s(r['uid']);
        }
      }
      final res = (await MastersApiService.create(_type, {
        'name': name,
        'description': '',
      })).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
      return Js.s(res.dataMap['uid']);
    } catch (e, st) {
      ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw e.toString();
    }
  }

  static Future<String?> checkDepartmentExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Department name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking department existence: $e';
    }
  }
}
