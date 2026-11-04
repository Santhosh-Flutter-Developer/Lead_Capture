import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/services/services.dart';
import 'bloc/tasks_bloc.dart';

const String _pageTitle = "Tasks";
const double _wideBreakpoint = 1000;

class TasksListing extends StatelessWidget {
  const TasksListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskBloc()..add(StreamTasks()),
      child: const TaskListView(),
    );
  }
}

class TaskListView extends StatelessWidget {
  const TaskListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaginatedDataController<TaskModel>(
        // Task No ascending by default (column 0).
        initialSortColumnIndex: 0,
        filterLogic: (task, query) {
          final q = query.trim().toLowerCase();
          if (q.isEmpty) return true;
          // Task No: "4", "#4" (also finds 14, 24...)
          final numberQuery = q.startsWith('#') ? q.substring(1).trim() : q;
          final number = task.taskNumber?.toString();
          if (number != null &&
              numberQuery.isNotEmpty &&
              number.contains(numberQuery)) {
            return true;
          }
          return task.taskName.toLowerCase().contains(q) ||
              (task.tags.map((e) => e.toLowerCase()).contains(q));
        },
        // Column indexes follow the DataTable columns:
        // 0 Task No, 1 Name, 2 Project, 3 Project Lead, 4 Active, 5 Deadline.
        sortLogic: (a, b, col, asc) {
          int compare;
          switch (col) {
            case 0: // Task No (tasks without a number go last)
              compare = (a.taskNumber ?? 0x7fffffff).compareTo(
                b.taskNumber ?? 0x7fffffff,
              );
              break;
            case 1: // Name
              compare = a.taskName.toLowerCase().compareTo(
                b.taskName.toLowerCase(),
              );
              break;
            case 5: // Deadline (tasks without a deadline go last)
              compare = (a.deadline ?? DateTime(9999)).compareTo(
                b.deadline ?? DateTime(9999),
              );
              break;
            default:
              compare = 0;
          }
          // Stable, predictable order when the main key is equal.
          if (compare == 0) {
            compare = (a.taskNumber ?? 0x7fffffff).compareTo(
              b.taskNumber ?? 0x7fffffff,
            );
          }
          return asc ? compare : -compare;
        },
        getItemId: (task) => task.uid ?? '',
      ),
      child: const TaskListingView(),
    );
  }
}

class TaskListingView extends StatefulWidget {
  const TaskListingView({super.key});

  @override
  State<TaskListingView> createState() => _TaskListingViewState();
}

class _TaskListingViewState extends State<TaskListingView> {
  final List<TaskModel> _selectedTasks = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  String _selectedView = 'Grid';
  String? _currentUid;
  bool _isAdmin = false;
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

  // ---------------------------------------------------------------------
  // Filters: Status, Assignee, Created By, Deadline range
  // ---------------------------------------------------------------------
  TaskStatus? _fStatus;
  String? _fAssigneeUid;
  String? _fAssigneeName;
  String? _fCreatedByUid;
  String? _fCreatedByName;
  DateTimeRange? _fDeadline;
  String? _fProjectUid;
  String? _fProjectName;
  String? _fLeadUid;
  String? _fLeadName;
  // Bumped by "Clear filters" so the dropdowns rebuild with no selection.
  int _filterEpoch = 0;

  // Option lists are rebuilt only when the task list itself changes, so the
  // dropdowns keep their state across unrelated rebuilds.
  List<TaskModel>? _optionsSource;
  Map<String, String> _assigneeOpts = {}; // display name -> uid
  Map<String, String> _creatorOpts = {}; // display name -> uid
  List<String> _assigneeItems = const [];
  List<String> _creatorItems = const [];
  Map<String, String> _projectOpts = {}; // display name -> uid
  Map<String, String> _leadOpts = {}; // display name -> uid
  List<String> _projectItems = const [];
  List<String> _leadItems = const [];

  // Lookups used by the Project column and the Project / Lead filters.
  Map<String, String> _projectNames = {}; // project uid -> name
  Map<String, String> _legacyLeadNames = {}; // old CRM lead uid -> name
  Map<String, String> _projectLeads = {}; // project uid -> Project Lead uid

  static final Map<String, TaskStatus> _statusOpts = {
    for (final s in TaskStatus.values) s.label: s,
  };
  static final List<String> _statusItems = _statusOpts.keys.toList();

  int get _activeFilterCount =>
      (_fStatus != null ? 1 : 0) +
      (_fAssigneeUid != null ? 1 : 0) +
      (_fCreatedByUid != null ? 1 : 0) +
      (_fProjectUid != null ? 1 : 0) +
      (_fLeadUid != null ? 1 : 0) +
      (_fDeadline != null ? 1 : 0);

  bool get _hasActiveFilters => _activeFilterCount > 0;

  /// Same rule the "Created By" column uses to decide who to show.
  static List<String> _creatorUids(TaskModel t) =>
      t.taskCreatedBy.uid.isNotEmpty ? [t.taskCreatedBy.uid] : t.createdBy;

  bool _matchesFilters(TaskModel t) {
    if (_fStatus != null && t.currentStatus != _fStatus) return false;
    if (_fAssigneeUid != null && !t.assignees.contains(_fAssigneeUid)) {
      return false;
    }
    if (_fCreatedByUid != null && !_creatorUids(t).contains(_fCreatedByUid)) {
      return false;
    }
    if (_fProjectUid != null && t.project != _fProjectUid) return false;
    if (_fLeadUid != null && _taskLeadUid(t) != _fLeadUid) return false;
    final range = _fDeadline;
    if (range != null) {
      final d = t.deadline;
      if (d == null) return false; // no deadline => outside any range
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      // Inclusive of the whole end day.
      final endExclusive = DateTime(
        range.end.year,
        range.end.month,
        range.end.day + 1,
      );
      if (d.isBefore(start) || !d.isBefore(endExclusive)) return false;
    }
    return true;
  }

  /// Builds "display name -> uid" maps for the Assignee / Created By
  /// dropdowns from the tasks currently loaded.
  void _buildUserOptions(List<TaskModel> tasks) {
    if (identical(tasks, _optionsSource)) return;
    _optionsSource = tasks;

    final assignees = <String, String>{}; // uid -> name
    final creators = <String, String>{};
    for (final t in tasks) {
      for (final uid in t.assignees) {
        final name = CacheService.getUserByUid(uid)?.name ?? '';
        if (name.isNotEmpty) assignees[uid] = name;
      }
      for (final uid in _creatorUids(t)) {
        final name = uid == t.taskCreatedBy.uid
            ? t.taskCreatedBy.name
            : (CacheService.getUserByUid(uid)?.name ?? '');
        if (name.isNotEmpty) creators[uid] = name;
      }
    }
    final projects = <String, String>{}; // uid -> name
    final leads = <String, String>{};
    for (final t in tasks) {
      final pid = t.project;
      if (pid != null && pid.isNotEmpty) {
        final name = _projectNames[pid] ?? '';
        if (name.isNotEmpty) projects[pid] = name;
      }
      final lid = _taskLeadUid(t);
      if (lid.isNotEmpty) {
        final name = _leadName(lid);
        if (name.isNotEmpty) leads[lid] = name;
      }
    }
    // Like the Projects page: every Project Lead is selectable.
    for (final lid in _projectLeads.values) {
      if (lid.isEmpty) continue;
      final name = _leadName(lid);
      if (name.isNotEmpty) leads[lid] = name;
    }
    _projectOpts = _nameToUid(projects);
    _leadOpts = _nameToUid(leads);
    _projectItems = _projectOpts.keys.toList();
    _leadItems = _leadOpts.keys.toList();

    _assigneeOpts = _nameToUid(assignees);
    _creatorOpts = _nameToUid(creators);
    _assigneeItems = _assigneeOpts.keys.toList();
    _creatorItems = _creatorOpts.keys.toList();
  }

  /// Lead = Project Lead (an employee/user). Older tasks may still hold a
  /// CRM lead id, so fall back to that name.
  String _leadName(String uid) =>
      CacheService.getUserByUid(uid)?.name ?? _legacyLeadNames[uid] ?? '';

  /// Project Lead of a task = the lead of its project. Falls back to the
  /// lead saved on the task itself (older tasks without a project).
  String _taskLeadUid(TaskModel t) {
    final pid = t.project;
    if (pid != null && pid.isNotEmpty) {
      final owner = _projectLeads[pid] ?? '';
      if (owner.isNotEmpty) return owner;
    }
    return t.lead ?? '';
  }

  String _projectName(String? uid) =>
      uid == null || uid.isEmpty ? '' : (_projectNames[uid] ?? '');

  /// uid->name  ==>  name->uid, sorted A-Z. Two people with the same name get
  /// a "(2)" suffix so picking one can never silently match the other.
  static Map<String, String> _nameToUid(Map<String, String> uidToName) {
    final entries = uidToName.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final out = <String, String>{};
    for (final e in entries) {
      var label = e.value;
      var n = 2;
      while (out.containsKey(label)) {
        label = '${e.value} ($n)';
        n++;
      }
      out[label] = e.key;
    }
    return out;
  }

  /// Re-applies the filters. Selection is cleared because rows that were
  /// ticked may no longer be visible (and must not be bulk-deleted unseen).
  void _applyFilters(PaginatedDataController<TaskModel> c) {
    _selectedTasks.clear();
    c.clearSelection();
    c.setFilter(_hasActiveFilters ? _matchesFilters : null);
  }

  void _clearFilters(PaginatedDataController<TaskModel> c) {
    setState(() {
      _fStatus = null;
      _fAssigneeUid = _fAssigneeName = null;
      _fCreatedByUid = _fCreatedByName = null;
      _fProjectUid = _fProjectName = null;
      _fLeadUid = _fLeadName = null;
      _fDeadline = null;
      _filterEpoch++;
    });
    _applyFilters(c);
  }

  Future<void> _pickDeadlineRange(
    PaginatedDataController<TaskModel> c,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _fDeadline,
      helpText: 'Select deadline range',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() => _fDeadline = picked);
    _applyFilters(c);
  }

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadLookups();
  }

  /// Project names (Project column / filter) and legacy lead names.
  Future<void> _loadLookups() async {
    try {
      final projects = await ProjectService.getAllProjects();
      final leads = await LeadService.getAllLeads();
      if (!mounted) return;
      setState(() {
        _projectNames = {
          for (final p in projects)
            if ((p.uid ?? '').isNotEmpty) p.uid!: p.projectName,
        };
        _projectLeads = {
          for (final p in projects)
            if ((p.uid ?? '').isNotEmpty) p.uid!: p.projectOwner,
        };
        _legacyLeadNames = {
          for (final l in leads)
            if ((l.uid ?? '').isNotEmpty) l.uid!: l.leadName,
        };
        _optionsSource = null; // rebuild filter options with the names
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    _currentUid = await Spdb.getUid();
    _isAdmin = await Spdb.isAdminLoggedIn();
    if (!mounted) return;
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshTasks(BuildContext context) async {
    context.read<TaskBloc>().add(StreamTasks());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<TaskModel>>();
    final controllerWatch = context.watch<PaginatedDataController<TaskModel>>();
    final isWide = _isWide(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text(_pageTitle),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: BlocListener<TaskBloc, TaskState>(
        listenWhen: (previous, current) => current is TaskLoaded,
        listener: (context, state) {
          if (state is TaskLoaded) {
            controllerRead.setData(state.tasks);
          }
        },
        child: BlocBuilder<TaskBloc, TaskState>(
          builder: (context, state) {
            if (state is TaskLoading) return const WaitingLoading();

            if (state is TaskLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshTasks(context),
                child: Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: ListView(
                      controller: _vScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                      children: [
                        if (isWide) ...[
                          _buildHeaderBanner(context, state.tasks.length),
                          const SizedBox(height: 20),
                        ],
                        _buildToolbar(context, controllerRead),
                        const SizedBox(height: 14),
                        _buildFilterBar(context, controllerRead, state.tasks),
                        const SizedBox(height: 18),
                        if (controllerWatch.paginatedItems.isEmpty)
                          const NoData(text: "No matching records found")
                        else if (_selectedView == 'Calendar') ...[
                          TaskCalendarListing(
                            tasks: controllerWatch.filteredItems,
                          ),
                        ] else ...[
                          _buildMainBody(
                            context,
                            controllerWatch,
                            controllerRead,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is TaskError) {
              return Center(
                child: SelectableText(
                  state.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header banner (desktop only)
  // ---------------------------------------------------------------------
  Widget _buildHeaderBanner(BuildContext context, int totalTasks) {
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
              Iconsax.task_square,
              color: AppColors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tasks",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Plan, assign and track work across your team",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '$totalTasks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalTasks == 1 ? "Task" : "Tasks",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Toolbar: search + add + delete + view toggle + refresh
  // ---------------------------------------------------------------------
  Widget _buildToolbar(
    BuildContext context,
    PaginatedDataController<TaskModel> controllerRead,
  ) {
    final isWide = _isWide(context);

    final buttons = <Widget>[
      if (permissions?.canCreate ?? false) _gradientButton(
              context: context,
              icon: Icons.add_rounded,
              label: "Add $_pageTitle",
              colors: _brandGradient,
              onPressed: () {
                if (kIsMobile || !isWide) {
                  Sheet.showSheet(context, widget: const TaskCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const TaskCreate());
                }
              },
            ),
      if (_selectedTasks.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedTasks.length})",
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkDelete,
        ),
      _buildViewToggle(context),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                SizedBox(width: 260, child: _searchBox(controllerRead)),
                const Spacer(),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchBox(controllerRead),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------
  // Filter bar: Status / Assignee / Created By / Deadline range
  // ---------------------------------------------------------------------
  Widget _buildFilterBar(
    BuildContext context,
    PaginatedDataController<TaskModel> controllerRead,
    List<TaskModel> allTasks,
  ) {
    _buildUserOptions(allTasks);
    final scheme = Theme.of(context).colorScheme;

    final fields = <Widget>[
      FormDropdownSearch(
        key: ValueKey('f_status_$_filterEpoch'),
        label: 'Status',
        initialItem: _fStatus?.label,
        items: _statusItems,
        onChanged: (v) {
          setState(() => _fStatus = v == null ? null : _statusOpts[v as String]);
          _applyFilters(controllerRead);
        },
      ),
      FormDropdownSearch(
        key: ValueKey('f_assignee_${_filterEpoch}_${_assigneeOpts.length}'),
        label: 'Assignee',
        initialItem: _fAssigneeName,
        items: _assigneeItems,
        onChanged: (v) {
          setState(() {
            _fAssigneeName = v as String?;
            _fAssigneeUid = v == null ? null : _assigneeOpts[v];
          });
          _applyFilters(controllerRead);
        },
      ),
      FormDropdownSearch(
        key: ValueKey('f_creator_${_filterEpoch}_${_creatorOpts.length}'),
        label: 'Created By',
        initialItem: _fCreatedByName,
        items: _creatorItems,
        onChanged: (v) {
          setState(() {
            _fCreatedByName = v as String?;
            _fCreatedByUid = v == null ? null : _creatorOpts[v];
          });
          _applyFilters(controllerRead);
        },
      ),
      FormDropdownSearch(
        key: ValueKey('f_project_${_filterEpoch}_${_projectOpts.length}'),
        label: 'Project',
        initialItem: _fProjectName,
        items: _projectItems,
        onChanged: (v) {
          setState(() {
            _fProjectName = v as String?;
            _fProjectUid = v == null ? null : _projectOpts[v];
          });
          _applyFilters(controllerRead);
        },
      ),
      FormDropdownSearch(
        key: ValueKey('f_lead_${_filterEpoch}_${_leadOpts.length}'),
        label: 'Project Lead',
        initialItem: _fLeadName,
        items: _leadItems,
        onChanged: (v) {
          setState(() {
            _fLeadName = v as String?;
            _fLeadUid = v == null ? null : _leadOpts[v];
          });
          _applyFilters(controllerRead);
        },
      ),
      _DeadlineRangeField(
        range: _fDeadline,
        onTap: () => _pickDeadlineRange(controllerRead),
        onClear: () {
          setState(() => _fDeadline = null);
          _applyFilters(controllerRead);
        },
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
          const gap = 12.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Iconsax.filter, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _hasActiveFilters
                        ? 'Filters ($_activeFilterCount applied)'
                        : 'Filters',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _hasActiveFilters
                        ? () => _clearFilters(controllerRead)
                        : null,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: const Text('Clear filters'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: gap,
                runSpacing: 12,
                children: [for (final f in fields) SizedBox(width: w, child: f)],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!kIsMobile)
            _iconCircleButton(
              context,
              icon: Iconsax.refresh,
              tooltip: "Refresh",
              background: Colors.transparent,
              iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: () => _refreshTasks(context),
            ),
          _viewToggleButton(
            context,
            icon: Icons.list_rounded,
            selected: _selectedView == 'List',
            onTap: () => setState(() => _selectedView = 'List'),
          ),
          _viewToggleButton(
            context,
            icon: Iconsax.calendar_1,
            selected: _selectedView == 'Calendar',
            onTap: () => setState(() => _selectedView = 'Calendar'),
          ),
        ],
      ),
    );
  }

  Widget _viewToggleButton(
    BuildContext context, {
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: selected
                ? AppColors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _searchBox(PaginatedDataController<TaskModel> controllerRead) {
    return _TaskSearchField(onChanged: controllerRead.setSearch);
  }

  Widget _gradientButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _iconCircleButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color background,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Table card
  // ---------------------------------------------------------------------
  Widget _buildMainBody(
    BuildContext context,
    PaginatedDataController<TaskModel> controllerWatch,
    PaginatedDataController<TaskModel> controllerRead,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar(
                  controller: _hScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(6),
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _hScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        showCheckboxColumn: true,
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        sortColumnIndex: controllerWatch.sortColumnIndex,
                        sortAscending: controllerWatch.sortAscending,
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.06),
                        ),
                        headingTextStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        columns: [
                          DataColumn(
                            label: const Text("Task No"),
                            onSort: controllerRead.setSort,
                          ),
                          DataColumn(
                            label: const Text("Name"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Project")),
                          const DataColumn(label: Text("Project Lead")),
                          const DataColumn(label: Text("Active")),
                          DataColumn(
                            label: const Text("Deadline"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Assignee")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(
                          controllerWatch.paginatedItems.length,
                          (index) => _buildDataRow(
                            context,
                            controllerWatch.paginatedItems[index],
                            controllerWatch,
                            controllerRead,
                            index,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<TaskModel>(),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, TaskModel task) {
    final status = task.currentStatus;
    final color = switch (status) {
      TaskStatus.completed => AppColors.success,
      TaskStatus.onHold => AppColors.blueGrey,
      TaskStatus.inProgress => AppColors.primary,
      TaskStatus.started => AppColors.info,
      TaskStatus.pending => AppColors.warning,
    };
    final label = status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    TaskModel task,
    PaginatedDataController<TaskModel> controllerWatch,
    PaginatedDataController<TaskModel> controllerRead,
    int index,
  ) {
    final width = MediaQuery.of(context).size.width;
    final isSelected = controllerWatch.selectedIds.contains(task.uid);

    void openTask(BuildContext context, String uid) {
      if (kIsMobile || width < _wideBreakpoint) {
        Sheet.showSheet(context, widget: TaskView(uid: uid));
      } else {
        GeneralDialog.showRTLSheet(context, TaskView(uid: uid));
      }
    }

    DataCell dataCell(Widget child, String uid) {
      return DataCell(
        InkWell(
          onTap: () => openTask(context, uid),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: child,
          ),
        ),
      );
    }

    return DataRow(
      selected: isSelected,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
        }
        return index.isEven
            ? Colors.transparent
            : Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
      }),
      onSelectChanged: (selected) {
        controllerRead.onSelected(task.uid ?? '', selected);
        if (selected ?? false) {
          _selectedTasks.add(task);
        } else {
          _selectedTasks.remove(task);
        }
        setState(() {});
      },
      cells: [
        dataCell(
          Text(
            task.taskNumber?.toString() ?? '-',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          task.uid ?? '',
        ),
        dataCell(
          Text(
            task.taskName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          task.uid ?? '',
        ),
        dataCell(
          SizedBox(
            width: 140,
            child: Text(
              _projectName(task.project).isEmpty
                  ? '-'
                  : _projectName(task.project),
              softWrap: true,
              maxLines: null,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          task.uid ?? '',
        ),
        dataCell(
          SizedBox(
            width: 140,
            child: Text(
              _leadName(_taskLeadUid(task)).isEmpty
                  ? '-'
                  : _leadName(_taskLeadUid(task)),
              softWrap: true,
              maxLines: null,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          task.uid ?? '',
        ),
        dataCell(_statusPill(context, task), task.uid ?? ''),
        dataCell(
          Text(
            task.deadline?.listingDateTime ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          task.uid ?? '',
        ),
        dataCell(
          task.taskCreatedBy.uid.isNotEmpty
              ? CreatedByWidget(userData: task.taskCreatedBy)
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: task.createdBy
                      .map((uid) => CacheService.getUserByUid(uid))
                      .where((user) => user != null)
                      .map((user) => CreatedByWidget(userData: user!))
                      .toList(),
                ),
          task.uid ?? '',
        ),
        dataCell(
          SizedBox(
            width: 120,
            child: Text(
              task.assignees
                  .map((e) => CacheService.getUserByUid(e)?.name ?? '')
                  .where((name) => name.isNotEmpty)
                  .join(',\n'),
              softWrap: true,
              maxLines: null,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          task.uid ?? '',
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (permissions?.canEdit ?? false)
                _iconCircleButton(
                  context,
                  icon: Iconsax.edit,
                  tooltip: "Edit",
                  background: AppColors.info.withValues(alpha: 0.12),
                  iconColor: AppColors.info,
                  onPressed: () {
                    final form = TaskEdit(uid: task.uid ?? '');
                    if (kIsMobile || width < _wideBreakpoint) {
                      Sheet.showSheet(context, widget: form);
                    } else {
                      GeneralDialog.showRTLSheet(context, form);
                    }
                  },
                ),
              if (permissions?.canDelete ?? false) ...[
                const SizedBox(width: 8),
                _iconCircleButton(
                  context,
                  icon: Iconsax.trash,
                  tooltip: "Delete $_pageTitle",
                  background: AppColors.danger.withValues(alpha: 0.12),
                  iconColor: AppColors.danger,
                  onPressed: () => _onDeleteTap(task),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onDeleteTap(TaskModel task) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete $_pageTitle',
        content: 'Are you sure you want to delete this task?',
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedTask = task;

      await TaskService.deleteTask(uid: task.uid ?? '');

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await TaskService.restoreTask(deletedTask);
          context.read<TaskBloc>().add(StreamTasks());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedTasks.isEmpty) return;

    final result = await showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete',
        content: 'Are you sure want to delete this $_pageTitle?',
      ),
      barrierDismissible: false,
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedTasks = List<TaskModel>.from(_selectedTasks);

      futureLoading(context);

      for (var task in deletedTasks) {
        await TaskService.deleteTask(uid: task.uid ?? '');
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _selectedTasks.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var task in deletedTasks) {
            await TaskService.restoreTask(task);
          }
          context.read<TaskBloc>().add(StreamTasks());
        },
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}

// ---------------------------------------------------------------------
// Deadline range field. Looks like the other filter dropdowns (label on top,
// 33px outlined box) but opens a date-range picker.
// ---------------------------------------------------------------------
class _DeadlineRangeField extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DeadlineRangeField({
    required this.range,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = range;
    final hasValue = r != null;
    final String text;
    if (r == null) {
      text = 'Select range';
    } else if (r.start == r.end) {
      text = r.start.formatDateMonth;
    } else {
      text = '${r.start.formatDateMonth} - ${r.end.formatDateMonth}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deadline Range',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 33,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: hasValue
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (hasValue)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.clear, size: 16, color: Colors.grey),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  Iconsax.calendar_1,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// A more polished, colorful search field for the Tasks toolbar.
// ---------------------------------------------------------------------
class _TaskSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _TaskSearchField({required this.onChanged});

  @override
  State<_TaskSearchField> createState() => _TaskSearchFieldState();
}

class _TaskSearchFieldState extends State<_TaskSearchField> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 46,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _focused
              ? primary.withValues(alpha: 0.55)
              : Theme.of(context).colorScheme.outlineVariant,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: _focused
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
        controller: _controller,
        focusNode: _focusNode,
        style: Theme.of(context).textTheme.bodySmall,
        onChanged: (val) {
          setState(() => _hasText = val.isNotEmpty);
          widget.onChanged(val);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search tasks',
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                ),
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
          suffixIcon: _hasText
              ? IconButton(
                  splashRadius: 16,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _hasText = false);
                    widget.onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 4,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}