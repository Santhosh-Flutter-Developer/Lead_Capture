import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class ProjectService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<bool> checkProjectCodeExists({
    required String code,
    String? uid,
  }) async {
    try {
      var projectCode = code.trim();
      if (projectCode.isEmpty) return false;

      var cid = await Spdb.getCid();

      var query = firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .where('projectCode', isEqualTo: projectCode);

      if (uid != null && uid.isNotEmpty) {
        query = query.where(FieldPath.documentId, isNotEqualTo: uid);
      }

      var snap = await query.get();

      return snap.docs.isNotEmpty;
    } catch (e, st) {
      debugPrint("$e\n$st");
      rethrow;
    }
  }

  static Future<void> createProject({required ProjectModel project}) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      var projectDoc = await firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .add(project.toMap());

      // Collect Users
      List<String> users = [
        ...project.members,
        project.projectOwner,
        project.teamLead,
      ];

      if (project.client != null && project.client!.isNotEmpty) {
        users.add(project.client!);
      }

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Project : ${project.projectName}',
        body: 'New project created by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.project,
        payload: {'projectId': projectDoc.id},
      );

      PostNotificationService.sendNotification(model: notif);

      if (project.deadline != null) {
        ReminderService.createReminder(
          docId: projectDoc.id,
          scheduledAt: project.deadline!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Project Deadline Reminder',
            body: 'Project "${project.projectName}" is due soon',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.project,
            payload: {'projectId': projectDoc.id},
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating project: $e';
    }
  }

  static Future<void> editProject({
    required String uid,
    required ProjectModel project,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.projects.name}',
        uid,
        project.toUpdateMap(),
        activity: '${project.projectName} has been updated',
      );

      // Collect Users
      List<String> users = [
        ...project.members,
        project.projectOwner,
        project.teamLead,
      ];

      if (project.client != null && project.client!.isNotEmpty) {
        users.add(project.client!);
      }

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Project : ${project.projectName}',
        body: 'Project has updated by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.project,
        payload: {'projectId': uid},
      );

      PostNotificationService.sendNotification(model: notif);

      if (project.deadline != null) {
        ReminderService.createReminder(
          docId: uid,
          scheduledAt: project.deadline!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Project Deadline Reminder',
            body: 'Project "${project.projectName}" is due soon',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.project,
            payload: {'projectId': uid},
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating project: $e';
    }
  }

  static Future<ProjectModel> getProject({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var projectDoc = await firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .doc(uid)
          .get();

      if (projectDoc.exists) {
        var projectData = projectDoc.data();
        if (projectData != null) {
          var project = ProjectModel.fromMap(projectDoc.id, projectData);
          return project;
        } else {
          throw 'Project data is empty';
        }
      } else {
        throw 'Project not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating project: $e';
    }
  }

  static Future<List<ProjectModel>> getAllProjects() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .get();

      List<ProjectModel> projects = querySnapshot.docs.map((doc) {
        return ProjectModel.fromMap(doc.id, doc.data());
      }).toList();

      projects.sort((a, b) => a.projectName.compareTo(b.projectName));

      return projects;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching projects: $e';
    }
  }

  static Future<bool> isProjectAssigned(String uid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .where('project', isEqualTo: uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking project assignment: $e\n$st");
      return false;
    }
  }

  static Future<void> deleteProject({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['projectName'] ?? 'N/A'} has been deleted',
        description:
            'User has deleted an entry in ${Collections.projects.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.projects.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting project: $e\n$st");
      throw 'Error deleting project: $e';
    }
  }

  static Future<void> restoreProject(ProjectModel project) async {
    var cid = await Spdb.getCid();

    final uid = project.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.projects.name)
        .doc(uid)
        .set(project.toMap());
  }

  static Future<int> getUserProjectsCount({required String userId}) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .where('members', arrayContains: userId)
          .get();

      return snapshot.docs.length;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting user project count: $e';
    }
  }
}
