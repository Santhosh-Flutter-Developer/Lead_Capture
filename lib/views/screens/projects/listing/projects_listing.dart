import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/projects_bloc.dart';

const String _pageTitle = "Projects";
const double _wideBreakpoint = 900;

class ProjectsListing extends StatelessWidget {
  const ProjectsListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProjectsBloc()..add(StreamProjects()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<ProjectModel>(
          initialSortColumnIndex: 0,
          filterLogic: (project, query) {
            final q = query.toLowerCase();
            return project.projectName.toLowerCase().contains(q) ||
                (project.projectCode ?? '').toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 0:
                compare = a.projectName.toLowerCase().compareTo(
                  b.projectName.toLowerCase(),
                );
                break;
              case 1:
                compare = (a.projectCode ?? '').toLowerCase().compareTo(
                  (b.projectCode ?? '').toLowerCase(),
                );
                break;
              default:
                compare = a.projectName.toLowerCase().compareTo(
                  b.projectName.toLowerCase(),
                );
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (project) => project.uid ?? '',
        ),
        child: const ProjectsListingView(),
      ),
    );
  }
}

class ProjectsListingView extends StatefulWidget {
  const ProjectsListingView({super.key});

  @override
  State<ProjectsListingView> createState() => _ProjectsListingViewState();
}

class _ProjectsListingViewState extends State<ProjectsListingView> {
  final List<ProjectModel> _selectedProjects = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

  // ---------------------------------------------------------------------
  // Filters: Project Lead, Master Client, Created By, Deadline range
  // ---------------------------------------------------------------------
  String? _fLeadUid;
  String? _fLeadName;
  String? _fMasterUid;
  String? _fMasterName;
  String? _fCreatedByUid;
  String? _fCreatedByName;
  DateTimeRange? _fDeadline;
  // Bumped by "Clear filters" so the dropdowns rebuild with no selection.
  int _filterEpoch = 0;

  // Rebuilt only when the project list itself changes, so the dropdowns keep
  // their state across unrelated rebuilds.
  List<ProjectModel>? _optionsSource;
  Map<String, String> _leadOpts = {}; // display name -> uid
  Map<String, String> _creatorOpts = {}; // display name -> uid
  Map<String, String> _masterOpts = {}; // display name -> uid
  List<String> _masterItems = const [];
  List<String> _leadItems = const [];

  // Master Client lookups (uid -> name) and the deal links used when an
  // older project has no master client saved on it.
  Map<String, String> _masterNames = {};
  Map<String, String> _dealClientById = {}; // deal uid -> master client uid
  Map<String, String> _dealClientByName = {}; // project name -> master client uid

  /// Master Client of a project: saved on the project, else from its deal.
  String _masterClientUid(ProjectModel p) {
    final own = (p.clientId ?? '').trim();
    if (own.isNotEmpty) return own;
    final byDeal = _dealClientById[p.dealId ?? ''] ?? '';
    if (byDeal.isNotEmpty) return byDeal;
    return _dealClientByName[p.projectName.trim().toLowerCase()] ?? '';
  }

  String _masterClientName(ProjectModel p) =>
      _masterNames[_masterClientUid(p)] ?? '';
  List<String> _creatorItems = const [];

  int get _activeFilterCount =>
      (_fLeadUid != null ? 1 : 0) +
      (_fMasterUid != null ? 1 : 0) +
      (_fCreatedByUid != null ? 1 : 0) +
      (_fDeadline != null ? 1 : 0);

  bool get _hasActiveFilters => _activeFilterCount > 0;

  bool _matchesFilters(ProjectModel p) {
    // "Lead" column shows projectOwner, so that is what we filter on.
    if (_fLeadUid != null && p.projectOwner != _fLeadUid) return false;
    if (_fMasterUid != null && _masterClientUid(p) != _fMasterUid) {
      return false;
    }
    if (_fCreatedByUid != null && p.createdBy.uid != _fCreatedByUid) {
      return false;
    }
    final range = _fDeadline;
    if (range != null && !dateInRange(p.deadline, range)) return false;
    return true;
  }

  void _buildUserOptions(List<ProjectModel> projects) {
    if (identical(projects, _optionsSource)) return;
    _optionsSource = projects;

    final leads = <String, String>{}; // uid -> name
    final creators = <String, String>{};
    final masters = <String, String>{};
    for (final p in projects) {
      final mid = _masterClientUid(p);
      final mname = _masterNames[mid] ?? '';
      if (mid.isNotEmpty && mname.isNotEmpty) masters[mid] = mname;
      final lead = CacheService.getUserByUid(p.projectOwner)?.name ?? '';
      if (p.projectOwner.isNotEmpty && lead.isNotEmpty) {
        leads[p.projectOwner] = lead;
      }
      if (p.createdBy.uid.isNotEmpty && p.createdBy.name.isNotEmpty) {
        creators[p.createdBy.uid] = p.createdBy.name;
      }
    }
    _leadOpts = nameToUidOptions(leads);
    _masterOpts = nameToUidOptions(masters);
    _creatorOpts = nameToUidOptions(creators);
    _masterItems = _masterOpts.keys.toList();
    _leadItems = _leadOpts.keys.toList();
    _creatorItems = _creatorOpts.keys.toList();
  }

  /// Re-applies the filters. Selection is cleared because ticked rows may no
  /// longer be visible (and must not be bulk-deleted unseen).
  void _applyFilters(PaginatedDataController<ProjectModel> c) {
    _selectedProjects.clear();
    c.clearSelection();
    c.setFilter(_hasActiveFilters ? _matchesFilters : null);
  }

  void _clearFilters(PaginatedDataController<ProjectModel> c) {
    setState(() {
      _fLeadUid = _fLeadName = null;
      _fMasterUid = _fMasterName = null;
      _fCreatedByUid = _fCreatedByName = null;
      _fDeadline = null;
      _filterEpoch++;
    });
    _applyFilters(c);
  }

  Future<void> _pickDeadlineRange(
    PaginatedDataController<ProjectModel> c,
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

  Widget _buildFilterBar(
    PaginatedDataController<ProjectModel> controllerRead,
    List<ProjectModel> allProjects,
  ) {
    _buildUserOptions(allProjects);
    return ListFilterCard(
      activeCount: _activeFilterCount,
      onClear: () => _clearFilters(controllerRead),
      fields: [
        FormDropdownSearch(
          key: ValueKey('f_lead_${_filterEpoch}_${_leadItems.length}'),
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
        FormDropdownSearch(
          key: ValueKey('f_master_${_filterEpoch}_${_masterItems.length}'),
          label: 'Master Client',
          initialItem: _fMasterName,
          items: _masterItems,
          onChanged: (v) {
            setState(() {
              _fMasterName = v as String?;
              _fMasterUid = v == null ? null : _masterOpts[v];
            });
            _applyFilters(controllerRead);
          },
        ),
        FormDropdownSearch(
          key: ValueKey('f_creator_${_filterEpoch}_${_creatorItems.length}'),
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
        DateRangeFilterField(
          label: 'Deadline Range',
          range: _fDeadline,
          onTap: () => _pickDeadlineRange(controllerRead),
          onClear: () {
            setState(() => _fDeadline = null);
            _applyFilters(controllerRead);
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadMasterClients();
  }

  Future<void> _loadMasterClients() async {
    try {
      final clients = await ClientService.getMasterClients();
      final deals = await DealService.getAllDeals();
      if (!mounted) return;
      setState(() {
        _masterNames = {
          for (final c in clients)
            if ((c.uid ?? '').isNotEmpty) c.uid!: c.displayName,
        };
        _dealClientById = {
          for (final d in deals)
            if ((d.uid ?? '').isNotEmpty && (d.clientId ?? '').isNotEmpty)
              d.uid!: d.clientId!,
        };
        _dealClientByName = {
          for (final d in deals)
            if ((d.clientId ?? '').isNotEmpty)
              (((d.projectName ?? '').trim().isNotEmpty
                          ? d.projectName!
                          : d.dealName)
                      .trim()
                      .toLowerCase()):
                  d.clientId!,
        };
        _optionsSource = null; // rebuild filter options with the names
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    if (!mounted) return;
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshProjects() async {
    context.read<ProjectsBloc>().add(StreamProjects());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<ProjectModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<ProjectModel>>();
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
      body: BlocListener<ProjectsBloc, ProjectsState>(
        listenWhen: (previous, current) => current is ProjectsLoaded,
        listener: (context, state) {
          if (state is ProjectsLoaded) {
            controllerRead.setData(state.projects);
          }
        },
        child: BlocBuilder<ProjectsBloc, ProjectsState>(
          builder: (context, state) {
            if (state is ProjectsLoading) {
              return const WaitingLoading();
            }

            if (state is ProjectsLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: _refreshProjects,
                child: Scrollbar(
                  controller: _vScrollController,
                  thumbVisibility: true,
                  interactive: true,
                  trackVisibility: true,
                  radius: const Radius.circular(8),
                  thickness: 8,
                  child: ListView(
                    controller: _vScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      if (isWide) ...[
                        _buildHeaderBanner(context, state.projects.length),
                        const SizedBox(height: 20),
                      ],
                      _buildToolbar(
                        context,
                        controllerRead,
                        state.projects.length,
                      ),
                      const SizedBox(height: 14),
                      _buildFilterBar(controllerRead, state.projects),
                      const SizedBox(height: 18),
                      controllerWatch.paginatedItems.isEmpty
                          ? NoData(
                              text: state.projects.isEmpty
                                  ? "No projects available"
                                  : "No matching records found",
                            )
                          : _buildTableCard(
                              context,
                              controllerWatch,
                              controllerRead,
                            ),
                    ],
                  ),
                ),
              );
            }

            if (state is ProjectsError) {
              return Center(
                child: Text(
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
  Widget _buildHeaderBanner(BuildContext context, int totalProjects) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
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
              Iconsax.briefcase,
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
                  "Project Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Plan, track and manage all your projects in one place",
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
                  '$totalProjects',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalProjects == 1 ? "Project" : "Projects",
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
  // Toolbar: search + add + delete + refresh
  // ---------------------------------------------------------------------
  Widget _buildToolbar(
    BuildContext context,
    PaginatedDataController<ProjectModel> controllerRead,
    int totalProjects,
  ) {
    final isWide = _isWide(context);

    final buttons = <Widget>[
      if (permissions?.canCreate ?? false) _gradientButton(
              context: context,
              icon: Icons.add_rounded,
              label: "Add $_pageTitle",
              colors: const [
                Color(0xFF0052D4),
                Color(0xFF4364F7),
                Color(0xFF6FB1FC),
              ],
              onPressed: () {
                if (kIsMobile || !isWide) {
                  Sheet.showSheet(context, widget: const ProjectCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const ProjectCreate());
                }
              },
            ),
      if (_selectedProjects.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedProjects.length})",
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkDelete,
        ),
      if (isWide)
        _iconCircleButton(
          context,
          icon: Iconsax.refresh,
          tooltip: "Refresh",
          background: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          iconColor: Theme.of(context).colorScheme.primary,
          onPressed: _refreshProjects,
        ),
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
                SizedBox(width: 260, child: _searchBox()),
                const SizedBox(width: 16),
                _projectCountChip(context, totalProjects),
                const Spacer(),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchBox(),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: buttons),
              ],
            ),
    );
  }

  Widget _projectCountChip(BuildContext context, int totalProjects) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.briefcase,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "$totalProjects total",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return _ProjectsSearchField(
      pageTitle: _pageTitle,
      onChanged: context.read<PaginatedDataController<ProjectModel>>().setSearch,
    );
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }

  Widget _avatarCircle(String name, {double size = 38}) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = LetterColors.getColor(letter);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Desktop / wide layout: table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<ProjectModel> controllerWatch,
    PaginatedDataController<ProjectModel> controllerRead,
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
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: true,
                        sortColumnIndex: controllerWatch.sortColumnIndex,
                        sortAscending: controllerWatch.sortAscending,
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.06,
                          ),
                        ),
                        headingTextStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        columns: [
                          DataColumn(
                            label: const Text("Project Name"),
                            onSort: controllerRead.setSort,
                          ),
                          DataColumn(
                            label: const Text("Project Code"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Master Client")),
                          const DataColumn(label: Text("Project Lead")),
                          const DataColumn(label: Text("Deadline")),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(
                          controllerWatch.paginatedItems.length,
                          (index) {
                            final project = controllerWatch.paginatedItems[index];
                            return _buildDataRow(
                              context,
                              project,
                              controllerWatch,
                              controllerRead,
                              index,
                            );
                          },
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
            child: PaginationControls<ProjectModel>(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    ProjectModel project,
    PaginatedDataController<ProjectModel> controllerWatch,
    PaginatedDataController<ProjectModel> controllerRead,
    int index,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(project.uid);
    final leadName = CacheService.getUserByUid(project.projectOwner)?.name ?? '';

    return DataRow(
      selected: isSelected,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
        }
        return index.isEven
            ? Colors.transparent
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              );
      }),
      onSelectChanged: (selected) {
        controllerRead.onSelected(project.uid ?? '', selected);
        if (selected ?? false) {
          _selectedProjects.add(project);
        } else {
          _selectedProjects.remove(project);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatarCircle(project.projectName, size: 32),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  project.projectName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          (project.projectCode ?? '').isNotEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    project.projectCode!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              : Text(
                  "—",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        DataCell(
          _masterClientName(project).isNotEmpty
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    _masterClientName(project),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : Text(
                  "—",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        DataCell(
          leadName.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _avatarCircle(leadName, size: 26),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        leadName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                )
              : Text(
                  "—",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        DataCell(
          project.deadline != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.calendar_1,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      project.deadline!.listingDateTime,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                )
              : Text(
                  "—",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        DataCell(CreatedByWidget(userData: project.createdBy)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (permissions?.canEdit ?? false) _iconCircleButton(
                      context,
                      icon: Iconsax.edit,
                      tooltip: "Edit",
                      background: AppColors.info.withValues(alpha: 0.12),
                      iconColor: AppColors.info,
                      onPressed: () => _onEditTap(project),
                    ),
              if ((permissions?.canEdit ?? false) && (permissions?.canDelete ?? false))
                const SizedBox(width: 8),
              if (permissions?.canDelete ?? false) _iconCircleButton(
                      context,
                      icon: Iconsax.trash,
                      tooltip: "Delete",
                      background: AppColors.danger.withValues(alpha: 0.12),
                      iconColor: AppColors.danger,
                      onPressed: () => _onDeleteTap(project),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------
  void _onEditTap(ProjectModel project) {
    final isWide = _isWide(context);
    if (!isWide) {
      Sheet.showSheet(context, widget: ProjectEdit(uid: project.uid ?? ''));
    } else {
      GeneralDialog.showRTLSheet(context, ProjectEdit(uid: project.uid ?? ''));
    }
  }

  Future<void> _onDeleteTap(ProjectModel project) async {
    try {
      final isAssigned = await ProjectService.isProjectAssigned(
        project.uid ?? '',
      );

      if (isAssigned) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: const Text(
              'This project is associated with one or more tasks and cannot be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmDialog(
          title: 'Delete $_pageTitle',
          content: 'Are you sure you want to delete this $_pageTitle?',
        ),
      );

      if (result != true) return;
      if (!mounted) return;

      final deletedProject = project.copyWith();

      await ProjectService.deleteProject(uid: project.uid ?? '');

      if (!mounted) return;

      FlushBar.show(
        context,
        'Project deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          if (deletedProject.uid == null) return;
          await ProjectService.restoreProject(deletedProject);
          if (!mounted) return;
          context.read<ProjectsBloc>().add(StreamProjects());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, 'Failed to delete project: $e', isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedProjects.isEmpty) return;

    try {
      for (var project in _selectedProjects) {
        final isAssigned = await ProjectService.isProjectAssigned(
          project.uid ?? '',
        );

        if (isAssigned) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Cannot Delete'),
              content: const Text(
                'One or more selected projects are associated with tasks.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ConfirmDialog(
          title: 'Delete $_pageTitle',
          content: 'Are you sure you want to delete selected $_pageTitle?',
        ),
        barrierDismissible: false,
      );

      if (result != true) return;
      if (!mounted) return;

      final deletedProjects = _selectedProjects.map((e) => e.copyWith()).toList();

      futureLoading(context);

      for (var project in deletedProjects) {
        await ProjectService.deleteProject(uid: project.uid ?? '');
      }

      if (Navigator.canPop(context)) Navigator.pop(context);

      _selectedProjects.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        'Projects deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var project in deletedProjects) {
            if (project.uid == null) continue;
            await ProjectService.restoreProject(project);
          }
          if (!mounted) return;
          context.read<ProjectsBloc>().add(StreamProjects());
        },
      );
    } catch (e, st) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(
        context,
        'Failed to delete projects: $e',
        isSuccess: false,
      );
    }
  }
}

// ---------------------------------------------------------------------
// A polished, colorful search field for the Projects toolbar.
// ---------------------------------------------------------------------
class _ProjectsSearchField extends StatefulWidget {
  final String pageTitle;
  final ValueChanged<String> onChanged;
  const _ProjectsSearchField({required this.pageTitle, required this.onChanged});

  @override
  State<_ProjectsSearchField> createState() => _ProjectsSearchFieldState();
}

class _ProjectsSearchFieldState extends State<_ProjectsSearchField> {
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
          hintText: 'Search ${widget.pageTitle}',
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