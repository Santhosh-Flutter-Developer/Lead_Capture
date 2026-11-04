import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTimeRange _resolveDateRange(String filter, DateTimeRange? customRange) {
    final now = DateTime.now();

    switch (filter) {
      case "Today":
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: now,
        );

      case "This Week":
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: start, end: now);

      case "This Month":
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);

      case "Custom Date":
        if (customRange != null) {
          return customRange;
        } else {
          debugPrint("Custom date range is null, defaulting to today");
          return DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: now,
          );
        }

      default:
        return DateTimeRange(start: DateTime(2000), end: now);
    }
  }

  Future<DashboardModel> fetchDashboardData({
    required bool isAdmin,
    required String userId,
    required String filter,
    DateTimeRange? range,
  }) async {
    try {
      final cid = await Spdb.getCid();
      if (cid == null) throw "CollectionId cannot be null";

      final dateRange = _resolveDateRange(filter, range);

      // Parallelize independent count queries for better performance
      final results = await Future.wait([
        _fetchTotalLeads(cid, dateRange),
        _fetchConvertedLeads(cid, dateRange),
        _fetchOngoingDeals(cid, dateRange),
        _fetchPendingTasks(cid, dateRange),
        _fetchActiveEmployees(cid, dateRange),
        _fetchAssignedTasks(cid, userId, dateRange),
        _fetchPendingFollowUps(cid, dateRange),
        _fetchLeadsAssigned(cid, userId, dateRange),
        _fetchTotalTickets(cid, dateRange),
        _fetchPendingTickets(cid, dateRange),
        _fetchAssignedTickets(cid, userId, dateRange),
        _fetchNotifications(cid, userId),
        _fetchUpcomingTasks(cid),
        RecentActivityService().getRecentActivities(),
      ]);

      final totalLeads = results[0] as int;
      final convertedLeads = results[1] as int;
      final ongoingDeals = results[2] as int;
      final pendingTasks = results[3] as int;
      final activeEmployees = results[4] as int;
      final assignedTasks = results[5] as int;
      final pendingFollowUps = results[6] as int;
      final leadsAssigned = results[7] as int;
      final totalTickets = results[8] as int;
      final pendingTickets = results[9] as int;
      final assignedTickets = results[10] as int;
      final notifications = results[11] as List<NotificationModel>;
      final upcomingTasks = results[12] as List<UpcomingDeadlineItemModel>;
      final recentActivities = results[13] as List<ActivityItem>;

      // Only fetch chart data if admin (optimization)
      final allLeads = isAdmin
          ? await _fetchLeadsForCharts(cid)
          : <LeadModel>[];
      final allDeals = isAdmin
          ? await _fetchDealsForCharts(cid)
          : <DealModel>[];
      final allTasks = isAdmin
          ? await _fetchTasksForCharts(cid)
          : <TaskModel>[];
      final allTickets = isAdmin
          ? await _fetchTicketsForCharts(cid)
          : <CustomerTicketModel>[];
      // List<HolidayModel> holidays = [];

      // Parallelize attendance and salary fetch
      // final payrollResults = await Future.wait([
      //   AttendanceService.getAttendanceStats(
      //     userUid: userId,
      //     fromDate: dateRange.start,
      //     toDate: dateRange.end,
      //     holidays: holidays,
      //   ),
      //   SalaryLedgerService.getSalarySummary(
      //     userUid: userId,
      //     fromDate: dateRange.start,
      //     toDate: dateRange.end,
      //   ),
      // ]);

      // final attendanceStats = payrollResults[0] as AttendanceStatsModel;
      // final salary = payrollResults[1] as SalarySummaryModel;
      return DashboardModel(
        totalLeads: totalLeads,
        convertedLeads: convertedLeads,
        ongoingDeals: ongoingDeals,
        pendingTasks: pendingTasks,
        activeEmployees: activeEmployees,
        assignedTasks: assignedTasks,
        pendingFollowUps: pendingFollowUps,
        leadsAssigned: leadsAssigned,
        totalTickets: totalTickets,
        pendingTickets: pendingTickets,
        assignedTickets: assignedTickets,
        recentActivities: recentActivities,
        notifications: notifications,
        upcomingTasks: upcomingTasks,
        allLeads: allLeads,
        allDeals: allDeals,
        allTasks: allTasks,
        allTickets: allTickets,
        // attendanceStats: attendanceStats,
        // salary: salary,
      );
    } catch (e, st) {
      debugPrint("Error fetching dashboard: $e\n$st");
      throw 'Error fetching dashboard: $e';
    }
  }

  Future<int> _fetchTotalLeads(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchConvertedLeads(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where("leadsConversion", isEqualTo: true)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchOngoingDeals(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.deals.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchPendingTasks(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.tasks.name)
        .where("completed", isEqualTo: false)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchActiveEmployees(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.employees.name)
        .where("isActive", isEqualTo: true)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchAssignedTasks(
    String cid,
    String userId,
    DateTimeRange range,
  ) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.tasks.name)
        .where("assignees", arrayContains: userId)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchLeadsAssigned(
    String cid,
    String userId,
    DateTimeRange range,
  ) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where("assignedTo", isEqualTo: userId)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchPendingFollowUps(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.leads.name)
        .where("allowFollowUp", isEqualTo: true)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchTotalTickets(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchPendingTickets(String cid, DateTimeRange range) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .where("status", isEqualTo: TicketStatus.open.name)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  Future<int> _fetchAssignedTickets(
    String cid,
    String userId,
    DateTimeRange range,
  ) async {
    final snap = await _firestore
        .collection(Collections.users.name)
        .doc(cid)
        .collection(Collections.customerTickets.name)
        .where("assignTo", arrayContains: userId)
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: range.start.millisecondsSinceEpoch,
        )
        .where(
          "createdAt",
          isLessThanOrEqualTo: range.end.millisecondsSinceEpoch,
        )
        .count()
        .get();

    return snap.count ?? 0;
  }

  // Future<List<String>> _fetchPersonalActivities(String userId) async {
  //   final snap = await _firestore
  //       .collection("personalActivities")
  //       .where("userId", isEqualTo: userId)
  //       .orderBy("createdAt", descending: true)
  //       .limit(5)
  //       .get();
  //   return snap.docs.map((d) => d.data()['activity'].toString()).toList();
  // }

  Future<List<NotificationModel>> _fetchNotifications(
    String cid,
    String userId,
  ) async {
    try {
      final snap = await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.notifications.name)
          .where("toUids", arrayContains: userId)
          .orderBy("createdAt", descending: true)
          .limit(5)
          .get();

      return snap.docs
          .map((d) => NotificationModel.fromMap(d.id, d.data()))
          .toList();
    } catch (e, st) {
      debugPrint("Error fetching notifications: $e\n$st");
      throw 'Error fetching notifications: $e';
    }
  }

  Future<List<LeadModel>> _fetchLeadsForCharts(String cid) async {
    try {
      final snap = await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.leads.name)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      return FollowUpAccess.filterVisible(
        snap.docs.map((d) => LeadModel.fromMap(d.id, d.data())).toList(),
        (l) => l.followUp,
      );
    } catch (e, st) {
      debugPrint("Error fetching leads for charts: $e\n$st");
      return [];
    }
  }

  Future<List<DealModel>> _fetchDealsForCharts(String cid) async {
    try {
      final snap = await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.deals.name)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      return FollowUpAccess.filterVisible(
        snap.docs.map((d) => DealModel.fromMap(d.id, d.data())).toList(),
        (d) => d.followUp,
      );
    } catch (e, st) {
      debugPrint("Error fetching deals for charts: $e\n$st");
      return [];
    }
  }

  Future<List<TaskModel>> _fetchTasksForCharts(String cid) async {
    try {
      final snap = await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.tasks.name)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      return snap.docs.map((d) => TaskModel.fromMap(d.id, d.data())).toList();
    } catch (e, st) {
      debugPrint("Error fetching tasks for charts: $e\n$st");
      return [];
    }
  }

  Future<List<CustomerTicketModel>> _fetchTicketsForCharts(String cid) async {
    try {
      final snap = await _firestore
          .collection(Collections.users.name)
          .doc(cid)
          .collection(Collections.customerTickets.name)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();
      return snap.docs
          .map((d) => CustomerTicketModel.fromMap(d.id, d.data()))
          .toList();
    } catch (e, st) {
      debugPrint("Error fetching tickets for charts: $e\n$st");
      return [];
    }
  }

  Future<List<UpcomingDeadlineItemModel>> _fetchUpcomingTasks(
    String cid,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.millisecondsSinceEpoch;
      final end = now.add(const Duration(days: 1)).millisecondsSinceEpoch;

      // Parallelize the three queries and add limits
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.tasks.name)
            .where("deadline", isGreaterThan: start)
            .where("deadline", isLessThanOrEqualTo: end)
            .where("completed", isEqualTo: false)
            .orderBy("deadline")
            .limit(10)
            .get(),
        FirebaseFirestore.instance
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.events.name)
            .where("eventDateTime", isGreaterThan: start)
            .where("eventDateTime", isLessThanOrEqualTo: end)
            .where("completed", isEqualTo: false)
            .orderBy("eventDateTime")
            .limit(10)
            .get(),
        FirebaseFirestore.instance
            .collection(Collections.users.name)
            .doc(cid)
            .collection(Collections.customerTickets.name)
            .where("deadline", isGreaterThan: start)
            .where("deadline", isLessThanOrEqualTo: end)
            .where("status", isNotEqualTo: TicketStatus.closed.name)
            .orderBy("deadline")
            .limit(10)
            .get(),
      ]);

      final tasksSnap = results[0] as QuerySnapshot;
      final eventsSnap = results[1] as QuerySnapshot;
      final ticketsSnap = results[2] as QuerySnapshot;

      final upcoming = <UpcomingDeadlineItemModel>[];

      for (final d in tasksSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        upcoming.add(
          UpcomingDeadlineItemModel(
            id: d.id,
            title: data['taskName'] ?? 'Task',
            scheduledAt: DateTime.fromMillisecondsSinceEpoch(data['deadline']),
            source: 'task',
          ),
        );
      }

      for (final d in eventsSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        upcoming.add(
          UpcomingDeadlineItemModel(
            id: d.id,
            title: data['eventName'] ?? 'Event',
            scheduledAt: DateTime.fromMillisecondsSinceEpoch(
              data['eventDateTime'],
            ),
            source: 'event',
          ),
        );
      }

      for (final d in ticketsSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (data['deadline'] != null) {
          upcoming.add(
            UpcomingDeadlineItemModel(
              id: d.id,
              title: data['ticketTitle'] ?? 'Ticket',
              scheduledAt: DateTime.fromMillisecondsSinceEpoch(
                data['deadline'],
              ),
              source: 'ticket',
            ),
          );
        }
      }

      upcoming.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

      return upcoming.take(5).toList();
    } catch (e, st) {
      debugPrint("Error fetching upcoming tasks: $e\n$st");
      return [];
    }
  }
}