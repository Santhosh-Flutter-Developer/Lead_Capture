import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Lead category master – backed by masters.php?type=lead_category (no Firestore).
class LeadCategoryService {
  static const String _type = MasterTypes.leadCategory;

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

  static Map<String, dynamic> _body(LeadCategoryModel m) => {'name': m.name, 'description': m.description};

  static Future<void> createLeadCategory({required LeadCategoryModel leadCategory}) async {
    try {
      (await MastersApiService.create(_type, _body(leadCategory))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editLeadCategory({
    required String uid,
    required LeadCategoryModel leadCategory,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, _body(leadCategory))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<LeadCategoryModel> getLeadCategory({required String uid}) async {
    try {
      final r = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (r.isEmpty) throw 'Lead category not found';
      return ApiMappers.leadCategory(r.first);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<LeadCategoryModel>> getAllLeadCategories() async {
    try {
      return (await _rows()).map(ApiMappers.leadCategory).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server refuses to delete a lead category that is in use and says
  /// why, so no client-side pre-check is needed (deleteLeadCategory surfaces it).
  static Future<bool> isLeadCategoryAssigned(String uid) async => false;

  static Future<void> deleteLeadCategory({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restoreLeadCategory(LeadCategoryModel item) async {
    throw 'Restoring a deleted lead category is not supported by the server yet.';
  }

  static Future<LeadCategoryModel> getByNameOrCreate({required String name}) async {
    try {
      final n = name.trim().toLowerCase();
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadCategory(r);
      }
      final admin = await Spdb.getUser();
      (await MastersApiService.create(_type, _body(LeadCategoryModel(
        name: name, description: '', createdBy: admin,
      )))).ensureSuccess();
      ApiLive.changed(_type);
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadCategory(r);
      }
      throw 'Could not create lead category';
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<String?> checkLeadCategoryExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Lead category name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking lead category existence: $e';
    }
  }
}
