import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

/// CRUD for Payments (`users/{cid}/payments`). Each document is one
/// allocation line; a deal's lines together never exceed its deal value.
class PaymentService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static String _path(String? cid) =>
      '${Collections.users.name}/$cid/${Collections.payments.name}';

  static Future<List<PaymentModel>> getAll() async {
    try {
      final cid = await Spdb.getCid();
      final snap = await firebase.users
          .doc(cid)
          .collection(Collections.payments.name)
          .get();
      final list = snap.docs
          .map((d) => PaymentModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching payments: $e';
    }
  }

  static Future<PaymentModel> get({required String uid}) async {
    try {
      final cid = await Spdb.getCid();
      final doc = await firebase.users
          .doc(cid)
          .collection(Collections.payments.name)
          .doc(uid)
          .get();
      final data = doc.data();
      if (!doc.exists || data == null) throw 'Payment not found';
      return PaymentModel.fromMap(doc.id, data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error loading payment: $e';
    }
  }

  /// Validates that, per deal, the allocated total (saved lines that are not
  /// being replaced + [lines]) stays within the deal value.
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

  /// Saves a batch: lines with a uid are updated, the rest are created and
  /// [removeUids] are deleted. All lines are checked against the deal value.
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
      final cid = await Spdb.getCid();
      for (final uid in removeUids) {
        await delete(uid: uid);
      }
      for (final l in lines) {
        if (l.uid != null && l.uid!.isNotEmpty) {
          await CommonService.update(
            _path(cid),
            l.uid!,
            l.copyWith(updatedAt: DateTime.now()).toMap(),
            activity: 'Payment for ${l.projectName} has been updated',
          );
        } else {
          await CommonService.add(
            _path(cid),
            l.toMap(),
            activity: 'Payment for ${l.projectName} has been added',
          );
        }
      }
    } catch (e, st) {
      debugPrint('$e, $st');
      if (e is String && e.startsWith('Allocated value')) rethrow;
      await ErrorService.recordError(e, st);
      throw 'Error saving payments: $e';
    }
  }

  static Future<void> delete({required String uid}) async {
    try {
      final cid = await Spdb.getCid();
      final snap = await firebase.users
          .doc(cid)
          .collection(Collections.payments.name)
          .doc(uid)
          .get();
      final data = snap.data();
      if (data == null) return;
      await TrashService.moveToTrash(
        docRef: snap.reference,
        docData: data,
        reason: 'user_deleted',
      );
      await snap.reference.delete();
      final user = await Spdb.getUser();
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        ActivityLogModel(
          userData: user,
          activity:
              'Payment for ${data['projectName'] ?? 'a project'} has been deleted',
          description:
              'User has deleted an entry in ${Collections.payments.name}',
          collection: _path(cid),
          docId: uid,
        ).toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting payment: $e';
    }
  }

  static Future<void> restore(PaymentModel p) async {
    final cid = await Spdb.getCid();
    final uid = p.uid;
    if (uid == null || uid.isEmpty) throw Exception('UID missing');
    await firebase.users
        .doc(cid)
        .collection(Collections.payments.name)
        .doc(uid)
        .set(p.toMap());
  }
}