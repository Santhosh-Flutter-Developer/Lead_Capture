import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Tasks – backed by tasks.php (no Firestore). The server writes the activity
/// log and notifications. It has no task-history table or time-log write
/// action: history is returned empty and time logs are read-only.
class TaskService {
  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e\n$st');
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  static Map<String, dynamic> _body(TaskModel t) => {
    'task_name': t.taskName,
    'description': t.description,
    'deadline': t.deadline?.toIso8601String(),
    'deadline_required': t.deadlineRequired ? 1 : 0,
    'high_priority': t.highPriority ? 1 : 0,
    'status_summary_required': t.statusSummaryRequired ? 1 : 0,
    'assignees': t.assignees,
    'observers': t.observers,
    'participants': t.participants,
    'tags': t.tags,
    'reminder': t.reminder?.toIso8601String(),
    'project': t.project ?? '',
    'status': t.status ?? 'started',
    'attachment_ids': CrmMappers.attachmentIds(t.attachments),
  };

  static Future<void> createTask({required TaskModel task}) async {
    try {
      (await TasksApiService.call('create', _body(task))).ensureSuccess();
      ApiLive.changed('tasks');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> updateTask({required String uid, required TaskModel task}) async {
    try {
      (await TasksApiService.call('update', {'uid': uid, ..._body(task)})).ensureSuccess();
      ApiLive.changed({'tasks', 'task_$uid'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> deleteTask({required String uid}) async {
    try {
      (await TasksApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed({'tasks', 'trash'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> restoreTask(TaskModel task) async {
    throw 'Restoring a deleted task is not supported by the server yet.';
  }

  static Future<TaskModel> getTask({required String uid}) async {
    try {
      final res = (await TasksApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.task(res.dataMap);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<TaskModel>> getAllTasks() async {
    try {
      final res = (await TasksApiService.call('list')).ensureSuccess();
      return res.dataList.map((r) => CrmMappers.task(Js.m(r))).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Tasks the current user is involved in (assignee/creator/observer/participant).
  static Future<List<TaskModel>> getMyTasks() async {
    final uid = await Spdb.getUid();
    final all = await getAllTasks();
    if (await Spdb.isAdminLoggedIn()) return all;
    return all
        .where((t) =>
            t.assignees.contains(uid) ||
            t.createdBy.contains(uid) ||
            t.observers.contains(uid) ||
            t.participants.contains(uid))
        .toList();
  }

  static Future<void> _setStatus(String taskId, TaskStatus s) async {
    (await TasksApiService.call('update_status', {'uid': taskId, 'status': s.name})).ensureSuccess();
    ApiLive.changed({'tasks', 'task_$taskId'});
  }

  static Future<void> startTask({
    required String taskId,
    TaskStatus status = TaskStatus.inProgress,
  }) async {
    try {
      final uid = await Spdb.getUid();
      if (uid == null) throw 'User not logged in';
      if (await hasActiveTask(userId: uid, excludeTaskId: taskId)) {
        throw 'You already have an active task. Complete it first.';
      }
      await _setStatus(taskId, status);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<bool> hasActiveTask({required String userId, String? excludeTaskId}) async {
    try {
      final all = await getAllTasks();
      return all.any((t) =>
          t.uid != excludeTaskId &&
          t.assignees.contains(userId) &&
          t.hasStarted &&
          !t.completed &&
          t.status != 'onHold');
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return false;
    }
  }

  static Future<void> completeTask({required String taskId}) async {
    try {
      await _setStatus(taskId, TaskStatus.completed);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> updateTaskStatus({
    required String taskId,
    required TaskStatus newStatus,
  }) async {
    try {
      final uid = await Spdb.getUid();
      if (uid == null) throw 'User not logged in';
      final task = await getTask(uid: taskId);
      final current = task.currentStatus;
      if (current == newStatus) return;
      if (current == TaskStatus.completed) throw "Completed tasks can't be changed.";
      if (newStatus == TaskStatus.pending) throw "A started task can't go back to pending.";
      if (current == TaskStatus.pending &&
          (newStatus == TaskStatus.completed || newStatus == TaskStatus.onHold)) {
        throw newStatus == TaskStatus.completed
            ? 'Start the task before marking it as completed.'
            : 'Start the task before putting it on hold.';
      }
      if ((newStatus == TaskStatus.started || newStatus == TaskStatus.inProgress) &&
          (current == TaskStatus.pending || current == TaskStatus.onHold)) {
        if (await hasActiveTask(userId: uid, excludeTaskId: taskId)) {
          throw 'You already have an active task. Complete it first.';
        }
      }
      await _setStatus(taskId, newStatus);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  // ── Detail data (all in one `get`) ─────────────────────────────────────
  static Future<Map<String, dynamic>> _detail(String taskId) async =>
      (await TasksApiService.call('get', {'uid': taskId})).ensureSuccess().dataMap;

  static Stream<List<TaskTimeLogModel>> streamTimeLogs({
    required String cid,
    required String taskId,
  }) => ApiLive.watch({'task_$taskId'}, () async {
    final l = Js.mapList((await _detail(taskId))['time_logs']).map(CrmMappers.taskTimeLog).toList();
    l.sort((a, b) => a.startTime.compareTo(b.startTime));
    return l;
  });

  /// tasks.php keeps no per-task history table.
  static Stream<List<TaskHistoryModel>> streamTaskHistory({
    required String cid,
    required String taskId,
  }) => Stream.value(<TaskHistoryModel>[]);

  static Stream<List<TaskCommentModel>> streamComments({
    required String cid,
    required String taskId,
  }) => ApiLive.watch({'task_$taskId'}, () async {
    final l = Js.mapList((await _detail(taskId))['comments']).map(CrmMappers.taskComment).toList();
    l.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return l;
  });

  static Future<List<TaskHistoryModel>> getTaskHistory({required String taskId}) async =>
      <TaskHistoryModel>[];

  static Future<List<TaskCommentModel>> getComments({required String taskId}) async {
    try {
      return Js.mapList((await _detail(taskId))['comments']).map(CrmMappers.taskComment).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> addComment({required String taskId, required String comment}) async {
    try {
      (await TasksApiService.call('add_comment', {'task_uid': taskId, 'comment': comment})).ensureSuccess();
      ApiLive.changed('task_$taskId');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<int> getUserTaskCount({required String userId}) async {
    try {
      return (await getAllTasks()).where((t) => t.assignees.contains(userId)).length;
    } catch (e, st) {
      _fail(e, st);
    }
  }
}
