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
  static const double _stripItemExtent = 68; // 60 width + 2*4 padding
  static const int _stripDays = 30;

  /// True when the available width is large enough for the desktop-style
  /// layout (native desktop, web and tablet browsers). Set in build().
  bool _wide = false;
  double get _hp => _wide ? 20 : 14;
  _Pal get _p => _Pal(Theme.of(context).colorScheme);

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
    final p = _p;
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
      backgroundColor: p.pageBg,
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Wide layout = desktop app AND web / tablet browsers.
                  _wide = constraints.maxWidth >= 640;
                  return _pageScroll([
                    if (_wide) ...[
                      _buildHeaderBanner(),
                      const SizedBox(height: 14),
                    ],
                    _buildViewSwitcher(),
                    const SizedBox(height: 14),
                    _buildSearchAndFilters(),
                    if (!searching && _currentView != Calendar.month) ...[
                      const SizedBox(height: 14),
                      _buildDateStripHeader(),
                      const SizedBox(height: 8),
                      _buildHorizontalDatePicker(),
                    ],
                    const SizedBox(height: 14),
                    if (searching) _buildSearchResults() else _buildBody(),
                  ]);
                },
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
        return _buildDayView();
      case Calendar.week:
        return _buildWeekView();
      case Calendar.month:
        return _buildMonthView();
    }
  }

  /// Whole page (banner, switcher, search, strip, content) scrolls together,
  /// exactly like the reference design.
  Widget _pageScroll(List<Widget> children) {
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
          padding: EdgeInsets.fromLTRB(_hp, _wide ? 16 : 8, _hp, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header banner (wide layouts)
  // ---------------------------------------------------------------------

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Iconsax.calendar_1,
              color: AppColors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Calendar",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Stay on top of events, tasks, leads, deals & tickets",
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.88),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: _brandBlue),
                      SizedBox(width: 6),
                      Text(
                        "Add Event",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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
      color: AppColors.white.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
      color: _brandBlue.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: _brandBlue),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // View switcher + search + filter chips
  // ---------------------------------------------------------------------

  Widget _buildViewSwitcher() {
    final p = _p;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.box,
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
    );
  }

  Widget _buildSwitchTab(String label, Calendar view, IconData icon) {
    final p = _p;
    final isSelected = _currentView == view;
    final fg = isSelected ? AppColors.white : p.muted;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _currentView = view);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollStripToSelected(),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: _brandGradient)
                  : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4364F7).withValues(alpha: 0.30),
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
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final p = _p;
    final search = _buildSearchField();
    final chips = _CalFilter.values.map(_buildFilterChip).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: p.cardDecoration(radius: 16),
      child: _wide
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 590),
                      child: search,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                for (var i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i != chips.length - 1) const SizedBox(width: 8),
                ],
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
    );
  }

  Widget _buildFilterChip(_CalFilter f) {
    final p = _p;
    final selected = _filter == f;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? f.color : p.chip,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? f.color : p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (f != _CalFilter.all) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.white : f.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                f.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.white : p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final p = _p;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 44,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _searchFocused ? _blue.withValues(alpha: 0.6) : p.border,
          width: _searchFocused ? 1.4 : 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(fontSize: 14, color: p.text),
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search by title, created by, or category...',
          hintStyle: TextStyle(fontSize: 14, color: p.muted),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(5),
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF2455DB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.search_normal_1,
                size: 15,
                color: AppColors.white,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
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
            horizontal: 6,
            vertical: 13,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Search results
  // ---------------------------------------------------------------------

  Widget _buildSearchResults() {
    final p = _p;
    final results = _searchResults();

    if (results.isEmpty) {
      return _card(
        child: _emptyState(
          title: 'No records found',
          subtitle: 'Nothing matches "${_searchQuery.trim()}".',
          showAdd: false,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            '${results.length} result(s) found',
            style: TextStyle(fontSize: 13, color: p.muted),
          ),
        ),
        for (final r in results)
          _itemCard(r, showDate: true, onTap: () => _onItemTap(r)),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Date strip (Day / Week views)
  // ---------------------------------------------------------------------

  Widget _buildDateStripHeader() {
    final p = _p;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: p.text,
            ),
          ),
          _todayButton(),
        ],
      ),
    );
  }

  /// [dot] = month-header variant (grey fill + small blue dot) as in the
  /// reference; the default variant is white with a calendar-check icon.
  Widget _todayButton({bool dot = false}) {
    final p = _p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _goToday,
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: dot ? 22 : 12),
          decoration: BoxDecoration(
            color: dot ? p.chip : p.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot)
                const Icon(Icons.circle, size: 5, color: _blue)
              else
                const Icon(Iconsax.calendar_tick, size: 15, color: _blue),
              const SizedBox(width: 8),
              Text(
                'Today',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: p.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDatePicker() {
    final p = _p;
    final today = DateTime.now();
    return SizedBox(
      height: 96,
      child: Scrollbar(
        controller: _stripController,
        thumbVisibility: true,
        interactive: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: ListView.builder(
          controller: _stripController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(0, 2, 0, 22),
          itemCount: _stripDays,
          itemBuilder: (context, index) {
            final date = DateTime(
              _stripStart.year,
              _stripStart.month,
              _stripStart.day + index,
            );
            final isSelected = _isSameDay(date, _selectedDate);
            final isToday = _isSameDay(date, today);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedDate = date;
                    _focusedMonth = DateTime(date.year, date.month);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _brandGradient,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isToday && !p.dark
                                ? const Color(0xFFEFF3FF)
                                : p.card),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isToday
                                  ? const Color(0xFF4181EF)
                                  : p.border.withValues(alpha: 0.7),
                            ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: const Color(
                              0xFF4364F7,
                            ).withValues(alpha: 0.32),
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
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF5B6577),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : p.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------

  Widget _pill(String label, Color color, {IconData? icon, bool solid = false}) {
    final fg = solid ? AppColors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    final p = _p;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(_wide ? 24 : 14),
      decoration: p.cardDecoration(radius: 20, shadow: true),
      child: child,
    );
  }

  /// List card used by the day view, search results and the dialog.
  Widget _itemCard(
    _CalItem item, {
    required VoidCallback onTap,
    bool showDate = false,
    double gap = 12,
  }) {
    final p = _p;
    final muted = TextStyle(fontSize: 13.5, color: p.muted);

    return _Hover(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: gap),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? 0.10 : 0.03),
              blurRadius: hovered ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            hoverColor: Colors.transparent,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _wide ? 20 : 14,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, size: 22, color: item.color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _pill(item.badge, item.color),
                            // Reference shows only the main badge for events.
                            if (item.subBadge != null &&
                                item.subBadge != item.badge &&
                                item.kind != _CalFilter.events)
                              _pill(item.subBadge!, p.muted),
                            if (item.completed)
                              _pill(
                                item.completedLabel,
                                _completedGreen,
                                icon: Icons.check_circle_outline,
                                solid: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(
                            style: muted,
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Iconsax.clock,
                                  size: 13,
                                  color: p.muted,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${showDate ? '${DateFormat('MMM d, yyyy').format(item.date)}, ' : ''}${item.timeLabel} • ',
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Iconsax.user,
                                  size: 13,
                                  color: p.muted,
                                ),
                              ),
                              TextSpan(text: ' By ${item.createdBy}'),
                              if (item.description.trim().isNotEmpty)
                                TextSpan(text: ' • ${item.description.trim()}'),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: p.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required String title,
    required String subtitle,
    bool showAdd = true,
  }) {
    final p = _p;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.calendar_remove, size: 56, color: p.faint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
            if (showAdd && _canCreate) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => _openCreateEvent(_selectedDate),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Event'),
                style: TextButton.styleFrom(
                  foregroundColor: p.text,
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Day view
  // ---------------------------------------------------------------------

  Widget _buildDayView() {
    final p = _p;
    final items = _itemsFor(_selectedDate);
    final count = items.length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count item${count == 1 ? '' : 's'} scheduled',
                      style: TextStyle(fontSize: 13.5, color: p.muted),
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
                    foregroundColor: p.text,
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 18),
          if (items.isEmpty)
            _emptyState(
              title: _filter == _CalFilter.all
                  ? 'No items for this day'
                  : 'No ${_filter.label.toLowerCase()} for this day',
              subtitle: _filter == _CalFilter.all
                  ? 'No events, tasks, or CRM activities recorded for this date.'
                  : 'Nothing recorded under this filter for this date.',
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
    final p = _p;
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
              _squareNavButton(Icons.chevron_left, () => _shiftWeek(-1)),
              const SizedBox(width: 8),
              _squareNavButton(Icons.chevron_right, () => _shiftWeek(1)),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 7; i++)
            _weekRow(
              DateTime(weekStart.year, weekStart.month, weekStart.day + i),
            ),
        ],
      ),
    );
  }

  Widget _squareNavButton(IconData icon, VoidCallback onTap) {
    final p = _p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: p.chip,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 18, color: p.text),
        ),
      ),
    );
  }

  Widget _weekRow(DateTime day) {
    final p = _p;
    final isToday = _isSameDay(day, DateTime.now());
    final items = _itemsFor(day);
    final total = items.length;

    return _Hover(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hovered
                ? const Color(0xFF4F8EF0)
                : (isToday
                      ? const Color(0xFF4364F7).withValues(alpha: 0.45)
                      : p.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: hovered ? 0.08 : 0.02),
              blurRadius: hovered ? 12 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            hoverColor: Colors.transparent,
            onTap: () {
              if (total == 0) {
                _openCreateEvent(day);
              } else {
                _showDayDialog(day);
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _wide ? 18 : 12,
                vertical: 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _brandGradient,
                                )
                              : null,
                          color: isToday ? null : p.box,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(day).toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? AppColors.white.withValues(alpha: 0.9)
                                    : p.text,
                              ),
                            ),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: isToday ? AppColors.white : p.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM d').format(day),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              total == 0
                                  ? 'No activities scheduled'
                                  : '$total item${total == 1 ? '' : 's'} scheduled',
                              style: TextStyle(fontSize: 13.5, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      if (total > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565E8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$total',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      Icon(Icons.chevron_right, color: p.muted),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: p.border),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final i in items.take(8))
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: _smallChip(i.title, i.color),
                          ),
                        if (items.length > 8)
                          _smallChip('+${items.length - 8} more', p.muted),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Month view
  // ---------------------------------------------------------------------

  Widget _buildMonthView() {
    final p = _p;
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = _getDaysInMonth(first.year, first.month);
    final lead = first.weekday % 7; // Sunday = 0
    final rows = ((lead + daysInMonth) / 7).ceil();
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final gap = _wide ? 5.0 : 2.0;

    return _card(
      padding: EdgeInsets.all(_wide ? 20 : 8),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              _wide ? 6 : 4,
              4,
              _wide ? 6 : 4,
              _wide ? 18 : 14,
            ),
            child: Row(
              children: [
                _squareNavButton(Icons.chevron_left, _previousMonth),
                SizedBox(width: _wide ? 16 : 8),
                Text(
                  DateFormat('MMMM yyyy').format(first),
                  style: TextStyle(
                    fontSize: _wide ? 19 : 16,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                SizedBox(width: _wide ? 16 : 8),
                _squareNavButton(Icons.chevron_right, _nextMonth),
                const Spacer(),
                if (_wide) ...[
                  _todayButton(dot: true),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _openDatePicker,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MMMM, yyyy').format(first),
                              style: TextStyle(fontSize: 14, color: p.text),
                            ),
                            const SizedBox(width: 10),
                            Icon(Iconsax.calendar_1, size: 14, color: p.text),
                          ],
                        ),
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
                    padding: EdgeInsets.only(bottom: _wide ? 12 : 8),
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _wide ? 12 : 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: const Color(0xFF5F6B7E),
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
                        padding: EdgeInsets.all(gap),
                        child: _monthCell(
                          DateTime(
                            first.year,
                            first.month,
                            r * 7 + c - lead + 1,
                          ),
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

  Widget _monthCell(DateTime date, DateTime first) {
    final p = _p;
    final inMonth = date.month == first.month && date.year == first.year;

    if (!inMonth) {
      // Leading / trailing days of the neighbouring months (faded, inert).
      return Container(
        constraints: BoxConstraints(minHeight: _wide ? 110 : 52),
        padding: EdgeInsets.all(_wide ? 10 : 3),
        decoration: BoxDecoration(
          color: p.dark ? p.chip.withValues(alpha: 0.4) : const Color(0xFFF7F8FB),
          borderRadius: BorderRadius.circular(_wide ? 14 : 10),
          border: Border.all(color: p.border.withValues(alpha: 0.5)),
        ),
        child: Align(
          alignment: _wide ? Alignment.topLeft : Alignment.center,
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: _wide ? 15 : 11.5,
              fontWeight: FontWeight.w700,
              color: p.faint,
            ),
          ),
        ),
      );
    }

    final isToday = _isSameDay(date, DateTime.now());
    final items = _itemsFor(date);
    final hasItems = items.isNotEmpty;

    return _Hover(
      builder: (hovered) => GestureDetector(
        onTap: () {
          if (hasItems) {
            _showDayDialog(date);
          } else {
            _openCreateEvent(date);
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: BoxConstraints(minHeight: _wide ? 110 : 52),
            padding: EdgeInsets.all(_wide ? 10 : 3),
            decoration: BoxDecoration(
              color: isToday
                  ? (p.dark ? p.chip : const Color(0xFFF7F8FB))
                  : p.card,
              borderRadius: BorderRadius.circular(_wide ? 14 : 10),
              border: Border.all(
                color: isToday
                    ? const Color(0xFF4F5FDB)
                    : (hovered && _wide
                          ? const Color(0xFF4F8EF0)
                          : p.border),
                width: isToday ? 1.4 : 1,
              ),
            ),
            child: _wide
                ? _monthCellWide(date.day, isToday, items)
                : _monthCellMobile(date.day, isToday, items),
          ),
        ),
      ),
    );
  }

  Widget _dayNumber(int dayNum, bool isToday) {
    final p = _p;
    if (isToday) {
      final size = _wide ? 24.0 : 20.0;
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$dayNum',
          style: TextStyle(
            fontSize: _wide ? 12.5 : 10.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }
    return Text(
      '$dayNum',
      style: TextStyle(
        fontSize: _wide ? 15 : 11.5,
        height: _wide ? 1.3 : null,
        fontWeight: FontWeight.w800,
        color: p.text,
      ),
    );
  }

  Widget _monthCellWide(int dayNum, bool isToday, List<_CalItem> items) {
    final p = _p;
    const maxVisible = 3;
    final visible = items.take(maxVisible).toList();
    final more = items.length - visible.length;

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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EBF9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B5BDB),
                  ),
                ),
              ),
          ],
        ),
        for (final i in visible)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: p.dark ? p.box : const Color(0xFFF2F3F8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: i.color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    i.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              '+$more more',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: p.muted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _monthCellMobile(int dayNum, bool isToday, List<_CalItem> items) {
    final p = _p;
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
                        color: p.muted,
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
    final p = _p;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        return Dialog(
          backgroundColor: p.card,
          surfaceTintColor: p.card,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: size.height * 0.85,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activities on ${DateFormat('MMM d, yyyy').format(day)}',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'You have ${items.length} item(s) recorded for this day.',
                              style: TextStyle(fontSize: 13.5, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(dialogContext),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 24, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No items found',
                                style: TextStyle(fontSize: 13.5, color: p.muted),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 2,
                              ),
                              children: [
                                for (final i in items)
                                  _itemCard(
                                    i,
                                    gap: 20,
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: p.chip,
                            foregroundColor: p.text,
                            side: BorderSide(color: p.border),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                        if (_canCreate) ...[
                          const SizedBox(width: 10),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _openCreateEvent(day);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Event'),
                            style: TextButton.styleFrom(
                              foregroundColor: p.text,
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

// -------------------------------------------------------------------------
// Palette + helpers (exact colours sampled from the reference design)
// -------------------------------------------------------------------------

const Color _blue = Color(0xFF2563EB);
const Color _completedGreen = Color(0xFF229457);

class _Pal {
  final ColorScheme cs;
  final bool dark;
  _Pal(this.cs) : dark = cs.brightness == Brightness.dark;

  Color get pageBg => dark ? cs.surface : const Color(0xFFF1F4FB);
  Color get card => dark ? cs.surfaceContainer : Colors.white;
  Color get border => dark ? cs.outlineVariant : const Color(0xFFE6E7EE);
  Color get box => dark ? cs.surfaceContainerHighest : const Color(0xFFF0F4F8);
  Color get chip => dark ? cs.surfaceContainerHigh : const Color(0xFFF6F7FB);
  Color get text => dark ? cs.onSurface : const Color(0xFF1E2233);
  Color get muted => dark ? cs.onSurfaceVariant : const Color(0xFF6B7280);
  Color get faint => dark ? cs.outline : const Color(0xFF9CA3AF);

  BoxDecoration cardDecoration({required double radius, bool shadow = false}) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border.withValues(alpha: dark ? 0.6 : 0.7)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1B2559).withValues(alpha: shadow ? 0.06 : 0.03),
          blurRadius: shadow ? 18 : 8,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

/// Tiny hover helper (desktop / web). Rebuilds only the child.
class _Hover extends StatefulWidget {
  final Widget Function(bool hovered) builder;
  const _Hover({required this.builder});

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}