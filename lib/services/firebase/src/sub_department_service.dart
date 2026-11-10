import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Sub department master – backed by masters.php?type=sub_department (no Firestore).
class SubDepartmentService {
  static const String _type = MasterTypes.subDepartment;

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

  static Future<void> createSubDepartment({required SubDepartmentModel subDepartment}) async {
    try {
      (await MastersApiService.create(_type, {'name': subDepartment.name, 'description': subDepartment.description, 'department': subDepartment.department})).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail('Error creating sub department', e, st);
    }
  }

  static Future<void> editSubDepartment({
    required String uid,
    required SubDepartmentModel subDepartment,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, {'name': subDepartment.name, 'description': subDepartment.description, 'department': subDepartment.department})).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail('Error updating sub department', e, st);
    }
  }

  static Future<SubDepartmentModel> getSubDepartment({required String uid}) async {
    try {
      final row = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (row.isEmpty) throw 'Sub department not found';
      return ApiMappers.subDepartment(row.first);
    } catch (e, st) {
      _fail('Error getting sub department', e, st);
    }
  }

  static Future<List<SubDepartmentModel>> getAllSubDepartments() async {
    try {
      return (await _rows()).map(ApiMappers.subDepartment).toList();
    } catch (e, st) {
      _fail('Error fetching subdepartments', e, st);
    }
  }

  static Future<List<SubDepartmentModel>> getSubDepartmentsByDepId({
    required String depId,
  }) async {
    final all = await getAllSubDepartments();
    return all.where((s) => s.department == depId).toList();
  }

  /// Returns a user-facing message if this sub department cannot be deleted
  /// (still assigned to an employee), otherwise null.
  static Future<String?> getSubDepartmentDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;
      await ApiLookup.ensure();
      final id = ApiLookup.idOf(ApiLookup.kSubDepartment, uid);
      if (id == null) return null;
      final emps = (await EmployeesApiService.list()).ensureSuccess().dataList.map(Js.m);
      if (emps.any((e) => Js.i(e['sub_department_id']) == id)) {
        return 'This sub department is already mapped to an employee. Please reassign or update that employee before deleting this sub department.';
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> deleteSubDepartment({required String uid}) async {
    try {
      final blocker = await getSubDepartmentDeletionBlocker(uid);
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
  static Future<void> restoreSubDepartment(SubDepartmentModel subDepartment) async {
    throw 'Restoring a deleted sub department is not supported by the server yet.';
  }

  static Future<String> getSubDepartmentByNameOrCreateSubDepartment({
    required String name,
    String? department,
  }) async {
    try {
      final rows = await _rows();
      for (final r in rows) {
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase() && (department == null || Js.s(r['department_uid']) == department)) {
          return Js.s(r['uid']);
        }
      }
      final res = (await MastersApiService.create(_type, {
        'name': name,
        'description': '', 'department': department,
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

  static Future<String?> checkSubDepartmentExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Sub department name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking sub department existence: $e';
    }
  }
}
