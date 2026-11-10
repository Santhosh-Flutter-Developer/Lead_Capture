import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Designation master – backed by masters.php?type=designation (no Firestore).
class DesignationService {
  static const String _type = MasterTypes.designation;

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

  static Future<void> createDesignation({required DesignationModel designation}) async {
    try {
      (await MastersApiService.create(_type, {'name': designation.name, 'description': designation.description})).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail('Error creating designation', e, st);
    }
  }

  static Future<void> editDesignation({
    required String uid,
    required DesignationModel designation,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, {'name': designation.name, 'description': designation.description})).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail('Error updating designation', e, st);
    }
  }

  static Future<DesignationModel> getDesignation({required String uid}) async {
    try {
      final row = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (row.isEmpty) throw 'Designation not found';
      return ApiMappers.designation(row.first);
    } catch (e, st) {
      _fail('Error getting designation', e, st);
    }
  }

  static Future<List<DesignationModel>> getAllDesignations() async {
    try {
      return (await _rows()).map(ApiMappers.designation).toList();
    } catch (e, st) {
      _fail('Error fetching designations', e, st);
    }
  }

  /// Returns a user-facing message if this designation cannot be deleted
  /// (still assigned to an employee), otherwise null.
  static Future<String?> getDesignationDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;
      await ApiLookup.ensure();
      final id = ApiLookup.idOf(ApiLookup.kDesignation, uid);
      if (id == null) return null;
      final emps = (await EmployeesApiService.list()).ensureSuccess().dataList.map(Js.m);
      if (emps.any((e) => Js.i(e['designation_id']) == id)) {
        return 'This designation is already mapped to an employee. Please reassign or update that employee before deleting this designation.';
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> deleteDesignation({required String uid}) async {
    try {
      final blocker = await getDesignationDeletionBlocker(uid);
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
  static Future<void> restoreDesignation(DesignationModel designation) async {
    throw 'Restoring a deleted designation is not supported by the server yet.';
  }

  static Future<String> getDesignationByNameOrCreateDesignation({
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

  static Future<String?> checkDesignationExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Designation name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking designation existence: $e';
    }
  }
}
