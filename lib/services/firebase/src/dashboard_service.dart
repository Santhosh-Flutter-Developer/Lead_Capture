import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/api/api.dart';
import '/services/services.dart';

/// Dashboard data.
/// KPI counts come from dashboard.php `overview` (server side, same filter
/// names as the app). Values the server does not return (pending tasks,
/// assigned tickets, chart lists, notifications, deadlines) are derived from
/// the already migrated API services.
class DashboardService {
  String _serverFilter(String filter) {
    switch (filter) {
      case 'Today':
      case 'This Week':
      case 'This Month':
      case 'Custom Date':
        return filter;
      default:
        return 'All';
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTimeRange _range(String filter, DateTimeRange? custom) {
    final now = DateTime.now();
    switch (filter) {
      case 'Today':
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case 'This Week':
        final s = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(s.year, s.month, s.day), end: now);
      case 'This Month':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case 'Custom Date':
        return custom ?? DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      default:
        return DateTimeRange(start: DateTime(2000), end: now);
    }
  }

  bool _inRange(DateTime d, DateTimeRange r) {
    final end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
    return !d.isBefore(DateTime(r.start.year, r.start.month, r.start.day)) && !d.isAfter(end);
  }

  Future<T> _safe<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('Dashboard partial load failed: $e');
      return fallback;
    }
  }

  Future<DashboardModel> fetchDashboardData({
    required bool isAdmin,
    required String userId,
    required String filter,
    DateTimeRange? range,
  }) async {
    try {
      final r = _range(filter, range);
      final res = (await DashboardApiService.overview(
        filter: _serverFilter(filter),
        startDate: filter == 'Custom Date' ? _ymd(r.start) : null,
        endDate: filter == 'Custom Date' ? _ymd(r.end) : null,
      ))
          .ensureSuccess();
      final kpi = Js.m(res.dataMap['kpi']);

      final results = await Future.wait([
        _safe(() => TaskService.getAllTasks(), <TaskModel>[]),
        _safe(() => TicketService.getAllTickets(), <CustomerTicketModel>[]),
        _safe(() => _notifications(), <NotificationModel>[]),
        _safe(() => EventService.getAllEvents(), <EventModel>[]),
        _safe(() => RecentActivityService().getRecentActivities(), <ActivityItem>[]),
        _safe(() => isAdmin ? LeadService.getAllLeads() : Future.value(<LeadModel>[]), <LeadModel>[]),
        _safe(() => isAdmin ? DealService.getAllDeals() : Future.value(<DealModel>[]), <DealModel>[]),
      ]);

      final tasks = results[0] as List<TaskModel>;
      final tickets = results[1] as List<CustomerTicketModel>;
      final notifications = results[2] as List<NotificationModel>;
      final events = results[3] as List<EventModel>;
      final recent = results[4] as List<ActivityItem>;
      final leads = results[5] as List<LeadModel>;
      final deals = results[6] as List<DealModel>;

      final pendingTasks =
          tasks.where((t) => !t.completed && _inRange(t.createdAt, r)).length;
      final assignedTickets = tickets
          .where((t) => t.assignTo.contains(userId) && _inRange(t.createdAt, r))
          .length;

      return DashboardModel(
        totalLeads: Js.i(kpi['totalLeads']) ?? 0,
        convertedLeads: Js.i(kpi['convertedLeads']) ?? 0,
        ongoingDeals: Js.i(kpi['ongoingDeals']) ?? 0,
        pendingTasks: pendingTasks,
        activeEmployees: Js.i(kpi['activeEmployees']) ?? 0,
        assignedTasks: Js.i(kpi['assignedTasks']) ?? 0,
        pendingFollowUps: Js.i(kpi['pendingFollowUps']) ?? 0,
        leadsAssigned: Js.i(kpi['leadsAssigned']) ?? 0,
        totalTickets: Js.i(kpi['totalTickets']) ?? 0,
        pendingTickets: Js.i(kpi['pendingTickets']) ?? 0,
        assignedTickets: assignedTickets,
        recentActivities: recent,
        notifications: notifications,
        upcomingTasks: _upcoming(tasks, events, tickets),
        allLeads: leads.take(500).toList(),
        allDeals: deals.take(500).toList(),
        allTasks: isAdmin ? tasks.take(500).toList() : <TaskModel>[],
        allTickets: isAdmin ? tickets.take(500).toList() : <CustomerTicketModel>[],
      );
    } catch (e, st) {
      debugPrint('Error fetching dashboard: $e\n$st');
      throw 'Error fetching dashboard: $e';
    }
  }

  Future<List<NotificationModel>> _notifications() async {
    final res = (await NotificationsApiService.call('list')).ensureSuccess();
    final list = Js.mapList(res.dataMap['notifications'])
        .map((m) => CrmMappers.notification(m))
        .toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return list.take(5).toList();
  }

  /// Next 24h deadlines from tasks, events and tickets (same rule as before).
  List<UpcomingDeadlineItemModel> _upcoming(
    List<TaskModel> tasks,
    List<EventModel> events,
    List<CustomerTicketModel> tickets,
  ) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 1));
    bool within(DateTime d) => d.isAfter(now) && !d.isAfter(end);
    final out = <UpcomingDeadlineItemModel>[];
    for (final t in tasks) {
      final d = t.deadline;
      if (!t.completed && d != null && within(d)) {
        out.add(UpcomingDeadlineItemModel(
            id: t.uid ?? '', title: t.taskName, scheduledAt: d, source: 'task'));
      }
    }
    for (final e in events) {
      if (!e.completed && within(e.eventDateTime)) {
        out.add(UpcomingDeadlineItemModel(
            id: e.uid ?? '', title: e.eventName, scheduledAt: e.eventDateTime, source: 'event'));
      }
    }
    for (final t in tickets) {
      final d = t.deadline;
      if (d != null && t.status != TicketStatus.closed && within(d)) {
        out.add(UpcomingDeadlineItemModel(
            id: t.uid ?? '', title: t.ticketTitle, scheduledAt: d, source: 'ticket'));
      }
    }
    out.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return out.take(5).toList();
  }
}
