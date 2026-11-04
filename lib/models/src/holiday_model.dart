import 'dart:convert';
import '/models/models.dart';

class HolidayModel {
  final String? uid;
  final DateTime date;
  final String reason;
  final int days;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  HolidayModel({
    this.uid,
    required this.date,
    required this.reason,
    this.days = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  HolidayModel copyWith({
    String? uid,
    DateTime? date,
    String? reason,
    int? days,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HolidayModel(
      uid: uid ?? this.uid,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      days: days ?? this.days,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': date.millisecondsSinceEpoch,
      'reason': reason,
      'days': days,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'createdBy': createdBy.toMap(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'date': date.millisecondsSinceEpoch,
      'reason': reason,
      'days': days,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'createdBy': createdBy.toMap(),
    };
  }

  factory HolidayModel.fromMap(String uid, Map<String, dynamic> map) {
    return HolidayModel(
      uid: uid,
      date: map['date'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : DateTime.now(),
      reason: map['reason'] as String? ?? '',
      days: map['days'] is int ? map['days'] as int : 1,
      createdAt: map['createdAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      updatedAt: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : DateTime.now(),
      createdBy: map['createdBy'] != null && map['createdBy'] is Map
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),
    );
  }

  String toJson() => json.encode(toMap());

  factory HolidayModel.fromJson(String uid, String source) =>
      HolidayModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'HolidayModel(uid: $uid, date: $date, reason: $reason, days: $days, createdAt: $createdAt, updatedAt: $updatedAt, createdBy: $createdBy)';
  }

  @override
  bool operator ==(covariant HolidayModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.date == date &&
        other.reason == reason &&
        other.days == days &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.createdBy == createdBy;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        date.hashCode ^
        reason.hashCode ^
        days.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        createdBy.hashCode;
  }
}
