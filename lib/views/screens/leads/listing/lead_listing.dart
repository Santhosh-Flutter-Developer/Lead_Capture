import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/constants/src/enum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/utils/src/download_io.dart'
    if (dart.library.html) 'package:leadcapture/utils/src/download_web.dart'
    show saveFileToDownloads;
import 'package:leadcapture/views/screens/leads/listing/lead_upload.dart';
import 'package:leadcapture/views/screens/leads/listing/lead_status_graph.dart';
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
  String _selectedView = 'List';
  List<LeadStatusModel> _statuses = [];
  String? _selectedFollowUp; // employee uid
  int _resetCount = 0;
  final Map<String, String> _statusOverride = {};
  List<LeadModel> _filteredLeads = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  bool _compact = false;
  double _contentWidth = 1200;
  bool _filtersExpanded = false;
  double _filterWidth = 180;

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedStatus;
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
      _selectedCreatedBy = null;
      _selectedSource = null;
      _selectedPriority = null;
      _selectedClient = null;
      _selectedProject = null;
      _selectedConverted = null;
      _selectedFollowUp = null;
      _value = null;
      _resetCount++;
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
          _contentWidth = box.maxWidth;
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
              _statuses = state.allStatuses;
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
                      if (_selectedView == 'Graph')
                        LeadStatusGraph(
                          leads: state.leads,
                          statuses: state.allStatuses,
                          onViewLeads: (uid) {
                            setState(() {
                              _selectedFollowUp = uid;
                              _selectedView = 'List';
                              _resetCount++;
                            });
                            _applyFilters();
                          },
                        )
                      else if (controllerWatch.paginatedItems.isEmpty)
                        _buildEmptyState()
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

  // ---------------------------------------------------------------------
  // Reference-style helpers
  // ---------------------------------------------------------------------
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE2E8F0);
  static const Color _blue = Color(0xFF2563EB);

  final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.personalcard, color: _blue, size: 26),
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching leads found',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your filters or add a new lead.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // Column widths (px) for: check, id, name, email, mobile, value, source,
  // status, priority, created, follow up, created by, action.
  static const List<double> _w = [
    44, 78, 210, 190, 112, 108, 104, 136, 92, 106, 140, 160, 150,
  ];
  double get _tableWidth => _w.fold(0.0, (a, b) => a + b);

  Widget _cell(int i, Widget child, {Alignment align = Alignment.centerLeft}) {
    return SizedBox(
      width: _w[i],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: align, child: child),
      ),
    );
  }

  Widget _headCell(
    int i,
    String label,
    PaginatedDataController<LeadModel> c, {
    int? sortIndex,
  }) {
    final sorted = sortIndex != null && c.sortColumnIndex == sortIndex;
    final text = Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    );
    return _cell(
      i,
      sortIndex == null
          ? text
          : InkWell(
              onTap: () => context
                  .read<PaginatedDataController<LeadModel>>()
                  .setSort(sortIndex, sorted ? !c.sortAscending : true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  text,
                  const SizedBox(width: 3),
                  Icon(
                    sorted && !c.sortAscending
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 12,
                    color: sorted ? _blue : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    PaginatedDataController<LeadModel> controllerWatch,
    PaginatedDataController<LeadModel> controllerRead,
  ) {
    final items = controllerWatch.paginatedItems;
    final selectable = items
        .where((l) => !l.leadsConverted && (l.uid ?? '').isNotEmpty)
        .map((l) => l.uid!)
        .toList();
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every(controllerWatch.selectedIds.contains);

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > _tableWidth
                  ? constraints.maxWidth
                  : _tableWidth;
              return Scrollbar(
                controller: _hScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _hScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: _line)),
                          ),
                          child: Row(
                            children: [
                              _cell(
                                0,
                                _canDelete
                                    ? Checkbox(
                                        value: allSelected,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: selectable.isEmpty
                                            ? null
                                            : (v) => _setPageSelection(
                                                controllerRead,
                                                v ?? false,
                                              ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              _headCell(1, 'Id', controllerWatch, sortIndex: 1),
                              _headCell(2, 'Name', controllerWatch, sortIndex: 2),
                              _headCell(3, 'Email', controllerWatch, sortIndex: 3),
                              _headCell(4, 'Mobile No', controllerWatch),
                              _headCell(5, 'Lead Value', controllerWatch, sortIndex: 5),
                              _headCell(6, 'Source', controllerWatch),
                              _headCell(7, 'Status', controllerWatch),
                              _headCell(8, 'Priority', controllerWatch),
                              _headCell(9, 'Created', controllerWatch, sortIndex: 6),
                              _headCell(10, 'Follow Up', controllerWatch),
                              _headCell(11, 'Created By', controllerWatch),
                              _headCell(12, 'Action', controllerWatch),
                            ],
                          ),
                        ),
                        for (final lead in items)
                          _buildRow(context, lead, controllerWatch, controllerRead),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          _buildFooter(controllerWatch, controllerRead),
        ],
      ),
    );
  }

  Widget _buildFooter(
    PaginatedDataController<LeadModel> c,
    PaginatedDataController<LeadModel> r,
  ) {
    final style = const TextStyle(fontSize: 12, color: _muted);
    Widget pageBtn(Widget child, VoidCallback? onTap, {bool active = false}) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _blue : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: active ? _blue : _line),
            ),
            child: child,
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 16,
        children: [
          Text(
            'Showing ${c.startEntry} to ${c.endEntry} of ${c.totalEntries} entries',
            style: style,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rows:', style: style),
              const SizedBox(width: 6),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _line),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: c.rowsPerPage,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 16),
                    items: [10, 25, 50, 100]
                        .map(
                          (v) => DropdownMenuItem<int>(
                            value: v,
                            child: Text('$v', style: const TextStyle(fontSize: 12)),
                          ),
                        )
                        .toList(),
                    onChanged: r.setRowsPerPage,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              pageBtn(
                const Icon(Icons.chevron_left, size: 16, color: _muted),
                c.currentPage > 1 ? r.previousPage : null,
              ),
              const SizedBox(width: 4),
              pageBtn(
                Text(
                  '${c.currentPage}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                null,
                active: true,
              ),
              const SizedBox(width: 4),
              pageBtn(
                const Icon(Icons.chevron_right, size: 16, color: _muted),
                c.currentPage < c.totalPages ? r.nextPage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color bg, {Color fg = Colors.white, double size = 10.5}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _letterAvatar(String name, {double size = 28}) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: _blue,
        ),
      ),
    );
  }

  Widget _followUpCell(LeadModel lead) {
    final uid = lead.followUp ?? '';
    if (uid.isEmpty) {
      return const Text('—', style: TextStyle(color: _muted, fontSize: 12));
    }
    final emp = CacheService.employeeByUid(uid);
    final name = emp?.name ?? '';
    if (name.isEmpty) {
      return const Text('—', style: TextStyle(color: _muted, fontSize: 12));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          size: 22,
          showCrown: false,
          userData: UserDataModel(
            uid: uid,
            name: name,
            profilePic: emp?.profileImageUrl,
            userType: UserType.employee,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink),
          ),
        ),
      ],
    );
  }

  Widget _statusCell(LeadModel lead) {
    final override = _statusOverride[lead.uid ?? ''];
    if (override != null && override == lead.leadStatus) {
      _statusOverride.remove(lead.uid ?? '');
    }
    final effective = _statusOverride[lead.uid ?? ''] ?? lead.leadStatus;
    final current = CacheService.leadStatusByUid(effective);
    final color = Color(current?.color ?? 0xFF64748B);
    if (lead.leadsConverted) {
      return _chip(
        '✓ Converted',
        const Color(0xFFDCFCE7),
        fg: const Color(0xFF15803D),
      );
    }
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            current?.name ?? '—',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          Icon(Icons.arrow_drop_down, size: 16, color: color),
        ],
      ),
    );
    if (!_canEdit || _statuses.isEmpty) return pill;
    return PopupMenuButton<LeadStatusModel>(
      tooltip: 'Change status',
      padding: EdgeInsets.zero,
      onSelected: (s) => _changeStatus(lead, s),
      itemBuilder: (_) => [
        for (final s in _statuses)
          if (s.uid != effective)
            PopupMenuItem<LeadStatusModel>(
              value: s,
              height: 34,
              child: Text(s.name, style: const TextStyle(fontSize: 12)),
            ),
      ],
      child: pill,
    );
  }

  Future<void> _changeStatus(LeadModel lead, LeadStatusModel s) async {
    final leadUid = lead.uid ?? '';
    final statusUid = s.uid ?? '';
    if (leadUid.isEmpty || statusUid.isEmpty) return;
    // Optimistic: show the new status immediately.
    setState(() => _statusOverride[leadUid] = statusUid);
    try {
      await LeadService.updateLeadStatus(uid: leadUid, leadStatus: statusUid);
      if (!mounted) return;
      FlushBar.show(context, 'Status updated to ${s.name}');
      context.read<LeadBloc>().add(StreamLead());
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusOverride.remove(leadUid));
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Widget _iconAction(
    IconData icon,
    Color color,
    String tip,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  Future<void> _openLead(LeadModel lead) async {
    final result = (kIsMobile || _compact)
        ? await Sheet.showSheet(context, widget: LeadsViewPage(lead: lead))
        : await GeneralDialog.showRTLSheet(context, LeadsViewPage(lead: lead));
    if (result == 'deleted' && mounted) {
      context.read<LeadBloc>().add(StreamLead());
      showLeadDeletedUndo(
        context,
        lead,
        () => context.read<LeadBloc>().add(StreamLead()),
      );
    }
  }

  Future<void> _openDeal(LeadModel lead) async {
    try {
      futureLoading(context);
      String? dealUid = (lead.dealId ?? '').isNotEmpty ? lead.dealId : null;
      if (dealUid != null) {
        try {
          await DealService.getDeal(uid: dealUid);
        } catch (_) {
          dealUid = null;
        }
      }
      if (dealUid == null) {
        // dealId is not always part of the list payload: look the deal up by
        // the lead it was created from.
        final deals = await DealService.getAllDeals();
        dealUid = deals
            .firstWhereOrNull((d) => d.leadId == lead.uid)
            ?.uid;
      }
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (!mounted) return;
      if (dealUid == null) {
        FlushBar.show(context, 'Deal not found', isSuccess: false);
        return;
      }
      final page = DealsListing(showAppBar: true, focusDealUid: dealUid);
      if (kIsMobile || _compact) {
        await Sheet.showSheet(context, widget: page);
      } else {
        await GeneralDialog.showRTLSheet(context, page);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Widget _buildRow(
    BuildContext context,
    LeadModel lead,
    PaginatedDataController<LeadModel> controllerWatch,
    PaginatedDataController<LeadModel> controllerRead,
  ) {
    final selected = controllerWatch.selectedIds.contains(lead.uid);
    final priority = CacheService.leadPriorityByUid(lead.leadPriority);
    final company = (lead.companyName ?? '').trim();
    final mobile = (lead.clientMobile ?? '').isNotEmpty
        ? lead.clientMobile!
        : (lead.companyMobile ?? '');
    const dash = Text('—', style: TextStyle(color: _muted, fontSize: 12));
    const small = TextStyle(fontSize: 12, color: _ink);

    return InkWell(
      onTap: () => _openLead(lead),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: selected ? _blue.withValues(alpha: 0.05) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            _cell(
              0,
              _canDelete && !lead.leadsConverted
                  ? Checkbox(
                      value: selected,
                      visualDensity: VisualDensity.compact,
                      onChanged: (v) =>
                          controllerRead.onSelected(lead.uid ?? '', v),
                    )
                  : const SizedBox.shrink(),
            ),
            _cell(
              1,
              _chip(
                '#${lead.leadNumber ?? '—'}',
                const Color(0xFFF1F5F9),
                fg: _muted,
                size: 10,
              ),
            ),
            _cell(
              2,
              Row(
                children: [
                  _letterAvatar(lead.leadName),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.leadName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        if (company.isNotEmpty)
                          Text(
                            company,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, color: _muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _cell(
              3,
              lead.leadEmail.trim().isEmpty
                  ? dash
                  : Text(
                      lead.leadEmail,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: _muted),
                    ),
            ),
            _cell(4, mobile.isEmpty ? dash : Text(mobile, style: small)),
            _cell(
              5,
              Text(
                _money.format(lead.leadValue),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            _cell(
              6,
              lead.leadSource.name.isEmpty
                  ? dash
                  : _chip(
                      lead.leadSource.name,
                      const Color(0xFFF1F5F9),
                      fg: _muted,
                      size: 10,
                    ),
            ),
            _cell(7, _statusCell(lead)),
            _cell(
              8,
              priority == null
                  ? dash
                  : _chip(priority.name, Color(priority.color)),
            ),
            _cell(
              9,
              Text(DateFormat('dd MMM yyyy').format(lead.createdAt), style: small),
            ),
            _cell(10, _followUpCell(lead)),
            _cell(
              11,
              Row(
                children: [
                  UserAvatar(userData: lead.createdBy, size: 22, showCrown: false),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      lead.createdBy.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _cell(12, _rowActions(lead)),
          ],
        ),
      ),
    );
  }

  Widget _rowActions(LeadModel lead) {
    return Row(
      children: [
        // Role based: View (eye) only for users with View permission.
        if (permissions?.canView ?? false)
          _iconAction(Iconsax.eye, _blue, 'View', () => _openLead(lead)),
        if (lead.leadsConverted)
          InkWell(
            onTap: () => _openDeal(lead),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF16A34A)),
              ),
              child: const Text(
                'View Deal',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          )
        else ...[
          if (_canEdit)
            _iconAction(Iconsax.edit, _blue, 'Edit', () async {
              final result = (kIsMobile || _compact)
                  ? await Sheet.showSheet(
                      context,
                      widget: LeadEdit(uid: lead.uid ?? ''),
                    )
                  : await GeneralDialog.showRTLSheet(
                      context,
                      LeadEdit(uid: lead.uid ?? ''),
                    );
              if (result == true && mounted) await _refreshLeads(context);
            }),
          if (_canEdit)
            _iconAction(
              Icons.autorenew_rounded,
              const Color(0xFF16A34A),
              'Convert to Deal',
              () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ConfirmDialog(
                    title: 'Convert $_pageTitle',
                    content:
                        'Are you sure you want to convert this lead to a deal?',
                  ),
                );
                if (ok == true && mounted) {
                  await _convertLeadToDeal(context, lead);
                }
              },
            ),
          if (_canDelete)
            _iconAction(
              Iconsax.trash,
              const Color(0xFFDC2626),
              'Delete',
              () async {
                final deleted = await confirmAndDeleteLead(context, lead);
                if (deleted && mounted) {
                  context.read<LeadBloc>().add(StreamLead());
                  showLeadDeletedUndo(
                    context,
                    lead,
                    () => context.read<LeadBloc>().add(StreamLead()),
                  );
                }
              },
            ),
        ],
      ],
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

  // ---------------------------------------------------------------------
  // Filters (reference layout: labelled grid, "All ..." placeholders)
  // ---------------------------------------------------------------------
  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: _ink,
      ),
    ),
  );

  Widget _field({required String label, required Widget child}) {
    return SizedBox(
      width: _filterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_label(label), child],
      ),
    );
  }

  InputDecoration _boxDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _blue, width: 1.2),
      ),
    );
  }

  Widget _selectFilter({
    required String label,
    required String allLabel,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return _field(
      label: label,
      child: CustomSearchableDropdown<String>(
        key: ValueKey('$label-$_resetCount'),
        items: items,
        initialValue: value,
        hintText: allLabel,
        height: 36,
        onChanged: onChanged,
      ),
    );
  }

  String _fmtDate(DateTime? d) => d == null
      ? 'dd-mm-yyyy'
      : '${d.day.toString().padLeft(2, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-${d.year}';

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> set) {
    return _field(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDate: value ?? DateTime.now(),
          );
          if (picked != null) {
            set(picked);
            _applyFilters();
          }
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _fmtDate(value),
                  style: TextStyle(
                    fontSize: 12,
                    color: value == null ? _muted : _ink,
                  ),
                ),
              ),
              const Icon(Iconsax.calendar_1, size: 15, color: _muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    final w = MediaQuery.of(context).size.width;
    if (_compact) {
      final available = w - 28 - 32;
      final cols = available >= 2 * 170 + 10 ? 2 : 1;
      _filterWidth = (available - (cols - 1) * 10) / cols;
    } else {
      // Sidebar + page padding are already excluded by LayoutBuilder in
      // build(); 6 columns like the reference.
      final inner = (_contentWidth - 48 - 32).clamp(600.0, 4000.0);
      _filterWidth = (inner - 5 * 14) / 6;
    }

    if (!Hive.isBoxOpen('leadStatus') || !Hive.isBoxOpen('employees')) {
      return _buildSearchField(onSearchChanged);
    }

    final statusBox = Hive.box<Map<dynamic, dynamic>>('leadStatus');
    final cache = CacheService();
    final employees = cache.getAllListenableEmployees().value;
    final statusName = _selectedStatus == null || _selectedStatus!.isEmpty
        ? null
        : CacheService.leadStatusByUid(_selectedStatus!)?.name;
    final createdByName = employees
        .firstWhereOrNull((e) => e.uid == _selectedCreatedBy)
        ?.name;
    final followUpName = employees
        .firstWhereOrNull((e) => e.uid == _selectedFollowUp)
        ?.name;

    final filters = <Widget>[
      _dateField('From Date', _fromDate, (d) => setState(() => _fromDate = d)),
      _dateField('To Date', _toDate, (d) => setState(() => _toDate = d)),
      _selectFilter(
        label: 'Status',
        allLabel: 'All Status',
        value: statusName,
        items: statusItems(statusBox),
        onChanged: (v) {
          final key = v == null
              ? null
              : statusBox.keys.firstWhere(
                  (k) =>
                      LeadStatusModel.fromMap(
                        k,
                        Map<String, dynamic>.from(statusBox.get(k) ?? {}),
                      ).name ==
                      v,
                  orElse: () => '',
                );
          setState(
            () => _selectedStatus = (key == null || key == '')
                ? null
                : key.toString(),
          );
          _applyFilters();
        },
      ),
      _selectFilter(
        label: 'Priority',
        allLabel: 'All Prioritys',
        value: _selectedPriority,
        items: _distinct([..._priorityOptions, ..._allLeads.map(_priorityName)]),
        onChanged: (v) {
          setState(() => _selectedPriority = v);
          _applyFilters();
        },
      ),
      _selectFilter(
        label: 'Source',
        allLabel: 'All Sources',
        value: _selectedSource,
        items: _distinct([
          ..._sourceOptions,
          ..._allLeads.map((l) => l.leadSource.name),
        ]),
        onChanged: (v) {
          setState(() => _selectedSource = v);
          _applyFilters();
        },
      ),
      _selectFilter(
        label: 'Master Client',
        allLabel: 'All Clients',
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
      _selectFilter(
        label: 'Created By',
        allLabel: 'All Creators',
        value: createdByName,
        items: employeeItems(cache),
        onChanged: (v) {
          setState(
            () => _selectedCreatedBy = v == null
                ? null
                : employees.firstWhereOrNull((e) => e.name == v)?.uid,
          );
          _applyFilters();
        },
      ),
      _selectFilter(
        label: 'Follow Up',
        allLabel: 'All Follow Ups',
        value: followUpName,
        items: employeeItems(cache),
        onChanged: (v) {
          setState(
            () => _selectedFollowUp = v == null
                ? null
                : employees.firstWhereOrNull((e) => e.name == v)?.uid,
          );
          _applyFilters();
        },
      ),
      _selectFilter(
        label: 'Project Name',
        allLabel: 'All Projects',
        value: _selectedProject,
        items: _distinct(
          _allLeads.map((l) => (l.projectName ?? '').trim()),
        ).where((e) => e.isNotEmpty).toList(),
        onChanged: (v) {
          setState(() => _selectedProject = v);
          _applyFilters();
        },
      ),
      _selectFilter(
        label: 'Conversion',
        allLabel: 'All Leads',
        value: _selectedConverted,
        items: const ['Converted', 'Not Converted'],
        onChanged: (v) {
          setState(() => _selectedConverted = v);
          _applyFilters();
        },
      ),
      _field(
        label: 'Exact Value (₹)',
        child: SizedBox(
          height: 36,
          child: TextField(
            key: ValueKey('value-$_resetCount'),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: _boxDecoration('e.g. 50000'),
            onChanged: _onValueChanged,
          ),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          borderRadius: BorderRadius.circular(10),
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
                SizedBox(width: 250, child: _buildSearchField(onSearchChanged)),
                const Spacer(),
                _buildResetButton(),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 12, children: filters),
          ],
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: _resetFilters,
        icon: const Icon(Icons.refresh, size: 15),
        label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          backgroundColor: const Color(0xFFFEF2F2),
          side: const BorderSide(color: Color(0xFFFECACA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildSearchField(ValueChanged<String> onSearchChanged) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 12.5),
        onChanged: (value) {
          setState(() {});
          onSearchChanged(value);
          _applyFilters();
        },
        decoration: _boxDecoration(
          'Search leads...',
          suffix: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    onSearchChanged('');
                    _applyFilters();
                  },
                )
              : null,
        ).copyWith(
          prefixIcon: const Icon(Iconsax.search_normal_1, size: 15, color: _muted),
        ),
      ),
    );
  }

  void _onValueChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\s,]'), '');
    _value = cleaned.isEmpty ? null : double.tryParse(cleaned);
    _applyFilters();
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
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      filtered = filtered.where((e) => !e.createdAt.isAfter(end)).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((e) => e.leadStatus == _selectedStatus)
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

    if (_selectedFollowUp != null) {
      filtered = filtered.where((e) => e.followUp == _selectedFollowUp).toList();
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
              child: const Text('Select all'),
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

  // ---------------------------------------------------------------------
  // Action row (reference: Add Lead | Upload | Template | Export | Status
  // Graph ........ refresh | List | Board | Calendar | Graph)
  // ---------------------------------------------------------------------
  Widget _toolButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool primary = false,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    if (primary) {
      return SizedBox(
        height: 34,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12.5)),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: shape,
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
        ),
      );
    }
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        style: OutlinedButton.styleFrom(
          shape: shape,
          foregroundColor: _ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: _line),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final buttons = <Widget>[];
    void gap() => buttons.add(const SizedBox(width: 8));

    if (permissions?.canCreate ?? false) {
      buttons.add(
        _toolButton(
          label: 'Add Lead',
          icon: Icons.add,
          primary: true,
          onPressed: () async {
            final result = (kIsMobile || _compact)
                ? await Sheet.showSheet(context, widget: const LeadCreate())
                : await GeneralDialog.showRTLSheet(context, const LeadCreate());
            if (result == true && context.mounted) {
              context.read<LeadBloc>().add(StreamLead());
            }
          },
        ),
      );
    }

    if (permissions?.canImport ?? false) {
      gap();
      buttons.add(
        _toolButton(
          label: 'Upload',
          icon: Iconsax.cloud_plus,
          onPressed: () {
            if (kIsMobile || _compact) {
              Sheet.showSheet(context, widget: const LeadUpload());
            } else {
              GeneralDialog.showRTLSheet(context, const LeadUpload());
            }
          },
        ),
      );
      gap();
      buttons.add(
        PopupMenuButton<String>(
          tooltip: 'Templates',
          offset: const Offset(0, 38),
          onSelected: (v) async {
            if (v == 'template') {
              await Download.downloadFromAsset(
                context,
                'assets/templates/lead_upload_template.xlsx',
                'Lead_Template.xlsx',
              );
            } else {
              await Download.downloadFromAsset(
                context,
                'assets/templates/lead_upload_template_with_data.xlsx',
                'Lead_Sample_Data.xlsx',
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'template', child: Text('Lead Template')),
            PopupMenuItem(value: 'sample', child: Text('Sample Data')),
          ],
          child: IgnorePointer(
            child: _toolButton(
              label: 'Template ▾',
              icon: Icons.file_download_outlined,
              onPressed: () {},
            ),
          ),
        ),
      );
    }

    if ((permissions?.canExport ?? false) && _filteredLeads.isNotEmpty) {
      gap();
      buttons.add(
        _toolButton(
          label: 'Export',
          icon: Iconsax.export_3,
          onPressed: _exportLeads,
        ),
      );
    }

    final viewToggle = Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _refreshLeads(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Iconsax.refresh, size: 15, color: _muted),
            ),
          ),
          _buildToggleIcon(Icons.list, 'List', 'List'),
          _buildToggleIcon(Iconsax.grid_3, 'Grid', 'Board'),
          _buildToggleIcon(Iconsax.calendar_1, 'Calendar', 'Calendar'),
          _buildToggleIcon(Iconsax.chart_2, 'Graph', 'Graph'),
        ],
      ),
    );

    if (_compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: buttons),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: viewToggle,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: buttons),
          ),
        ),
        const SizedBox(width: 12),
        viewToggle,
      ],
    );
  }

  Widget _buildToggleIcon(IconData icon, String viewName, String label) {
    final selected = _selectedView == viewName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (viewName != 'List') {
          context.read<PaginatedDataController<LeadModel>>().clearSelection();
        }
        setState(() => _selectedView = viewName);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? _blue : _muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? _blue : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLeads() async {
    try {
      final priorities = await LeadPriorityService.getAllLeadPriority();
      final statuses = await LeadStatusService.getAllLeadStatus();

      final exportData = <List<String>>[
        [
          'Lead Name',
          'Email',
          'Source',
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
        ],
      ];

      for (final lead in _filteredLeads) {
        final priority = priorities.firstWhereOrNull(
          (p) => p.uid == lead.leadPriority,
        );
        final status = statuses.firstWhereOrNull(
          (s) => s.uid == lead.leadStatus,
        );
        exportData.add([
          lead.leadName,
          lead.leadEmail,
          lead.leadSource.name,
          priority?.name ?? lead.leadPriority,
          lead.leadValue.toString(),
          status?.name ?? lead.leadStatus,
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

      final fileBytes = await XlsxWriter().create(exportData);
      final filePath = await saveFileToDownloads(
        fileBytes,
        fileName: 'Leads_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      if (!kIsWeb && mounted) openfile(filePath, context);
      if (mounted) {
        FlushBar.show(context, 'Leads exported successfully', isSuccess: true);
      }
    } catch (e) {
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
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