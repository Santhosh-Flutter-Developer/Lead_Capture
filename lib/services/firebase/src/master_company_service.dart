import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

/// CRUD for Master Companies (`users/{cid}/masterCompanies`).
class MasterCompanyService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static String _path(String? cid) =>
      '${Collections.users.name}/$cid/${Collections.masterCompanies.name}';

  static String _norm(String? v) => (v ?? '').trim().toLowerCase();

  static Future<List<MasterCompanyModel>> getAll() async {
    try {
      final cid = await Spdb.getCid();
      final snap = await firebase.users
          .doc(cid)
          .collection(Collections.masterCompanies.name)
          .get();
      final list = snap.docs
          .map((d) => MasterCompanyModel.fromMap(d.id, d.data()))
          .where((e) => e.companyName.trim().isNotEmpty)
          .toList();
      list.sort(
        (a, b) =>
            a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()),
      );
      return list;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching companies: $e';
    }
  }

  static Future<MasterCompanyModel> get({required String uid}) async {
    try {
      final cid = await Spdb.getCid();
      final doc = await firebase.users
          .doc(cid)
          .collection(Collections.masterCompanies.name)
          .doc(uid)
          .get();
      final data = doc.data();
      if (!doc.exists || data == null) throw 'Master company not found';
      return MasterCompanyModel.fromMap(doc.id, data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error loading company: $e';
    }
  }

  /// True when another company already has the same company name
  /// (or the same non-empty GST/VAT number).
  static Future<bool> isDuplicate({
    required MasterCompanyModel company,
    String? excludeUid,
  }) async {
    final all = await getAll();
    final name = _norm(company.companyName);
    final gst = _norm(company.gstVatNumber);
    return all.any(
      (c) =>
          c.uid != excludeUid &&
          (_norm(c.companyName) == name ||
              (gst.isNotEmpty && _norm(c.gstVatNumber) == gst)),
    );
  }

  static const _dupMsg =
      'This company already exists (matching company name or GST/VAT number).';

  static Future<String> create({required MasterCompanyModel company}) async {
    try {
      if (await isDuplicate(company: company)) throw _dupMsg;
      final cid = await Spdb.getCid();
      final ref = await CommonService.add(
        _path(cid),
        company.toMap(),
        activity: '${company.companyName} has been added as our company',
      );
      return ref.id;
    } catch (e, st) {
      debugPrint('$e, $st');
      if (e == _dupMsg) rethrow;
      await ErrorService.recordError(e, st);
      throw 'Error creating company: $e';
    }
  }

  static Future<void> edit({
    required String uid,
    required MasterCompanyModel company,
  }) async {
    try {
      if (await isDuplicate(company: company, excludeUid: uid)) throw _dupMsg;
      final cid = await Spdb.getCid();
      await CommonService.update(
        _path(cid),
        uid,
        company.toMap(),
        activity: '${company.companyName} has been updated',
      );
    } catch (e, st) {
      debugPrint('$e, $st');
      if (e == _dupMsg) rethrow;
      await ErrorService.recordError(e, st);
      throw 'Error updating company: $e';
    }
  }

  static Future<void> delete({required String uid}) async {
    try {
      final cid = await Spdb.getCid();
      final snap = await firebase.users
          .doc(cid)
          .collection(Collections.masterCompanies.name)
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
          activity: '${data['companyName'] ?? 'Company'} has been deleted',
          description:
              'User has deleted an entry in ${Collections.masterCompanies.name}',
          collection: _path(cid),
          docId: uid,
        ).toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting company: $e';
    }
  }

  static Future<void> restore(MasterCompanyModel company) async {
    final cid = await Spdb.getCid();
    final uid = company.uid;
    if (uid == null || uid.isEmpty) throw Exception('UID missing');
    await firebase.users
        .doc(cid)
        .collection(Collections.masterCompanies.name)
        .doc(uid)
        .set(company.toMap());
  }
}