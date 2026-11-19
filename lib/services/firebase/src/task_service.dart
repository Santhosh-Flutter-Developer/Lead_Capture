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

  /// [create] sends the initial status (a new task starts as `pending`).
  /// On update the status is NOT sent, so editing a task never changes its
  /// status (status changes go through update_status only).
  static Map<String, dynamic> _body(TaskModel t, {bool create = false}) => {
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
    if (create) 'status': t.status ?? 'pending',
    'lead': t.lead ?? '',
    'sub_task_of': t.subTaskOf ?? '',
    if (t.createdBy.isNotEmpty) 'created_by': t.createdBy.first,
    'attachment_ids': CrmMappers.attachmentIds(t.attachments),
  };

  static Future<void> createTask({required TaskModel task}) async {
    try {
      (await TasksApiService.call('create', _body(task, create: true))).ensureSuccess();
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

  /// "Delete" = Cancel with remarks (tasks.php `cancel`). The server refuses
  /// when the status was ever changed and keeps the task in the list.
  static Future<void> cancelTask({
    required String uid,
    required String remarks,
  }) async {
    try {
      if (remarks.trim().isEmpty) throw 'Cancellation remarks are required.';
      (await TasksApiService.call('cancel', {
        'uid': uid,
        'remarks': remarks.trim(),
      })).ensureSuccess();
      ApiLive.changed({'tasks', 'task_$uid'});
    } catch (e, st) {
      _fail(e, st);
    }
  }

  /// Bulk cancel (`bulk_cancel`). The server cancels only the tasks whose
  /// status was never changed and returns how many it cancelled in `message`.
  static Future<String> cancelTasks({
    required List<String> uids,
    required String remarks,
  }) async {
    try {
      if (remarks.trim().isEmpty) throw 'Cancellation remarks are required.';
      final res = (await TasksApiService.call('bulk_cancel', {
        'uids': uids,
        'remarks': remarks.trim(),
      })).ensureSuccess();
      ApiLive.changed('tasks');
      return res.message;
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> deleteTask({
    required String uid,
    String remarks = '',
  }) => cancelTask(uid: uid, remarks: remarks);

  /// Task Status master (Creation -> Task Status), ordered. The first one is
  /// the initial status.
  static Future<List<WorkflowStatus>> getStatuses() =>
      WorkflowStatusService.task.getAll();

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
          !t.isCancelled &&
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

  static String _normKey(String k) =>
      k.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();

  /// Moves the task to a master status picked from the dynamic dropdown.
  /// [statuses] is the ordered master list (first = initial status).
  /// Same rules as before: completed / cancelled are final, one active task
  /// per user, a task can't go back to the initial status.
  static Future<void> changeStatus({
    required String taskId,
    required WorkflowStatus target,
    required List<WorkflowStatus> statuses,
  }) async {
    try {
      final uid = await Spdb.getUid();
      if (uid == null) throw 'User not logged in';
      final task = await getTask(uid: taskId);
      if (task.isCancelled) throw 'Task is cancelled and its status cannot be changed.';
      if (task.completed) throw "Completed tasks can't be changed.";
      if (_normKey(task.status ?? '') == _normKey(target.statusKey)) return;

      final isInitial = statuses.isNotEmpty && statuses.first.uid == target.uid;
      final isHold = _normKey(target.statusKey) == 'onhold';
      final pending = task.currentStatus == TaskStatus.pending;
      final onHold = task.currentStatus == TaskStatus.onHold;

      if (isInitial) throw "A started task can't go back to ${target.name}.";
      if (pending && target.isFinal) {
        throw 'Start the task before marking it as completed.';
      }
      if (pending && isHold) throw 'Start the task before putting it on hold.';
      if (!target.isFinal && !isHold && (pending || onHold)) {
        if (await hasActiveTask(userId: uid, excludeTaskId: taskId)) {
          throw 'You already have an active task. Complete it first.';
        }
      }
      (await TasksApiService.call('update_status', {
        'uid': taskId,
        'status': target.statusKey,
      })).ensureSuccess();
      ApiLive.changed({'tasks', 'task_$taskId'});
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

  /// History = tasks.php `get` -> activity_history (activity log entries that
  /// mention this task: created / updated / status changes).
  static Stream<List<TaskHistoryModel>> streamTaskHistory({
    required String cid,
    required String taskId,
  }) => ApiLive.watch({'task_$taskId'}, () async {
    final l = Js.mapList((await _detail(taskId))['activity_history']).map(CrmMappers.taskHistory).toList();
    l.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return l;
  });

  static Stream<List<TaskCommentModel>> streamComments({
    required String cid,
    required String taskId,
  }) => ApiLive.watch({'task_$taskId'}, () async {
    final l = Js.mapList((await _detail(taskId))['comments']).map(CrmMappers.taskComment).toList();
    l.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return l;
  });

  static Future<List<TaskHistoryModel>> getTaskHistory({required String taskId}) async {
    try {
      return Js.mapList((await _detail(taskId))['activity_history']).map(CrmMappers.taskHistory).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

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