import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:leadcapture/constants/src/enum.dart';
import 'package:leadcapture/models/src/workpermission_model.dart';
import 'package:leadcapture/models/src/worktime_model.dart';

class AttendanceModel {
  String employeeId;
  WorktimeModel? worktime;
  List<PunchModel> punchList;
  int breakMinutes;
  AttendanceStatus? status;
  String present;
  String holiday;
  String absent;
  int workingHourMinutes;
  int lessHourMinutes;
  int otHourMinutes;
  List<WorkPermissionModel>? permissions;

  AttendanceModel({
    required this.employeeId,
    this.worktime,
    required this.punchList,
    required this.breakMinutes,
    this.status,
    required this.present,
    required this.holiday,
    required this.absent,
    required this.workingHourMinutes,
    required this.lessHourMinutes,
    required this.otHourMinutes,
    this.permissions,
  });

  AttendanceModel copyWith({
    String? employeeId,
    WorktimeModel? worktime,
    List<PunchModel>? punchList,
    int? breakMinutes,
    AttendanceStatus? status,
    String? present,
    String? holiday,
    String? absent,
    int? workingHourMinutes,
    int? lessHourMinutes,
    int? otHourMinutes,
    List<WorkPermissionModel>? permissions,
  }) {
    return AttendanceModel(
      employeeId: employeeId ?? this.employeeId,
      worktime: worktime ?? this.worktime,
      punchList: punchList ?? this.punchList,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      status: status ?? this.status,
      present: present ?? this.present,
      holiday: holiday ?? this.holiday,
      absent: absent ?? this.absent,
      workingHourMinutes: workingHourMinutes ?? this.workingHourMinutes,
      lessHourMinutes: lessHourMinutes ?? this.lessHourMinutes,
      otHourMinutes: otHourMinutes ?? this.otHourMinutes,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employeeId': employeeId,
      'worktime': worktime?.toMap(),
      'punchList': punchList.map((x) => x.toMap()).toList(),
      'breakMinutes': breakMinutes,
      'status': status,
      'present': present,
      'holiday': holiday,
      'absent': absent,
      'workingHourMinutes': workingHourMinutes,
      'lessHourMinutes': lessHourMinutes,
      'otHourMinutes': otHourMinutes,
      'permissions': permissions?.map((x) => x.toMap()).toList(),
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    final punchRaw = map['punchList'] ?? map['punch_list'];

    return AttendanceModel(
      employeeId: map['employeeId'] ?? '',
      worktime: map['worktime'] != null
          ? WorktimeModel.fromMap('', map['worktime'])
          : null,
      punchList: punchRaw == null
          ? []
          : punchRaw
                .map((e) => PunchModel.fromMap(e as Map<String, dynamic>))
                .toList(),
      breakMinutes: map['breakMinutes'] is int
          ? map['breakMinutes']
          : int.tryParse(map['breakMinutes']?.toString() ?? '0') ?? 0,
      status: AttendanceStatus.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (map['status'] ?? '').toString().toLowerCase(),
        orElse: () => AttendanceStatus.absent,
      ),
      present: map['present']?.toString() ?? '0',
      holiday: map['holiday']?.toString() ?? '0',
      absent: map['absent']?.toString() ?? '0',
      workingHourMinutes: map['working_hour_minutes'] is int
          ? map['working_hour_minutes']
          : int.tryParse(map['working_hour_minutes']?.toString() ?? '0') ?? 0,
      lessHourMinutes: map['less_hour_minutes'] is int
          ? map['less_hour_minutes']
          : int.tryParse(map['less_hour_minutes']?.toString() ?? '0') ?? 0,
      otHourMinutes: map['ot_hour_minutes'] is int
          ? map['ot_hour_minutes']
          : int.tryParse(map['ot_hour_minutes']?.toString() ?? '0') ?? 0,
      permissions: map['permissions'] == null
          ? []
          : (map['permissions'] as List)
                .map((e) => WorkPermissionModel.fromMap(e))
                .toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AttendanceModel.fromJson(String source) =>
      AttendanceModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'AttendanceModel(punchList: $punchList, present: $present, holiday: $holiday, absent: $absent, workingHourMinutes: $workingHourMinutes, lessHourMinutes: $lessHourMinutes, otHourMinutes: $otHourMinutes)';
  }

  @override
  bool operator ==(covariant AttendanceModel other) {
    if (identical(this, other)) return true;
    return listEquals(other.punchList, punchList) &&
        other.breakMinutes == breakMinutes &&
        other.present == present &&
        other.holiday == holiday &&
        other.absent == absent &&
        other.workingHourMinutes == workingHourMinutes &&
        other.lessHourMinutes == lessHourMinutes &&
        other.otHourMinutes == otHourMinutes;
  }

  @override
  int get hashCode {
    return punchList.hashCode ^
        breakMinutes.hashCode ^
        present.hashCode ^
        holiday.hashCode ^
        absent.hashCode ^
        workingHourMinutes.hashCode ^
        lessHourMinutes.hashCode ^
        otHourMinutes.hashCode;
  }

  String _formatMinutes(int m) {
    final h = m ~/ 60;
    final r = m % 60;
    return "${h.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}";
  }

  String get formattedWork => _formatMinutes(workingHourMinutes);
  String get formattedLess => _formatMinutes(lessHourMinutes);
  String get formattedOT => _formatMinutes(otHourMinutes);
  String get formattedBreak => _formatMinutes(breakMinutes);

  AttendanceModel applyPermissions({required bool isAdmin}) {
    if (permissions == null || permissions!.isEmpty) return this;

    int updatedWorking = workingHourMinutes;
    int updatedLess = lessHourMinutes;
    int updatedOt = otHourMinutes;

    // bool isHolidayDay = status == AttendanceStatus.holiday;

    for (final p in permissions!) {
      if (!isAdmin && p.status != PermissionsStatus.approved) continue;

      switch (p.type) {
        case PermissionType.leaveFullDay:
          return copyWith(
            status: AttendanceStatus.leave,
            present: '0',
            absent: '0',
            workingHourMinutes: 0,
            lessHourMinutes: 0,
            otHourMinutes: 0,
          );

        case PermissionType.leaveHalfDay:
          updatedWorking += 240; // 4 hours
          updatedLess = (updatedLess - 240).clamp(0, updatedLess);
          break;

        case PermissionType.workFromHome:
          return copyWith(
            status: AttendanceStatus.wfh,
            present: '1',
            absent: '0',
            lessHourMinutes: 0,
          );

        case PermissionType.lateEntry:
          updatedLess = (updatedLess - 30).clamp(0, updatedLess);
          break;

        case PermissionType.earlyExit:
          updatedLess = (updatedLess - 30).clamp(0, updatedLess);
          break;

        case PermissionType.permission:
          updatedLess = (updatedLess - 60).clamp(0, updatedLess);
          break;
      }
    }

    return copyWith(
      workingHourMinutes: updatedWorking,
      lessHourMinutes: updatedLess,
      otHourMinutes: updatedOt,
    );
  }
}

class PunchModel {
  String? uid;
  String punchDate;
  List<String> punchTime;
  String totalHours;
  String lessHours;
  String status;
  String day;
  String otHours;
  String otApproval;
  PermissionType? permissionType;
  PermissionsStatus? permissionStatus;
  int? clockIn;
  int? clockOut;
  double? latitude;
  double? longitude;
  bool? isWithinGeofence;

  PunchModel({
    this.uid,
    required this.punchDate,
    required this.punchTime,
    required this.totalHours,
    required this.lessHours,
    required this.status,
    required this.day,
    required this.otHours,
    required this.otApproval,
    this.permissionType,
    this.permissionStatus,
    this.clockIn,
    this.clockOut,
    this.latitude,
    this.longitude,
    this.isWithinGeofence,
  });

  PunchModel copyWith({
    String? uid,
    String? punchDate,
    List<String>? punchTime,
    String? totalHours,
    String? lessHours,
    String? status,
    String? day,
    String? otHours,
    String? otApproval,
    PermissionType? permissionType,
    PermissionsStatus? permissionStatus,
    int? clockIn,
    int? clockOut,
    double? latitude,
    double? longitude,
    bool? isWithinGeofence,
  }) {
    return PunchModel(
      uid: uid ?? this.uid,
      punchDate: punchDate ?? this.punchDate,
      punchTime: punchTime ?? this.punchTime,
      totalHours: totalHours ?? this.totalHours,
      lessHours: lessHours ?? this.lessHours,
      status: status ?? this.status,
      day: day ?? this.day,
      otHours: otHours ?? this.otHours,
      otApproval: otApproval ?? this.otApproval,
      permissionType: permissionType ?? this.permissionType,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'punchDate': punchDate,
      'punchTime': punchTime,
      'totalHours': totalHours,
      'lessHours': lessHours,
      'status': status,
      'day': day,
      'otHours': otHours,
      'otApproval': otApproval,
      'permissionType': permissionType?.toString().split('.').last,
      'permissionStatus': permissionStatus?.toString().split('.').last,
      'clockIn': clockIn,
      'clockOut': clockOut,
      'latitude': latitude,
      'longitude': longitude,
      'isWithinGeofence': isWithinGeofence,
    };
  }

  factory PunchModel.fromMap(Map<String, dynamic> map) {
    PermissionType? permissionType;
    final permissionRaw = map['permissionType'];

    if (permissionRaw != null) {
      try {
        permissionType = PermissionType.values.firstWhere(
          (e) => e.name.toLowerCase() == permissionRaw.toString().toLowerCase(),
        );
      } catch (_) {
        permissionType = null;
      }
    }

    PermissionsStatus? permissionStatus;
    final statusRaw = map['permissionStatus'];

    if (statusRaw != null) {
      try {
        permissionStatus = PermissionsStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == statusRaw.toString().toLowerCase(),
        );
      } catch (_) {
        permissionStatus = null;
      }
    }

    String minutesToTime(dynamic minutes) {
      if (minutes == null) return '';
      int m = minutes is int ? minutes : int.tryParse(minutes.toString()) ?? 0;
      int h = m ~/ 60;
      int r = m % 60;
      return "${h.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}";
    }

    return PunchModel(
      uid: map['uid'],
      punchDate: map['punchDate'] ?? '',
      punchTime: map['punchTime'] != null
          ? List<String>.from(map['punchTime'].map((e) => e.toString()))
          : [],
      totalHours: map['totalHours'] ?? minutesToTime(map['workingMinutes']),
      lessHours: map['lessHours'] ?? minutesToTime(map['lessMinutes']),
      otHours: map['otHours'] ?? minutesToTime(map['otMinutes']),
      status: map['status'] ?? '',
      day: map['day'] ?? '',
      otApproval: map['otApproval']?.toString() ?? '0',
      permissionType: permissionType,
      permissionStatus: permissionStatus,
      clockIn: map['clockIn'] is int
          ? map['clockIn']
          : int.tryParse(map['clockIn']?.toString() ?? ''),
      clockOut: map['clockOut'] is int
          ? map['clockOut']
          : int.tryParse(map['clockOut']?.toString() ?? ''),
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      isWithinGeofence: map['isWithinGeofence'] as bool?,
    );
  }
  DateTime? get clockInDate =>
      clockIn != null ? DateTime.fromMillisecondsSinceEpoch(clockIn!) : null;

  DateTime? get clockOutDate =>
      clockOut != null ? DateTime.fromMillisecondsSinceEpoch(clockOut!) : null;

  String toJson() => json.encode(toMap());

  factory PunchModel.fromJson(String source) =>
      PunchModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'PunchModel(punchDate: $punchDate, punchTime: $punchTime, totalHours: $totalHours, lessHours: $lessHours, status: $status, day: $day, otHours: $otHours, otApproval: $otApproval, permissionType: $permissionType)';
  }

  @override
  bool operator ==(covariant PunchModel other) {
    if (identical(this, other)) return true;
    return other.punchDate == punchDate &&
        listEquals(other.punchTime, punchTime) &&
        other.totalHours == totalHours &&
        other.lessHours == lessHours &&
        other.status == status &&
        other.day == day &&
        other.otHours == otHours &&
        other.otApproval == otApproval &&
        other.permissionType == permissionType &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.isWithinGeofence == isWithinGeofence;
  }

  @override
  int get hashCode {
    return punchDate.hashCode ^
        punchTime.hashCode ^
        totalHours.hashCode ^
        lessHours.hashCode ^
        status.hashCode ^
        day.hashCode ^
        otHours.hashCode ^
        otApproval.hashCode ^
        permissionType.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        isWithinGeofence.hashCode;
  }
}

class Session {
  final DateTime? inTime;
  final DateTime? outTime;

  Session({this.inTime, this.outTime});
}

class AttendanceStats {
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int holidayDays;

  final int wfhDays;
  final int halfDayDays;
  final int lateDays;
  final int earlyExitDays;

  final int pendingDays;
  final int rejectedDays;
  final int permissionDays;
  final int inProgressDays;
  final int lessHoursDays;

  final String totalWorkingHours;
  final String totalLessHours;
  final String totalOTHours;

  final List<AttendanceModel> attendanceData;

  AttendanceStats({
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.holidayDays,
    required this.wfhDays,
    required this.halfDayDays,
    required this.lateDays,
    required this.earlyExitDays,

    this.pendingDays = 0,
    this.rejectedDays = 0,
    this.permissionDays = 0,
    this.inProgressDays = 0,
    this.lessHoursDays = 0,

    required this.totalWorkingHours,
    required this.totalLessHours,
    required this.totalOTHours,
    required this.attendanceData,
  });

  factory AttendanceStats.fromMap(Map<String, dynamic> map) {
    return AttendanceStats(
      presentDays: _parseInt(map['presentDays']),
      absentDays: _parseInt(map['absentDays']),
      leaveDays: _parseInt(map['leaveDays']),
      holidayDays: _parseInt(map['holidayDays']),
      wfhDays: _parseInt(map['wfhDays']),
      halfDayDays: _parseInt(map['halfDayDays']),
      lateDays: _parseInt(map['lateDays']),
      earlyExitDays: _parseInt(map['earlyExitDays']),

      pendingDays: _parseInt(map['pendingDays']),
      rejectedDays: _parseInt(map['rejectedDays']),
      permissionDays: _parseInt(map['permissionDays']),
      inProgressDays: _parseInt(map['inProgressDays']),
      lessHoursDays: _parseInt(map['lessHoursDays']),

      totalWorkingHours: map['totalWorkingHours']?.toString() ?? '0',
      totalLessHours: map['totalLessHours']?.toString() ?? '0',
      totalOTHours: map['totalOTHours']?.toString() ?? '0',

      attendanceData:
          map['attendanceData'] != null && map['attendanceData'] is List
          ? List<AttendanceModel>.from(
              (map['attendanceData'] as List).map(
                (e) => AttendanceModel.fromMap(e as Map<String, dynamic>),
              ),
            )
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'presentDays': presentDays,
      'absentDays': absentDays,
      'leaveDays': leaveDays,
      'wfhDays': wfhDays,
      'halfDayDays': halfDayDays,
      'lateDays': lateDays,
      'earlyExitDays': earlyExitDays,

      'pendingDays': pendingDays,
      'rejectedDays': rejectedDays,
      'permissionDays': permissionDays,
      'inProgressDays': inProgressDays,
      'lessHoursDays': lessHoursDays,

      'totalWorkingHours': totalWorkingHours,
      'totalLessHours': totalLessHours,
      'totalOTHours': totalOTHours,
      'attendanceData': attendanceData.map((e) => e.toMap()).toList(),
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String toJson() => json.encode(toMap());
  factory AttendanceStats.fromJson(String source) =>
      AttendanceStats.fromMap(json.decode(source) as Map<String, dynamic>);

  int get sundayHolidayCount {
    final Set<String> uniqueSundays = {};

    for (final attendance in attendanceData) {
      for (final punch in attendance.punchList) {
        try {
          final date = DateTime.parse(punch.punchDate);

          if (date.weekday == DateTime.sunday) {
            uniqueSundays.add("${date.year}-${date.month}-${date.day}");
          }
        } catch (_) {}
      }
    }

    return uniqueSundays.length;
  }
}

// class HolidayModel {
//   final DateTime date;
//   final String name;

//   HolidayModel({required this.date, required this.name});
// }
