import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

class DesignationService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createDesignation({
    required DesignationModel designation,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.designations.name}',
        designation.toMap(),
        activity: '${designation.name} has been added as a designation',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating designation: $e';
    }
  }

  static Future<void> editDesignation({
    required String uid,
    required DesignationModel designation,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.designations.name}',
        uid,
        designation.toUpdateMap(),
        activity: '${designation.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating designation: $e';
    }
  }

  static Future<DesignationModel> getDesignation({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var designationDoc = await firebase.users
          .doc(cid)
          .collection(Collections.designations.name)
          .doc(uid)
          .get();

      if (designationDoc.exists) {
        var designationData = designationDoc.data();
        if (designationData != null) {
          var designation = DesignationModel.fromMap(
            designationDoc.id,
            designationData,
          );
          return designation;
        } else {
          throw 'Designation data is empty';
        }
      } else {
        throw 'Designation not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating designation: $e';
    }
  }

  static Future<List<DesignationModel>> getAllDesignations() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.designations.name)
          .get();

      List<DesignationModel> designations = querySnapshot.docs.map((doc) {
        return DesignationModel.fromMap(doc.id, doc.data());
      }).toList();

      return designations;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching designations: $e';
    }
  }

  /// Returns a user-facing message if this designation cannot be
  /// deleted (currently mapped to one or more employees), or null if
  /// it is safe to delete. Call this before showing a delete
  /// confirmation so the user only sees "are you sure?" when the
  /// delete can actually succeed.
  static Future<String?> getDesignationDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;

      var cid = await Spdb.getCid();
      var employeeAssignedDocs = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .where('designation', isEqualTo: uid)
          .limit(1)
          .get();

      if (employeeAssignedDocs.docs.isNotEmpty) {
        return 'This designation is already mapped to an employee. Please reassign or update that employee before deleting this designation.';
      }

      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return null;
    }
  }

  static Future<void> deleteDesignation({required String uid}) async {
    try {
      final blocker = await getDesignationDeletionBlocker(uid);
      if (blocker != null) {
        throw blocker;
      }

      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.designations.name)
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
            'User has deleted an entry in ${Collections.designations.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.designations.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<void> restoreDesignation(DesignationModel designation) async {
    var cid = await Spdb.getCid();

    final uid = designation.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.designations.name)
        .doc(uid)
        .set(designation.toMap());
  }

  static Future<String> getDesignationByNameOrCreateDesignation({
    required String name,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.designations.name)
          .get();

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data['name'].toString().decrypt.toLowerCase() ==
            name.toLowerCase()) {
          return doc.id;
        }
      }

      var designation = DesignationModel(
        name: name,
        description: '',
        createdBy: await Spdb.getUser(),
      );
      var newDoc = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.designations.name}',
        designation.toMap(),
        activity: '${designation.name} has been added as a designation',
      );

      return newDoc.id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<String?> checkDesignationExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.designations.name)
          .get();

      for (var doc in querySnapshot.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;
        
        var data = doc.data();
        if (data['name'] != null && 
            data['name'].toString().decrypt.trim().toLowerCase() ==
                name.trim().toLowerCase()) {
          return 'Designation name already exists';
        }
      }
      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return 'Error checking designation existence: $e';
    }
  }
}
