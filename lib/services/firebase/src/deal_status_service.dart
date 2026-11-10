import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Deal status master – backed by masters.php?type=deal_status (no Firestore).
class DealStatusService {
  static const String _type = MasterTypes.dealStatus;

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

  static Map<String, dynamic> _body(DealStatusModel m) => {'name': m.name, 'description': m.description, 'color': ApiMappers.colorToServer(m.color), 'order_index': m.orderNumber, 'is_final': m.isFinal ? 1 : 0, 'is_move_to_deal': m.isMoveToDeal ? 1 : 0};

  static Future<void> createDealStatus({required DealStatusModel dealStatus}) async {
    try {
      (await MastersApiService.create(_type, _body(dealStatus))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editDealStatus({
    required String uid,
    required DealStatusModel dealStatus,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, _body(dealStatus))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<DealStatusModel> getDealStatus({required String uid}) async {
    try {
      final r = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (r.isEmpty) throw 'Deal status not found';
      return ApiMappers.dealStatus(r.first);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<DealStatusModel>> getAllDealStatus() async {
    try {
      return (await _rows()).map(ApiMappers.dealStatus).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server refuses to delete a deal status that is in use and says
  /// why, so no client-side pre-check is needed (deleteDealStatus surfaces it).
  static Future<bool> isDealStatusAssigned(String uid) async => false;

  static Future<void> deleteDealStatus({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restoreDealStatus(DealStatusModel item) async {
    throw 'Restoring a deleted deal status is not supported by the server yet.';
  }

  static Future<DealStatusModel> getByNameOrCreate({required String name}) async {
    try {
      final n = name.trim().toLowerCase();
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.dealStatus(r);
      }
      final admin = await Spdb.getUser();
      (await MastersApiService.create(_type, _body(DealStatusModel(
        name: name, description: '', color: 0xFF2E5EAA, orderNumber: 0, createdBy: admin,
      )))).ensureSuccess();
      ApiLive.changed(_type);
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.dealStatus(r);
      }
      throw 'Could not create deal status';
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<String?> checkDealStatusExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Deal status name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking deal status existence: $e';
    }
  }

  static Future<void> updateDealStatusReorder({required List<DealStatusModel> dealStatusList}) async {
    try {
      for (final m in dealStatusList) {
        if (m.uid == null) continue;
        (await MastersApiService.update(_type, m.uid!, _body(m))).ensureSuccess();
      }
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }
}
