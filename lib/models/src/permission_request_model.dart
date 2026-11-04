// import 'dart:convert';
// import 'package:leadcapture/models/src/user_data_model.dart';

// import 'leave_request_model.dart';

// class PermissionRequestModel {
//   final String? uid;
//   final String employeeId;
//   final DateTime requestDate;
//   final String fromTime;
//   final String toTime;
//   final int? minutes;
//   final String? reason;
//   final LeaveStatus status;
//   final String? approvedBy;
//   final DateTime? approvedAt;
//   final bool isActive;
//   final UserDataModel createdBy;
//   final DateTime createdAt;
//   final DateTime updatedAt;

//   PermissionRequestModel({
//     this.uid,
//     required this.employeeId,
//     required this.requestDate,
//     required this.fromTime,
//     required this.toTime,
//     this.minutes,
//     this.reason,
//     this.status = LeaveStatus.pending,
//     this.approvedBy,
//     this.approvedAt,
//     this.isActive = true,
//     required this.createdBy,
//     DateTime? createdAt,
//     DateTime? updatedAt,
//   }) : createdAt = createdAt ?? DateTime.now(),
//        updatedAt = updatedAt ?? DateTime.now();

//   PermissionRequestModel copyWith({
//     String? uid,
//     String? employeeId,
//     DateTime? requestDate,
//     String? fromTime,
//     String? toTime,
//     int? minutes,
//     String? reason,
//     LeaveStatus? status,
//     String? approvedBy,
//     DateTime? approvedAt,
//     bool? isActive,
//     UserDataModel? createdBy,
//     DateTime? createdAt,
//     DateTime? updatedAt,
//   }) {
//     return PermissionRequestModel(
//       uid: uid ?? this.uid,
//       employeeId: employeeId ?? this.employeeId,
//       requestDate: requestDate ?? this.requestDate,
//       fromTime: fromTime ?? this.fromTime,
//       toTime: toTime ?? this.toTime,
//       minutes: minutes ?? this.minutes,
//       reason: reason ?? this.reason,
//       status: status ?? this.status,
//       approvedBy: approvedBy ?? this.approvedBy,
//       approvedAt: approvedAt ?? this.approvedAt,
//       isActive: isActive ?? this.isActive,
//       createdBy: createdBy ?? this.createdBy,
//       createdAt: createdAt ?? this.createdAt,
//       updatedAt: updatedAt ?? this.updatedAt,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return <String, dynamic>{
//       'employeeId': employeeId,
//       'requestDate': requestDate.millisecondsSinceEpoch,
//       'fromTime': fromTime,
//       'toTime': toTime,
//       'minutes': minutes,
//       'reason': reason,
//       'status': status.name,
//       'approvedBy': approvedBy,
//       'approvedAt': approvedAt?.millisecondsSinceEpoch,
//       'isActive': isActive,
//       'createdBy': createdBy.toMap(),
//       'createdAt': createdAt.millisecondsSinceEpoch,
//       'updatedAt': updatedAt.millisecondsSinceEpoch,
//     };
//   }

//   Map<String, dynamic> toUpdateMap() {
//     return {
//       'employeeId': employeeId,
//       'requestDate': requestDate.millisecondsSinceEpoch,
//       'fromTime': fromTime,
//       'toTime': toTime,
//       'minutes': minutes,
//       'reason': reason,
//       'status': status.name,
//       'approvedBy': approvedBy,
//       'approvedAt': approvedAt?.millisecondsSinceEpoch,
//       'isActive': isActive,
//       'updatedAt': DateTime.now().millisecondsSinceEpoch,
//     };
//   }

//   factory PermissionRequestModel.fromMap(String uid, Map<String, dynamic> map) {
//     return PermissionRequestModel(
//       uid: uid,
//       employeeId: map['employeeId'] ?? '',
//       requestDate: map['requestDate'] != null
//           ? DateTime.fromMillisecondsSinceEpoch(map['requestDate'] as int)
//           : DateTime.now(),
//       fromTime: map['fromTime'] ?? '',
//       toTime: map['toTime'] ?? '',
//       minutes: map['minutes'],
//       reason: map['reason'],
//       status: LeaveStatus.values.firstWhere(
//         (e) => e.name == (map['status'] as String? ?? ''),
//         orElse: () => LeaveStatus.pending,
//       ),
//       approvedBy: map['approvedBy'],
//       approvedAt: map['approvedAt'] != null
//           ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'] as int)
//           : null,
//       isActive: map['isActive'] ?? true,
//       createdBy: map['createdBy'] != null
//           ? UserDataModel.fromMap(Map<String, dynamic>.from(map['createdBy']))
//           : UserDataModel.fromEmptyMap(),
//       createdAt: map['createdAt'] != null
//           ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
//           : DateTime.now(),
//       updatedAt: map['updatedAt'] != null
//           ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
//           : DateTime.now(),
//     );
//   }

//   String toJson() => json.encode(toMap());

//   factory PermissionRequestModel.fromJson(String uid, String source) =>
//       PermissionRequestModel.fromMap(
//         uid,
//         json.decode(source) as Map<String, dynamic>,
//       );

//   @override
//   String toString() {
//     return 'PermissionRequestModel(employeeId: $employeeId, requestDate: $requestDate, fromTime: $fromTime, toTime: $toTime, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
//   }

//   @override
//   bool operator ==(covariant PermissionRequestModel other) {
//     if (identical(this, other)) return true;
//     return other.employeeId == employeeId &&
//         other.requestDate == requestDate &&
//         other.fromTime == fromTime &&
//         other.toTime == toTime &&
//         other.status == status;
//   }

//   @override
//   int get hashCode {
//     return employeeId.hashCode ^
//         requestDate.hashCode ^
//         fromTime.hashCode ^
//         toTime.hashCode ^
//         status.hashCode;
//   }
// }
