import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class ProjectUpdationService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<String> _collectionPath() async {
    final cid = await Spdb.getCid();
    return '${Collections.users.name}/$cid/${Collections.projectUpdations.name}';
  }

  /// Creates an updation and auto-generates its UPD-0001 style number.
  static Future<String> createUpdation({
    required ProjectUpdationModel updation,
  }) async {
    try {
      final cid = await Spdb.getCid();
      final ref = firebase.users
          .doc(cid)
          .collection(Collections.projectUpdations.name);

      var number = 1;
      final last = await ref
          .orderBy('updationNumber', descending: true)
          .limit(1)
          .get();
      if (last.docs.isNotEmpty) {
        number = (parseFirestoreInt(last.docs.first.data()['updationNumber']) ??
                0) +
            1;
      }

      final model = updation.copyWith(updationNumber: number);
      final doc = await CommonService.add(
        await _collectionPath(),
        model.toMap(),
        activity:
            '${model.updationCode} "${model.title}" has been added to ${model.projectName}',
      );
      return doc.id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('$e\n$st');
      throw 'Error creating project updation: $e';
    }
  }

  static Future<void> updateUpdation({
    required String uid,
    required ProjectUpdationModel updation,
  }) async {
    try {
      await CommonService.update(
        await _collectionPath(),
        uid,
        updation.toUpdateMap(),
        activity: '${updation.updationCode} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error updating project updation: $e';
    }
  }

  static Future<void> updateStatus({
    required String uid,
    required UpdationStatus status,
  }) async {
    try {
      await CommonService.update(await _collectionPath(), uid, {
        'status': status.name,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error updating status: $e';
    }
  }

  static Future<ProjectUpdationModel> getUpdation({required String uid}) async {
    final cid = await Spdb.getCid();
    final doc = await firebase.users
        .doc(cid)
        .collection(Collections.projectUpdations.name)
        .doc(uid)
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) throw 'Project updation not found';
    return ProjectUpdationModel.fromMap(doc.id, data);
  }

  static Future<List<ProjectUpdationModel>> getAllUpdations({
    String? projectId,
  }) async {
    try {
      final cid = await Spdb.getCid();
      Query<Map<String, dynamic>> query = firebase.users
          .doc(cid)
          .collection(Collections.projectUpdations.name);
      if (projectId != null && projectId.isNotEmpty) {
        query = query.where('projectId', isEqualTo: projectId);
      }
      final snap = await query.get();
      final list = snap.docs
          .map((d) => ProjectUpdationModel.fromMap(d.id, d.data()))
          .toList();
      list.sort(
        (a, b) => (b.updationNumber ?? 0).compareTo(a.updationNumber ?? 0),
      );
      // Follow Up set -> only that employee + admins see the updation.
      return FollowUpAccess.filterVisible(list, (u) => u.followUp);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching project updations: $e';
    }
  }

  static Future<void> deleteUpdation({required String uid}) async {
    try {
      final cid = await Spdb.getCid();
      final docRef = firebase.users
          .doc(cid)
          .collection(Collections.projectUpdations.name)
          .doc(uid);
      final snap = await docRef.get();
      final data = snap.data();
      if (data == null) throw 'Project updation not found';
      await TrashService.moveToTrash(
        docRef: docRef,
        docData: data,
        reason: 'user_deleted',
      );
      await docRef.delete();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting project updation: $e';
    }
  }

  static Future<void> restoreUpdation(ProjectUpdationModel updation) async {
    final cid = await Spdb.getCid();
    await firebase.users
        .doc(cid)
        .collection(Collections.projectUpdations.name)
        .doc(updation.uid)
        .set(updation.toMap());
  }
}