import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Lead status master – backed by masters.php?type=lead_status (no Firestore).
class LeadStatusService {
  static const String _type = MasterTypes.leadStatus;

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

  static Map<String, dynamic> _body(LeadStatusModel m) => {'name': m.name, 'description': m.description, 'color': ApiMappers.colorToServer(m.color), 'order_index': m.orderNumber, 'is_final': m.isFinal ? 1 : 0, 'is_move_to_deal': m.isMoveToDeal ? 1 : 0};

  static Future<int> _nextOrder() async {
    var max = 0;
    for (final r in await _rows()) {
      final o = Js.i(r['order_index']) ?? 0;
      if (o > max) max = o;
    }
    return max + 1;
  }

  static Future<void> createLeadStatus({required LeadStatusModel leadStatus}) async {
    try {
      final body = _body(leadStatus);
      // order_index is assigned here (max + 1), as the old Firestore code did.
      body['order_index'] = await _nextOrder();
      (await MastersApiService.create(_type, body)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editLeadStatus({
    required String uid,
    required LeadStatusModel leadStatus,
  }) async {
    try {
      final body = _body(leadStatus);
      if ((leadStatus.orderNumber) <= 0) {
        // Edit forms don't carry the order: keep the stored one.
        for (final r in await _rows()) {
          if (Js.s(r['uid']) == uid) {
            body['order_index'] = Js.i(r['order_index']) ?? 0;
            break;
          }
        }
      }
      (await MastersApiService.update(_type, uid, body)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<LeadStatusModel> getLeadStatus({required String uid}) async {
    try {
      final r = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (r.isEmpty) throw 'Lead status not found';
      return ApiMappers.leadStatus(r.first);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<LeadStatusModel>> getAllLeadStatus() async {
    try {
      return (await _rows()).map(ApiMappers.leadStatus).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server refuses to delete a lead status that is in use and says
  /// why, so no client-side pre-check is needed (deleteLeadStatus surfaces it).
  static Future<bool> isLeadStatusAssigned(String uid) async => false;

  static Future<void> deleteLeadStatus({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restoreLeadStatus(LeadStatusModel item) async {
    throw 'Restoring a deleted lead status is not supported by the server yet.';
  }

  static Future<LeadStatusModel> getByNameOrCreate({required String name}) async {
    try {
      final n = name.trim().toLowerCase();
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadStatus(r);
      }
      final admin = await Spdb.getUser();
      (await MastersApiService.create(_type, _body(LeadStatusModel(
        name: name, description: '', color: 0xFF2E5EAA, orderNumber: 0, createdBy: admin,
      )))).ensureSuccess();
      ApiLive.changed(_type);
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.leadStatus(r);
      }
      throw 'Could not create lead status';
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<String?> checkLeadStatusExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Lead status name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking lead status existence: $e';
    }
  }

  static Future<void> updateLeadStatusReorder({required List<LeadStatusModel> leadStatusList}) async {
    try {
      for (final m in leadStatusList) {
        if (m.uid == null) continue;
        (await MastersApiService.update(_type, m.uid!, _body(m))).ensureSuccess();
      }
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<bool> hasFinalStatus({String? excludeUid}) async {
    final statuses = await getAllLeadStatus();
    return statuses.any((s) => s.isFinal && (excludeUid == null || s.uid != excludeUid));
  }
}