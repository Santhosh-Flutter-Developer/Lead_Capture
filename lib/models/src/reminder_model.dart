import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';

class ReminderModel {
  final String? uid;
  final NotificationModel notification;
  final DateTime scheduledAt;
  final bool isSent;
  final DateTime createdAt;
  final UserDataModel createdBy;
  ReminderModel({
    this.uid,
    required this.notification,
    required this.scheduledAt,
    required this.isSent,
    required this.createdAt,
    required this.createdBy,
  });

  ReminderModel copyWith({
    String? uid,
    NotificationModel? notification,
    DateTime? scheduledAt,
    bool? isSent,
    DateTime? createdAt,
    UserDataModel? createdBy,
  }) {
    return ReminderModel(
      uid: uid ?? this.uid,
      notification: notification ?? this.notification,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isSent: isSent ?? this.isSent,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'notification': notification.toMap(),
      'scheduledAt': scheduledAt,
      'isSent': isSent,
      'createdAt': createdAt,
      'createdBy': createdBy.toMap(),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      uid: map['uid'] != null ? map['uid'] as String : null,
      notification: NotificationModel.fromMap(
        map['notification']['uid'],
        map['notification'] as Map<String, dynamic>,
      ),
      scheduledAt: (map['scheduledAt'] as Timestamp).toDate(),
      isSent: map['isSent'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: UserDataModel.fromMap(
        map['createdBy'] as Map<String, dynamic>,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ReminderModel.fromJson(String source) =>
      ReminderModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ReminderModel(uid: $uid, notification: $notification, scheduledAt: $scheduledAt, isSent: $isSent, createdAt: $createdAt, createdBy: $createdBy)';
  }

  @override
  bool operator ==(covariant ReminderModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.notification == notification &&
        other.scheduledAt == scheduledAt &&
        other.isSent == isSent &&
        other.createdAt == createdAt &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        notification.hashCode ^
        scheduledAt.hashCode ^
        isSent.hashCode ^
        createdAt.hashCode ^
        createdBy.hashCode;
  }
}
