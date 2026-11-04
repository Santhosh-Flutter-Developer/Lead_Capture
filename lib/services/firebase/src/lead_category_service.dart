import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class LeadCategoryService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createLeadCategory({
    required LeadCategoryModel leadCategory,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.leadCategory.name}',
        leadCategory.toMap(),
        activity: '${leadCategory.name} has been added as a lead category',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating leadCategory: $e';
    }
  }

  static Future<void> editLeadCategory({
    required String uid,
    required LeadCategoryModel leadCategory,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.leadCategory.name}',
        uid,
        leadCategory.toUpdateMap(),
        activity: '${leadCategory.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating leadCategory: $e';
    }
  }

  static Future<void> restoreLeadCategory(LeadCategoryModel category) async {
    var cid = await Spdb.getCid();

    final uid = category.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.leadCategory.name)
        .doc(uid)
        .set(category.toMap());
  }

  static Future<LeadCategoryModel> getLeadCategory({
    required String uid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var leadCategoryDoc = await firebase.users
          .doc(cid)
          .collection(Collections.leadCategory.name)
          .doc(uid)
          .get();

      if (leadCategoryDoc.exists) {
        var leadCategoryData = leadCategoryDoc.data();
        if (leadCategoryData != null) {
          var leadCategory = LeadCategoryModel.fromMap(
            leadCategoryDoc.id,
            leadCategoryData,
          );
          return leadCategory;
        } else {
          throw 'Lead Source data is empty';
        }
      } else {
        throw 'Lead Source not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating leadCategory: $e';
    }
  }

  static Future<List<LeadCategoryModel>> getAllLeadCategories() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leadCategory.name)
          .get();

      List<LeadCategoryModel> leadCategory = querySnapshot.docs.map((doc) {
        return LeadCategoryModel.fromMap(doc.id, doc.data());
      }).toList();

      return leadCategory;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching leadCategory: $e';
    }
  }

  static Future<bool> isLeadCategoryAssigned(String categoryUid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .where('leadCategory', isEqualTo: categoryUid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking lead category assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deleteLeadCategory({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leadCategory.name)
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
            'User has deleted an entry in ${Collections.leadCategory.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.leadCategory.name}',
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

  static Future<LeadCategoryModel> getByNameOrCreate({
    required String name,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final query = await firebase.users
          .doc(cid)
          .collection(Collections.leadCategory.name)
          .where('name', isEqualTo: name.encrypt)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return LeadCategoryModel.fromMap(doc.id, doc.data());
      }

      final newModel = LeadCategoryModel(
        name: name,
        createdBy: await Spdb.getUser(),
        description: '',
      );

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.leadCategory.name)
          .add(newModel.toMap());

      final createdDoc = await docRef.get();

      return LeadCategoryModel.fromMap(createdDoc.id, createdDoc.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error in getByNameOrCreate LeadCategory: $e\n$st");
      rethrow;
    }
  }

  static Future<String?> checkLeadCategoryExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leadCategory.name)
          .get();

      for (var doc in querySnapshot.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;

        var data = doc.data();
        if (data['name'] != null &&
            data['name'].toString().decrypt.trim().toLowerCase() ==
                name.trim().toLowerCase()) {
          return 'Lead Category name already exists';
        }
      }
      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return 'Error checking lead category existence: $e';
    }
  }
}
