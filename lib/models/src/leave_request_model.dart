import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_model.dart';

DateTime? parseDate(dynamic value) {
  if (value == null) return null;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

enum LeaveStatus { pending, approved, rejected }

class LeaveRequestModel {
  final String? uid;
  final String employeeId;
  final String employeeName;
  final DateTime fromDate;
  final DateTime toDate;
  final int days;
  final String? reason;
  final LeaveStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveRequestModel({
    this.uid,
    required this.employeeId,
    required this.employeeName,
    required this.fromDate,
    required this.toDate,
    required this.days,
    this.reason,
    this.status = LeaveStatus.pending,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  LeaveRequestModel copyWith({
    String? uid,
    String? employeeId,
    String? employeeName,
    DateTime? fromDate,
    DateTime? toDate,
    int? days,
    String? reason,
    LeaveStatus? status,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    String? rejectionReason,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequestModel(
      uid: uid ?? this.uid,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      days: days ?? this.days,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employeeId': employeeId,
      'employeeName': employeeName,
      'fromDate': fromDate.millisecondsSinceEpoch,
      'toDate': toDate.millisecondsSinceEpoch,
      'days': days,
      'reason': reason,
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'rejectionReason': rejectionReason,
      'createdBy': createdBy.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'fromDate': fromDate.millisecondsSinceEpoch,
      'toDate': toDate.millisecondsSinceEpoch,
      'days': days,
      'reason': reason,
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'rejectionReason': rejectionReason,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory LeaveRequestModel.fromMap(String uid, Map<String, dynamic> map) {
    return LeaveRequestModel(
      uid: uid,
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      fromDate: parseDate(map['fromDate']) ?? DateTime.now(),
      toDate: parseDate(map['toDate']) ?? DateTime.now(),
      days: map['days'] ?? 1,
      reason: map['reason'],
      status: LeaveStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? ''),
        orElse: () => LeaveStatus.pending,
      ),
      approvedBy: map['approvedBy'],
      approvedByName: map['approvedByName'],
      approvedAt: parseDate(map['approvedAt']),
      rejectionReason: map['rejectionReason'],
      createdBy: map['createdBy'] != null
          ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
          : UserDataModel.fromEmptyMap(),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory LeaveRequestModel.fromJson(String uid, String source) =>
      LeaveRequestModel.fromMap(uid, json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'LeaveRequestModel(employeeId: $employeeId, employeeName: $employeeName, fromDate: $fromDate, toDate: $toDate, days: $days, status: $status)';
  }
}
