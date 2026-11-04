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
const Color _dealColor = Color(0xFF8B5CF6);

class CalendarEventScreen extends StatelessWidget {
  final bool showAppbar;
  const CalendarEventScreen({super.key, this.showAppbar = false});

  @override
  Widget build(BuildContext context) {
    // Replace with your actual Bloc construction or injection
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
  Calendar _currentView = Calendar.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  PermissionModel? _permissions;
  PermissionModel? _taskPermissions;
  PermissionModel? _leadPermissions;
  PermissionModel? _dealPermissions;
  PermissionModel? _ticketPermissions;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _vhScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchFocused = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _searchFocusNode.addListener(() {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _vScrollController.dispose();
    _vhScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Calendar');
    _taskPermissions = await PermissionService.getPermissions('Tasks');
    _leadPermissions = await PermissionService.getPermissions('Leads');
    _dealPermissions = await PermissionService.getPermissions('Deals');
    _ticketPermissions = await PermissionService.getPermissions('Tickets');
    if (mounted) setState(() {});
  }

  // --- HELPERS ---

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    final fmt = DateFormat('hh:mm a');
    return "${fmt.format(start)} - ${fmt.format(end)}";
  }

  String _getMonthName(int month) {
    return DateFormat('MMMM').format(DateTime(2024, month));
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // --- VISUAL HELPERS (type -> color / icon) ---

  Color _accentForItem(dynamic item) {
    if (item is EventModel) return const Color(0xFF4364F7);
    if (item is TaskModel) {
      return item.highPriority ? AppColors.danger : AppColors.info;
    }
    if (item is LeadModel) return AppColors.success;
    if (item is DealModel) return _dealColor;
    if (item is CustomerTicketModel) return AppColors.warning;
    return Theme.of(context).colorScheme.primary;
  }

  IconData _iconForItem(dynamic item) {
    if (item is EventModel) return Iconsax.calendar_1;
    if (item is TaskModel) return Iconsax.task_square;
    if (item is LeadModel) return Iconsax.personalcard;
    if (item is DealModel) return Iconsax.dollar_circle;
    if (item is CustomerTicketModel) return Iconsax.ticket;
    return Iconsax.document;
  }

  // --- SEARCH ---

  DateTime _dateOfItem(dynamic item) {
    if (item is EventModel) return item.eventDateTime;
    if (item is TaskModel) return item.deadline ?? item.createdAt;
    if (item is LeadModel) return item.createdAt;
    if (item is DealModel) return item.createdAt;
    if (item is CustomerTicketModel) return item.createdAt;
    return DateTime.now();
  }

  String _titleOfItem(dynamic item) {
    if (item is EventModel) return item.eventName;
    if (item is TaskModel) return '#${item.taskNumber} ${item.taskName}';
    if (item is LeadModel) {
      return item.clientName != null && item.clientName!.isNotEmpty
          ? item.clientName!
          : item.leadName;
    }
    if (item is DealModel) {
      return item.clientName != null && item.clientName!.isNotEmpty
          ? item.clientName!
          : item.dealName;
    }
    if (item is CustomerTicketModel) {
      return '#${item.ticketNumber} ${item.ticketTitle}';
    }
    return '';
  }

  String _createdByNameOfItem(dynamic item) {
    if (item is EventModel) return item.createdBy.name;
    if (item is TaskModel) return item.taskCreatedBy.name;
    if (item is LeadModel) return item.createdBy.name;
    if (item is DealModel) return item.createdBy.name;
    if (item is CustomerTicketModel) return item.ticketCreatedBy.name;
    return '';
  }

  bool _matchesSearch(dynamic item, String query) {
    return _titleOfItem(item).toLowerCase().contains(query) ||
        _createdByNameOfItem(item).toLowerCase().contains(query);
  }

  List<dynamic> _filteredSearchResults(
    List<EventModel> events,
    List<TaskModel> tasks,
    List<LeadModel> leads,
    List<DealModel> deals,
    List<CustomerTicketModel> tickets,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return [];

    final allItems = [
      ...events,
      ...tasks,
      ...leads,
      ...deals,
      ...tickets,
    ].where((item) => _matchesSearch(item, query)).toList();

    allItems.sort((a, b) => _dateOfItem(b).compareTo(_dateOfItem(a)));
    return allItems;
  }

  void _onItemTap(dynamic e) {
    if (e is EventModel) {
      if (kIsDesktop) {
        GeneralDialog.showRTLSheet(context, EventViewPage(event: e));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventViewPage(event: e)),
        );
      }
    } else if (e is TaskModel) {
      if (kIsDesktop) {
        GeneralDialog.showRTLSheet(context, TaskView(uid: e.uid ?? ''));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaskView(uid: e.uid ?? '')),
        );
      }
    } else if (e is LeadModel) {
      if (kIsDesktop) {
        GeneralDialog.showRTLSheet(context, LeadsViewPage(lead: e));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LeadsViewPage(lead: e)),
        );
      }
    } else if (e is DealModel) {
      if (kIsDesktop) {
        GeneralDialog.showRTLSheet(context, DealsViewPage(deal: e));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DealsViewPage(deal: e)),
        );
      }
    } else if (e is CustomerTicketModel) {
      if (kIsDesktop) {
        GeneralDialog.showRTLSheet(context, TicketView(uid: e.uid ?? ''));
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TicketView(uid: e.uid ?? '')),
        );
      }
    }
  }

  String _categoryOfItem(dynamic item) {
    if (item is EventModel) return item.eventDescription;
    if (item is TaskModel) {
      return item.highPriority ? 'High Priority' : 'Low Priority';
    }
    if (item is LeadModel) return item.leadName;
    if (item is DealModel) return item.dealName;
    if (item is CustomerTicketModel) return item.category.label;
    return '';
  }

  bool _completedOfItem(dynamic item) {
    if (item is EventModel) return item.completed;
    if (item is TaskModel) return item.completed;
    if (item is LeadModel) return item.leadsConverted;
    if (item is CustomerTicketModel) return item.status == TicketStatus.closed;
    return false;
  }

  Widget _buildSearchResults(
    List<EventModel> events,
    List<TaskModel> tasks,
    List<LeadModel> leads,
    List<DealModel> deals,
    List<CustomerTicketModel> tickets,
  ) {
    final results = _filteredSearchResults(
      events,
      tasks,
      leads,
      deals,
      tickets,
    );

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

    return Scrollbar(
      controller: _vScrollController,
      thumbVisibility: true,
      interactive: true,
      trackVisibility: true,
      radius: const Radius.circular(8),
      thickness: 8,
      child: ListView.builder(
        controller: _vScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final e = results[index];
          final date = _dateOfItem(e);
          return EventCard(
            title: _titleOfItem(e),
            category: _categoryOfItem(e),
            categoryColor: _accentForItem(e).withValues(alpha: 0.12),
            textColor: _accentForItem(e),
            accentColor: _accentForItem(e),
            leadingIcon: _iconForItem(e),
            time:
                '${DateFormat('MMM d, yyyy').format(date)} • By ${_createdByNameOfItem(e)}',
            completed: _completedOfItem(e),
            onTap: () => _onItemTap(e),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _searchFocused
                ? primary.withValues(alpha: 0.55)
                : Theme.of(context).colorScheme.outlineVariant,
            width: _searchFocused ? 1.4 : 1,
          ),
          boxShadow: _searchFocused
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: Theme.of(context).textTheme.bodySmall,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search by title or created by...',
            hintStyle: Theme.of(context).textTheme.bodySmall,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(11),
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
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(15),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(15),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _previousMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1),
  );
  void _nextMonth() => setState(
    () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1),
  );

  Future<void> _refresh() async {
    context.read<CalendarBloc>().add(StreamCalendar());
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _openDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _focusedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _focusedMonth = DateTime(pickedDate.year, pickedDate.month);
        _selectedDate = pickedDate;
      });
    }
  }

  void _openCreateEvent(DateTime? forDate) {
    if (!(_permissions?.canCreate ?? false)) return;
    if (kIsDesktop) {
      GeneralDialog.showRTLSheet(context, EventCreate(selectedDate: forDate));
    } else {
      Sheet.showSheet(context, widget: EventCreate(selectedDate: forDate));
    }
  }

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
          if (state is CalendarLoading) {
            return const WaitingLoading();
          }

          if (state is CalendarError) {
            return Center(
              child: Text(
                state.message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          if (state is CalendarLoaded) {
            return SafeArea(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height,
                  child: Column(
                    children: [
                      if (kIsDesktop) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _buildHeaderBanner(),
                        ),
                      ],

                      _buildViewSwitcher(),

                      _buildSearchField(),

                      if (_searchQuery.trim().isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_filteredSearchResults(state.events, state.tasks, state.leads, state.deals, state.tickets).length} result(s) found',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ] else if (_currentView != Calendar.month) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedDate),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              _circleIconButton(
                                icon: Iconsax.calendar_1,
                                onPressed: _openDatePicker,
                              ),
                            ],
                          ),
                        ),
                        _buildHorizontalDatePicker(),
                      ],

                      Expanded(
                        child: _searchQuery.trim().isNotEmpty
                            ? _buildSearchResults(
                                state.events,
                                state.tasks,
                                state.leads,
                                state.deals,
                                state.tickets,
                              )
                            : _buildBody(
                                state.events,
                                state.tasks,
                                state.leads,
                                state.deals,
                                state.tickets,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
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
            color: const Color(0xFF0052D4).withValues(alpha: 0.28),
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
          if (_permissions?.canCreate ?? false)
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
                      const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Color(0xFF0052D4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Add Event",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0052D4),
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

  Widget _buildViewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            _buildSwitchTab('Day', Calendar.day),
            _buildSwitchTab('Week', Calendar.week),
            _buildSwitchTab('Month', Calendar.month),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTab(String label, Calendar view) {
    bool isSelected = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentView = view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: _brandGradient)
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDatePicker() {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: 30,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index - 3));
          bool isSelected = _isSameDay(date, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
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
                color: isSelected
                    ? null
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? null
                    : Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
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
                    DateFormat('E').format(date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
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

  Widget _buildBody(
    List<EventModel> events,
    List<TaskModel> tasks,
    List<LeadModel> leads,
    List<DealModel> deals,
    List<CustomerTicketModel> tickets,
  ) {
    switch (_currentView) {
      case Calendar.day:
        return _buildDayView(events, tasks, leads, deals, tickets);
      case Calendar.week:
        return _buildWeekView(events, tasks, leads, deals, tickets);
      case Calendar.month:
        return _buildMonthView(events, tasks, leads, deals, tickets);
    }
  }

  Widget _buildDayView(
    List<EventModel> events,
    List<TaskModel> tasks,
    List<LeadModel> leads,
    List<DealModel> deals,
    List<CustomerTicketModel> tickets,
  ) {
    final dayEvents = events
        .where((e) => _isSameDay(e.eventDateTime, _selectedDate))
        .toList();

    final dayTasks = tasks
        .where((e) => _isSameDay(e.deadline ?? DateTime.now(), _selectedDate))
        .toList();

    final dayLeads = leads
        .where((e) => _isSameDay(e.createdAt, _selectedDate))
        .toList();

    final dayDeals = deals
        .where((e) => _isSameDay(e.createdAt, _selectedDate))
        .toList();

    final dayTickets = tickets
        .where((e) => _isSameDay(e.createdAt, _selectedDate))
        .toList();

    if (dayEvents.isEmpty &&
        dayTasks.isEmpty &&
        dayLeads.isEmpty &&
        dayDeals.isEmpty &&
        dayTickets.isEmpty) {
      return Center(
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
              "No events, tasks, leads, deals, or tickets for today",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    var totalIndexes = [
      ...dayEvents,
      ...dayTasks,
      ...dayLeads,
      ...dayDeals,
      ...dayTickets,
    ];

    return Scrollbar(
      controller: _vScrollController,
      thumbVisibility: true,
      interactive: true,
      trackVisibility: true,
      radius: const Radius.circular(8),
      thickness: 8,
      child: ListView.builder(
        controller: _vScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: totalIndexes.length,
        itemBuilder: (context, index) {
          final e = totalIndexes[index];

          if (e is EventModel) {
            return EventCard(
              title: e.eventName,
              category: e.eventDescription,
              categoryColor: _accentForItem(e).withValues(alpha: 0.12),
              textColor: _accentForItem(e),
              accentColor: _accentForItem(e),
              leadingIcon: _iconForItem(e),
              time: _formatTimeRange(e.eventDateTime, e.eventEndDateTime),
              onTap: () {
                if (kIsDesktop) {
                  GeneralDialog.showRTLSheet(context, EventViewPage(event: e));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventViewPage(event: e),
                    ),
                  );
                }
              },
              completed: e.completed,
            );
          } else if (e is TaskModel) {
            return EventCard(
              title: '#${e.taskNumber} ${e.taskName}',
              category: e.highPriority ? 'High Priority' : 'Low Priority',
              categoryColor: _accentForItem(e).withValues(alpha: 0.12),
              textColor: _accentForItem(e),
              accentColor: _accentForItem(e),
              leadingIcon: _iconForItem(e),
              time: (e.deadline ?? DateTime.now()).formatDateTime,
              onTap: () {
                if (kIsDesktop) {
                  GeneralDialog.showRTLSheet(
                    context,
                    TaskView(uid: e.uid ?? ''),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskView(uid: e.uid ?? ''),
                    ),
                  );
                }
              },
              completed: e.completed,
            );
          } else if (e is LeadModel) {
            return EventCard(
              title: e.clientName != null && e.clientName!.isNotEmpty
                  ? e.clientName!
                  : e.leadName,
              category: e.leadName,
              categoryColor: _accentForItem(e).withValues(alpha: 0.12),
              textColor: _accentForItem(e),
              accentColor: _accentForItem(e),
              leadingIcon: _iconForItem(e),
              time: e.createdAt.formatDateTime,
              onTap: () {
                if (kIsDesktop) {
                  GeneralDialog.showRTLSheet(context, LeadsViewPage(lead: e));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeadsViewPage(lead: e),
                    ),
                  );
                }
              },
              completed: e.leadsConverted,
            );
          } else if (e is DealModel) {
            return EventCard(
              title: e.clientName != null && e.clientName!.isNotEmpty
                  ? e.clientName!
                  : e.dealName,
              category: e.dealName,
              categoryColor: _accentForItem(e).withValues(alpha: 0.12),
              textColor: _accentForItem(e),
              accentColor: _accentForItem(e),
              leadingIcon: _iconForItem(e),
              time: e.createdAt.formatDateTime,
              onTap: () {
                if (kIsDesktop) {
                  GeneralDialog.showRTLSheet(context, DealsViewPage(deal: e));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DealsViewPage(deal: e),
                    ),
                  );
                }
              },
              completed: false,
            );
          } else if (e is CustomerTicketModel) {
            return EventCard(
              title: '#${e.ticketNumber} ${e.ticketTitle}',
              category: e.category.label,
              categoryColor: _accentForItem(e).withValues(alpha: 0.12),
              textColor: _accentForItem(e),
              accentColor: _accentForItem(e),
              leadingIcon: _iconForItem(e),
              time: e.createdAt.formatDateTime,
              onTap: () {
                if (kIsDesktop) {
                  GeneralDialog.showRTLSheet(
                    context,
                    TicketView(uid: e.uid ?? ''),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TicketView(uid: e.uid ?? ''),
                    ),
                  );
                }
              },
              completed: e.status == TicketStatus.closed,
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildWeekView(
    List<EventModel> events,
    List<TaskModel> tasks,
    List<LeadModel> leads,
    List<DealModel> deals,
    List<CustomerTicketModel> tickets,
  ) {
    DateTime firstDayOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Scrollbar(
      controller: _vScrollController,
      thumbVisibility: true,
      interactive: true,
      trackVisibility: true,
      radius: const Radius.circular(8),
      thickness: 8,
      child: ListView.builder(
        controller: _vScrollController,
        padding: const EdgeInsets.all(20),
        itemCount: 7,
        itemBuilder: (context, index) {
          DateTime day = firstDayOfWeek.add(Duration(days: index));
          bool isToday = _isSameDay(day, DateTime.now());
          var count = events
              .where((e) => _isSameDay(e.eventDateTime, day))
              .length;

          var taskCount = tasks
              .where((e) => _isSameDay(e.deadline ?? DateTime.now(), day))
              .length;

          var leadCount = leads
              .where((e) => _isSameDay(e.createdAt, day))
              .length;

          var dealCount = deals
              .where((e) => _isSameDay(e.createdAt, day))
              .length;

          var ticketCount = tickets
              .where((e) => _isSameDay(e.createdAt, day))
              .length;

          var totalCount =
              count + taskCount + leadCount + dealCount + ticketCount;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isToday
                    ? const Color(0xFF4364F7).withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  if (totalCount == 0) {
                    if (!(_permissions?.canCreate ?? false)) return;
                    var popResult = await showCreateDialog();
                    if (popResult == null) return;
                    if (popResult == 1) {
                      _openCreateEvent(day);
                    }
                  } else {
                    showInfoGeneralDialog(
                      context,
                      title: 'Items on ${day.day}/${day.month}/${day.year}',
                      description:
                          'You have $count event(s), $taskCount task(s), $leadCount lead(s), $dealCount deal(s), & $ticketCount ticket(s) scheduled for this day.',
                      items: events
                          .where((e) => _isSameDay(e.eventDateTime, day))
                          .toList(),
                      tasks: tasks
                          .where(
                            (e) =>
                                _isSameDay(e.deadline ?? DateTime.now(), day),
                          )
                          .toList(),
                      leads: leads
                          .where((e) => _isSameDay(e.createdAt, day))
                          .toList(),
                      deals: deals
                          .where((e) => _isSameDay(e.createdAt, day))
                          .toList(),
                      tickets: tickets
                          .where((e) => _isSameDay(e.createdAt, day))
                          .toList(),
                      selectedDate: day,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: isToday
                              ? const LinearGradient(colors: _brandGradient)
                              : null,
                          color: isToday
                              ? null
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(day),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? AppColors.white.withValues(
                                            alpha: 0.85,
                                          )
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              '${day.day}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? AppColors.white
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          totalCount == 0
                              ? "No items"
                              : "$totalCount item${totalCount == 1 ? '' : 's'} scheduled",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: totalCount == 0
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      if (totalCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$totalCount',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthView(
    List<EventModel> events,
    List<TaskModel> tasks,
    List<LeadModel> leads,
    List<DealModel> deals,
    List<CustomerTicketModel> tickets,
  ) {
    int daysInMonth = _getDaysInMonth(_focusedMonth.year, _focusedMonth.month);

    return Scrollbar(
      controller: _vScrollController,
      thumbVisibility: true,
      interactive: true,
      trackVisibility: true,
      radius: const Radius.circular(8),
      thickness: 8,
      child: SingleChildScrollView(
        controller: _vScrollController,
        padding: EdgeInsets.all(kIsDesktop ? 20 : 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _circleIconButton(
                      icon: Icons.chevron_left,
                      onPressed: _previousMonth,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _circleIconButton(
                      icon: Icons.chevron_right,
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
                _circleIconButton(
                  icon: Iconsax.calendar_1,
                  onPressed: _openDatePicker,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: kIsDesktop ? 10 : 6,
                crossAxisSpacing: kIsDesktop ? 10 : 6,
                childAspectRatio: kIsDesktop ? 1 : 0.8,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                int dayNum = index + 1;
                DateTime date = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month,
                  dayNum,
                );
                bool isToday = _isSameDay(date, DateTime.now());
                final dayEvents = events
                    .where((e) => _isSameDay(e.eventDateTime, date))
                    .toList();
                bool hasEvents = dayEvents.isNotEmpty;

                final dayTasks = tasks
                    .where(
                      (e) => _isSameDay((e.deadline ?? DateTime.now()), date),
                    )
                    .toList();
                bool hasTasks = dayTasks.isNotEmpty;

                final dayLeads = leads
                    .where((e) => _isSameDay(e.createdAt, date))
                    .toList();
                bool hasLeads = dayLeads.isNotEmpty;

                final dayDeals = deals
                    .where((e) => _isSameDay(e.createdAt, date))
                    .toList();
                bool hasDeals = dayDeals.isNotEmpty;

                final dayTickets = tickets
                    .where((e) => _isSameDay(e.createdAt, date))
                    .toList();
                bool hasTickets = dayTickets.isNotEmpty;

                bool hasItems =
                    hasEvents || hasTasks || hasLeads || hasDeals || hasTickets;
                var totalItemsCount =
                    dayEvents.length +
                    dayTasks.length +
                    dayLeads.length +
                    dayDeals.length +
                    dayTickets.length;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    if (hasItems) {
                      showInfoGeneralDialog(
                        context,
                        title:
                            'Items on ${date.day}/${date.month}/${date.year}',
                        description:
                            'You have ${dayEvents.length} event(s), ${dayTasks.length} task(s), ${dayLeads.length} lead(s), ${dayDeals.length} deal(s), & ${dayTickets.length} ticket(s) scheduled for this day.',
                        items: dayEvents,
                        tasks: dayTasks,
                        leads: dayLeads,
                        deals: dayDeals,
                        tickets: dayTickets,
                        selectedDate: date,
                      );
                    } else {
                      if (!(_permissions?.canCreate ?? false)) return;
                      var popResult = await showCreateDialog();
                      if (popResult == null) return;
                      if (popResult == 1) {
                        _openCreateEvent(date);
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(kIsDesktop ? 5 : 3),
                    decoration: BoxDecoration(
                      gradient: isToday
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _brandGradient,
                            )
                          : null,
                      color: isToday
                          ? null
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday
                          ? null
                          : Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF4364F7,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: kIsDesktop
                        ? _buildMonthCellDesktop(
                            dayNum: dayNum,
                            isToday: isToday,
                            hasItems: hasItems,
                            totalItemsCount: totalItemsCount,
                            dayEvents: dayEvents,
                            dayTasks: dayTasks,
                            dayLeads: dayLeads,
                            dayDeals: dayDeals,
                            dayTickets: dayTickets,
                          )
                        : _buildMonthCellMobile(
                            dayNum: dayNum,
                            isToday: isToday,
                            hasItems: hasItems,
                            totalItemsCount: totalItemsCount,
                            itemColors: [
                              ...dayEvents.map(_accentForItem),
                              ...dayTasks.map(_accentForItem),
                              ...dayLeads.map(_accentForItem),
                              ...dayDeals.map(_accentForItem),
                              ...dayTickets.map(_accentForItem),
                            ],
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Desktop month cell: day number, count badge, and a scrollable list of
  // item names color-coded by type.
  Widget _buildMonthCellDesktop({
    required int dayNum,
    required bool isToday,
    required bool hasItems,
    required int totalItemsCount,
    required List<EventModel> dayEvents,
    required List<TaskModel> dayTasks,
    required List<LeadModel> dayLeads,
    required List<DealModel> dayDeals,
    required List<CustomerTicketModel> dayTickets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Number and Event Count Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$dayNum',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isToday
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasItems)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.white.withValues(alpha: 0.24)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$totalItemsCount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Names Scroll View
        if (hasItems)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...dayEvents.map(
                    (e) => _monthCellItemRow(
                      e.eventName,
                      _accentForItem(e),
                      isToday,
                    ),
                  ),
                  ...dayTasks.map(
                    (e) => _monthCellItemRow(
                      '#${e.taskNumber} ${e.taskName}',
                      _accentForItem(e),
                      isToday,
                    ),
                  ),
                  ...dayLeads.map(
                    (e) => _monthCellItemRow(
                      e.clientName != null && e.clientName!.isNotEmpty
                          ? e.clientName!
                          : e.leadName,
                      _accentForItem(e),
                      isToday,
                    ),
                  ),
                  ...dayDeals.map(
                    (e) => _monthCellItemRow(
                      e.clientName != null && e.clientName!.isNotEmpty
                          ? e.clientName!
                          : e.dealName,
                      _accentForItem(e),
                      isToday,
                    ),
                  ),
                  ...dayTickets.map(
                    (e) => _monthCellItemRow(
                      '#${e.ticketNumber} ${e.ticketTitle}',
                      _accentForItem(e),
                      isToday,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Mobile month cell: compact layout — centered day number plus up to 3
  // small colored dots (one per item, color-coded by type) and a "+N" for
  // any remaining items. Avoids the badge+number Row overflow that happens
  // on narrow mobile cell widths, and skips unreadable tiny item-name text.
  Widget _buildMonthCellMobile({
    required int dayNum,
    required bool isToday,
    required bool hasItems,
    required int totalItemsCount,
    required List<Color> itemColors,
  }) {
    const int maxDots = 3;
    final visibleColors = itemColors.take(maxDots).toList();
    final remaining = totalItemsCount - visibleColors.length;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$dayNum',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: isToday
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (hasItems) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in visibleColors)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: isToday ? Colors.white : color,
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
                        color: isToday
                            ? Colors.white.withValues(alpha: 0.9)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _monthCellItemRow(String text, Color color, bool isToday) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: isToday ? AppColors.white : color,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                height: 1.1,
                color: isToday
                    ? Colors.white.withValues(alpha: 0.9)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // "Items on <date>" dialog
  // ---------------------------------------------------------------------

  Widget _infoDialogItemTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String trailingLabel,
    required String trailingValue,
    required VoidCallback onTap,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trailingLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      trailingValue,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showInfoGeneralDialog(
    BuildContext context, {
    required String title,
    required String description,
    required List<EventModel> items,
    required List<TaskModel> tasks,
    required List<LeadModel> leads,
    required List<DealModel> deals,
    required List<CustomerTicketModel> tickets,
    DateTime? selectedDate,
  }) {
    final totalItems = [...items, ...tasks, ...leads, ...deals, ...tickets];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: _brandGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Iconsax.calendar_1,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// Description
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Scrollable list
                  Expanded(
                    child: totalItems.isEmpty
                        ? Center(
                            child: Text(
                              "No items found",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        : Scrollbar(
                    controller: _vhScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ListView.builder(
                              controller: _vhScrollController,
                              itemCount: totalItems.length,
                              itemBuilder: (context, index) {
                                var item = totalItems[index];
                                if (item is EventModel) {
                                  return _infoDialogItemTile(
                                    icon: _iconForItem(item),
                                    color: _accentForItem(item),
                                    title: item.eventName,
                                    subtitle: item.eventDescription.isNotEmpty
                                        ? item.eventDescription
                                        : "No description",
                                    trailingLabel: "Time",
                                    trailingValue:
                                        item.eventDateTime.formatTime,
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (kIsDesktop) {
                                        GeneralDialog.showRTLSheet(
                                          context,
                                          EventViewPage(event: item),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EventViewPage(event: item),
                                          ),
                                        );
                                      }
                                    },
                                    onEdit: (_permissions?.canEdit ?? false)
                                        ? () {
                                            Navigator.pop(context);
                                            if (kIsDesktop) {
                                              GeneralDialog.showRTLSheet(
                                                context,
                                                EventEdit(uid: item.uid ?? ''),
                                              );
                                            } else {
                                              Sheet.showSheet(
                                                context,
                                                widget: EventEdit(
                                                  uid: item.uid ?? '',
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                } else if (item is TaskModel) {
                                  return _infoDialogItemTile(
                                    icon: _iconForItem(item),
                                    color: _accentForItem(item),
                                    title:
                                        '#${item.taskNumber} ${item.taskName}',
                                    subtitle: item.description.isNotEmpty
                                        ? item.description
                                        : "No description",
                                    trailingLabel: "Deadline",
                                    trailingValue:
                                        (item.deadline ?? DateTime.now())
                                            .formatTime,
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (kIsDesktop) {
                                        GeneralDialog.showRTLSheet(
                                          context,
                                          TaskView(uid: item.uid ?? ''),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TaskView(uid: item.uid ?? ''),
                                          ),
                                        );
                                      }
                                    },
                                    onEdit: (_taskPermissions?.canEdit ?? false)
                                        ? () {
                                            Navigator.pop(context);
                                            if (kIsDesktop) {
                                              GeneralDialog.showRTLSheet(
                                                context,
                                                TaskEdit(uid: item.uid ?? ''),
                                              );
                                            } else {
                                              Sheet.showSheet(
                                                context,
                                                widget: TaskEdit(
                                                  uid: item.uid ?? '',
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                } else if (item is LeadModel) {
                                  return _infoDialogItemTile(
                                    icon: _iconForItem(item),
                                    color: _accentForItem(item),
                                    title:
                                        item.clientName != null &&
                                            item.clientName!.isNotEmpty
                                        ? item.clientName!
                                        : item.leadName,
                                    subtitle: item.leadName,
                                    trailingLabel: "Created",
                                    trailingValue: item.createdAt.formatTime,
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (kIsDesktop) {
                                        GeneralDialog.showRTLSheet(
                                          context,
                                          LeadsViewPage(lead: item),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                LeadsViewPage(lead: item),
                                          ),
                                        );
                                      }
                                    },
                                    onEdit: (_leadPermissions?.canEdit ?? false)
                                        ? () {
                                            Navigator.pop(context);
                                            if (kIsDesktop) {
                                              GeneralDialog.showRTLSheet(
                                                context,
                                                LeadEdit(uid: item.uid ?? ''),
                                              );
                                            } else {
                                              Sheet.showSheet(
                                                context,
                                                widget: LeadEdit(
                                                  uid: item.uid ?? '',
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                } else if (item is DealModel) {
                                  return _infoDialogItemTile(
                                    icon: _iconForItem(item),
                                    color: _accentForItem(item),
                                    title:
                                        item.clientName != null &&
                                            item.clientName!.isNotEmpty
                                        ? item.clientName!
                                        : item.dealName,
                                    subtitle: item.dealName,
                                    trailingLabel: "Created",
                                    trailingValue: item.createdAt.formatTime,
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (kIsDesktop) {
                                        GeneralDialog.showRTLSheet(
                                          context,
                                          DealsViewPage(deal: item),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DealsViewPage(deal: item),
                                          ),
                                        );
                                      }
                                    },
                                    onEdit: (_dealPermissions?.canEdit ?? false)
                                        ? () {
                                            Navigator.pop(context);
                                            if (kIsDesktop) {
                                              GeneralDialog.showRTLSheet(
                                                context,
                                                DealEdit(uid: item.uid ?? ''),
                                              );
                                            } else {
                                              Sheet.showSheet(
                                                context,
                                                widget: DealEdit(
                                                  uid: item.uid ?? '',
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                } else if (item is CustomerTicketModel) {
                                  return _infoDialogItemTile(
                                    icon: _iconForItem(item),
                                    color: _accentForItem(item),
                                    title:
                                        '#${item.ticketNumber} ${item.ticketTitle}',
                                    subtitle: item.ticketDescription.isNotEmpty
                                        ? item.ticketDescription
                                        : "No description",
                                    trailingLabel: "Created",
                                    trailingValue: item.createdAt.formatTime,
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (kIsDesktop) {
                                        GeneralDialog.showRTLSheet(
                                          context,
                                          TicketView(uid: item.uid ?? ''),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TicketView(uid: item.uid ?? ''),
                                          ),
                                        );
                                      }
                                    },
                                    onEdit:
                                        (_ticketPermissions?.canEdit ?? false)
                                        ? () {
                                            Navigator.pop(context);
                                            if (kIsDesktop) {
                                              GeneralDialog.showRTLSheet(
                                                context,
                                                TicketEdit(uid: item.uid ?? ''),
                                              );
                                            } else {
                                              Sheet.showSheet(
                                                context,
                                                widget: TicketEdit(
                                                  uid: item.uid ?? '',
                                                ),
                                              );
                                            }
                                          }
                                        : null,
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                  ),

                  const SizedBox(height: 12),

                  /// Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (selectedDate != null &&
                          (_permissions?.canCreate ?? false))
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: _brandGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.pop(context);
                                _openCreateEvent(selectedDate);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      size: 18,
                                      color: AppColors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Create Event',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "CLOSE",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },

      /// Animation
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  Future<int?> showCreateDialog() {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _brandGradient),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.calendar_add,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Create Event',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogButton(
                context,
                icon: Iconsax.box_1,
                label: 'Create Event',
                result: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dialogButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int result,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pop(context, result),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String category;
  final Color categoryColor;
  final Color textColor;
  final String time;
  final bool completed;
  final VoidCallback? onTap;
  final Color? accentColor;
  final IconData? leadingIcon;

  const EventCard({
    super.key,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.textColor,
    required this.time,
    required this.completed,
    this.onTap,
    this.accentColor,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor = accentColor ?? textColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: barColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (leadingIcon != null) ...[
                                      Icon(
                                        leadingIcon,
                                        size: 12,
                                        color: textColor,
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      category,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle_outline,
                                size: 22,
                                color: completed
                                    ? AppColors.success
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 15,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  time,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
