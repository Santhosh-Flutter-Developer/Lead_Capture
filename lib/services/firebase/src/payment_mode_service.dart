import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Payment mode master – backed by masters.php?type=payment_mode (no Firestore).
class PaymentModeService {
  static const String _type = MasterTypes.paymentMode;

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

  static Map<String, dynamic> _body(PaymentModeModel m) => {'name': m.name, 'description': m.description};

  static Future<void> createPaymentMode({required PaymentModeModel paymentMode}) async {
    try {
      (await MastersApiService.create(_type, _body(paymentMode))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editPaymentMode({
    required String uid,
    required PaymentModeModel paymentMode,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, _body(paymentMode))).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<PaymentModeModel> getPaymentMode({required String uid}) async {
    try {
      final r = (await _rows()).where((r) => Js.s(r['uid']) == uid);
      if (r.isEmpty) throw 'Payment mode not found';
      return ApiMappers.paymentMode(r.first);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<PaymentModeModel>> getAllPaymentMode() async {
    try {
      return (await _rows()).map(ApiMappers.paymentMode).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// The server refuses to delete a payment mode that is in use and says
  /// why, so no client-side pre-check is needed (deletePaymentMode surfaces it).
  static Future<bool> isPaymentModeAssigned(String uid) async => false;

  static Future<void> deletePaymentMode({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed(_type);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Trash restore is not exposed by masters.php (see MISSING_API_REQUIREMENTS.md).
  static Future<void> restorePaymentMode(PaymentModeModel item) async {
    throw 'Restoring a deleted payment mode is not supported by the server yet.';
  }

  static Future<PaymentModeModel> getByNameOrCreate({required String name}) async {
    try {
      final n = name.trim().toLowerCase();
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.paymentMode(r);
      }
      final admin = await Spdb.getUser();
      (await MastersApiService.create(_type, _body(PaymentModeModel(
        name: name, description: '', createdBy: admin,
      )))).ensureSuccess();
      ApiLive.changed(_type);
      for (final r in await _rows()) {
        if (Js.s(r['name']).trim().toLowerCase() == n) return ApiMappers.paymentMode(r);
      }
      throw 'Could not create payment mode';
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<String?> checkPaymentModeExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      for (final r in await _rows()) {
        if (excludeUid != null && Js.s(r['uid']) == excludeUid) continue;
        if (Js.s(r['name']).trim().toLowerCase() == name.trim().toLowerCase()) {
          return 'Payment mode name already exists';
        }
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return 'Error checking payment mode existence: $e';
    }
  }
}
