import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class TaskService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createTask({required TaskModel task}) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      if (!task.createdBy.contains(uid)) {
        task.createdBy.add(uid!);
      }

      final userDoc = firebase.users.doc(cid);
      final tasksRef = userDoc.collection(Collections.tasks.name);

      // Generate task number if not provided
      int taskNumber = task.taskNumber ?? 1;
      var lastTaskSnapshot = await tasksRef
          .orderBy('taskNumber', descending: true)
          .limit(1)
          .get();
      if (lastTaskSnapshot.docs.isNotEmpty) {
        taskNumber =
            (lastTaskSnapshot.docs.first.data()['taskNumber'] ?? 0) + 1;
      }

      var taskData = task.toMap();
      taskData['taskNumber'] = taskNumber;

      var taskDoc = await tasksRef.add(taskData);

      // Task History
      TaskHistoryModel taskHistoryModel = TaskHistoryModel(
        userId: uid ?? '',
        updateDisposition: 'Task Created',
      );

      await taskDoc
          .collection(Collections.taskHistory.name)
          .add(taskHistoryModel.toMap());

      // Who should be notified: an employee-created task notifies the
      // creator + every admin; an admin-created task notifies admins only.
      List<String> users = await NotificationRecipientService.forRecord(
        createdBy: task.taskCreatedBy,
      );

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Task : ${task.taskName}',
        body: 'New task created by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.task,
        payload: {'taskId': taskDoc.id},
      );

      PostNotificationService.sendNotification(model: notif);

      if (task.deadlineRequired && task.deadline != null) {
        ReminderService.createReminder(
          scheduledAt: task.deadline!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Task Deadline Reminder',
            body: 'Task "${task.taskName}" is due soon',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.task,
            payload: {'taskId': taskDoc.id},
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error creating task: $e';
    }
  }

  static Future<void> updateTask({
    required String uid,
    required TaskModel task,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var userId = await Spdb.getUid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.tasks.name}',
        uid,
        task.toUpdateMap(),
        activity: '${task.taskName} has been updated',
      );

      TaskHistoryModel taskHistoryModel = TaskHistoryModel(
        userId: userId ?? '',
        updateDisposition: 'Task Updated',
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(uid)
          .collection(Collections.taskHistory.name)
          .add(taskHistoryModel.toMap());

      List<String> users = [
        ...task.assignees,
        ...task.participants,
        ...task.createdBy,
        ...task.observers,
      ];

      users = users.toSet().toList();

      List<String> toUids = List<String>.from(users);
      List<String> fcmIds = [];

      for (var i in users) {
        fcmIds.addAll(await AuthService.getUserFcmIds(uid: i));
      }

      var user = await Spdb.getUser();

      var notif = NotificationModel(
        collectionId: await Spdb.getCid() ?? '',
        title: 'Task : ${task.taskName}',
        body: 'Task has updated by ${user.name}',
        toFcms: fcmIds,
        toUids: toUids,
        senderId: await Spdb.getUid(),
        type: NotificationType.task,
        payload: {'taskId': uid},
      );

      PostNotificationService.sendNotification(model: notif);
      if (task.deadlineRequired && task.deadline != null) {
        ReminderService.createReminder(
          scheduledAt: task.deadline!,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Task Deadline Reminder',
            body: 'Task "${task.taskName}" is due soon',
            toFcms: fcmIds,
            toUids: users,
            type: NotificationType.task,
            payload: {'taskId': uid},
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Error updating task: $e\n$st");
      await ErrorService.recordError(e, st);
      throw 'Error updating task: $e';
    }
  }

  // Delete task
  static Future<void> deleteTask({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
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
        activity: '${data['taskName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.tasks.name}',
        collection: '${Collections.users.name}/$cid/${Collections.tasks.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting task: $e';
    }
  }

  static Future<void> restoreTask(TaskModel task) async {
    try {
      final FirebaseConfig firebase = FirebaseConfig();
      final cid = await Spdb.getCid();

      await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(task.uid)
          .set(task.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // Get a single task
  static Future<TaskModel> getTask({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var doc = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(uid)
          .get();

      if (!doc.exists) throw 'Task not found';
      return TaskModel.fromMap(doc.id, doc.data()!);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching task: $e';
    }
  }

  // Get all tasks
  static Future<List<TaskModel>> getAllTasks() async {
    try {
      var cid = await Spdb.getCid();
      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .get();

      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching tasks: $e';
    }
  }

  static Future<void> startTask({
    required String taskId,
    TaskStatus status = TaskStatus.inProgress,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      if (uid == null) throw "User not logged in";

      final hasActive = await hasActiveTask(userId: uid, excludeTaskId: taskId);

      if (hasActive) {
        throw "You already have an active task. Complete it first.";
      }

      final startTime = DateTime.now();

      /// Update task main document
      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.tasks.name}',
        taskId,
        {
          "hasStarted": true,
          "completed": false,
          "status": status.name,
          "startedTime": startTime.millisecondsSinceEpoch,
        },
        activity: 'Task started',
      );

      /// Create time log
      await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection('taskTimeLogs')
          .add({
            "userId": uid,
            "startTime": startTime.millisecondsSinceEpoch,
            "endTime": null,
          });

      /// History
      TaskHistoryModel history = TaskHistoryModel(
        userId: uid,
        updateDisposition: 'Task Started',
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection(Collections.taskHistory.name)
          .add(history.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  static Future<bool> hasActiveTask({
    required String userId,
    String? excludeTaskId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .where('assignees', arrayContains: userId)
          .where('hasStarted', isEqualTo: true)
          .where('completed', isEqualTo: false)
          .get();

      // Tasks that are On Hold are paused, so they don't count as active.
      return snapshot.docs.any(
        (doc) => doc.id != excludeTaskId && doc.data()['status'] != 'onHold',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return false;
    }
  }

  static Future<void> completeTask({required String taskId}) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      final endTime = DateTime.now();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.tasks.name}',
        taskId,
        {
          "completed": true,
          "hasStarted": false,
          "status": TaskStatus.completed.name,
          "completedTime": endTime.millisecondsSinceEpoch,
        },
        activity: 'Task completed',
      );

      /// Close active time log
      final activeLog = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection('taskTimeLogs')
          .where('endTime', isNull: true)
          .limit(1)
          .get();

      if (activeLog.docs.isNotEmpty) {
        await activeLog.docs.first.reference.update({
          "endTime": endTime.millisecondsSinceEpoch,
        });
      }

      /// History
      TaskHistoryModel history = TaskHistoryModel(
        userId: uid ?? '',
        updateDisposition: 'Task Completed',
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection(Collections.taskHistory.name)
          .add(history.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw "Error completing task: $e";
    }
  }

  /// Moves a task to [newStatus] while keeping the existing workflow intact:
  /// - pending -> started / in progress   (uses [startTask]: active-task check,
  ///                                       time log, history)
  /// - started <-> in progress             (label change only)
  /// - started / in progress -> on hold    (pauses: closes the open time log)
  /// - on hold -> started / in progress    (resumes: opens a new time log)
  /// - any started task -> completed       (uses [completeTask])
  /// Completed tasks are final and cannot be changed.
  static Future<void> updateTaskStatus({
    required String taskId,
    required TaskStatus newStatus,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();
      if (uid == null) throw "User not logged in";

      final taskRef = firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId);

      // Always decide from the latest server state, not from what the screen
      // thinks the status is.
      final snap = await taskRef.get();
      final data = snap.data();
      if (!snap.exists || data == null) throw "Task not found";

      final task = TaskModel.fromMap(snap.id, data);
      final current = task.currentStatus;

      if (current == newStatus) return;
      if (current == TaskStatus.completed) {
        throw "Completed tasks can't be changed.";
      }
      if (newStatus == TaskStatus.pending) {
        throw "A started task can't go back to pending.";
      }

      switch (newStatus) {
        case TaskStatus.completed:
          if (current == TaskStatus.pending) {
            throw "Start the task before marking it as completed.";
          }
          await completeTask(taskId: taskId);
          return;

        case TaskStatus.onHold:
          if (current == TaskStatus.pending) {
            throw "Start the task before putting it on hold.";
          }
          final now = DateTime.now();

          await CommonService.update(
            '${Collections.users.name}/$cid/${Collections.tasks.name}',
            taskId,
            {"status": TaskStatus.onHold.name},
            activity: 'Task put on hold',
          );

          // Pause time tracking.
          final activeLog = await taskRef
              .collection('taskTimeLogs')
              .where('endTime', isNull: true)
              .limit(1)
              .get();
          if (activeLog.docs.isNotEmpty) {
            await activeLog.docs.first.reference.update({
              "endTime": now.millisecondsSinceEpoch,
            });
          }
          break;

        case TaskStatus.started:
        case TaskStatus.inProgress:
          if (current == TaskStatus.pending) {
            // First start: identical to the original "Start" flow.
            await startTask(taskId: taskId, status: newStatus);
            return;
          }

          if (current == TaskStatus.onHold) {
            // Resume: same one-active-task rule as a fresh start.
            final hasActive = await hasActiveTask(
              userId: uid,
              excludeTaskId: taskId,
            );
            if (hasActive) {
              throw "You already have an active task. Complete it first.";
            }

            await CommonService.update(
              '${Collections.users.name}/$cid/${Collections.tasks.name}',
              taskId,
              {"status": newStatus.name},
              activity: 'Task resumed',
            );

            await taskRef.collection('taskTimeLogs').add({
              "userId": uid,
              "startTime": DateTime.now().millisecondsSinceEpoch,
              "endTime": null,
            });
          } else {
            // started <-> in progress
            await CommonService.update(
              '${Collections.users.name}/$cid/${Collections.tasks.name}',
              taskId,
              {"status": newStatus.name},
              activity: 'Task status changed',
            );
          }
          break;

        case TaskStatus.pending:
          return;
      }

      await taskRef
          .collection(Collections.taskHistory.name)
          .add(
            TaskHistoryModel(
              userId: uid,
              updateDisposition:
                  'Status changed: ${current.label} → ${newStatus.label}',
            ).toMap(),
          );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  /// Work sessions (start/resume -> hold/complete) of a task, oldest first.
  static Stream<List<TaskTimeLogModel>> streamTimeLogs({
    required String cid,
    required String taskId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.tasks.name)
        .doc(taskId)
        .collection('taskTimeLogs')
        .orderBy('startTime')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TaskTimeLogModel.fromMap(d.data())).toList(),
        )
        .asBroadcastStream();
  }

  static Stream<List<TaskHistoryModel>> streamTaskHistory({
    required String cid,
    required String taskId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.tasks.name)
        .doc(taskId)
        .collection(Collections.taskHistory.name)
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TaskHistoryModel.fromMap(d.data())).toList(),
        )
        .asBroadcastStream(); // allows multiple listeners
  }

  static Stream<List<TaskCommentModel>> streamComments({
    required String cid,
    required String taskId,
  }) {
    return firebase.users
        .doc(cid)
        .collection(Collections.tasks.name)
        .doc(taskId)
        .collection(Collections.taskComments.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TaskCommentModel.fromMap(d.data())).toList(),
        )
        .asBroadcastStream(); // allows multiple listeners
  }

  static Future<List<TaskHistoryModel>> getTaskHistory({
    required String taskId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection(Collections.taskHistory.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((d) => TaskHistoryModel.fromMap(d.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting task history: $e';
    }
  }

  static Future<List<TaskCommentModel>> getComments({
    required String taskId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection(Collections.taskComments.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((d) => TaskCommentModel.fromMap(d.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting comments: $e';
    }
  }

  static Future<void> addComment({
    required String taskId,
    required String comment,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var uid = await Spdb.getUid();

      TaskCommentModel commentModel = TaskCommentModel(
        userId: uid ?? '',
        comment: comment,
        timestamp: DateTime.now(),
      );

      await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .doc(taskId)
          .collection(Collections.taskComments.name)
          .add(commentModel.toMap());
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error adding comment: $e';
    }
  }

  static Future<int> getUserTaskCount({required String userId}) async {
    try {
      var cid = await Spdb.getCid();

      var snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .where('assignees', arrayContains: userId)
          .get();

      return snapshot.docs.length;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error getting user task count: $e';
    }
  }
}