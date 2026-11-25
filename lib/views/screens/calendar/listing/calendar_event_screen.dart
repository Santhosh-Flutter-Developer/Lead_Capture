import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/views/screens/calendar/form/event_view.dart';
import '/constants/constants.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';

const List<Color> _brandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];
const Color _brandBlue = Color(0xFF0052D4);
const Color _dealColor = Color(0xFF8B5CF6);

/// Calendar filter chips: All / Events / Tasks / Leads / Deals / Tickets.
enum _CalFilter { all, events, tasks, leads, deals, tickets }

extension _CalFilterX on _CalFilter {
  String get label {
    switch (this) {
      case _CalFilter.all:
        return 'All';
      case _CalFilter.events:
        return 'Events';
      case _CalFilter.tasks:
        return 'Tasks';
      case _CalFilter.leads:
        return 'Leads';
      case _CalFilter.deals:
        return 'Deals';
      case _CalFilter.tickets:
        return 'Tickets';
    }
  }

  Color get color {
    switch (this) {
      case _CalFilter.all:
        return _brandBlue;
      case _CalFilter.events:
        return const Color(0xFF4364F7);
      case _CalFilter.tasks:
        return AppColors.info;
      case _CalFilter.leads:
        return AppColors.success;
      case _CalFilter.deals:
        return _dealColor;
      case _CalFilter.tickets:
        return AppColors.warning;
    }
  }
}

/// One normalised calendar entry (event / task / lead / deal / ticket).
class _CalItem {
  final dynamic source;
  final _CalFilter kind;
  final String title;
  final DateTime date;
  final String timeLabel;
  final String createdBy;
  final String description;
  final String category;
  final Color color;
  final IconData icon;
  final String badge;
  final String? subBadge;
  final bool completed;
  final String completedLabel;

  const _CalItem({
    required this.source,
    required this.kind,
    required this.title,
    required this.date,
    required this.timeLabel,
    required this.createdBy,
    required this.description,
    required this.category,
    required this.color,
    required this.icon,
    required this.badge,
    this.subBadge,
    this.completed = false,
    this.completedLabel = 'Completed',
  });
}

class CalendarEventScreen extends StatelessWidget {
  final bool showAppbar;
  const CalendarEventScreen({super.key, this.showAppbar = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CalendarBloc()..add(StreamCalendar()),
      child: CalendarDisplay(showAppbar: showAppbar),
    );
  }
}

class CalendarDisplay extends StatefulWidget {
  final bool showAppbar;
  const CalendarDisplay({super.key, this.showAppbar = true});

  @override
  State<CalendarDisplay> createState() => _CalendarDisplayState();
}

class _CalendarDisplayState extends State<CalendarDisplay> {
  static const double _stripItemExtent = 70; // 60 width + 2*5 margin
  static const int _stripDays = 30;

  Calendar _currentView = Calendar.month;
  _CalFilter _filter = _CalFilter.all;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  late DateTime _stripStart;

  PermissionModel? _permissions;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _dialogScrollController = ScrollController();
  final ScrollController _stripController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchFocused = false;
  String _searchQuery = '';

  // Rebuilt on every build from the bloc state + active filter.
  List<_CalItem> _items = [];
  Map<String, List<_CalItem>> _byDay = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _stripStart = DateTime(now.year, now.month, now.day - 7);
    _loadPermissions();
    _searchFocusNode.addListener(() {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStripToSelected());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _vScrollController.dispose();
    _dialogScrollController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Calendar');
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  String _timeOf(DateTime d) => DateFormat('hh:mm a').format(d).toLowerCase();

  int _getDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  bool get _canCreate => _permissions?.canCreate ?? false;

  _CalItem _toItem(dynamic e) {
    if (e is EventModel) {
      return _CalItem(
        source: e,
        kind: _CalFilter.events,
        title: e.eventName,
        date: e.eventDateTime,
        timeLabel: e.allDay ? 'All day' : _timeOf(e.eventDateTime),
        createdBy: e.createdBy.name,
        description: e.eventDescription,
        category: e.eventType.label,
        color: Color(e.accentColor),
        icon: Iconsax.calendar_1,
        badge: 'Event',
        subBadge: e.eventType.label,
        completed: e.completed,
      );
    }
    if (e is TaskModel) {
      final d = e.deadline ?? e.createdAt;
      return _CalItem(
        source: e,
        kind: _CalFilter.tasks,
        title: '#${e.taskNumber} ${e.taskName}',
        date: d,
        timeLabel: _timeOf(d),
        createdBy: e.taskCreatedBy.name,
        description: e.description,
        category: e.highPriority ? 'High Priority' : 'Low Priority',
        color: e.highPriority ? AppColors.danger : AppColors.info,
        icon: Iconsax.task_square,
        badge: e.highPriority ? 'High Priority Task' : 'Task',
        completed: e.completed,
      );
    }
    if (e is LeadModel) {
      final hasClient = e.clientName != null && e.clientName!.isNotEmpty;
      return _CalItem(
        source: e,
        kind: _CalFilter.leads,
        title: hasClient ? e.clientName! : e.leadName,
        date: e.createdAt,
        timeLabel: _timeOf(e.createdAt),
        createdBy: e.createdBy.name,
        description: hasClient ? e.leadName : '',
        category: e.leadName,
        color: AppColors.success,
        icon: Iconsax.personalcard,
        badge: 'Lead',
        completed: e.leadsConverted,
        completedLabel: 'Converted',
      );
    }
    if (e is DealModel) {
      final hasClient = e.clientName != null && e.clientName!.isNotEmpty;
      return _CalItem(
        source: e,
        kind: _CalFilter.deals,
        title: hasClient ? e.clientName! : e.dealName,
        date: e.createdAt,
        timeLabel: _timeOf(e.createdAt),
        createdBy: e.createdBy.name,
        description: hasClient ? e.dealName : '',
        category: e.dealName,
        color: _dealColor,
        icon: Iconsax.dollar_circle,
        badge: 'Deal',
      );
    }
    final t = e as CustomerTicketModel;
    return _CalItem(
      source: t,
      kind: _CalFilter.tickets,
      title: '#${t.ticketNumber} ${t.ticketTitle}',
      date: t.createdAt,
      timeLabel: _timeOf(t.createdAt),
      createdBy: t.ticketCreatedBy.name,
      description: t.ticketDescription,
      category: t.category.label,
      color: AppColors.warning,
      icon: Iconsax.ticket,
      badge: 'Ticket',
      subBadge: t.category.label,
      completed: t.status == TicketStatus.closed,
      completedLabel: 'Closed',
    );
  }

  /// Applies the active filter chip and groups everything by day.
  void _prepare(CalendarLoaded s) {
    final all = <_CalItem>[
      if (_filter == _CalFilter.all || _filter == _CalFilter.events)
        ...s.events.map(_toItem),
      if (_filter == _CalFilter.all || _filter == _CalFilter.tasks)
        ...s.tasks.map(_toItem),
      if (_filter == _CalFilter.all || _filter == _CalFilter.leads)
        ...s.leads.map(_toItem),
      if (_filter == _CalFilter.all || _filter == _CalFilter.deals)
        ...s.deals.map(_toItem),
      if (_filter == _CalFilter.all || _filter == _CalFilter.tickets)
        ...s.tickets.map(_toItem),
    ];
    all.sort((a, b) => a.date.compareTo(b.date));
    _items = all;
    _byDay = {};
    for (final i in all) {
      _byDay.putIfAbsent(_dayKey(i.date), () => []).add(i);
    }
  }

  List<_CalItem> _itemsFor(DateTime day) => _byDay[_dayKey(day)] ?? const [];

  List<_CalItem> _searchResults() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return [];
    final r = _items
        .where(
          (i) =>
              i.title.toLowerCase().contains(q) ||
              i.createdBy.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q) ||
              i.badge.toLowerCase().contains(q),
        )
        .toList();
    r.sort((a, b) => b.date.compareTo(a.date));
    return r;
  }

  void _open(Widget page) {
    if (kIsDesktop) {
      GeneralDialog.showRTLSheet(context, page);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }
  }

  void _onItemTap(_CalItem item) {
    final e = item.source;
    if (e is EventModel) {
      _open(EventViewPage(event: e));
    } else if (e is TaskModel) {
      _open(TaskView(uid: e.uid ?? ''));
    } else if (e is LeadModel) {
      _open(LeadsViewPage(lead: e));
    } else if (e is DealModel) {
      _open(DealsViewPage(deal: e));
    } else if (e is CustomerTicketModel) {
      _open(TicketView(uid: e.uid ?? ''));
    }
  }

  void _openCreateEvent(DateTime? forDate) {
    if (!_canCreate) return;
    if (kIsDesktop) {
      GeneralDialog.showRTLSheet(context, EventCreate(selectedDate: forDate));
    } else {
      Sheet.showSheet(context, widget: EventCreate(selectedDate: forDate));
    }
  }

  Future<void> _refresh() async {
    context.read<CalendarBloc>().add(StreamCalendar());
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _scrollStripToSelected() {
    if (!_stripController.hasClients) return;
    final index = _selectedDate
        .difference(DateTime(_stripStart.year, _stripStart.month, _stripStart.day))
        .inDays;
    final target = (index * _stripItemExtent - _stripItemExtent * 2)
        .clamp(0.0, _stripController.position.maxScrollExtent)
        .toDouble();
    _stripController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _focusedMonth = DateTime(date.year, date.month);
      _stripStart = DateTime(date.year, date.month, date.day - 7);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStripToSelected());
  }

  void _goToday() => _selectDate(DateTime.now());

  Future<void> _openDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) _selectDate(pickedDate);
  }

  void _previousMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
  );
  void _nextMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
  );

  void _shiftWeek(int direction) => setState(() {
    _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  });

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppbar
          ? AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              leading: const Back(color: AppColors.white),
              centerTitle: false,
              title: const Text(
                "Calendar",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            )
          : null,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          if (state is CalendarLoading) return const WaitingLoading();

          if (state is CalendarError) {
            return Center(
              child: Text(
                state.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          if (state is CalendarLoaded) {
            _prepare(state);
            final searching = _searchQuery.trim().isNotEmpty;
            return SafeArea(
              child: Column(
                children: [
                  if (kIsDesktop)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildHeaderBanner(),
                    ),
                  _buildViewSwitcher(),
                  _buildSearchAndFilters(),
                  if (!searching && _currentView != Calendar.month) ...[
                    _buildDateStripHeader(),
                    _buildHorizontalDatePicker(),
                  ],
                  Expanded(
                    child: searching
                        ? _buildSearchResults()
                        : _buildBody(),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case Calendar.day:
        return _scrollWrap(_buildDayView());
      case Calendar.week:
        return _scrollWrap(_buildWeekView());
      case Calendar.month:
        return _scrollWrap(_buildMonthView());
    }
  }

  Widget _scrollWrap(Widget child) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Scrollbar(
        controller: _vScrollController,
        thumbVisibility: true,
        interactive: true,
        radius: const Radius.circular(8),
        thickness: 8,
        child: SingleChildScrollView(
          controller: _vScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            kIsDesktop ? 20 : 14,
            4,
            kIsDesktop ? 20 : 14,
            24,
          ),
          child: child,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header banner (desktop only)
  // ---------------------------------------------------------------------

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _brandBlue.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Iconsax.calendar_1,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Calendar",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Stay on top of events, tasks, leads, deals & tickets",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _headerCircleButton(icon: Iconsax.refresh, onPressed: _refresh),
          const SizedBox(width: 10),
          if (_canCreate)
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openCreateEvent(_selectedDate),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: _brandBlue),
                      const SizedBox(width: 6),
                      Text(
                        "Add Event",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 18, color: AppColors.white),
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // View switcher + search + filter chips
  // ---------------------------------------------------------------------

  Widget _buildViewSwitcher() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: kIsDesktop ? 20 : 14,
        vertical: 10,
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildSwitchTab('Day', Calendar.day, Iconsax.calendar_1),
            _buildSwitchTab('Week', Calendar.week, Iconsax.calendar),
            _buildSwitchTab(
              'Month',
              Calendar.month,
              Icons.calendar_view_month_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTab(String label, Calendar view, IconData icon) {
    final isSelected = _currentView == view;
    final fg = isSelected
        ? AppColors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentView = view);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollStripToSelected(),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: _brandGradient)
                : null,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4364F7).withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final search = _buildSearchField();
    final chips = _CalFilter.values.map(_buildFilterChip).toList();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(kIsDesktop ? 20 : 14, 0, kIsDesktop ? 20 : 14, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: kIsDesktop
            ? Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 16),
                  for (final c in chips) ...[c, const SizedBox(width: 8)],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  search,
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in chips) ...[c, const SizedBox(width: 8)],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(_CalFilter f) {
    final selected = _filter == f;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _filter = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? f.color : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? f.color : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f != _CalFilter.all) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: selected ? AppColors.white : f.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              f.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 44,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchFocused
              ? primary.withValues(alpha: 0.55)
              : cs.outlineVariant,
          width: _searchFocused ? 1.4 : 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by title, created by, or category...',
          hintStyle: Theme.of(context).textTheme.bodySmall,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: _brandGradient),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(
                  Iconsax.search_normal_1,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Search results
  // ---------------------------------------------------------------------

  Widget _buildSearchResults() {
    final results = _searchResults();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.search_status,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No records found for "${_searchQuery.trim()}"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return _scrollWrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              '${results.length} result(s) found',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final r in results)
            _itemCard(r, showDate: true, onTap: () => _onItemTap(r)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Date strip (Day / Week views)
  // ---------------------------------------------------------------------

  Widget _buildDateStripHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kIsDesktop ? 20 : 14,
        6,
        kIsDesktop ? 20 : 14,
        4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          _todayButton(),
        ],
      ),
    );
  }

  Widget _todayButton() {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: _goToday,
      icon: Icon(Iconsax.calendar_1, size: 14, color: cs.primary),
      label: const Text('Today'),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: Theme.of(context).textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHorizontalDatePicker() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 84,
      child: ListView.builder(
        controller: _stripController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: kIsDesktop ? 15 : 9),
        itemCount: _stripDays,
        itemBuilder: (context, index) {
          final date = DateTime(
            _stripStart.year,
            _stripStart.month,
            _stripStart.day + index,
          );
          final isSelected = _isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _focusedMonth = DateTime(date.year, date.month);
            }),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _brandGradient,
                      )
                    : null,
                color: isSelected ? null : cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: cs.outlineVariant),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF4364F7).withValues(alpha: 0.32),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white70
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------

  Widget _pill(String label, Color color, {IconData? icon, bool solid = false}) {
    final fg = solid ? AppColors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(kIsDesktop ? 22 : 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// List card used by the day view, search results and the dialog.
  Widget _itemCard(
    _CalItem item, {
    required VoidCallback onTap,
    bool showDate = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 12);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 20, color: item.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pill(item.badge, item.color),
                          if (item.subBadge != null &&
                              item.subBadge != item.badge)
                            _pill(item.subBadge!, cs.onSurfaceVariant),
                          if (item.completed)
                            _pill(
                              item.completedLabel,
                              AppColors.success,
                              icon: Icons.check_circle_outline,
                              solid: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          style: muted,
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Iconsax.clock,
                                size: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' ${showDate ? '${DateFormat('MMM d, yyyy').format(item.date)}, ' : ''}${item.timeLabel}  •  ',
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Iconsax.user,
                                size: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(text: ' By ${item.createdBy}'),
                            if (item.description.trim().isNotEmpty)
                              TextSpan(text: '  •  ${item.description.trim()}'),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.calendar_remove,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Day view
  // ---------------------------------------------------------------------

  Widget _buildDayView() {
    final items = _itemsFor(_selectedDate);
    final count = items.length;
    final cs = Theme.of(context).colorScheme;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'No items scheduled'
                          : '$count item${count == 1 ? '' : 's'} scheduled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_canCreate)
                TextButton.icon(
                  onPressed: () => _openCreateEvent(_selectedDate),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Event'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    textStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.7), height: 1),
          const SizedBox(height: 16),
          if (items.isEmpty)
            _emptyState(
              _filter == _CalFilter.all
                  ? 'Nothing scheduled for this day'
                  : 'No ${_filter.label.toLowerCase()} for this day',
            )
          else
            for (final i in items) _itemCard(i, onTap: () => _onItemTap(i)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Week view
  // ---------------------------------------------------------------------

  Widget _buildWeekView() {
    final cs = Theme.of(context).colorScheme;
    // Week runs Sunday -> Saturday.
    final weekStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day - (_selectedDate.weekday % 7),
    );
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week of ${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, yyyy').format(weekEnd)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _squareNavButton(Icons.chevron_left, () => _shiftWeek(-1)),
              const SizedBox(width: 8),
              _squareNavButton(Icons.chevron_right, () => _shiftWeek(1)),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < 7; i++)
            _weekRow(
              DateTime(weekStart.year, weekStart.month, weekStart.day + i),
              cs,
            ),
        ],
      ),
    );
  }

  Widget _squareNavButton(IconData icon, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Icon(icon, size: 18, color: cs.onSurface),
      ),
    );
  }

  Widget _weekRow(DateTime day, ColorScheme cs) {
    final isToday = _isSameDay(day, DateTime.now());
    final items = _itemsFor(day);
    final total = items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? const Color(0xFF4364F7).withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (total == 0) {
              _openCreateEvent(day);
            } else {
              _showDayDialog(day);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isToday
                            ? const LinearGradient(colors: _brandGradient)
                            : null,
                        color: isToday ? null : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E').format(day).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? AppColors.white.withValues(alpha: 0.85)
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isToday ? AppColors.white : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM d').format(day),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            total == 0
                                ? 'No activities scheduled'
                                : '$total item${total == 1 ? '' : 's'} scheduled',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (total > 0)
                      Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _brandBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$total',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final i in items.take(8))
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: _smallChip(i.title, i.color),
                        ),
                      if (items.length > 8)
                        _smallChip('+${items.length - 8} more', cs.onSurfaceVariant),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Month view
  // ---------------------------------------------------------------------

  Widget _buildMonthView() {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = _getDaysInMonth(first.year, first.month);
    final lead = first.weekday % 7; // Sunday = 0
    final rows = ((lead + daysInMonth) / 7).ceil();
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return _card(
      padding: EdgeInsets.all(kIsDesktop ? 16 : 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: Row(
              children: [
                _squareNavButton(Icons.chevron_left, _previousMonth),
                SizedBox(width: kIsDesktop ? 12 : 8),
                Text(
                  DateFormat('MMMM yyyy').format(first),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: kIsDesktop ? 12 : 8),
                _squareNavButton(Icons.chevron_right, _nextMonth),
                const Spacer(),
                if (kIsDesktop) ...[
                  _todayButton(),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _openDatePicker,
                    icon: const Icon(Iconsax.calendar_1, size: 14),
                    label: Text(DateFormat('MMMM, yyyy').format(first)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(color: cs.outlineVariant),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: Theme.of(context).textTheme.bodySmall,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ] else ...[
                  _circleIconButton(
                    icon: Icons.today_rounded,
                    onPressed: _goToday,
                  ),
                  const SizedBox(width: 6),
                  _circleIconButton(
                    icon: Iconsax.calendar_1,
                    onPressed: _openDatePicker,
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var r = 0; r < rows; r++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(kIsDesktop ? 3 : 2),
                        child: _monthCell(
                          r * 7 + c - lead + 1,
                          daysInMonth,
                          first,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthCell(int dayNum, int daysInMonth, DateTime first) {
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 0);
    }
    final cs = Theme.of(context).colorScheme;
    final date = DateTime(first.year, first.month, dayNum);
    final isToday = _isSameDay(date, DateTime.now());
    final items = _itemsFor(date);
    final hasItems = items.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (hasItems) {
          _showDayDialog(date);
        } else {
          _openCreateEvent(date);
        }
      },
      child: Container(
        constraints: BoxConstraints(minHeight: kIsDesktop ? 68 : 52),
        padding: EdgeInsets.all(kIsDesktop ? 7 : 3),
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFFF8FAFF) : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday
                ? const Color(0xFF2563EB)
                : cs.outlineVariant.withValues(alpha: 0.8),
            width: isToday ? 1.4 : 1,
          ),
        ),
        child: kIsDesktop
            ? _monthCellDesktop(dayNum, isToday, items)
            : _monthCellMobile(dayNum, isToday, items),
      ),
    );
  }

  Widget _dayNumber(int dayNum, bool isToday) {
    final cs = Theme.of(context).colorScheme;
    if (isToday) {
      return Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$dayNum',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return Text(
      '$dayNum',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }

  Widget _monthCellDesktop(int dayNum, bool isToday, List<_CalItem> items) {
    const maxVisible = 3;
    final visible = items.take(maxVisible).toList();
    final more = items.length - visible.length;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _dayNumber(dayNum, isToday),
            if (items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF4364F7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4364F7),
                  ),
                ),
              ),
          ],
        ),
        for (final i in visible)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i.color,
                    shape: i.kind == _CalFilter.events
                        ? BoxShape.rectangle
                        : BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    i.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 2),
            child: Text(
              '+$more more',
              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _monthCellMobile(int dayNum, bool isToday, List<_CalItem> items) {
    const maxDots = 3;
    final visible = items.take(maxDots).toList();
    final remaining = items.length - visible.length;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _dayNumber(dayNum, isToday),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final i in visible)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: i.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+$remaining',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------
  // "Activities on <date>" dialog
  // ---------------------------------------------------------------------

  void _showDayDialog(DateTime day) {
    final items = _itemsFor(day);
    final cs = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        return Dialog(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: size.height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Activities on ${DateFormat('MMM d, yyyy').format(day)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(dialogContext),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have ${items.length} item(s) recorded for this day.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No items found',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: _dialogScrollController,
                            thumbVisibility: true,
                            radius: const Radius.circular(8),
                            child: ListView(
                              controller: _dialogScrollController,
                              shrinkWrap: true,
                              children: [
                                for (final i in items)
                                  _itemCard(
                                    i,
                                    onTap: () {
                                      Navigator.pop(dialogContext);
                                      _onItemTap(i);
                                    },
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                      if (_canCreate) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _openCreateEvent(day);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Event'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}