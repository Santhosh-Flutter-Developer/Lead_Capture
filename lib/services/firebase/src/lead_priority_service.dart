import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Lead priority master – backed by masters.php?type=lead_priority (no Firestore).
class LeadPriorityService {
  static const String _type = MasterTypes.leadPriority;

  static Future<List<Map<String, dynamic>>> _rows() async {
    final res = (await MastersApiService.list(_type)).ensureSuccess();
    return res.dataList.map(Js.m).toList();
  }

  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint("$e, $st");
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  static Map<String, dynamic> _body(LeadPriorityModel m) => {'name': m.name, 'description': m.description, 'color': ApiMappers.colorToServer(m.color)};

  static Future<void> createLeadPriority({required LeadPriorityModel leadPriority}) async {
    try {
      (await MastersApiService.create(_type, _body(leadPriority))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editLeadPriority({
    required String uid,
    required LeadPriorityModel leadPriority,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, _body(leadPriority))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<LeadPriorityModel> getLeadPriority({required String uid}) async {
    try {
      final r = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (r.isEmpty) throw 'Lead priority not found';
      return ApiMappers.leadPriority(r.first);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<LeadPriorityModel>> getAllLeadPriority() async {
    try {
      return (await _rows()).map(ApiMappers.leadPriority).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server refuses to delete a lead priority that is in use and says
  /// why, so no client-side pre-check is needed (deleteLeadPriority surfaces it).
  static Future<bool> isLeadPriorityAssigned(String uid) async => false;

  static Future<void> deleteLeadPriority({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restoreLeadPriority(LeadPriorityModel item) async {
    throw 'Restoring a deleted lead priority is not supported by the server yet.';
  }

  static Future<LeadPriorityModel> getByNameOrCreate({required String name}) async {
    try {
      final n = name.trim().toLowerCase();
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadPriority(r);
      }
      final admin = await Spdb.getUser();
      (await MastersApiService.create(_type, _body(LeadPriorityModel(
        name: name, description: '', color: 0xFFFFA000, createdBy: admin,
      )))).ensureSuccess();
      ApiLive.changed(_type);
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadPriority(r);
      }
      throw 'Could not create lead priority';
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<String?> checkLeadPriorityExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Lead priority name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking lead priority existence: $e';
    }
  }
}
