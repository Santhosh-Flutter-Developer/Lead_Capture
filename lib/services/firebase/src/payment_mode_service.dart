import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class PaymentModeService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createPaymentMode({
    required PaymentModeModel paymentMode,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.paymentMode.name}',
        paymentMode.toMap(),
        activity: '${paymentMode.name} has been added as a payment mode',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating paymentMode: $e';
    }
  }

  static Future<void> editPaymentMode({
    required String uid,
    required PaymentModeModel paymentMode,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.paymentMode.name}',
        uid,
        paymentMode.toUpdateMap(),
        activity: '${paymentMode.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating paymentMode: $e';
    }
  }

  static Future<PaymentModeModel> getPaymentMode({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var paymentModeDoc = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .doc(uid)
          .get();

      if (paymentModeDoc.exists) {
        var paymentModeData = paymentModeDoc.data();
        if (paymentModeData != null) {
          var paymentMode = PaymentModeModel.fromMap(
            paymentModeDoc.id,
            paymentModeData,
          );
          return paymentMode;
        } else {
          throw 'Payment Mode data is empty';
        }
      } else {
        throw 'Payment Mode not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating paymentMode: $e';
    }
  }

  static Future<List<PaymentModeModel>> getAllPaymentMode() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .get();

      List<PaymentModeModel> paymentMode = querySnapshot.docs.map((doc) {
        return PaymentModeModel.fromMap(doc.id, doc.data());
      }).toList();

      return paymentMode;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching paymentMode: $e';
    }
  }

  /// True when any payment already uses this payment mode (payments store
  /// the mode by name).
  static Future<bool> isPaymentModeAssigned(String modeUid) async {
    try {
      var cid = await Spdb.getCid();
      final modeDoc = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .doc(modeUid)
          .get();
      final data = modeDoc.data();
      if (data == null || data['name'] is! String) return false;
      final name = (data['name'] as String).decrypt;

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.payments.name)
          .where('paymentMode', isEqualTo: name)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking payment mode assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deletePaymentMode({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['name'].toString().decrypt} has been deleted',
        description:
            'User has deleted an entry in ${Collections.paymentMode.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.paymentMode.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error deleting payment mode: $e';
    }
  }

  static Future<void> restorePaymentMode(PaymentModeModel source) async {
    var cid = await Spdb.getCid();

    final uid = source.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.paymentMode.name)
        .doc(uid)
        .set(source.toMap());
  }

  static Future<PaymentModeModel> getByNameOrCreate({
    required String name,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final query = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .where('name', isEqualTo: name.encrypt)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return PaymentModeModel.fromMap(doc.id, doc.data());
      }

      final newModel = PaymentModeModel(
        name: name,
        createdBy: await Spdb.getUser(),
        description: '',
      );

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .add(newModel.toMap());

      final createdDoc = await docRef.get();

      return PaymentModeModel.fromMap(createdDoc.id, createdDoc.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error in getByNameOrCreate PaymentMode: $e\n$st");
      rethrow;
    }
  }

  static Future<String?> checkPaymentModeExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.paymentMode.name)
          .get();

      for (var doc in querySnapshot.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;

        var data = doc.data();
        if (data['name'] != null &&
            data['name'].toString().decrypt.trim().toLowerCase() ==
                name.trim().toLowerCase()) {
          return 'Payment Mode name already exists';
        }
      }
      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return 'Error checking payment mode existence: $e';
    }
  }
}