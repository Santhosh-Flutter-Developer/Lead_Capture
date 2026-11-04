// Project imports:
import '/constants/constants.dart';

class WorkPermissionModel {
  String uid;
  String userId;
  String userName;
  String reason;
  PermissionsStatus status;
  PermissionType type;
  bool withSalary;
  String? approvedBy;
  DateTime? approvedAt;
  DateTime date;
  DateTime from;
  DateTime to;
  final HalfDaySession? session;
  DateTime created;
  DateTime modified;
  WorkPermissionModel({
    required this.uid,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.date,
    required this.from,
    required this.to,
    required this.status,
    required this.type,
    required this.created,
    required this.modified,
    this.withSalary = false,
    this.session,
    this.approvedBy,
    this.approvedAt,
  });

  WorkPermissionModel copyWith({
    String? uid,
    String? userId,
    String? userName,
    String? reason,
    PermissionsStatus? status,
    PermissionType? type,
    bool? withSalary,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? date,
    DateTime? from,
    DateTime? to,
    // bool? isApproved,
    HalfDaySession? session,
    DateTime? created,
    DateTime? modified,
  }) {
    return WorkPermissionModel(
      uid: uid ?? this.uid,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      reason: reason ?? this.reason,
      date: date ?? this.date,
      from: from ?? this.from,
      status: status ?? this.status,
      type: type ?? this.type,
      withSalary: withSalary ?? this.withSalary,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      to: to ?? this.to,
      session: session ?? this.session,
      created: created ?? this.created,
      modified: modified ?? this.modified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'reason': reason,
      'status': status.name,
      'type': type.name,
      'withSalary': withSalary,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'date': date.millisecondsSinceEpoch,
      'from': from.millisecondsSinceEpoch,
      'to': to.millisecondsSinceEpoch,
      'session': session?.name,
      'created': created.millisecondsSinceEpoch,
      'modified': modified.millisecondsSinceEpoch,
    };
  }

  factory WorkPermissionModel.fromMap(Map<String, dynamic> map) {
    return WorkPermissionModel(
      uid: map['uid'] ?? '',
      userId: (map['userId'] ?? ''),
      userName: (map['userName'] ?? ''),
      reason: (map['reason'] ?? ''),
      status: PermissionsStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PermissionsStatus.pending,
      ),
      type: PermissionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PermissionType.permission,
      ),
      withSalary: map['withSalary'] ?? false,
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['approvedAt'])
          : null,
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'])
          : DateTime.now(),
      from: DateTime.fromMillisecondsSinceEpoch(map['from']),
      to: DateTime.fromMillisecondsSinceEpoch(map['to']),
      session: map['session'] != null
          ? HalfDaySession.values.firstWhere(
              (e) => e.name == map['session'],
              orElse: () => HalfDaySession.morning,
            )
          : null,
      created: DateTime.fromMillisecondsSinceEpoch(map['created']),
      modified: DateTime.fromMillisecondsSinceEpoch(map['modified']),
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'status': status.name,
      'type': type.name,
      'withSalary': withSalary,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.millisecondsSinceEpoch,
      'modified': modified.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(covariant WorkPermissionModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.userId == userId &&
        other.userName == userName &&
        other.reason == reason &&
        other.status == status &&
        other.withSalary == withSalary &&
        other.from == from &&
        other.to == to &&
        other.created == created &&
        other.modified == modified;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        userId.hashCode ^
        userName.hashCode ^
        reason.hashCode ^
        status.hashCode ^
        withSalary.hashCode ^
        from.hashCode ^
        to.hashCode ^
        created.hashCode ^
        modified.hashCode;
  }
}
