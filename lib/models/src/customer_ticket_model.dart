// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '/models/models.dart';
import '/constants/constants.dart';

class CustomerTicketModel {
  final String? uid;
  final int? ticketNumber;
  final String? masterClientId; // Master Client (ClientModel.uid)
  final String clientName; // Master Client display label
  final String? clientCompanyName;
  final TicketModeOfContact modeOfContact;
  final String ticketTitle;
  final String ticketDescription;
  final List<String> assignTo;
  final List<String> participants;
  final List<String> observers;
  final List<String> createdBy;
  final List<FileModel> attachments;
  final TicketPriority priorityLevel;
  final DateTime? deadline;
  final DateTime? reminder;
  final TicketCategory category;
  TicketStatus status;
  final List<TicketCommentModel> comments;
  final List<TicketHistoryModel> history;
  final UserDataModel ticketCreatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? project;
  final String? task;

  CustomerTicketModel({
    String? uid,
    this.ticketNumber,
    this.masterClientId,
    required this.clientName,
    this.clientCompanyName,
    required this.modeOfContact,
    required this.ticketTitle,
    required this.ticketDescription,
    required this.assignTo,
    required this.participants,
    required this.observers,
    required this.createdBy,
    this.attachments = const [],
    required this.priorityLevel,
    this.deadline,
    this.reminder,
    required this.category,
    this.status = TicketStatus.open,
    this.comments = const [],
    this.history = const [],
    required this.ticketCreatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.project,
    this.task,
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

  CustomerTicketModel copyWith({
    String? uid,
    int? ticketNumber,
    String? masterClientId,
    String? clientName,
    String? clientCompanyName,
    TicketModeOfContact? modeOfContact,
    String? ticketTitle,
    String? ticketDescription,
    List<String>? assignTo,
    List<String>? participants,
    List<String>? observers,
    List<String>? createdBy,
    List<FileModel>? attachments,
    TicketPriority? priorityLevel,
    DateTime? deadline,
    DateTime? reminder,
    TicketCategory? category,
    TicketStatus? status,
    List<TicketCommentModel>? comments,
    List<TicketHistoryModel>? history,
    UserDataModel? ticketCreatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? project,
    String? task,
  }) {
    return CustomerTicketModel(
      uid: uid ?? this.uid,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      masterClientId: masterClientId ?? this.masterClientId,
      clientName: clientName ?? this.clientName,
      clientCompanyName: clientCompanyName ?? this.clientCompanyName,
      modeOfContact: modeOfContact ?? this.modeOfContact,
      ticketTitle: ticketTitle ?? this.ticketTitle,
      ticketDescription: ticketDescription ?? this.ticketDescription,
      assignTo: assignTo ?? this.assignTo,
      participants: participants ?? this.participants,
      observers: observers ?? this.observers,
      createdBy: createdBy ?? this.createdBy,
      attachments: attachments ?? this.attachments,
      priorityLevel: priorityLevel ?? this.priorityLevel,
      deadline: deadline ?? this.deadline,
      reminder: reminder ?? this.reminder,
      category: category ?? this.category,
      status: status ?? this.status,
      comments: comments ?? this.comments,
      history: history ?? this.history,
      ticketCreatedBy: ticketCreatedBy ?? this.ticketCreatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      project: project ?? this.project,
      task: task ?? this.task,
    );
  }

  factory CustomerTicketModel.fromMap(String uid, Map<String, dynamic> map) {
    return CustomerTicketModel(
      uid: uid,
      ticketNumber: map['ticketNumber'] as int?,
      masterClientId: map['masterClientId'] as String?,
      clientName: (map['clientName'] as String?) ?? '',
      clientCompanyName: map['clientCompanyName'] as String?,
      modeOfContact: TicketModeOfContact.values.firstWhere(
        (e) => e.name == (map['modeOfContact'] as String?),
        orElse: () => TicketModeOfContact.phone,
      ),
      ticketTitle: map['ticketTitle'] as String,
      ticketDescription: map['ticketDescription'] as String,
      assignTo: List<String>.from(map['assignTo'] ?? []),
      participants: List<String>.from(map['participants'] ?? []),
      observers: List<String>.from(map['observers'] ?? []),
      createdBy: List<String>.from(map['createdBy'] ?? []),
      attachments: map['attachments'] != null
          ? List<FileModel>.from(
              (map['attachments'] as List).map((x) => FileModel.fromMap(x)),
            )
          : [],
      priorityLevel: TicketPriority.values.firstWhere(
        (e) => e.name == (map['priorityLevel'] as String?),
        orElse: () => TicketPriority.medium,
      ),
      deadline: _toDateTime(map['deadline']),
      reminder: _toDateTime(map['reminder']),
      category: TicketCategory.values.firstWhere(
        (e) => e.name == (map['category'] as String?),
        orElse: () => TicketCategory.technicalSupport,
      ),
      status: TicketStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String?),
        orElse: () => TicketStatus.open,
      ),
      comments: map['comments'] != null
          ? List<TicketCommentModel>.from(
              (map['comments'] as List).map(
                (c) => TicketCommentModel.fromMap(c),
              ),
            )
          : [],
      history: map['history'] != null
          ? List<TicketHistoryModel>.from(
              (map['history'] as List).map(
                (h) => TicketHistoryModel.fromMap(h),
              ),
            )
          : [],
      ticketCreatedBy:
          map['ticketCreatedBy'] != null &&
              map['ticketCreatedBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(
              map['ticketCreatedBy'] as Map<String, dynamic>,
            )
          : UserDataModel.fromEmptyMap(),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(map['updatedAt']) ?? DateTime.now(),
      project: map['project'] as String?,
      task: map['task'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'ticketNumber': ticketNumber,
      'masterClientId': masterClientId,
      'clientName': clientName,
      'clientCompanyName': clientCompanyName,
      'modeOfContact': modeOfContact.name,
      'ticketTitle': ticketTitle,
      'ticketDescription': ticketDescription,
      'assignTo': assignTo,
      'participants': participants,
      'observers': observers,
      'createdBy': createdBy,
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'priorityLevel': priorityLevel.name,
      'deadline': deadline?.millisecondsSinceEpoch,
      'reminder': reminder?.millisecondsSinceEpoch,
      'category': category.name,
      'status': status.name,
      'comments': comments.map((c) => c.toMap()).toList(),
      'history': history.map((h) => h.toMap()).toList(),
      'ticketCreatedBy': ticketCreatedBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'project': project,
      'task': task,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'masterClientId': masterClientId,
      'clientName': clientName,
      'clientCompanyName': clientCompanyName,
      'modeOfContact': modeOfContact.name,
      'ticketTitle': ticketTitle,
      'ticketDescription': ticketDescription,
      'assignTo': assignTo,
      'participants': participants,
      'observers': observers,
      'createdBy': createdBy,
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'priorityLevel': priorityLevel.name,
      'deadline': deadline?.millisecondsSinceEpoch,
      'reminder': reminder?.millisecondsSinceEpoch,
      'category': category.name,
      'status': status.name,
      'comments': comments.map((c) => c.toMap()).toList(),
      'history': history.map((h) => h.toMap()).toList(),
      'ticketCreatedBy': ticketCreatedBy.toMap(),
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'project': project,
      'task': task,
    };
  }

  String toJson() => json.encode(toMap());

  factory CustomerTicketModel.fromJson(String uid, String source) =>
      CustomerTicketModel.fromMap(
        uid,
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() {
    return 'CustomerTicketModel(uid: $uid, ticketNumber: $ticketNumber, masterClientId: $masterClientId, clientName: $clientName, clientCompanyName: $clientCompanyName, modeOfContact: $modeOfContact, ticketTitle: $ticketTitle, ticketDescription: $ticketDescription, assignTo: $assignTo, participants: $participants, observers: $observers, createdBy: $createdBy, priorityLevel: $priorityLevel, deadline: $deadline, reminder: $reminder, category: $category, status: $status,project: $project, task: $task, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant CustomerTicketModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.ticketNumber == ticketNumber &&
        other.masterClientId == masterClientId &&
        other.clientName == clientName &&
        other.clientCompanyName == clientCompanyName &&
        other.modeOfContact == modeOfContact &&
        other.ticketTitle == ticketTitle &&
        other.ticketDescription == ticketDescription &&
        listEquals(other.assignTo, assignTo) &&
        listEquals(other.participants, participants) &&
        listEquals(other.observers, observers) &&
        listEquals(other.createdBy, createdBy) &&
        listEquals(other.attachments, attachments) &&
        other.priorityLevel == priorityLevel &&
        other.deadline == deadline &&
        other.reminder == reminder &&
        other.category == category &&
        other.status == status &&
        listEquals(other.comments, comments) &&
        listEquals(other.history, history) &&
        other.ticketCreatedBy == ticketCreatedBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.project == project &&
        other.task == task;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        ticketNumber.hashCode ^
        masterClientId.hashCode ^
        clientName.hashCode ^
        clientCompanyName.hashCode ^
        modeOfContact.hashCode ^
        ticketTitle.hashCode ^
        ticketDescription.hashCode ^
        assignTo.hashCode ^
        participants.hashCode ^
        observers.hashCode ^
        createdBy.hashCode ^
        attachments.hashCode ^
        priorityLevel.hashCode ^
        deadline.hashCode ^
        reminder.hashCode ^
        category.hashCode ^
        status.hashCode ^
        comments.hashCode ^
        history.hashCode ^
        ticketCreatedBy.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        project.hashCode ^
        task.hashCode;
  }
}

class TicketCommentModel {
  String userId;
  String comment;
  DateTime timestamp;
  TicketCommentModel({
    required this.userId,
    required this.comment,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  TicketCommentModel copyWith({
    String? userId,
    String? comment,
    DateTime? timestamp,
  }) {
    return TicketCommentModel(
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

  factory TicketCommentModel.fromMap(Map<String, dynamic> map) {
    return TicketCommentModel(
      userId: map['userId'] as String,
      comment: map['comment'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory TicketCommentModel.fromJson(String source) =>
      TicketCommentModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'TicketCommentModel(userId: $userId, comment: $comment, timestamp: $timestamp)';

  @override
  bool operator ==(covariant TicketCommentModel other) {
    if (identical(this, other)) return true;

    return other.userId == userId &&
        other.comment == comment &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => userId.hashCode ^ comment.hashCode ^ timestamp.hashCode;
}

class TicketHistoryModel {
  DateTime timestamp;
  String userId;
  String updateDisposition;
  String? update;
  TicketHistoryModel({
    required this.userId,
    required this.updateDisposition,
    this.update,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  TicketHistoryModel copyWith({
    DateTime? timestamp,
    String? userId,
    String? updateDisposition,
    String? update,
  }) {
    return TicketHistoryModel(
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

  factory TicketHistoryModel.fromMap(Map<String, dynamic> map) {
    return TicketHistoryModel(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      userId: map['userId'] as String,
      updateDisposition: map['updateDisposition'] as String,
      update: map['update'] != null ? map['update'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory TicketHistoryModel.fromJson(String source) =>
      TicketHistoryModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'TicketHistoryModel(timestamp: $timestamp, userId: $userId, updateDisposition: $updateDisposition, update: $update)';
  }

  @override
  bool operator ==(covariant TicketHistoryModel other) {
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