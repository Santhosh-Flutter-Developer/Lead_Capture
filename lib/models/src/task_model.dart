// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '/constants/constants.dart';
import '/models/models.dart';

class TaskModel {
  final String? uid;
  final int? taskNumber;
  final String taskName;
  final String description;
  final DateTime? deadline;
  final bool deadlineRequired;
  final bool highPriority;
  final bool statusSummaryRequired;
  final List<String> assignees;
  final List<String> createdBy;
  final List<String> observers;
  final List<String> participants;
  final List<String> tags;
  final DateTime? reminder;
  final String? project;
  final String? lead;
  final String? subTaskOf;
  bool hasStarted;
  DateTime? startedTime;

  /// Stored workflow status: 'started' | 'inProgress' | 'onHold' | 'completed'.
  /// null for tasks that are pending, or created before this field existed.
  /// `hasStarted` / `completed` stay the source of truth for older code paths
  /// (listings, dashboard, active-task check) and are kept in sync with it.
  String? status;
  bool completed;
  DateTime? completedTime;
  final List<FileModel> attachments;
  final List<TaskCommentModel> comments;
  final List<TaskHistoryModel> history;
  final UserDataModel taskCreatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    String? uid,
    this.taskNumber,
    required this.taskName,
    required this.description,
    this.deadline,
    required this.deadlineRequired,
    required this.highPriority,
    required this.statusSummaryRequired,
    required this.assignees,
    required this.createdBy,
    required this.observers,
    required this.participants,
    required this.tags,
    this.reminder,
    this.project,
    this.lead,
    this.subTaskOf,
    this.hasStarted = false,
    this.startedTime,
    this.status,
    this.completed = false,
    this.completedTime,
    this.attachments = const [],
    this.comments = const [],
    this.history = const [],
    required this.taskCreatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : uid = uid ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value.runtimeType.toString().contains('Timestamp')) {
      return (value as dynamic).toDate() as DateTime;
    }
    return null;
  }

  factory TaskModel.fromMap(String uid, Map<String, dynamic> map) {
    return TaskModel(
      uid: uid,
      taskNumber: map['taskNumber'] as int?,
      taskName: map['taskName'] as String,
      description: map['description'] as String,
      deadline: _toDateTime(map['deadline']),
      deadlineRequired: map['deadlineRequired'] as bool,
      highPriority: map['highPriority'] as bool,
      statusSummaryRequired: map['statusSummaryRequired'] as bool,
      assignees: List<String>.from(map['assignees'] ?? []),
      createdBy: List<String>.from(map['createdBy'] ?? []),
      observers: List<String>.from(map['observers'] ?? []),
      participants: List<String>.from(map['participants'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      reminder: _toDateTime(map['reminder']),
      project: map['project'] as String?,
      lead: map['lead'] as String?,
      subTaskOf: map['subTaskOf'] as String?,
      hasStarted: map['hasStarted'] as bool? ?? false,
      startedTime: _toDateTime(map['startedTime']),
      status: map['status'] as String?,
      completedTime: _toDateTime(map['completedTime']),
      completed: map['completed'] as bool? ?? false,
      attachments: map['attachments'] != null
          ? List<FileModel>.from(
              (map['attachments'] as List).map((x) => FileModel.fromMap(x)),
            )
          : [],
      comments: map['comments'] != null
          ? List<TaskCommentModel>.from(
              (map['comments'] as List).map((c) => TaskCommentModel.fromMap(c)),
            )
          : [],
      history: map['history'] != null
          ? List<TaskHistoryModel>.from(
              (map['history'] as List).map((h) => TaskHistoryModel.fromMap(h)),
            )
          : [],
      taskCreatedBy:
          map['taskCreatedBy'] != null &&
              map['taskCreatedBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['taskCreatedBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'taskNumber': taskNumber,
      'taskName': taskName,
      'description': description,
      'deadline': deadline?.millisecondsSinceEpoch,
      'deadlineRequired': deadlineRequired,
      'highPriority': highPriority,
      'statusSummaryRequired': statusSummaryRequired,
      'assignees': assignees,
      'createdBy': createdBy,
      'observers': observers,
      'participants': participants,
      'tags': tags,
      'reminder': reminder?.millisecondsSinceEpoch,
      'project': project,
      'lead': lead,
      'subTaskOf': subTaskOf,
      'hasStarted': hasStarted,
      'startedTime': startedTime?.millisecondsSinceEpoch,
      'completedTime': completedTime?.millisecondsSinceEpoch,
      'completed': completed,
      'status': status,
      'taskCreatedBy': taskCreatedBy.toMap(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'comments': comments.map((c) => c.toMap()).toList(),
      'history': history.map((h) => h.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'taskName': taskName,
      'description': description,
      'deadline': deadline?.millisecondsSinceEpoch,
      'deadlineRequired': deadlineRequired,
      'highPriority': highPriority,
      'statusSummaryRequired': statusSummaryRequired,
      'assignees': assignees,
      'createdBy': createdBy,
      'observers': observers,
      'participants': participants,
      'tags': tags,
      'reminder': reminder?.millisecondsSinceEpoch,
      'project': project,
      'lead': lead,
      'subTaskOf': subTaskOf,
      // NOTE: workflow fields (hasStarted, startedTime, completed,
      // completedTime, status) are intentionally NOT written here. The edit
      // form builds a fresh TaskModel without them, so including them would
      // reset a running/completed task back to "pending" on every edit.
      'taskCreatedBy': taskCreatedBy.toMap(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'comments': comments.map((c) => c.toMap()).toList(),
      'history': history.map((h) => h.toMap()).toList(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Effective status, derived from the stored flags (works for legacy tasks).
  TaskStatus get currentStatus {
    if (completed) return TaskStatus.completed;
    if (!hasStarted) return TaskStatus.pending;
    switch (status) {
      case 'started':
        return TaskStatus.started;
      case 'onHold':
        return TaskStatus.onHold;
      case 'inProgress':
      default:
        // Legacy tasks (no status stored) were shown as "In Progress".
        return TaskStatus.inProgress;
    }
  }

  double get totalHours {
    if (startedTime == null) return 0;

    final end = completedTime ?? DateTime.now();
    final minutes = end.difference(startedTime!).inMinutes;

    return minutes / 60;
  }

  String toJson() => json.encode(toMap());

  factory TaskModel.fromJson(String uid, String source) =>
      TaskModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TaskModel(uid: $uid, taskName: $taskName, description: $description, deadline: $deadline, deadlineRequired: $deadlineRequired, highPriority: $highPriority, statusSummaryRequired: $statusSummaryRequired, assignees: $assignees, createdBy: $createdBy, observers: $observers, participants: $participants, tags: $tags, reminder: $reminder, project: $project, lead: $lead, subTaskOf: $subTaskOf, comments: hasStarted: $hasStarted, completed: $completed, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant TaskModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.taskName == taskName &&
        other.description == description &&
        other.deadline == deadline &&
        other.deadlineRequired == deadlineRequired &&
        other.highPriority == highPriority &&
        other.statusSummaryRequired == statusSummaryRequired &&
        listEquals(other.assignees, assignees) &&
        listEquals(other.createdBy, createdBy) &&
        listEquals(other.observers, observers) &&
        listEquals(other.participants, participants) &&
        listEquals(other.tags, tags) &&
        other.reminder == reminder &&
        other.project == project &&
        other.lead == lead &&
        other.subTaskOf == subTaskOf &&
        other.hasStarted == hasStarted &&
        other.status == status &&
        other.completed == completed &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        taskName.hashCode ^
        description.hashCode ^
        deadline.hashCode ^
        deadlineRequired.hashCode ^
        highPriority.hashCode ^
        statusSummaryRequired.hashCode ^
        assignees.hashCode ^
        createdBy.hashCode ^
        observers.hashCode ^
        participants.hashCode ^
        tags.hashCode ^
        reminder.hashCode ^
        project.hashCode ^
        lead.hashCode ^
        subTaskOf.hashCode ^
        hasStarted.hashCode ^
        status.hashCode ^
        completed.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

/// One work session on a task: from start/resume until hold/complete.
/// Written by TaskService into `tasks/{id}/taskTimeLogs`. [endTime] is null
/// while the session is still open.
class TaskTimeLogModel {
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;

  const TaskTimeLogModel({
    required this.userId,
    required this.startTime,
    this.endTime,
  });

  factory TaskTimeLogModel.fromMap(Map<String, dynamic> map) {
    DateTime? ms(dynamic v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return TaskTimeLogModel(
      userId: (map['userId'] as String?) ?? '',
      startTime: ms(map['startTime']) ?? DateTime.now(),
      endTime: ms(map['endTime']),
    );
  }
}

class TaskCommentModel {
  String userId;
  String comment;
  DateTime timestamp;
  TaskCommentModel({
    required this.userId,
    required this.comment,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  TaskCommentModel copyWith({
    String? userId,
    String? comment,
    DateTime? timestamp,
  }) {
    return TaskCommentModel(
      userId: userId ?? this.userId,
      comment: comment ?? this.comment,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'comment': comment,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TaskCommentModel.fromMap(Map<String, dynamic> map) {
    return TaskCommentModel(
      userId: map['userId'] as String,
      comment: map['comment'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory TaskCommentModel.fromJson(String source) =>
      TaskCommentModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'TaskCommentModel(userId: $userId, comment: $comment, timestamp: $timestamp)';

  @override
  bool operator ==(covariant TaskCommentModel other) {
    if (identical(this, other)) return true;

    return other.userId == userId &&
        other.comment == comment &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => userId.hashCode ^ comment.hashCode ^ timestamp.hashCode;
}

class TaskHistoryModel {
  DateTime timestamp;
  String userId;
  String updateDisposition;
  String? update;
  TaskHistoryModel({
    required this.userId,
    required this.updateDisposition,
    this.update,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  TaskHistoryModel copyWith({
    DateTime? timestamp,
    String? userId,
    String? updateDisposition,
    String? update,
  }) {
    return TaskHistoryModel(
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      updateDisposition: updateDisposition ?? this.updateDisposition,
      update: update ?? this.update,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'timestamp': timestamp.millisecondsSinceEpoch,
      'userId': userId,
      'updateDisposition': updateDisposition,
      'update': update,
    };
  }

  factory TaskHistoryModel.fromMap(Map<String, dynamic> map) {
    return TaskHistoryModel(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      userId: map['userId'] as String,
      updateDisposition: map['updateDisposition'] as String,
      update: map['update'] != null ? map['update'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory TaskHistoryModel.fromJson(String source) =>
      TaskHistoryModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TaskHistoryModel(timestamp: $timestamp, userId: $userId, updateDisposition: $updateDisposition, update: $update)';
  }

  @override
  bool operator ==(covariant TaskHistoryModel other) {
    if (identical(this, other)) return true;

    return other.timestamp == timestamp &&
        other.userId == userId &&
        other.updateDisposition == updateDisposition &&
        other.update == update;
  }

  @override
  int get hashCode {
    return timestamp.hashCode ^
        userId.hashCode ^
        updateDisposition.hashCode ^
        update.hashCode;
  }
}