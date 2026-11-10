import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Lead source master – backed by masters.php?type=lead_source (no Firestore).
class LeadSourceService {
  static const String _type = MasterTypes.leadSource;

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

  static Map<String, dynamic> _body(LeadSourceModel m) => {'name': m.name, 'description': m.description};

  static Future<void> createLeadSource({required LeadSourceModel leadSource}) async {
    try {
      (await MastersApiService.create(_type, _body(leadSource))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editLeadSource({
    required String uid,
    required LeadSourceModel leadSource,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, _body(leadSource))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<LeadSourceModel> getLeadSource({required String uid}) async {
    try {
      final r = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (r.isEmpty) throw 'Lead source not found';
      return ApiMappers.leadSource(r.first);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<LeadSourceModel>> getAllLeadSource() async {
    try {
      return (await _rows()).map(ApiMappers.leadSource).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server refuses to delete a lead source that is in use and says
  /// why, so no client-side pre-check is needed (deleteLeadSource surfaces it).
  static Future<bool> isLeadSourceAssigned(String uid) async => false;

  static Future<void> deleteLeadSource({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restoreLeadSource(LeadSourceModel item) async {
    throw 'Restoring a deleted lead source is not supported by the server yet.';
  }

  static Future<LeadSourceModel> getByNameOrCreate({required String name}) async {
    try {
      final n = name.trim().toLowerCase();
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadSource(r);
      }
      final admin = await Spdb.getUser();
      (await MastersApiService.create(_type, _body(LeadSourceModel(
        name: name, description: '', createdBy: admin,
      )))).ensureSuccess();
      ApiLive.changed(_type);
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadSource(r);
      }
      throw 'Could not create lead source';
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<String?> checkLeadSourceExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Lead source name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking lead source existence: $e';
    }
  }
}
