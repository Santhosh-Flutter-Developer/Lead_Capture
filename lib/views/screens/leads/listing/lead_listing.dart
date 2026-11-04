import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/utils/src/download_io.dart'
    if (dart.library.html) 'package:leadcapture/utils/src/download_web.dart'
    show saveFileToDownloads;
import 'package:leadcapture/views/screens/leads/listing/lead_upload.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '/services/services.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';

/// Layout is decided by the available CONTENT width (not the platform), so the
/// web build, narrow desktop windows and phones all get the compact layout.
const double _wideBreakpoint = 760;
const List<Color> _brandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

const String _pageTitle = "Leads";

class LeadsListing extends StatelessWidget {
  final bool showAppBar;
  const LeadsListing({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => LeadBloc()..add(StreamLead()))],

      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<LeadModel>(
          initialSortColumnIndex: 1,
          filterLogic: (lead, query) {
            final q = query.toLowerCase();
            return lead.leadName.toLowerCase().contains(q) ||
                lead.leadName.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 1:
                compare = (a.leadNumber ?? 0).compareTo((b.leadNumber ?? 0));
                break;
              case 2:
                compare = a.leadName.toLowerCase().compareTo(
                  b.leadName.toLowerCase(),
                );
                break;
              case 3:
                compare = a.leadEmail.toLowerCase().compareTo(
                  b.leadEmail.toLowerCase(),
                );
                break;
              case 5:
                compare = a.leadValue.compareTo(b.leadValue);
                break;
              case 6:
                compare = a.createdAt.compareTo(b.createdAt);
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (lead) => lead.uid ?? '',
        ),
        child: LeadsListingView(showAppBar: showAppBar),
      ),
    );
  }
}

class LeadsListingView extends StatefulWidget {
  final bool showAppBar;
  const LeadsListingView({super.key, this.showAppBar = true});

  @override
  State<LeadsListingView> createState() => _LeadsListingViewState();
}

class _LeadsListingViewState extends State<LeadsListingView> {
  final ScrollController _hScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _vScrollController = ScrollController();
  String _selectedView = 'Grid';
  List<LeadModel> _filteredLeads = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  bool _compact = false;
  bool _filtersExpanded = false;
  double _filterWidth = 180;

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedStatus;
  String? _selectedCategory;
  String? _selectedCreatedBy;
  String? _selectedSource;
  String? _selectedPriority; // priority name
  String? _selectedClient; // client key (clientId, else company name)
  String? _selectedProject;
  String? _selectedConverted; // 'Converted' | 'Not Converted'

  double? _value;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadFilterMasters();
  }

  // Full master lists for the filter dropdowns (not just values already used).
  List<String> _sourceOptions = [];
  List<String> _priorityOptions = [];
  List<ClientModel> _masterClients = [];

  Future<void> _loadFilterMasters() async {
    try {
      final r = await Future.wait([
        LeadSourceService.getAllLeadSource(),
        LeadPriorityService.getAllLeadPriority(),
        ClientService.getMasterClients(),
      ]);
      if (!mounted) return;
      setState(() {
        _sourceOptions = _distinct(
          (r[0] as List<LeadSourceModel>).map((e) => e.name),
        );
        _priorityOptions = _distinct(
          (r[1] as List<LeadPriorityModel>).map((e) => e.name),
        );
        _masterClients = r[2] as List<ClientModel>;
      });
    } catch (_) {}
  }

  String _masterLabel(ClientModel c) {
    final company = (c.companyName ?? '').trim();
    final contact = (c.clientName ?? '').trim();
    if (company.isEmpty) return contact;
    return contact.isEmpty ? company : '$company - $contact';
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    _hScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Role-based permissions for this page. Everything on this screen
  /// (add / edit / delete / bulk delete / import / export) is driven by the
  /// role's flags only, so List, Board and Calendar all behave the same.
  Future<void> _loadPermissions() async {
    final perm = await PermissionService.getPermissions(_pageTitle);
    if (!mounted) return;
    setState(() {
      permissions = perm;
      _permissionsLoaded = true;
    });
  }

  bool get _canEdit => permissions?.canEdit ?? false;
  bool get _canDelete => permissions?.canDelete ?? false;

  List<String> statusItems(Box<Map<dynamic, dynamic>> box) {
    return box.keys.map((key) {
      final data = CacheService.normalizeFromCache(box.get(key) ?? {});
      final model = LeadStatusModel.fromMap(key, data);
      return model.name;
    }).toList();
  }

  List<String> categoryItems(Box<Map<dynamic, dynamic>> box) {
    return box.keys.map((key) {
      final data = CacheService.normalizeFromCache(box.get(key) ?? {});
      final model = LeadCategoryModel.fromMap(key, data);
      return model.name;
    }).toList();
  }

  List<String> employeeItems(CacheService cache) {
    return cache.getAllListenableEmployees().value.map((e) => e.name).toList();
  }

  Future<void> _refreshLeads(BuildContext context) async {
    context.read<LeadBloc>().add(StreamLead());
  }

  void _resetFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _selectedStatus = null;
      _selectedCategory = null;
      _selectedCreatedBy = null;
      _selectedSource = null;
      _selectedPriority = null;
      _selectedClient = null;
      _selectedProject = null;
      _selectedConverted = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<LeadModel>>();
    final controllerWatch = context.watch<PaginatedDataController<LeadModel>>();
    return Scaffold(
      appBar: widget.showAppBar &&
                (kIsMobile || MediaQuery.of(context).size.width < 1000)
          ? AppBar(
              title: const Text(_pageTitle),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            )
          : null,
      body: LayoutBuilder(
        builder: (context, box) {
          _compact = box.maxWidth < _wideBreakpoint;
          return _buildBody(context, controllerRead, controllerWatch);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PaginatedDataController<LeadModel> controllerRead,
    PaginatedDataController<LeadModel> controllerWatch,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocListener<LeadBloc, LeadState>(
        listenWhen: (previous, current) => current is LeadLoaded,
        listener: (context, state) {
          if (state is LeadLoaded) {
            // Re-apply the active filters (instead of silently dropping them)
            // and drop selected rows that no longer exist.
            _applyFilters();
          }
        },
        child: BlocBuilder<LeadBloc, LeadState>(
          builder: (context, state) {
            if (state is LeadLoading) {
              return const WaitingLoading();
            }
            if (state is LeadLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshLeads(context),
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
                    padding: EdgeInsets.all(_compact ? 14.0 : 24.0),
                    children: [
                      if (!_compact) ...[
                        _buildHeaderBanner(state.leads.length),
                        const SizedBox(height: 18),
                      ],
                      _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                      const SizedBox(height: 12),
                      _buildActionRow(context),
                      if (_selectedView == 'List' &&
                          _canDelete &&
                          controllerWatch.selectedIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildSelectionBar(controllerWatch, controllerRead),
                      ],
                      const SizedBox(height: 18),
                      if (controllerWatch.paginatedItems.isEmpty)
                        const NoData(text: "No matching records found")
                      else if (_selectedView == 'Grid') ...[
                        LeadKanbanListing(
                          leadList: _filteredLeads,
                          onLeadDeleted: () =>
                              context.read<LeadBloc>().add(StreamLead()),
                          onLeadConverted: () =>
                              context.read<LeadBloc>().add(StreamLead()),
                        ),
                      ] else if (_selectedView == 'Calendar') ...[
                        LeadCalendarListing(
                          leadList: _filteredLeads,
                          onLeadCreated: () =>
                              context.read<LeadBloc>().add(StreamLead()),
                        ),
                      ] else ...[
                        _buildListView(context, controllerWatch, controllerRead),
                      ],
                    ],
                  ),
                ),
              );
            }

            if (state is LeadError) {
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

  Container _buildListView(
    BuildContext context,
    PaginatedDataController<LeadModel> controllerWatch,
    PaginatedDataController<LeadModel> controllerRead,
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
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
                      showCheckboxColumn: _canDelete,
                      onSelectAll: _canDelete
                          ? (selected) => _setPageSelection(
                              controllerRead,
                              selected ?? false,
                            )
                          : null,
                      columnSpacing: 12,
                      horizontalMargin: 8,
                      // headingRowHeight: 40,
                      // dataRowMinHeight: 36,
                      // dataRowMaxHeight: 36,
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
                          label: IntrinsicWidth(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Id",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_upward,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Name",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_upward,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Email",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_upward,
                                  size: 14,
                                  color: AppColors.grey400,
                                ),
                              ],
                            ),
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Text(
                              "Mobile No",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Lead Value",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_upward,
                                  size: 14,
                                  color: AppColors.grey400,
                                ),
                              ],
                            ),
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Text(
                              "Source",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Text(
                              "Status",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Created",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_upward,
                                  size: 14,
                                  color: AppColors.grey400,
                                ),
                              ],
                            ),
                          ),
                          onSort: controllerRead.setSort,
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Text(
                              "Created By",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: IntrinsicWidth(
                            child: Text(
                              "Action",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ],
                      rows: controllerWatch.paginatedItems.map((lead) {
                        return _buildDataRow(
                          context,
                          lead,
                          controllerWatch,
                          controllerRead,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<LeadModel>(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(int total) {
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
              Iconsax.personalcard,
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
                  "Lead Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Capture, track and convert your leads in one place",
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
                  '$total',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  total == 1 ? "Lead" : "Leads",
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

  List<LeadModel> get _allLeads => context.read<LeadBloc>().state is LeadLoaded
      ? (context.read<LeadBloc>().state as LeadLoaded).leads
      : <LeadModel>[];

  String _priorityName(LeadModel l) =>
      CacheService.leadPriorityByUid(l.leadPriority)?.name ?? '';

  String _clientKey(LeadModel l) => (l.clientId ?? '').isNotEmpty
      ? l.clientId!
      : (l.companyName ?? '').trim().toLowerCase();

  String _clientLabel(LeadModel l) {
    final company = (l.companyName ?? '').trim();
    final contact = (l.clientName ?? '').trim();
    if (company.isEmpty) return contact;
    return contact.isEmpty ? company : '$company - $contact';
  }

  List<String> _distinct(Iterable<String> v) =>
      (v.where((e) => e.trim().isNotEmpty).toSet().toList()..sort());

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    if (_compact) {
      final available = MediaQuery.of(context).size.width - 28 - 32;
      final cols = available >= 2 * 170 + 10 ? 2 : 1;
      _filterWidth = (available - (cols - 1) * 10) / cols;
    } else {
      _filterWidth = 180;
    }
    if (!Hive.isBoxOpen('leadStatus') ||
        !Hive.isBoxOpen('leadCategory') ||
        !Hive.isBoxOpen('employees')) {
      return _buildSearchField(onSearchChanged);
    }

    final statusBox = Hive.box<Map<dynamic, dynamic>>('leadStatus');
    final categoryBox = Hive.box<Map<dynamic, dynamic>>('leadCategory');
    final cache = CacheService();

    final filters = [
      _dateFilter(
        label: "From Date",
        value: _fromDate,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: _fromDate ?? DateTime.now(),
          );

          if (picked != null) {
            setState(() => _fromDate = picked);
            _applyFilters();
          }
        },
      ),

      _dateFilter(
        label: "To Date",
        value: _toDate,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: _toDate ?? DateTime.now(),
          );

          if (picked != null) {
            setState(() => _toDate = picked);
            _applyFilters();
          }
        },
      ),

      _filterDropdown(
        label: "Status",
        value: _selectedStatus != null
            ? LeadStatusModel.fromMap(
                _selectedStatus!,
                Map<String, dynamic>.from(
                  statusBox.get(_selectedStatus!) ?? {},
                ),
              ).name
            : null,
        items: statusItems(statusBox),
        onChanged: (v) {
          final selectedModel = statusBox.keys.firstWhere(
            (key) =>
                LeadStatusModel.fromMap(
                  key,
                  Map<String, dynamic>.from(statusBox.get(key) ?? {}),
                ).name ==
                v,
            orElse: () => '',
          );

          setState(() => _selectedStatus = selectedModel);
          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Lead Category",
        value: _selectedCategory != null
            ? LeadCategoryModel.fromMap(
                _selectedCategory!,
                Map<String, dynamic>.from(
                  categoryBox.get(_selectedCategory!) ?? {},
                ),
              ).name
            : null,
        items: categoryItems(categoryBox),
        onChanged: (v) {
          final selectedModel = categoryBox.keys.firstWhere(
            (key) =>
                LeadCategoryModel.fromMap(
                  key,
                  Map<String, dynamic>.from(categoryBox.get(key) ?? {}),
                ).name ==
                v,
            orElse: () => '',
          );

          setState(() => _selectedCategory = selectedModel);
          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Created By",
        value: _selectedCreatedBy != null
            ? cache
                  .getAllListenableEmployees()
                  .value
                  .firstWhere((e) => e.uid == _selectedCreatedBy)
                  .name
            : null,
        items: employeeItems(cache),
        onChanged: (v) {
          final selectedEmployee = cache
              .getAllListenableEmployees()
              .value
              .firstWhereOrNull((e) => e.name == v);

          setState(() => _selectedCreatedBy = selectedEmployee?.uid);

          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Lead Source",
        value: _selectedSource,
        items: _distinct([..._sourceOptions, ..._allLeads.map((l) => l.leadSource.name)]),
        onChanged: (v) {
          setState(() => _selectedSource = v);
          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Lead Priority",
        value: _selectedPriority,
        items: _distinct([..._priorityOptions, ..._allLeads.map(_priorityName)]),
        onChanged: (v) {
          setState(() => _selectedPriority = v);
          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Master Client",
        value: _selectedClient == null
            ? null
            : _masterClients
                  .where((c) => c.uid == _selectedClient)
                  .map(_masterLabel)
                  .firstOrNull,
        items: _distinct(_masterClients.map(_masterLabel)),
        onChanged: (v) {
          final match = v == null
              ? null
              : _masterClients.where((c) => _masterLabel(c) == v).firstOrNull;
          setState(() => _selectedClient = match?.uid);
          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Project Name",
        value: _selectedProject,
        items: _distinct(_allLeads.map((l) => l.projectName ?? '')),
        onChanged: (v) {
          setState(() => _selectedProject = v);
          _applyFilters();
        },
      ),

      _filterDropdown(
        label: "Converted",
        value: _selectedConverted,
        items: const ['Converted', 'Not Converted'],
        onChanged: (v) {
          setState(() => _selectedConverted = v);
          _applyFilters();
        },
      ),

      _valueFilter(onChanged: _onValueChanged),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Search + reset
          if (_compact) ...[
            _buildSearchField(onSearchChanged),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _filtersExpanded = !_filtersExpanded),
                      icon: Icon(
                        _filtersExpanded
                            ? Icons.keyboard_arrow_up
                            : Iconsax.filter,
                        size: 18,
                      ),
                      label: Text(_filtersExpanded ? 'Hide Filters' : 'Filters'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildResetButton()),
              ],
            ),
            if (_filtersExpanded) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: filters),
            ],
          ] else ...[
            Row(
              children: [
                SizedBox(width: 280, child: _buildSearchField(onSearchChanged)),
                const Spacer(),
                _buildResetButton(),
              ],
            ),
            const SizedBox(height: 16),
            Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final filter in filters) ...[
                      filter,
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: _resetFilters,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text("Reset Filters"),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.errorContainer.withValues(alpha: 0.5),
          foregroundColor: Theme.of(context).colorScheme.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSearchField(ValueChanged<String> onSearchChanged) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          onSearchChanged(value);
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'Search leads...',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(
                  Iconsax.search_normal_1,
                  size: 12,
                  color: AppColors.white,
                ),
              ),
            ),
          ),

          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    onSearchChanged('');
                    _applyFilters();
                  },
                )
              : null,

          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,

          contentPadding: const EdgeInsets.symmetric(horizontal: 16),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.3,
            ),
          ),

          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _valueFilter({
    required ValueChanged<String> onChanged,
    double? itemWidth,
  }) {
    return SizedBox(
      width: itemWidth ?? _filterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Lead Value",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // Icon(
                //   Icons.currency_rupee,
                //   size: 18,
                //   color: Colors.grey.shade600,
                // ),
                // const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    onChanged: onChanged,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      // hintText: "1000 - 5000",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
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

  void _onValueChanged(String value) {
    _value = null;

    final cleaned = value.replaceAll(' ', '');
    if (cleaned.isEmpty) {
      _applyFilters();
      return;
    }

    final parsedValue = double.tryParse(cleaned);
    if (parsedValue == null) {
      _applyFilters();
      return;
    }

    _value = parsedValue;

    _applyFilters();
  }

  Widget _dateFilter({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    double? itemWidth,
  }) {
    return SizedBox(
      width: itemWidth ?? _filterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.calendar_1,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value == null
                          ? "Select $label"
                          : "${value.day.toString().padLeft(2, '0')}/"
                                "${value.month.toString().padLeft(2, '0')}/"
                                "${value.year}",
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? itemWidth,
  }) {
    return SizedBox(
      width: itemWidth ?? _filterWidth,
      child: FormDropdownSearch(
        label: label,
        items: items,
        initialItem: value,
        onChanged: (dynamic val) {
          onChanged(val as String?);
        },
        validator: (val) => val == null ? "* Required" : null,
      ),
    );
  }

  void _applyFilters() {
    final controller = context.read<PaginatedDataController<LeadModel>>();
    final List<LeadModel> allLeads =
        context.read<LeadBloc>().state is LeadLoaded
        ? (context.read<LeadBloc>().state as LeadLoaded).leads
        : <LeadModel>[];

    List<LeadModel> filtered = allLeads;
    final query = _searchController.text.toLowerCase();

    if (query.isNotEmpty) {
      filtered = filtered.where((lead) {
        return lead.leadName.toLowerCase().contains(query) ||
            lead.leadEmail.toLowerCase().contains(query) ||
            (lead.projectName ?? '').toLowerCase().contains(query) ||
            _clientLabel(lead).toLowerCase().contains(query) ||
            (lead.clientMobile ?? '').contains(query);
      }).toList();
    }
    if (_fromDate != null) {
      filtered = filtered
          .where((e) => !e.createdAt.isBefore(_fromDate!))
          .toList();
    }

    if (_toDate != null) {
      filtered = filtered.where((e) => !e.createdAt.isAfter(_toDate!)).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((e) => e.leadStatus == _selectedStatus)
          .toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((e) => e.leadCategory == _selectedCategory)
          .toList();
    }

    if (_selectedCreatedBy != null) {
      filtered = filtered
          .where((e) => e.createdBy.uid == _selectedCreatedBy)
          .toList();
    }

    if (_value != null) {
      filtered = filtered.where((e) => e.leadValue == _value!).toList();
    }

    if (_selectedSource != null) {
      filtered = filtered
          .where((e) => e.leadSource.name == _selectedSource)
          .toList();
    }

    if (_selectedPriority != null) {
      filtered = filtered
          .where((e) => _priorityName(e) == _selectedPriority)
          .toList();
    }

    if (_selectedClient != null) {
      filtered = filtered
          .where((e) {
            if ((e.clientId ?? '').isNotEmpty) {
              return e.clientId == _selectedClient;
            }
            final c = _masterClients
                .where((m) => m.uid == _selectedClient)
                .firstOrNull;
            return c != null &&
                (e.companyName ?? '').trim().toLowerCase() ==
                    (c.companyName ?? '').trim().toLowerCase();
          })
          .toList();
    }

    if (_selectedProject != null) {
      filtered = filtered
          .where((e) => (e.projectName ?? '') == _selectedProject)
          .toList();
    }

    if (_selectedConverted != null) {
      final wantConverted = _selectedConverted == 'Converted';
      filtered = filtered
          .where((e) => e.leadsConverted == wantConverted)
          .toList();
    }

    setState(() {
      _filteredLeads = filtered;
    });

    controller.retainSelection(
      filtered.map((l) => l.uid ?? '').where((id) => id.isNotEmpty).toSet(),
    );
    controller.setData(filtered);
  }

  // ---------------------------------------------------------------------
  // Selection + bulk delete
  // ---------------------------------------------------------------------

  /// Header checkbox: select / deselect every row on the current page.
  void _setPageSelection(
    PaginatedDataController<LeadModel> controller,
    bool select,
  ) {
    final ids = controller.paginatedItems
        .where((l) => !l.leadsConverted)
        .map((l) => l.uid ?? '')
        .where((id) => id.isNotEmpty);
    if (select) {
      controller.selectAll(ids);
    } else {
      controller.deselectAll(ids);
    }
  }

  List<LeadModel> _selectedLeadModels(
    PaginatedDataController<LeadModel> controller,
  ) {
    return _filteredLeads
        .where(
          (l) => !l.leadsConverted && controller.selectedIds.contains(l.uid),
        )
        .toList();
  }

  Future<void> _bulkDelete(
    PaginatedDataController<LeadModel> controller,
  ) async {
    final selected = _selectedLeadModels(controller);
    if (selected.isEmpty) return;

    final result = await confirmAndDeleteLeads(context, selected);
    if (result == null || !mounted) return;

    // Deleted rows leave the selection; failed ones stay selected so the
    // user can retry.
    controller.deselectAll(result.deleted.map((l) => l.uid ?? ''));

    if (result.deleted.isNotEmpty) {
      context.read<LeadBloc>().add(StreamLead());
    }
    showLeadsBulkDeletedUndo(
      context,
      result,
      () => context.read<LeadBloc>().add(StreamLead()),
    );
  }

  Widget _buildSelectionBar(
    PaginatedDataController<LeadModel> controllerWatch,
    PaginatedDataController<LeadModel> controllerRead,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCount = _selectedLeadModels(controllerWatch).length;
    final total = _filteredLeads.where((l) => !l.leadsConverted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$selectedCount of $total selected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          if (selectedCount < total)
            TextButton(
              onPressed: () => controllerRead.selectAll(
                _filteredLeads
                    .where((l) => !l.leadsConverted)
                    .map((l) => l.uid ?? ''),
              ),
              child: Text('Select all $total'),
            ),
          TextButton(
            onPressed: controllerRead.clearSelection,
            child: const Text('Clear'),
          ),
          ElevatedButton.icon(
            onPressed: selectedCount == 0
                ? null
                : () => _bulkDelete(controllerRead),
            icon: const Icon(Iconsax.trash, size: 18),
            label: Text('Delete ($selectedCount)'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final List<Widget> actionButtons = [];

        // ADD BUTTON
        if (permissions?.canCreate ?? false) {
          actionButtons.add(
            ElevatedButton.icon(
              onPressed: () async {
                final result = (kIsMobile || _compact)
                    ? await Sheet.showSheet(context, widget: const LeadCreate())
                    : await GeneralDialog.showRTLSheet(
                        context,
                        const LeadCreate(),
                      );
                if (result == true && context.mounted) {
                  context.read<LeadBloc>().add(StreamLead());
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text("Add $_pageTitle"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                backgroundColor: const Color(0xFF4364F7),
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        if (permissions?.canImport ?? false) {
          actionButtons.add(const SizedBox(width: 10));
          actionButtons.add(
            ElevatedButton.icon(
              onPressed: () {
                if (kIsMobile || _compact) {
                  Sheet.showSheet(context, widget: const LeadUpload());
                } else {
                  GeneralDialog.showRTLSheet(context, const LeadUpload());
                }
              },
              icon: const Icon(Iconsax.cloud_plus, size: 18),
              label: const Text("Upload"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          );
        }

        // TEMPLATE / SAMPLE DATA: only useful (and only shown) with import access
        if (permissions?.canImport ?? false) {
          actionButtons.add(const SizedBox(width: 10));

          actionButtons.add(
            OutlinedButton.icon(
              onPressed: () async {
                await Download.downloadFromAsset(
                  context,
                  "assets/templates/lead_upload_template.xlsx",
                  "Lead_Template.xlsx",
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text("Template"),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );

          // SAMPLE DATA BUTTON (template pre-filled with example leads)
          actionButtons.add(const SizedBox(width: 10));
          actionButtons.add(
            OutlinedButton.icon(
              onPressed: () async {
                await Download.downloadFromAsset(
                  context,
                  "assets/templates/lead_upload_template_with_data.xlsx",
                  "Lead_Sample_Data.xlsx",
                );
              },
              icon: const Icon(Icons.contact_page_outlined, size: 18),
              label: const Text("Sample Data"),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: Theme.of(context).colorScheme.secondary,
                side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          );
        }

        // EXPORT BUTTON
        if ((permissions?.canExport ?? false) && _filteredLeads.isNotEmpty) {
          actionButtons.add(const SizedBox(width: 10));
          actionButtons.add(
            ElevatedButton.icon(
              label: const Text("Export"),
              icon: const Icon(Iconsax.export_3, size: 18),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () async {
                try {
                  // Fetch all categories, priorities, and statuses
                  final categories =
                      await LeadCategoryService.getAllLeadCategories();
                  final priorities =
                      await LeadPriorityService.getAllLeadPriority();
                  final statuses = await LeadStatusService.getAllLeadStatus();

                  List<List<String>> exportData = [];
                  exportData.add([
                    'Lead Name',
                    'Email',
                    'Source',
                    'Category',
                    'Priority',
                    'Value',
                    'Status',
                    'Company',
                    'Mobile',
                    'Country',
                    'State',
                    'City',
                    'Address',
                    'Notes',
                    'Created At',
                  ]);

                  for (var lead in _filteredLeads) {
                    final category = categories.firstWhere(
                      (c) => c.uid == lead.leadCategory,
                      orElse: () => LeadCategoryModel(
                        name: lead.leadCategory,
                        description: '',
                        createdBy: UserDataModel.fromEmptyMap(),
                      ),
                    );
                    final priority = priorities.firstWhere(
                      (p) => p.uid == lead.leadPriority,
                      orElse: () => LeadPriorityModel(
                        name: lead.leadPriority,
                        description: '',
                        color: 0,
                        createdBy: UserDataModel.fromEmptyMap(),
                      ),
                    );
                    final status = statuses.firstWhere(
                      (s) => s.uid == lead.leadStatus,
                      orElse: () => LeadStatusModel(
                        name: lead.leadStatus,
                        description: '',
                        color: 0,
                        orderNumber: 0,
                        createdBy: UserDataModel.fromEmptyMap(),
                      ),
                    );

                    exportData.add([
                      lead.leadName,
                      lead.leadEmail,
                      lead.leadSource.name,
                      category.name,
                      priority.name,
                      lead.leadValue.toString(),
                      status.name,
                      lead.companyName ?? '',
                      lead.companyMobile ?? '',
                      lead.companyCountry?.name ?? '',
                      lead.companyState?.name ?? '',
                      lead.companyCity?.name ?? '',
                      lead.companyAddress ?? '',
                      lead.notes,
                      lead.createdAt.formatDateTime,
                    ]);
                  }

                  var fileBytes = await XlsxWriter().create(exportData);
                  var filePath = await saveFileToDownloads(
                    fileBytes,
                    fileName:
                        'Leads_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
                  );
                  if (!kIsWeb) openfile(filePath, context);
                  if (context.mounted) {
                    FlushBar.show(
                      context,
                      'Leads exported successfully',
                      isSuccess: true,
                    );
                  }
                } catch (e) {
                  FlushBar.show(context, e.toString(), isSuccess: false);
                }
              },
            ),
          );
        }


        // 2. View toggle (Grid / List / Calendar)
        final viewToggle = Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: _compact ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (!_compact)
                IconButton(
                  tooltip: "Refresh",
                  icon: const Icon(Iconsax.refresh),
                  iconSize: 18,
                  onPressed: () => _refreshLeads(context),
                ),
              _buildToggleIcon(Iconsax.grid_3, 'Grid', 'Board'),
              _buildToggleIcon(Icons.list, 'List', 'List'),
              _buildToggleIcon(Iconsax.calendar_1, 'Calendar', 'Calendar'),
            ],
          ),
        );

        // 3. Layout
        if (_compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: actionButtons),
              ),
              const SizedBox(height: 12),
              viewToggle,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: actionButtons),
                ),
              ),
              const SizedBox(width: 12),
              viewToggle,
            ],
          );
        }
      },
    );
  }

  // Helper for the View Toggle segments
  Widget _buildToggleIcon(IconData icon, String viewName, String label) {
    final selected = _selectedView == viewName;
    final scheme = Theme.of(context).colorScheme;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(horizontal: _compact ? 10 : 14),
      decoration: BoxDecoration(
        gradient: selected ? const LinearGradient(colors: _brandGradient) : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF4364F7).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: selected ? Colors.white : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    final tap = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (viewName != 'List') {
          context.read<PaginatedDataController<LeadModel>>().clearSelection();
        }
        setState(() => _selectedView = viewName);
      },
      child: child,
    );
    return _compact ? Expanded(child: tap) : tap;
  }

  DataRow _buildDataRow(
    BuildContext context,
    LeadModel lead,
    PaginatedDataController<LeadModel> controllerWatch,
    PaginatedDataController<LeadModel> controllerRead,
  ) {
    bool isSelected = controllerWatch.selectedIds.contains(lead.uid);
    var leadCategory = CacheService.leadCategoryByUid(lead.leadCategory);

    /// Open Lead View
    void openLead(BuildContext context, LeadModel lead) async {
      final result = (kIsMobile || _compact)
          ? await Sheet.showSheet(context, widget: LeadsViewPage(lead: lead))
          : await GeneralDialog.showRTLSheet(
              context,
              LeadsViewPage(lead: lead),
            );

      if (result == 'deleted' && context.mounted) {
        context.read<LeadBloc>().add(StreamLead());
        showLeadDeletedUndo(
          context,
          lead,
          () => context.read<LeadBloc>().add(StreamLead()),
        );
      }
    }

    /// Reusable tappable DataCell
    DataCell dataCell(BuildContext context, Widget child) {
      return DataCell(
        InkWell(
          onTap: () => openLead(context, lead),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: child,
          ),
        ),
      );
    }

    return DataRow(
      selected: isSelected,
      // A converted lead is locked: it cannot be selected for bulk delete.
      onSelectChanged: (_canDelete && !lead.leadsConverted)
          ? (selected) => controllerRead.onSelected(lead.uid ?? '', selected)
          : null,
      cells: [
        /// Lead Number
        dataCell(
          context,
          Text(
            lead.leadNumber?.toString() ?? '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),

        /// Lead Name
        dataCell(
          context,
          Text(
            lead.leadName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),

        /// Email
        dataCell(
          context,
          Text(lead.leadEmail, style: Theme.of(context).textTheme.bodySmall),
        ),

        /// Mobile No (from the master client)
        dataCell(
          context,
          Text(
            (lead.clientMobile ?? '').isNotEmpty
                ? lead.clientMobile!
                : (lead.companyMobile ?? ''),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Lead Value
        dataCell(
          context,
          Text(
            lead.leadValue.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Category
        dataCell(
          context,
          Text(
            leadCategory?.name ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Status
        dataCell(
          context,
          Text(
            CacheService.leadStatusByUid(lead.leadStatus)?.name ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Created At
        dataCell(
          context,
          Text(
            lead.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Created By
        dataCell(context, CreatedByWidget(userData: lead.createdBy)),

        /// Actions (❌ no row tap here)
        DataCell(
          Row(
            children: [
              if (_canEdit && !lead.leadsConverted) ...[
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  color: Theme.of(context).colorScheme.primary,
                  splashRadius: 20,
                  onPressed: () async {
                    final result = (kIsMobile || _compact)
                        ? await Sheet.showSheet(
                            context,
                            widget: LeadEdit(uid: lead.uid ?? ''),
                          )
                        : await GeneralDialog.showRTLSheet(
                            context,
                            LeadEdit(uid: lead.uid ?? ''),
                          );
                    if (result == true && context.mounted) {
                      await _refreshLeads(context);
                    }
                  },
                ),
              ],

              if (_canDelete && !lead.leadsConverted)
                IconButton(
                  icon: const Icon(Iconsax.trash),
                  tooltip: 'Delete $_pageTitle',
                  color: Theme.of(context).colorScheme.error,
                  splashRadius: 20,
                  onPressed: () async {
                    final deleted = await confirmAndDeleteLead(context, lead);
                    if (deleted && context.mounted) {
                      context.read<LeadBloc>().add(StreamLead());
                      showLeadDeletedUndo(
                        context,
                        lead,
                        () => context.read<LeadBloc>().add(StreamLead()),
                      );
                    }
                  },
                ),

              if (lead.leadsConverted != true)
                IconButton(
                  icon: const Icon(Icons.autorenew_rounded),
                  tooltip: 'Convert $_pageTitle to Deal',
                  color: Theme.of(context).colorScheme.secondary,
                  splashRadius: 20,
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => const ConfirmDialog(
                        title: 'Convert $_pageTitle',
                        content:
                            'Are you sure you want to convert this lead to a deal?',
                      ),
                    );

                    if (result == true) {
                      await _convertLeadToDeal(context, lead);
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Manually converts a lead: creates the deal in the "New" stage and links
  /// it to the lead (same result as setting the status to "Completed").
  Future<void> _convertLeadToDeal(BuildContext context, LeadModel lead) async {
    try {
      futureLoading(context);
      final leadDetails = await LeadService.getLead(uid: lead.uid ?? '');
      await LeadService.convertLeadToDeal(lead: leadDetails);
      if (Navigator.canPop(context)) Navigator.pop(context);
      if (context.mounted) {
        FlushBar.show(context, 'Deal created in the New stage');
        await _refreshLeads(context);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (Navigator.canPop(context)) Navigator.pop(context);
      if (context.mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  // Widget _searchBox({required ValueChanged<String> onSearchChanged}) {
  //   return SizedBox(
  //     width: 200,
  //     child: ListingSearchField(
  //       onChanged: onSearchChanged,
  //       pageTitle: _pageTitle,
  //     ),
  //   );
  // }
}