class WorktimeModel {
  String? uid;
  String userUid;
  String userName;
  DateTime clockIn;
  Map<String, dynamic> breaks;
  DateTime? clockOut;
  String? reason;
  List<Map<String, dynamic>> screenshots;
  DateTime created;
  DateTime modified;
  double? clockInLat;
  double? clockInLng;
  double? clockOutLat;
  double? clockOutLng;

  WorktimeModel({
    this.uid,
    required this.userUid,
    required this.userName,
    required this.clockIn,
    required this.breaks,
    this.clockOut,
    this.reason,
    required this.created,
    required this.modified,
    this.screenshots = const [],
    this.clockInLat,
    this.clockInLng,
    this.clockOutLat,
    this.clockOutLng,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userUid': userUid,
      'userName': userName,
      'clockIn': clockIn.millisecondsSinceEpoch,
      'breaks': breaks,
      'clockOut': clockOut?.millisecondsSinceEpoch,
      'created': created.millisecondsSinceEpoch,
      'modified': modified.millisecondsSinceEpoch,
      'screenshots': screenshots,
      'clockInLat': clockInLat,
      'clockInLng': clockInLng,
      'clockOutLat': clockOutLat,
      'clockOutLng': clockOutLng,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'breaks': breaks,
      'clockOut': clockOut?.millisecondsSinceEpoch,
      'modified': modified.millisecondsSinceEpoch,
      'clockOutLat': clockOutLat,
      'clockOutLng': clockOutLng,
    };
  }

  Map<String, dynamic> toClockOutMap() {
    return <String, dynamic>{
      'clockIn': clockIn.millisecondsSinceEpoch,
      'clockOut': clockOut?.millisecondsSinceEpoch,
      'reason': reason,
      'modified': modified.millisecondsSinceEpoch,
      'clockOutLat': clockOutLat,
      'clockOutLng': clockOutLng,
    };
  }

  factory WorktimeModel.fromMap(String docId, Map<String, dynamic> map) {
    return WorktimeModel(
      uid: docId,
      userUid: map['userUid']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      clockIn: DateTime.fromMillisecondsSinceEpoch(map['clockIn'] as int),
      breaks: map['breaks'] ?? {},
      clockOut: map['clockOut'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['clockOut'] as int)
          : null,
      reason: map['reason']?.toString(),
      screenshots: map['screenshots'] != null
          ? List<Map<String, dynamic>>.from(map['screenshots'] as List)
          : [],
      created: DateTime.fromMillisecondsSinceEpoch(map['created'] as int),
      modified: DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
      clockInLat: (map['clockInLat'] as num?)?.toDouble(),
      clockInLng: (map['clockInLng'] as num?)?.toDouble(),
      clockOutLat: (map['clockOutLat'] as num?)?.toDouble(),
      clockOutLng: (map['clockOutLng'] as num?)?.toDouble(),
    );
  }
}

class WorkingHoursCalendarModel {
  List<DateTime> presentDays;
  List<DateTime> absentDays;
  List<DateTime> officeHolidays;
  WorkingHoursCalendarModel({
    required this.presentDays,
    required this.absentDays,
    required this.officeHolidays,
  });

  WorkingHoursCalendarModel copyWith({
    List<DateTime>? presentDays,
    List<DateTime>? absentDays,
    List<DateTime>? officeHolidays,
  }) {
    return WorkingHoursCalendarModel(
      presentDays: presentDays ?? this.presentDays,
      absentDays: absentDays ?? this.absentDays,
      officeHolidays: officeHolidays ?? this.officeHolidays,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'presentDays': presentDays.map((x) => x.millisecondsSinceEpoch).toList(),
      'absentDays': absentDays.map((x) => x.millisecondsSinceEpoch).toList(),
      'officeHolidays': officeHolidays
          .map((x) => x.millisecondsSinceEpoch)
          .toList(),
    };
  }

  factory WorkingHoursCalendarModel.fromMap(Map<String, dynamic> map) {
    return WorkingHoursCalendarModel(
      presentDays: List<DateTime>.from(
        (map['presentDays'] as List<int>).map<DateTime>(
          (x) => DateTime.fromMillisecondsSinceEpoch(x),
        ),
      ),
      absentDays: List<DateTime>.from(
        (map['absentDays'] as List<int>).map<DateTime>(
          (x) => DateTime.fromMillisecondsSinceEpoch(x),
        ),
      ),
      officeHolidays: List<DateTime>.from(
        (map['officeHolidays'] as List<int>).map<DateTime>(
          (x) => DateTime.fromMillisecondsSinceEpoch(x),
        ),
      ),
    );
  }
}
