import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Layout is decided by the available CONTENT width (not the platform), so the
/// web build, narrow desktop windows and phones all get the compact layout.
const double _wideBreakpoint = 760;
const List<Color> _brandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

const String _pageTitle = "Deals";

class DealsListing extends StatelessWidget {
  final bool showAppBar;
  const DealsListing({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DealBloc()..add(StreamDeals()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<DealModel>(
          // Column indexes below match the DataTable columns in this file
          // (0 Id, 1 Name, 2 Email, 3 Value, 4 Status, 5 Created, ...).
          initialSortColumnIndex: 0,
          filterLogic: (deal, query) {
            final q = query.toLowerCase();
            return deal.dealName.toLowerCase().contains(q) ||
                deal.dealEmail.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 0:
                compare = (a.dealNumber ?? 0).compareTo((b.dealNumber ?? 0));
                break;
              case 1:
                compare = a.dealName.toLowerCase().compareTo(
                  b.dealName.toLowerCase(),
                );
                break;
              case 2:
                compare = a.dealEmail.toLowerCase().compareTo(
                  b.dealEmail.toLowerCase(),
                );
                break;
              case 3:
                compare = a.dealValue.compareTo(b.dealValue);
                break;
              case 5:
                compare = a.createdAt.compareTo(b.createdAt);
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (deal) => deal.uid ?? '',
        ),
        child: DealsListingView(showAppBar: showAppBar),
      ),
    );
  }
}

class DealsListingView extends StatefulWidget {
  final bool showAppBar;
  const DealsListingView({super.key, this.showAppBar = true});
  @override
  State<DealsListingView> createState() => _DealsListingViewState();
}

class _DealsListingViewState extends State<DealsListingView> {
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  String _selectedView = 'Grid';
  final List<DealModel> _selectedDeals = [];
  List<DealModel> _filteredDeals = [];

  DateTime? _fromDate;
  DateTime? _toDate;

  String? _selectedStatus;
  String? _selectedCreatedBy;
  String? _selectedClient; // master client uid
  String? _selectedSource;
  String? _selectedProject;
  DateTime? _nextFollowUp;

  List<ClientModel> _masterClients = [];
  List<String> _sourceOptions = [];
  Map<String, String> _dealSource = {}; // deal uid -> lead source name
  Map<String, DateTime> _followUps = {}; // deal uid -> next follow-up

  double? _value;

  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  bool _compact = false;
  bool _filtersExpanded = false;
  double _filterWidth = 180;
  double _boxWidth = 1000;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadFilterMasters();
  }

  String _masterLabel(ClientModel c) {
    final company = (c.companyName ?? '').trim();
    final contact = (c.clientName ?? '').trim();
    if (company.isEmpty) return contact;
    return contact.isEmpty ? company : '$company - $contact';
  }

  Future<void> _loadFilterMasters() async {
    try {
      final r = await Future.wait([
        ClientService.getMasterClients(),
        LeadSourceService.getAllLeadSource(),
        LeadService.getAllLeads(),
      ]);
      if (!mounted) return;
      final leads = r[2] as List<LeadModel>;
      final leadSource = {
        for (final l in leads)
          if (l.uid != null) l.uid!: l.leadSource.name,
      };
      final deals = _currentDeals;
      setState(() {
        _masterClients = r[0] as List<ClientModel>;
        _sourceOptions = (r[1] as List<LeadSourceModel>)
            .map((e) => e.name)
            .where((e) => e.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _dealSource = {
          for (final d in deals)
            if (d.uid != null && d.leadId != null && leadSource[d.leadId] != null)
              d.uid!: leadSource[d.leadId]!,
        };
      });
      _loadFollowUps(deals);
    } catch (_) {}
  }

  Future<void> _loadFollowUps(List<DealModel> deals) async {
    final ids = deals.map((d) => d.uid).whereType<String>().toList();
    final f = await DealService.getNextFollowUps(ids);
    if (!mounted) return;
    setState(() => _followUps = f);
    if (_nextFollowUp != null) _applyFilters();
  }

  List<DealModel> get _currentDeals =>
      context.read<DealBloc>().state is DealLoaded
      ? (context.read<DealBloc>().state as DealLoaded).deals
      : <DealModel>[];

  @override
  void dispose() {
    _hScrollController.dispose();
    _vScrollController.dispose();
    _searchController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    if (!mounted) return;
    _permissionsLoaded = true;
    setState(() {});
  }

  List<String> statusItems(Box<Map<dynamic, dynamic>> box) {
    return [
      'All',
      ...box.keys.map((key) {
        final data = CacheService.normalizeFromCache(box.get(key) ?? {});
        final model = DealStatusModel.fromMap(key, data);
        return model.name;
      }),
    ];
  }

  List<String> employeeItems(CacheService cache) {
    return [
      'All',
      ...cache.getAllListenableEmployees().value.map((e) => e.name),
    ];
  }

  Future<void> _refreshDeals(BuildContext context) async {
    context.read<DealBloc>().add(StreamDeals());
  }

  void _resetFilters() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _selectedStatus = null;
      _selectedCreatedBy = null;
      _selectedClient = null;
      _selectedSource = null;
      _selectedProject = null;
      _nextFollowUp = null;
      _value = null;
      _searchController.clear();
      _valueController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<DealModel>>();
    final controllerWatch = context.watch<PaginatedDataController<DealModel>>();
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
          _boxWidth = box.maxWidth;
          _compact = box.maxWidth < _wideBreakpoint;
          return _buildBody(context, controllerRead, controllerWatch);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PaginatedDataController<DealModel> controllerRead,
    PaginatedDataController<DealModel> controllerWatch,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocListener<DealBloc, DealState>(
        listenWhen: (previous, current) => current is DealLoaded,
        listener: (context, state) {
          if (state is DealLoaded) {
            controllerRead.setData(state.deals);
            setState(() {
              _filteredDeals = state.deals;
            });
            _loadFilterMasters();
          }
        },
        child: BlocBuilder<DealBloc, DealState>(
          builder: (context, state) {
            if (state is DealLoading) {
              return const WaitingLoading();
            }

            if (state is DealLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshDeals(context),
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
                        _buildHeaderBanner(state.deals),
                        const SizedBox(height: 18),
                      ],
                      _buildFilterRow(onSearchChanged: controllerRead.setSearch),
                      const SizedBox(height: 12),
                      _buildActionRow(context),
                      const SizedBox(height: 18),
                      if (controllerWatch.paginatedItems.isEmpty)
                        const NoData(text: "No matching records found")
                      else if (_selectedView == 'Grid') ...[
                        DealKanbanListing(
                          dealList: _filteredDeals,
                          onDealDeleted: () =>
                              context.read<DealBloc>().add(StreamDeals()),
                        ),
                      ] else if (_selectedView == 'Calendar') ...[
                        DealsCalendarListing(
                          dealList: _filteredDeals,
                          onDealCreated: () =>
                              context.read<DealBloc>().add(StreamDeals()),
                        ),
                      ] else ...[
                        _buildListView(context, controllerWatch, controllerRead),
                      ],
                    ],
                  ),
                ),
              );
            }

            if (state is DealError) {
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

  // ------------------------------------------------------------ LIST VIEW

  DataColumn _sortableHeader(
    String label,
    int index,
    int activeIndex, {
    bool sortable = true,
  }) {
    return DataColumn(
      label: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            if (sortable && index != activeIndex) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_upward, size: 14, color: AppColors.grey400),
            ],
          ],
        ),
      ),
      onSort: sortable
          ? context.read<PaginatedDataController<DealModel>>().setSort
          : null,
    );
  }

  Container _buildListView(
    BuildContext context,
    PaginatedDataController<DealModel> controllerWatch,
    PaginatedDataController<DealModel> controllerRead,
  ) {
    final active = controllerWatch.sortColumnIndex;
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
                      showCheckboxColumn: true,
                      columnSpacing: 12,
                      horizontalMargin: 8,
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
                        _sortableHeader("Id", 0, active),
                        _sortableHeader("Name", 1, active),
                        _sortableHeader("Email", 2, active),
                        _sortableHeader("Value", 3, active),
                        _sortableHeader("Status", 4, active, sortable: false),
                        _sortableHeader("Created", 5, active),
                        _sortableHeader(
                          "Created By",
                          6,
                          active,
                          sortable: false,
                        ),
                        _sortableHeader("Action", 7, active, sortable: false),
                      ],
                      rows: controllerWatch.paginatedItems
                          .map(
                            (deal) => _buildDataRow(
                              context,
                              deal,
                              controllerWatch,
                              controllerRead,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<DealModel>(),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- BANNER

  Widget _buildHeaderBanner(List<DealModel> deals) {
    final total = deals.length;
    final pipeline = deals.fold<double>(0, (sum, d) => sum + d.dealValue);
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
              Iconsax.briefcase,
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
                  "Deal Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Track, manage and close your deals in one place",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _bannerStat(_currencyFormat.format(pipeline), "Pipeline"),
          const SizedBox(width: 10),
          _bannerStat('$total', total == 1 ? "Deal" : "Deals"),
        ],
      ),
    );
  }

  Widget _bannerStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- FILTERS

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    if (_compact) {
      // page padding (14*2) + filter card padding (16*2)
      final available = _boxWidth - 28 - 32;
      final cols = available >= 2 * 170 + 10 ? 2 : 1;
      _filterWidth = (available - (cols - 1) * 10) / cols;
    } else {
      _filterWidth = 180;
    }

    if (!Hive.isBoxOpen('dealStatus') || !Hive.isBoxOpen('employees')) {
      return _buildSearchField(onSearchChanged);
    }

    // Wrapped in AnimatedBuilder so this row rebuilds automatically once the
    // dealStatus/employees Hive boxes finish syncing (they can still be
    // empty at first paint - CacheService populates them asynchronously),
    // instead of freezing on whatever snapshot existed at the first build.
    return AnimatedBuilder(
      animation: Listenable.merge([
        Hive.box<Map<dynamic, dynamic>>('dealStatus').listenable(),
        Hive.box<Map<dynamic, dynamic>>('employees').listenable(),
      ]),
      builder: (context, _) {
        final statusBox = Hive.box<Map<dynamic, dynamic>>('dealStatus');
        final cache = CacheService();

        final filters = [
          /// From Date
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

          /// To Date
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

          /// Status
          _filterDropdown(
            label: "Status",
            value: _selectedStatus != null
                ? CacheService.dealStatusByUid(_selectedStatus!)?.name
                : 'All',
            items: statusItems(statusBox),
            onChanged: (v) {
              if (v == null || v == 'All') {
                setState(() => _selectedStatus = null);
                _applyFilters();
                return;
              }
              final selectedModel = statusBox.keys.firstWhere(
                (key) => CacheService.dealStatusByUid(key)?.name == v,
                orElse: () => '',
              );

              setState(() => _selectedStatus = selectedModel);

              _applyFilters();
            },
          ),

          /// Created By
          _filterDropdown(
            label: "Created By",
            value: _selectedCreatedBy != null
                ? cache
                      .getAllListenableEmployees()
                      .value
                      .firstWhereOrNull((e) => e.uid == _selectedCreatedBy)
                      ?.name
                : 'All',
            items: employeeItems(cache),
            onChanged: (v) {
              if (v == null || v == 'All') {
                setState(() => _selectedCreatedBy = null);
                _applyFilters();
                return;
              }
              final selectedEmployee = cache
                  .getAllListenableEmployees()
                  .value
                  .firstWhereOrNull((e) => e.name == v);

              setState(() => _selectedCreatedBy = selectedEmployee?.uid);

              _applyFilters();
            },
          ),

          /// Master Client
          _filterDropdown(
            label: "Master Client",
            value: _selectedClient == null
                ? null
                : _masterClients
                      .where((c) => c.uid == _selectedClient)
                      .map(_masterLabel)
                      .firstOrNull,
            items: (_masterClients.map(_masterLabel).where((e) => e.isNotEmpty).toSet().toList()..sort()),
            onChanged: (v) {
              final m = v == null
                  ? null
                  : _masterClients.where((c) => _masterLabel(c) == v).firstOrNull;
              setState(() => _selectedClient = m?.uid);
              _applyFilters();
            },
          ),

          /// Lead Source
          _filterDropdown(
            label: "Lead Source",
            value: _selectedSource,
            items: _sourceOptions,
            onChanged: (v) {
              setState(() => _selectedSource = v);
              _applyFilters();
            },
          ),

          /// Project Name
          _filterDropdown(
            label: "Project Name",
            value: _selectedProject,
            items: (_currentDeals
                .map((d) => (d.projectName ?? '').trim())
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList()
              ..sort()),
            onChanged: (v) {
              setState(() => _selectedProject = v);
              _applyFilters();
            },
          ),

          /// Next Follow-up date
          _dateFilter(
            label: "Next Follow-up",
            value: _nextFollowUp,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: _nextFollowUp ?? DateTime.now(),
              );
              if (picked != null) {
                setState(() => _nextFollowUp = picked);
                _applyFilters();
              }
            },
          ),

          /// Deal Value Filter
          _valueFilter(onChanged: _onValueChanged),
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.05),
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
                          onPressed: () => setState(
                            () => _filtersExpanded = !_filtersExpanded,
                          ),
                          icon: Icon(
                            _filtersExpanded
                                ? Icons.keyboard_arrow_up
                                : Iconsax.filter,
                            size: 18,
                          ),
                          label: Text(
                            _filtersExpanded ? 'Hide Filters' : 'Filters',
                          ),
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
                    SizedBox(
                      width: 280,
                      child: _buildSearchField(onSearchChanged),
                    ),
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
      },
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
          hintText: 'Search deals...',
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
            "Deal Value",
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
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    onChanged: onChanged,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
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
        allowClear: true,
        onChanged: (dynamic val) {
          onChanged(val as String?);
        },
        validator: (val) => val == null ? "* Required" : null,
      ),
    );
  }

  void _applyFilters() {
    final controller = context.read<PaginatedDataController<DealModel>>();
    final List<DealModel> allDeals = context.read<DealBloc>().state is DealLoaded
        ? (context.read<DealBloc>().state as DealLoaded).deals
        : <DealModel>[];

    List<DealModel> filtered = allDeals;
    final query = _searchController.text.toLowerCase();

    if (query.isNotEmpty) {
      filtered = filtered.where((deal) {
        return deal.dealName.toLowerCase().contains(query) ||
            deal.dealEmail.toLowerCase().contains(query);
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
          .where((e) => e.dealStatus == _selectedStatus)
          .toList();
    }

    if (_selectedCreatedBy != null) {
      filtered = filtered
          .where((e) => e.createdBy.uid == _selectedCreatedBy)
          .toList();
    }

    if (_selectedClient != null) {
      filtered = filtered.where((e) {
        if ((e.clientId ?? '').isNotEmpty) return e.clientId == _selectedClient;
        final c = _masterClients
            .where((m) => m.uid == _selectedClient)
            .firstOrNull;
        return c != null &&
            (e.companyName ?? '').trim().toLowerCase() ==
                (c.companyName ?? '').trim().toLowerCase();
      }).toList();
    }

    if (_selectedSource != null) {
      filtered = filtered
          .where((e) => _dealSource[e.uid] == _selectedSource)
          .toList();
    }

    if (_selectedProject != null) {
      filtered = filtered
          .where((e) => (e.projectName ?? '').trim() == _selectedProject)
          .toList();
    }

    if (_nextFollowUp != null) {
      final d = _nextFollowUp!;
      filtered = filtered.where((e) {
        final f = _followUps[e.uid];
        return f != null && f.year == d.year && f.month == d.month && f.day == d.day;
      }).toList();
    }

    if (_value != null) {
      filtered = filtered.where((e) => e.dealValue == _value!).toList();
    }

    setState(() {
      _filteredDeals = filtered;
    });

    controller.setData(filtered);
  }

  // ----------------------------------------------------------- ACTION ROW

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
                    ? await Sheet.showSheet(context, widget: const DealCreate())
                    : await GeneralDialog.showRTLSheet(
                        context,
                        const DealCreate(),
                      );
                if (result == true && context.mounted) {
                  context.read<DealBloc>().add(StreamDeals());
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text("Add $_pageTitle"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                backgroundColor: const Color(0xFF4364F7),
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        // View toggle (Grid / List / Calendar)
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
                  onPressed: () => _refreshDeals(context),
                ),
              _buildToggleIcon(Iconsax.grid_3, 'Grid', 'Board'),
              _buildToggleIcon(Icons.list, 'List', 'List'),
              _buildToggleIcon(Iconsax.calendar_1, 'Calendar', 'Calendar'),
            ],
          ),
        );

        if (_compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (actionButtons.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: actionButtons),
                ),
                const SizedBox(height: 12),
              ],
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
      onTap: () => setState(() => _selectedView = viewName),
      child: child,
    );
    return _compact ? Expanded(child: tap) : tap;
  }

  // ------------------------------------------------------------- DATA ROW

  DataRow _buildDataRow(
    BuildContext context,
    DealModel deal,
    PaginatedDataController<DealModel> controllerWatch,
    PaginatedDataController<DealModel> controllerRead,
  ) {
    bool isSelected = controllerWatch.selectedIds.contains(deal.uid);
    final status = CacheService.dealStatusByUid(deal.dealStatus ?? '');

    /// Open Deal View (loads comments, history and activities)
    Future<void> openDeal(BuildContext context, DealModel deal) async {
      final result = (kIsMobile || _compact)
          ? await Sheet.showSheet(context, widget: DealsViewPage(deal: deal))
          : await GeneralDialog.showRTLSheet(
              context,
              DealsViewPage(deal: deal),
            );

      if ((result == 'deleted' || result == 'restored') && context.mounted) {
        context.read<DealBloc>().add(StreamDeals());
      }
    }

    /// Reusable tappable DataCell
    DataCell dataCell(BuildContext context, Widget child) {
      return DataCell(
        InkWell(
          onTap: () => openDeal(context, deal),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: child,
          ),
        ),
      );
    }

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(deal.uid ?? '', selected);
        if (selected ?? false) {
          _selectedDeals.add(deal);
        } else {
          _selectedDeals.remove(deal);
        }
        setState(() {});
      },
      cells: [
        /// Deal Number
        dataCell(
          context,
          Text(
            deal.dealNumber?.toString() ?? '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),

        /// Deal Name
        dataCell(
          context,
          Text(
            deal.dealName,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),

        /// Email
        dataCell(
          context,
          Text(deal.dealEmail, style: Theme.of(context).textTheme.bodySmall),
        ),

        /// Deal Value
        dataCell(
          context,
          Text(
            _currencyFormat.format(deal.dealValue),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),

        /// Status
        dataCell(context, _statusChip(status)),

        /// Created At
        dataCell(
          context,
          Text(
            deal.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),

        /// Created By
        dataCell(context, CreatedByWidget(userData: deal.createdBy)),

        /// Actions (no row tap here)
        DataCell(
          Row(
            children: [
              if (deal.isLocked)
                IconButton(
                  icon: const Icon(Iconsax.lock),
                  tooltip: 'This deal is locked',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  splashRadius: 20,
                  onPressed: () {
                    FlushBar.show(
                      context,
                      'This deal is locked and cannot be edited',
                      isSuccess: false,
                    );
                  },
                )
              else if (permissions?.canEdit ?? false)
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  color: Theme.of(context).colorScheme.primary,
                  splashRadius: 20,
                  onPressed: () async {
                    final result = (kIsMobile || _compact)
                        ? await Sheet.showSheet(
                            context,
                            widget: DealEdit(uid: deal.uid ?? ''),
                          )
                        : await GeneralDialog.showRTLSheet(
                            context,
                            DealEdit(uid: deal.uid ?? ''),
                          );
                    if (result != null && context.mounted) {
                      context.read<DealBloc>().add(StreamDeals());
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(DealStatusModel? status) {
    if (status == null) {
      return Text('', style: Theme.of(context).textTheme.bodySmall);
    }
    final color = Color(status.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}