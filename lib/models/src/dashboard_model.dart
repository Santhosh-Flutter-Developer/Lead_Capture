import '/models/models.dart';

class DashboardModel {
  final int totalLeads;
  final int convertedLeads;
  final int ongoingDeals;
  final int pendingTasks;
  final int activeEmployees;
  final int assignedTasks;
  final int pendingFollowUps;
  final int leadsAssigned;
  final int totalTickets;
  final int pendingTickets;
  final int assignedTickets;
  final List<ActivityItem> recentActivities;
  final List<String> personalActivities;
  final List<NotificationModel> notifications;
  final List<UpcomingDeadlineItemModel> upcomingTasks;
  final List<LeadModel> allLeads;
  final List<DealModel> allDeals;
  final List<TaskModel> allTasks;
  final List<CustomerTicketModel> allTickets;
  // final AttendanceStats attendanceStats;
  // final SalaryModel salary;

  DashboardModel({
    required this.totalLeads,
    required this.convertedLeads,
    required this.ongoingDeals,
    required this.pendingTasks,
    required this.activeEmployees,
    this.assignedTasks = 0,
    this.pendingFollowUps = 0,
    this.leadsAssigned = 0,
    this.totalTickets = 0,
    this.pendingTickets = 0,
    this.assignedTickets = 0,
    this.recentActivities = const [],
    this.personalActivities = const [],
    this.notifications = const [],
    this.upcomingTasks = const [],
    required this.allLeads,
    required this.allDeals,
    required this.allTasks,
    this.allTickets = const [],
    // required this.attendanceStats,
    // required this.salary,
  });

  factory DashboardModel.fromMap(Map<String, dynamic> map) {
    return DashboardModel(
      totalLeads: map['totalLeads'] is int
          ? map['totalLeads'] as int
          : int.tryParse(map['totalLeads']?.toString() ?? '0') ?? 0,
      convertedLeads: map['convertedLeads'] is int
          ? map['convertedLeads'] as int
          : int.tryParse(map['convertedLeads']?.toString() ?? '0') ?? 0,
      ongoingDeals: map['ongoingDeals'] is int
          ? map['ongoingDeals'] as int
          : int.tryParse(map['ongoingDeals']?.toString() ?? '0') ?? 0,
      pendingTasks: map['pendingTasks'] is int
          ? map['pendingTasks'] as int
          : int.tryParse(map['pendingTasks']?.toString() ?? '0') ?? 0,
      activeEmployees: map['activeEmployees'] is int
          ? map['activeEmployees'] as int
          : int.tryParse(map['activeEmployees']?.toString() ?? '0') ?? 0,
      assignedTasks: map['assignedTasks'] is int
          ? map['assignedTasks'] as int
          : int.tryParse(map['assignedTasks']?.toString() ?? '0') ?? 0,
      pendingFollowUps: map['pendingFollowUps'] is int
          ? map['pendingFollowUps'] as int
          : int.tryParse(map['pendingFollowUps']?.toString() ?? '0') ?? 0,
      leadsAssigned: map['leadsAssigned'] is int
          ? map['leadsAssigned'] as int
          : int.tryParse(map['leadsAssigned']?.toString() ?? '0') ?? 0,
      totalTickets: map['totalTickets'] is int
          ? map['totalTickets'] as int
          : int.tryParse(map['totalTickets']?.toString() ?? '0') ?? 0,
      pendingTickets: map['pendingTickets'] is int
          ? map['pendingTickets'] as int
          : int.tryParse(map['pendingTickets']?.toString() ?? '0') ?? 0,
      assignedTickets: map['assignedTickets'] is int
          ? map['assignedTickets'] as int
          : int.tryParse(map['assignedTickets']?.toString() ?? '0') ?? 0,
      recentActivities:
          map['recentActivities'] != null && map['recentActivities'] is List
          ? List<ActivityItem>.from(
              (map['recentActivities'] as List).map(
                (e) => ActivityItem.fromMap(e),
              ),
            )
          : [],
      personalActivities:
          map['personalActivities'] != null && map['personalActivities'] is List
          ? List<String>.from(
              (map['personalActivities'] as List).map((e) => e.toString()),
            )
          : [],
      notifications:
          map['notifications'] != null && map['notifications'] is List
          ? List<NotificationModel>.from(
              (map['notifications'] as List).map(
                (e) => NotificationModel.fromMap(
                  e['uid'],
                  e as Map<String, dynamic>,
                ),
              ),
            )
          : [],
      upcomingTasks:
          map['upcomingTasks'] != null && map['upcomingTasks'] is List
          ? List<UpcomingDeadlineItemModel>.from(
              (map['upcomingTasks'] as List).map(
                (e) => UpcomingDeadlineItemModel.fromMap(
                  e as Map<String, dynamic>,
                ),
              ),
            )
          : const [],
      allLeads: map['allLeads'] != null && map['allLeads'] is List
          ? List<LeadModel>.from(
              (map['allLeads'] as List).map(
                (e) => LeadModel.fromMap(e['uid'], e as Map<String, dynamic>),
              ),
            )
          : [],
      allDeals: map['allDeals'] != null && map['allDeals'] is List
          ? List<DealModel>.from(
              (map['allDeals'] as List).map(
                (e) => DealModel.fromMap(e['uid'], e as Map<String, dynamic>),
              ),
            )
          : [],
      allTasks: map['allTasks'] != null && map['allTasks'] is List
          ? List<TaskModel>.from(
              (map['allTasks'] as List).map(
                (e) => TaskModel.fromMap(e['uid'], e as Map<String, dynamic>),
              ),
            )
          : [],
      allTickets: map['allTickets'] != null && map['allTickets'] is List
          ? List<CustomerTicketModel>.from(
              (map['allTickets'] as List).map(
                (e) => CustomerTicketModel.fromMap(
                  e['uid'],
                  e as Map<String, dynamic>,
                ),
              ),
            )
          : [],
      // attendanceStats: map['attendanceStats'] != null
      //     ? AttendanceStats.fromMap(
      //         map['attendanceStats'] as Map<String, dynamic>,
      //       )
      //     : AttendanceStats(
      //         presentDays: 0,
      //         absentDays: 0,
      //         leaveDays: 0,
      //         holidayDays: 0,
      //         wfhDays: 0,
      //         halfDayDays: 0,
      //         lateDays: 0,
      //         earlyExitDays: 0,
      //         totalWorkingHours: '0',
      //         totalLessHours: '0',
      //         totalOTHours: '0',
      //         attendanceData: [],
      //       ),
      // salary: map['salary'] != null
      //     ? SalaryModel.fromMap(map['salary'] as Map<String, dynamic>)
      //     : SalaryModel(
      //         salaryNumber: '',
      //         employeeId: '',
      //         permissionId: '',
      //         workingDays: '0',
      //         leaveDays: '0',
      //         otHours: '0',
      //         earnAmount: '0',
      //         otAmount: '0',
      //         incentive: '0',
      //         grossPay: '0',
      //         otherDeduction: '0',
      //         pfAmount: '0',
      //         esiAmount: '0',
      //         advanceDeduction: '0',
      //         totalDeduction: '0',
      //         netPay: '0',
      //         salaryFromDate: DateTime.now().toIso8601String(),
      //         salaryToDate: DateTime.now().toIso8601String(),
      //       ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "totalLeads": totalLeads,
      "convertedLeads": convertedLeads,
      "ongoingDeals": ongoingDeals,
      "pendingTasks": pendingTasks,
      "activeEmployees": activeEmployees,
      "assignedTasks": assignedTasks,
      "pendingFollowUps": pendingFollowUps,
      "leadsAssigned": leadsAssigned,
      "totalTickets": totalTickets,
      "pendingTickets": pendingTickets,
      "assignedTickets": assignedTickets,
      "recentActivities": recentActivities,
      "personalActivities": personalActivities,
      "notifications": notifications,
      "upcomingTasks": upcomingTasks.map((e) => e.toMap()).toList(),
      "allLeads": allLeads.map((e) => e.toMap()).toList(),
      "allDeals": allDeals.map((e) => e.toMap()).toList(),
      "allTasks": allTasks.map((e) => e.toMap()).toList(),
      "allTickets": allTickets.map((e) => e.toMap()).toList(),
      // "attendanceStats": attendanceStats.toMap(),
      // "salary": salary.toMap(),
    };
  }

  // PunchModel? get todayAttendance {
  //   if (attendanceStats.attendanceData.isEmpty) return null;

  //   final today = DateTime.now();

  //   for (var attendance in attendanceStats.attendanceData) {
  //     for (var punch in attendance.punchList) {
  //       final punchDate = DateTime.tryParse(punch.punchDate);

  //       if (punchDate != null &&
  //           punchDate.year == today.year &&
  //           punchDate.month == today.month &&
  //           punchDate.day == today.day) {
  //         return punch;
  //       }
  //     }
  //   }

  //   return null;
  // }

  // static int _toInt(dynamic value) {
  //   return int.tryParse(value?.toString() ?? '0') ?? 0;
  // }

  // static List<String> _toStringList(dynamic value) {
  //   if (value is List) {
  //     return value.map((e) => e.toString()).toList();
  //   }
  //   return [];
  // }
}
