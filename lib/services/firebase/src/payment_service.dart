import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Payments – backed by payments.php (no Firestore).
class PaymentService {
  static Future<List<PaymentModel>> getAll() async {
    try {
      final res = (await PaymentsApiService.call('list')).ensureSuccess();
      final list = res.dataList.map((r) => CrmMappers.payment(Js.m(r))).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw 'Error fetching payments: $e';
    }
  }

  static Future<PaymentModel> get({required String uid}) async {
    try {
      final res = (await PaymentsApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.payment(res.dataMap);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw 'Error fetching payment: $e';
    }
  }

  static Future<void> _assertWithinDealValue(
    List<PaymentModel> lines, {
    Set<String> replacingUids = const {},
  }) async {
    final saved = await getAll();
    final all = <PaymentModel>[
      for (final p in saved)
        if (!replacingUids.contains(p.uid)) p,
      ...lines,
    ];
    // Each pool is limited on its own: lines without a project updation
    // share the deal value, lines of one updation share that updation's value.
    String keyOf(PaymentModel p) =>
        '${p.projectId}|${(p.updationId ?? '')}';
    double limitOf(PaymentModel p) =>
        (p.updationId ?? '').isEmpty ? p.dealValue : p.updationValue;
    final totals = <String, double>{};
    for (final p in all) {
      totals[keyOf(p)] = (totals[keyOf(p)] ?? 0) + p.allocatedValue;
    }
    for (final l in lines) {
      if ((totals[keyOf(l)] ?? 0) > limitOf(l) + 0.0001) {
        final what = (l.updationId ?? '').isEmpty
            ? 'the deal value'
            : 'the project updation value';
        throw 'Allocated value for "${l.projectName}" exceeds $what.';
      }
    }
  }

  static Map<String, dynamic> _line(PaymentModel l) => {
    if (l.uid != null && l.uid!.isNotEmpty) 'uid': l.uid,
    'client_id': l.clientId,
    'project_id': l.projectId,
    'master_company_id': l.companyId,
    'allocated_value': l.allocatedValue,
    'payment_mode': l.paymentMode,
    'upi_number': l.upiNumber ?? '',
    'updation_id': l.updationId,
    'updation_label': l.updationLabel,
    'updation_value': l.updationValue,
    'attachment_ids': CrmMappers.attachmentIds(l.attachments),
  };

  /// Saves a batch: lines with a uid are updated, the rest are created and
  /// [removeUids] are deleted (payments.php save_batch, one transaction).
  static Future<void> save({
    required List<PaymentModel> lines,
    List<String> removeUids = const [],
  }) async {
    try {
      await _assertWithinDealValue(
        lines,
        replacingUids: {
          ...removeUids,
          ...lines.map((l) => l.uid).whereType<String>(),
        },
      );
      (await PaymentsApiService.call('save_batch', {
        'lines': lines.map(_line).toList(),
        'removed_uids': removeUids,
      })).ensureSuccess();
      ApiLive.changed({'payments', 'deals'});
    } catch (e, st) {
      debugPrint('$e, $st');
      if (e is String && e.startsWith('Allocated value')) rethrow;
      await ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw 'Error saving payments: $e';
    }
  }

  static Future<void> delete({required String uid}) async {
    try {
      (await PaymentsApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'payments', 'trash'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw 'Error deleting payment: $e';
    }
  }

  /// payments.php has no restore action.
  static Future<void> restore(PaymentModel p) async {
    throw 'Restoring a deleted payment is not supported by the server yet.';
  }
}
