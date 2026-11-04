import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class LeadSourceService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createLeadSource({
    required LeadSourceModel leadSource,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.leadSource.name}',
        leadSource.toMap(),
        activity: '${leadSource.name} has been added as a lead category',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating leadSource: $e';
    }
  }

  static Future<void> editLeadSource({
    required String uid,
    required LeadSourceModel leadSource,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.leadSource.name}',
        uid,
        leadSource.toUpdateMap(),
        activity: '${leadSource.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating leadSource: $e';
    }
  }

  static Future<LeadSourceModel> getLeadSource({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var leadSourceDoc = await firebase.users
          .doc(cid)
          .collection(Collections.leadSource.name)
          .doc(uid)
          .get();

      if (leadSourceDoc.exists) {
        var leadSourceData = leadSourceDoc.data();
        if (leadSourceData != null) {
          var leadSource = LeadSourceModel.fromMap(
            leadSourceDoc.id,
            leadSourceData,
          );
          return leadSource;
        } else {
          throw 'Lead Source data is empty';
        }
      } else {
        throw 'Lead Source not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating leadSource: $e';
    }
  }

  static Future<List<LeadSourceModel>> getAllLeadSource() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leadSource.name)
          .get();

      List<LeadSourceModel> leadSource = querySnapshot.docs.map((doc) {
        return LeadSourceModel.fromMap(doc.id, doc.data());
      }).toList();

      return leadSource;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching leadSource: $e';
    }
  }

  static Future<bool> isLeadSourceAssigned(String categoryUid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .where('leadSource', isEqualTo: categoryUid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking lead category assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deleteLeadSource({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leadSource.name)
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
            'User has deleted an entry in ${Collections.leadSource.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.leadSource.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error deleting lead category: $e';
    }
  }

  static Future<void> restoreLeadSource(LeadSourceModel source) async {
    var cid = await Spdb.getCid();

    final uid = source.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.leadSource.name)
        .doc(uid)
        .set(source.toMap());
  }

  static Future<LeadSourceModel> getByNameOrCreate({
    required String name,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final query = await firebase.users
          .doc(cid)
          .collection(Collections.leadSource.name)
          .where('name', isEqualTo: name.encrypt)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return LeadSourceModel.fromMap(doc.id, doc.data());
      }

      final newModel = LeadSourceModel(
        name: name,
        createdBy: await Spdb.getUser(),
        description: '',
      );

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leadSource.name)
          .add(newModel.toMap());

      final createdDoc = await docRef.get();

      return LeadSourceModel.fromMap(createdDoc.id, createdDoc.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error in getByNameOrCreate LeadSource: $e\n$st");
      rethrow;
    }
  }

  static Future<String?> checkLeadSourceExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leadSource.name)
          .get();

      for (var doc in querySnapshot.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;

        var data = doc.data();
        if (data['name'] != null &&
            data['name'].toString().decrypt.trim().toLowerCase() ==
                name.trim().toLowerCase()) {
          return 'Lead Source name already exists';
        }
      }
      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return 'Error checking lead source existence: $e';
    }
  }
}
