import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/api/api.dart';
import '/services/services.dart';

/// Dashboard data.
///
/// Every count is worked out from the same role-scoped list APIs the listing
/// screens use (leads.php / deals.php / tasks.php / tickets.php), so a card
/// always matches the page it opens:
///   * admin / super admin           -> whole company
///   * role with "All Leads/Deals"   -> whole company (server decides)
///   * any other role                -> only records the user created,
///                                      follows up, or is assigned to
/// One date filter (created date) is applied to every count, the same one
/// shown in the dropdown. Only "Active Staff" (company wide) is read from
/// dashboard.php `overview`; the other server KPIs are used as a fallback
/// when a list cannot be loaded.
class DashboardService {
  /// Accepts the labels used by the dropdown and the empty / lower-case
  /// values the main screens send for the first load ('' / 'all').
  String _normalizeFilter(String filter) {
    switch (filter.trim().toLowerCase()) {
      case 'today':
        return 'Today';
      case 'this week':
        return 'This Week';
      case 'this month':
        return 'This Month';
      case 'custom date':
      case 'custom':
        return 'Custom Date';
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

  /// Lead is converted when the server flagged it or a deal exists for it.
  bool _isConverted(LeadModel l) =>
      l.leadsConverted || (l.dealId ?? '').isNotEmpty;

  bool _isOpenTicket(CustomerTicketModel t) =>
      !t.isCancelled &&
      t.status != TicketStatus.resolved &&
      t.status != TicketStatus.closed;

  Future<DashboardModel> fetchDashboardData({
    required bool isAdmin,
    required String userId,
    required String filter,
    DateTimeRange? range,
  }) async {
    try {
      final f = _normalizeFilter(filter);
      final r = _range(f, range);
      final res = (await DashboardApiService.overview(
        filter: f,
        startDate: f == 'Custom Date' ? _ymd(r.start) : null,
        endDate: f == 'Custom Date' ? _ymd(r.end) : null,
      ))
          .ensureSuccess();
      final kpi = Js.m(res.dataMap['kpi']);

      // null = the list could not be loaded (then the server KPI is used).
      final results = await Future.wait<Object?>([
        _safe<List<TaskModel>?>(() => TaskService.getAllTasks(), null),
        _safe<List<CustomerTicketModel>?>(() => TicketService.getAllTickets(), null),
        _safe(() => _notifications(), <NotificationModel>[]),
        _safe(() => EventService.getAllEvents(), <EventModel>[]),
        _safe(() => RecentActivityService().getRecentActivities(), <ActivityItem>[]),
        // Leads are role scoped by leads.php (admin / "All Leads" role ->
        // everything, otherwise created or follow-up only).
        _safe<List<LeadModel>?>(() => LeadService.getAllLeads(), null),
        // Deals are only needed for the admin cards / charts.
        _safe<List<DealModel>?>(
            () => isAdmin ? DealService.getAllDeals() : Future.value(<DealModel>[]), null),
        _safe<List<DealStatusModel>>(
            () => isAdmin ? DealStatusService.getAllDealStatus() : Future.value(<DealStatusModel>[]),
            <DealStatusModel>[]),
      ]);

      final allTasks = results[0] as List<TaskModel>?;
      final allTickets = results[1] as List<CustomerTicketModel>?;
      final notifications = results[2] as List<NotificationModel>;
      final events = results[3] as List<EventModel>;
      final recent = results[4] as List<ActivityItem>;
      final allLeadsList = results[5] as List<LeadModel>?;
      final allDealsList = results[6] as List<DealModel>?;
      final dealStatuses = results[7] as List<DealStatusModel>;

      final tasks = allTasks ?? <TaskModel>[];
      final tickets = allTickets ?? <CustomerTicketModel>[];
      final leads = allLeadsList ?? <LeadModel>[];
      final deals = allDealsList ?? <DealModel>[];

      // ---------------- Leads (role scoped by the API) ----------------
      final leadsInRange = leads.where((l) => _inRange(l.createdAt, r)).toList();
      final totalLeads =
          allLeadsList == null ? (Js.i(kpi['totalLeads']) ?? 0) : leadsInRange.length;
      // Same population as "Total Leads" (created in range) so the converted
      // number can never be larger than the total.
      final convertedLeads = allLeadsList == null
          ? (Js.i(kpi['convertedLeads']) ?? 0)
          : leadsInRange.where(_isConverted).length;
      // Open (not converted) leads the user can see.
      final pendingFollowUps = allLeadsList == null
          ? (Js.i(kpi['pendingFollowUps']) ?? 0)
          : leadsInRange.where((l) => !_isConverted(l)).length;
      // Leads the user can see: all leads for admin / "All Leads" roles,
      // otherwise the leads created by or assigned (follow-up) to the user.
      final leadsAssigned = allLeadsList == null
          ? (Js.i(kpi['leadsAssigned']) ?? 0)
          : leadsInRange.length;

      // ---------------- Deals (role scoped by the API) ----------------
      final statusById = {
        for (final s in dealStatuses)
          if ((s.uid ?? '').isNotEmpty) s.uid!: s,
      };
      bool isOngoing(DealModel d) {
        if (d.isLocked) return false;
        final st = statusById[d.dealStatus ?? ''];
        if (st == null) return true;
        final n = st.name.trim().toLowerCase();
        const closed = {'won', 'lost', 'complete', 'completed', 'closed'};
        return !(st.isFinal || closed.contains(n));
      }

      final ongoingDeals = allDealsList == null
          ? (Js.i(kpi['ongoingDeals']) ?? 0)
          : deals.where((d) => _inRange(d.createdAt, r) && isOngoing(d)).length;

      // ---------------- Tasks ----------------
      // Tasks the user is an assignee of that are still active.
      final assignedTasks = allTasks == null
          ? (Js.i(kpi['assignedTasks']) ?? 0)
          : tasks
                .where((t) =>
                    t.assignees.contains(userId) &&
                    !t.completed &&
                    !t.isCancelled &&
                    _inRange(t.createdAt, r))
                .length;
      final pendingTasks = tasks
          .where((t) => !t.completed && !t.isCancelled && _inRange(t.createdAt, r))
          .length;

      // ---------------- Tickets ----------------
      final ticketsInRange = tickets.where((t) => _inRange(t.createdAt, r)).toList();
      final totalTickets =
          allTickets == null ? (Js.i(kpi['totalTickets']) ?? 0) : ticketsInRange.length;
      final pendingTickets = allTickets == null
          ? (Js.i(kpi['pendingTickets']) ?? 0)
          : ticketsInRange.where(_isOpenTicket).length;
      final assignedTickets = ticketsInRange
          .where((t) => t.assignTo.contains(userId) && _isOpenTicket(t))
          .length;

      return DashboardModel(
        totalLeads: totalLeads,
        convertedLeads: convertedLeads,
        ongoingDeals: ongoingDeals,
        pendingTasks: pendingTasks,
        // Company wide head count (not date based) - from dashboard.php.
        activeEmployees: Js.i(kpi['activeEmployees']) ?? 0,
        assignedTasks: assignedTasks,
        pendingFollowUps: pendingFollowUps,
        leadsAssigned: leadsAssigned,
        totalTickets: totalTickets,
        pendingTickets: pendingTickets,
        assignedTickets: assignedTickets,
        recentActivities: recent,
        notifications: notifications,
        upcomingTasks: _upcoming(tasks, events, tickets),
        allLeads: isAdmin ? leads.take(500).toList() : <LeadModel>[],
        allDeals: isAdmin ? deals.take(500).toList() : <DealModel>[],
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