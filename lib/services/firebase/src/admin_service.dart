import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/models/models.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class AdminService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createAdmin({required AdminModel admin}) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.admins.name}',
        admin.toMap(),
        activity: '${admin.name} has been added as an admin',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error creating admin: $e";
    }
  }

  static Future<void> updateAdmin({
    required String id,
    required AdminModel data,
  }) async {
    try {
      var cid = await Spdb.getCid();

      // Check if document exists to decide activity message
      var docRef = firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .doc(id);
      var docSnap = await docRef.get();

      String activity = docSnap.exists
          ? '${data.name} has been updated'
          : '${data.name} has been added as an admin';

      // Use CommonService.add with merge to either create or update
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.admins.name}',
        data.toMap(),
        docId: id,
        activity: activity,
        merge: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error updating admin: $e";
    }
  }

  static Future<AdminModel?> getAdmin({required String uid}) async {
    try {
      if (uid.isEmpty) return null;
      var cid = await Spdb.getCid();
      var snap = await firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .doc(uid)
          .get();

      if (!snap.exists || snap.data() == null) {
        return null;
      }
      return AdminModel.fromMap(snap.id, snap.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error fetching admin: $e";
    }
  }

  static Future<List<AdminModel>> getAllAdmins({
    bool? excludeCurrentUser,
  }) async {
    try {
      var cid = await Spdb.getCid();
      Query<Map<String, dynamic>> query = firebase.users
          .doc(cid)
          .collection(Collections.admins.name);

      if (excludeCurrentUser ?? false) {
        var uid = await Spdb.getUid();
        query = query.where(FieldPath.documentId, isNotEqualTo: uid);
      }

      var querySnapshot = await query.get();

      return querySnapshot.docs.map((e) {
        return AdminModel.fromMap(e.id, e.data());
      }).toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error fetching admin list: $e";
    }
  }

  static Future<void> deleteAdminProfileImage({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .doc(uid)
          .get();

      var url = doc.data()?["profileImageUrl"];

      if (url != null) await StorageService.deleteImage(url);

      await firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .doc(uid)
          .update({"profileImageUrl": null});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error deleting admin profile image: $e";
    }
  }

  //  static Future<void> deleteAdmin({required String uid}) async {
  //   try {
  //     final firestore = FirebaseFirestore.instance;
  //     final cid = await Spdb.getCid();

  //     try {
  //       await _deleteAdminProfileImage(uid: uid);
  //     } catch (_) {}

  //     final ref = firestore
  //         .collection(Collections.users.name)
  //         .doc(cid)
  //         .collection(Collections.admins.name)
  //         .doc(uid);

  //     final snap = await ref.get();
  //     if (!snap.exists) return;

  //     final data = snap.data()!;

  //     try {
  //       await TrashService.moveToTrash(
  //         docRef: ref,
  //         docData: data,
  //         reason: 'user_deleted',
  //       );
  //     } catch (_) {}

  //     await ref.delete(); // ✅ actual delete

  //     try {
  //       final user = await Spdb.getUser();
  //       final log = ActivityLogModel(
  //         userData: user,
  //         activity: '${data['name']?.toString().decrypt ?? 'Admin'} deleted',
  //         description:
  //             'User deleted from ${Collections.admins.name}',
  //         collection:
  //             '${Collections.users.name}/$cid/${Collections.admins.name}',
  //         docId: uid,
  //       );

  //       await CommonService.add(
  //         '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
  //         log.toMap(),
  //       );
  //     } catch (_) {}
  //   } catch (e, st) {
  //     await ErrorService.recordError(e, st);
  //     debugPrint('Delete admin failed: $e');
  //   }
  // }

  static Future<void> deleteAdmin({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      await deleteAdminProfileImage(uid: uid);
      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .doc(uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${(data['name']).toString().decrypt} has been deleted',
        description: 'User has deleted an entry in ${Collections.admins.name}',
        collection: '${Collections.users.name}/$cid/${Collections.admins.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );

      docRef.reference.delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("$e, $st");
      throw "Error deleting admin: $e";
    }
  }
}
