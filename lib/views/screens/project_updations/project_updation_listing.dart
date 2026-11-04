import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import 'project_updation_calendar.dart';
import 'project_updation_form.dart';
import 'project_updation_kanban.dart';

/// Same layout rules as the Leads page: the available content width decides
/// between the wide and compact layouts.
const double _wideBreakpoint = 760;
const List<Color> _brandGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];
const String _pageTitle = 'Project Updation';

Color _statusColor(UpdationStatus s) => updationStatusColor(s);

/// Copyable ID: "UPD-0001 [copy]". The tap target is 40px for mobile.
class CopyableId extends StatelessWidget {
  final String id;
  const CopyableId({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          id,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          tooltip: 'Copy ID',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Iconsax.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: id));
            if (context.mounted) FlushBar.show(context, 'Copied!');
          },
        ),
      ],
    );
  }
}

/// Project Updation list. Same UI as the Leads page: banner, filter card,
/// action row with Board / List / Calendar toggle, selectable table.
class ProjectUpdationListing extends StatefulWidget {
  final bool showAppBar;
  const ProjectUpdationListing({super.key, this.showAppBar = true});

  @override
  State<ProjectUpdationListing> createState() => _ProjectUpdationListingState();
}

class _ProjectUpdationListingState extends State<ProjectUpdationListing> {
  late final PaginatedDataController<ProjectUpdationModel> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final _dateFmt = DateFormat('dd MMM yyyy');

  List<ProjectUpdationModel> _all = [];
  List<ProjectUpdationModel> _filtered = [];
  PermissionModel? _permissions;
  bool _loading = true;
  String? _error;

  String _selectedView = 'Grid';
  bool _compact = false;
  bool _filtersExpanded = false;
  double _filterWidth = 180;

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _status; // UpdationStatus label
  String? _client; // company label
  String? _project; // project name
  String? _createdBy; // user name
  double? _value;

  bool get _canEdit => _permissions?.canEdit ?? false;
  bool get _canDelete => _permissions?.canDelete ?? false;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<ProjectUpdationModel>(
      initialSortColumnIndex: 0,
      filterLogic: (u, query) => _matchesSearch(u, query),
      sortLogic: (a, b, col, asc) {
        int compare;
        switch (col) {
          case 0:
            compare = (a.updationNumber ?? 0).compareTo(b.updationNumber ?? 0);
            break;
          case 1:
            compare = a.projectName.toLowerCase().compareTo(
              b.projectName.toLowerCase(),
            );
            break;
          case 2:
            compare = a.title.toLowerCase().compareTo(b.title.toLowerCase());
            break;
          case 3:
            compare = (a.companyName ?? '').toLowerCase().compareTo(
              (b.companyName ?? '').toLowerCase(),
            );
            break;
          case 4:
            compare = (a.value ?? 0).compareTo(b.value ?? 0);
            break;
          case 6:
            compare = a.requestedDate.compareTo(b.requestedDate);
            break;
          default:
            compare = (a.uid ?? '').compareTo(b.uid ?? '');
        }
        return asc ? compare : -compare;
      },
      getItemId: (u) => u.uid ?? '',
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Refresh button: show the loader, then re-read permissions and data
  /// (filters stay applied), like the Leads page.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _load() async {
    try {
      _permissions = await PermissionService.getPermissions(_pageTitle);
      final list = await ProjectUpdationService.getAllUpdations();
      if (!mounted) return;
      _all = list;
      _loading = false;
      _error = null;
      _applyFilters();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// ID search works with or without prefix: "UPD-0007", "upd7" or "7".
  bool _matchesSearch(ProjectUpdationModel u, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return true;
    final digits = query.replaceAll(RegExp(r'^upd-?'), '');
    final n = int.tryParse(digits);
    if (n != null && u.updationNumber == n) return true;
    return u.updationCode.toLowerCase().contains(query) ||
        u.projectName.toLowerCase().contains(query) ||
        u.title.toLowerCase().contains(query) ||
        (u.companyName ?? '').toLowerCase().contains(query) ||
        (u.contactName ?? '').toLowerCase().contains(query) ||
        (u.contactMobile ?? '').toLowerCase().contains(query);
  }

  void _applyFilters() {
    var list = _all.where((u) {
      if (!_matchesSearch(u, _searchController.text)) return false;
      if (_status != null && u.status.label != _status) return false;
      if (_client != null && (u.companyName ?? '') != _client) return false;
      if (_project != null && u.projectName != _project) return false;
      if (_createdBy != null && u.createdBy.name != _createdBy) return false;
      if (_value != null && (u.value ?? 0) != _value) return false;
      if (_fromDate != null) {
        final d = DateTime(
          u.requestedDate.year,
          u.requestedDate.month,
          u.requestedDate.day,
        );
        if (d.isBefore(_fromDate!)) return false;
      }
      if (_toDate != null) {
        final d = DateTime(
          u.requestedDate.year,
          u.requestedDate.month,
          u.requestedDate.day,
        );
        if (d.isAfter(_toDate!)) return false;
      }
      return true;
    }).toList();
    setState(() => _filtered = list);
    _controller.retainSelection(
      list.map((u) => u.uid ?? '').where((id) => id.isNotEmpty).toSet(),
    );
    // The search box is applied here, so the controller gets no extra query.
    _controller.setData(list);
  }

  void _resetFilters() {
    _searchController.clear();
    _fromDate = null;
    _toDate = null;
    _status = null;
    _client = null;
    _project = null;
    _createdBy = null;
    _value = null;
    _applyFilters();
  }

  // ---------------------------------------------------------------- actions
  Future<void> _openForm({String? uid}) async {
    final form = ProjectUpdationForm(uid: uid);
    final result = (kIsMobile || _compact)
        ? await Sheet.showSheet(context, widget: form)
        : await GeneralDialog.showRTLSheet(context, form);
    if (result == true) await _load();
  }

  Future<bool> _confirm(String title, String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(title: title, content: content),
    );
    return ok == true;
  }

  Future<void> _delete(ProjectUpdationModel u) async {
    if (!await _confirm(
      'Delete $_pageTitle',
      'Are you sure you want to delete ${u.updationCode}?',
    )) {
      return;
    }
    try {
      final copy = u.copyWith();
      await ProjectUpdationService.deleteUpdation(uid: u.uid ?? '');
      await _load();
      if (!mounted) return;
      FlushBar.show(
        context,
        'Project updation deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await ProjectUpdationService.restoreUpdation(copy);
          await _load();
        },
      );
    } catch (e) {
      if (mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }

  List<ProjectUpdationModel> _selectedModels() =>
      _filtered.where((u) => _controller.selectedIds.contains(u.uid)).toList();

  Future<void> _bulkDelete() async {
    final chosen = _selectedModels();
    if (chosen.isEmpty) return;
    if (!await _confirm(
      'Delete $_pageTitle',
      'Are you sure you want to delete ${chosen.length} project updations?',
    )) {
      return;
    }
    final deleted = <ProjectUpdationModel>[];
    try {
      for (final u in chosen) {
        await ProjectUpdationService.deleteUpdation(uid: u.uid ?? '');
        deleted.add(u.copyWith());
      }
    } catch (e) {
      if (mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
    _controller.deselectAll(deleted.map((u) => u.uid ?? ''));
    await _load();
    if (!mounted || deleted.isEmpty) return;
    FlushBar.show(
      context,
      '${deleted.length} project updations deleted',
      actionLabel: 'UNDO',
      onActionPressed: () async {
        for (final u in deleted) {
          await ProjectUpdationService.restoreUpdation(u);
        }
        await _load();
      },
    );
  }

  /// Board drag: persist the new status. Throws so the board can revert.
  Future<void> _changeStatus(
    ProjectUpdationModel u,
    UpdationStatus status,
  ) async {
    if (u.status == status) return;
    await ProjectUpdationService.updateStatus(uid: u.uid ?? '', status: status);
    final idx = _all.indexWhere((x) => x.uid == u.uid);
    if (idx != -1) _all[idx] = _all[idx].copyWith(status: status);
    if (mounted) _applyFilters();
  }

  void _openItem(ProjectUpdationModel u) {
    if (_canEdit) _openForm(uid: u.uid);
  }

  Future<void> _export() async {
    try {
      final rows = <List<String>>[
        [
          'Updation ID',
          'Company',
          'Contact Name',
          'Contact Mobile',
          'Project',
          'Title',
          'Description',
          'Requested Date',
          'Status',
          'Value',
          'Note',
          'Created By',
        ],
        for (final u in _filtered)
          [
            u.updationCode,
            u.companyName ?? '',
            u.contactName ?? '',
            u.contactMobile ?? '',
            u.projectName,
            u.title,
            u.description,
            _dateFmt.format(u.requestedDate),
            u.status.label,
            u.value?.toStringAsFixed(2) ?? '',
            u.notes,
            u.createdBy.name,
          ],
      ];
      final bytes = await XlsxWriter().create(rows);
      final path = await saveFileToDownloads(
        bytes,
        fileName:
            'Project_Updations_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      if (!kIsWeb && mounted) openfile(path, context);
      if (mounted) {
        FlushBar.show(
          context,
          'Project updations exported successfully',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PaginatedDataController<ProjectUpdationModel>>.value(
      value: _controller,
      child: Scaffold(
        appBar: widget.showAppBar &&
                (kIsMobile || MediaQuery.of(context).size.width < 1000)
            ? AppBar(
                leading: const Back(),
                title: const Text(_pageTitle),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
              )
            : null,
        body: LayoutBuilder(
          builder: (context, box) {
            _compact = box.maxWidth < _wideBreakpoint;
            return _buildBody(context);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const WaitingLoading();
    if (_error != null) {
      return Center(
        child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    if (!(_permissions?.canView ?? false)) return buildNoPermissionView(context);

    final controller = context
        .watch<PaginatedDataController<ProjectUpdationModel>>();
    return RefreshIndicator(
      onRefresh: _load,
      child: Scrollbar(
        controller: _vScroll,
        thumbVisibility: true,
        interactive: true,
        trackVisibility: true,
        radius: const Radius.circular(8),
        thickness: 8,
        child: ListView(
          controller: _vScroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(_compact ? 14.0 : 24.0),
          children: [
            if (!_compact) ...[
              _buildHeaderBanner(_all.length),
              const SizedBox(height: 18),
            ],
            _buildFilterRow(),
            const SizedBox(height: 12),
            _buildActionRow(),
            if (_selectedView == 'List' &&
                _canDelete &&
                controller.selectedIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSelectionBar(controller),
            ],
            const SizedBox(height: 18),
            if (controller.paginatedItems.isEmpty)
              NoData(
                text: _all.isEmpty
                    ? 'No project updations available'
                    : 'No matching records found',
              )
            else if (_selectedView == 'Grid')
              ProjectUpdationKanban(
                items: _filtered,
                canEdit: _canEdit,
                canCreate: _permissions?.canCreate ?? false,
                onMove: _changeStatus,
                onOpen: _openItem,
                onCreate: () => _openForm(),
              )
            else if (_selectedView == 'Calendar')
              ProjectUpdationCalendar(
                items: _filtered,
                canCreate: _permissions?.canCreate ?? false,
                canEdit: _canEdit,
                onCreate: () => _openForm(),
                onOpen: _openItem,
              )
            else
              _buildListView(controller),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- banner
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
              Iconsax.refresh_circle,
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
                  'Project Updation',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track every change requested on your completed projects',
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
                  total == 1 ? 'Updation' : 'Updations',
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

  // ---------------------------------------------------------------- filters
  Widget _buildFilterRow() {
    if (_compact) {
      final available = MediaQuery.of(context).size.width - 28 - 32;
      final cols = available >= 2 * 170 + 10 ? 2 : 1;
      _filterWidth = (available - (cols - 1) * 10) / cols;
    } else {
      _filterWidth = 180;
    }

    List<String> distinct(Iterable<String> v) =>
        v.where((e) => e.trim().isNotEmpty).toSet().toList()..sort();

    Future<void> pick(bool isFrom) async {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      );
      if (picked == null) return;
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      _applyFilters();
    }

    final filters = [
      _dateFilter(
        label: 'From Date',
        value: _fromDate,
        onTap: () => pick(true),
      ),
      _dateFilter(label: 'To Date', value: _toDate, onTap: () => pick(false)),
      _filterDropdown(
        label: 'Status',
        value: _status,
        items: UpdationStatus.values.map((s) => s.label).toList(),
        onChanged: (v) {
          _status = v;
          _applyFilters();
        },
      ),
      _filterDropdown(
        label: 'Master Client',
        value: _client,
        items: distinct(_all.map((u) => u.companyName ?? '')),
        onChanged: (v) {
          _client = v;
          _applyFilters();
        },
      ),
      _filterDropdown(
        label: 'Project',
        value: _project,
        items: distinct(_all.map((u) => u.projectName)),
        onChanged: (v) {
          _project = v;
          _applyFilters();
        },
      ),
      _filterDropdown(
        label: 'Created By',
        value: _createdBy,
        items: distinct(_all.map((u) => u.createdBy.name)),
        onChanged: (v) {
          _createdBy = v;
          _applyFilters();
        },
      ),
      _valueFilter(),
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
          if (_compact) ...[
            _buildSearchField(),
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
                SizedBox(width: 280, child: _buildSearchField()),
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
                    for (final f in filters) ...[f, const SizedBox(width: 10)],
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
        label: const Text('Reset Filters'),
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

  Widget _buildSearchField() {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _applyFilters(),
        decoration: InputDecoration(
          hintText: 'Search ID, project, client...',
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
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: scheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: border(scheme.outlineVariant),
          enabledBorder: border(scheme.outlineVariant),
          focusedBorder: border(scheme.primary, 1.3),
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _valueFilter() {
    return SizedBox(
      width: _filterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updation Value',
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
            child: TextField(
              keyboardType: TextInputType.number,
              onChanged: (v) {
                _value = double.tryParse(v.replaceAll(' ', ''));
                _applyFilters();
              },
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
    );
  }

  Widget _dateFilter({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _filterWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
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
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.calendar_1,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value == null
                          ? 'Select $label'
                          : '${value.day.toString().padLeft(2, '0')}/'
                                '${value.month.toString().padLeft(2, '0')}/'
                                '${value.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: scheme.onSurface, size: 18),
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
  }) {
    return SizedBox(
      width: _filterWidth,
      child: FormDropdownSearch(
        key: ValueKey('$label-$value-${items.length}'),
        label: label,
        items: items,
        initialItem: value,
        onChanged: (dynamic val) => onChanged(val as String?),
      ),
    );
  }

  // ------------------------------------------------------------ action row
  Widget _buildActionRow() {
    final scheme = Theme.of(context).colorScheme;
    final buttons = <Widget>[
      if (_permissions?.canCreate ?? false)
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add $_pageTitle'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: const Color(0xFF4364F7),
            foregroundColor: Colors.white,
          ),
        ),
      if ((_permissions?.canExport ?? false) && _filtered.isNotEmpty) ...[
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _export,
          icon: const Icon(Iconsax.export_3, size: 18),
          label: const Text('Export'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurfaceVariant,
          ),
        ),
      ],
    ];

    final viewToggle = Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: _compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (!_compact)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Iconsax.refresh),
              iconSize: 18,
              onPressed: _refresh,
            ),
          _toggle(Iconsax.grid_3, 'Grid', 'Board'),
          _toggle(Icons.list, 'List', 'List'),
          _toggle(Iconsax.calendar_1, 'Calendar', 'Calendar'),
        ],
      ),
    );

    if (_compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: buttons),
          ),
          const SizedBox(height: 12),
          viewToggle,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
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

  Widget _toggle(IconData icon, String viewName, String label) {
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
        if (viewName != 'List') _controller.clearSelection();
        setState(() => _selectedView = viewName);
      },
      child: child,
    );
    return _compact ? Expanded(child: tap) : tap;
  }

  Widget _buildSelectionBar(
    PaginatedDataController<ProjectUpdationModel> controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final count = _selectedModels().length;
    final total = _filtered.length;
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
            '$count of $total selected',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          if (count < total)
            TextButton(
              onPressed: () =>
                  controller.selectAll(_filtered.map((u) => u.uid ?? '')),
              child: Text('Select all $total'),
            ),
          TextButton(
            onPressed: controller.clearSelection,
            child: const Text('Clear'),
          ),
          ElevatedButton.icon(
            onPressed: count == 0 ? null : _bulkDelete,
            icon: const Icon(Iconsax.trash, size: 18),
            label: Text('Delete ($count)'),
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

  // -------------------------------------------------------------- list view
  DataColumn _col(String label, {bool sortable = false}) {
    final style = Theme.of(context).textTheme.bodySmall;
    return DataColumn(
      label: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: style),
            if (sortable) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_upward,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
      onSort: sortable ? _controller.setSort : null,
    );
  }

  Widget _buildListView(
    PaginatedDataController<ProjectUpdationModel> controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
              controller: _hScroll,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 4,
              radius: const Radius.circular(6),
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: _canDelete,
                    onSelectAll: _canDelete
                        ? (sel) {
                            final ids = controller.paginatedItems
                                .map((u) => u.uid ?? '')
                                .where((id) => id.isNotEmpty);
                            (sel ?? false)
                                ? controller.selectAll(ids)
                                : controller.deselectAll(ids);
                          }
                        : null,
                    columnSpacing: 12,
                    horizontalMargin: 8,
                    sortColumnIndex: controller.sortColumnIndex,
                    sortAscending: controller.sortAscending,
                    headingRowColor: WidgetStateProperty.all(
                      scheme.primary.withValues(alpha: 0.06),
                    ),
                    headingTextStyle: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                    columns: [
                      _col('Id', sortable: true),
                      _col('Project', sortable: true),
                      _col('Title', sortable: true),
                      _col('Company', sortable: true),
                      _col('Value', sortable: true),
                      _col('Status'),
                      _col('Requested', sortable: true),
                      _col('Created By'),
                      _col('Action'),
                    ],
                    rows: controller.paginatedItems
                        .map((u) => _buildDataRow(u, controller))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<ProjectUpdationModel>(),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(UpdationStatus s) {
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  DataRow _buildDataRow(
    ProjectUpdationModel u,
    PaginatedDataController<ProjectUpdationModel> controller,
  ) {
    final style = Theme.of(context).textTheme.bodySmall;
    DataCell cell(Widget child) => DataCell(
      InkWell(
        onTap: _canEdit ? () => _openForm(uid: u.uid) : null,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child),
      ),
    );

    return DataRow(
      selected: controller.selectedIds.contains(u.uid),
      onSelectChanged: _canDelete
          ? (sel) => controller.onSelected(u.uid ?? '', sel)
          : null,
      cells: [
        DataCell(CopyableId(id: u.updationCode)),
        cell(
          Text(
            u.projectName,
            style: style?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        cell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(u.title, style: style, overflow: TextOverflow.ellipsis),
          ),
        ),
        cell(Text(u.companyName ?? '-', style: style)),
        cell(Text(u.value?.toStringAsFixed(2) ?? '-', style: style)),
        cell(_statusPill(u.status)),
        cell(Text(_dateFmt.format(u.requestedDate), style: style)),
        cell(CreatedByWidget(userData: u.createdBy)),
        DataCell(
          Row(
            children: [
              if (_canEdit)
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  tooltip: 'Edit $_pageTitle',
                  color: Theme.of(context).colorScheme.primary,
                  splashRadius: 20,
                  onPressed: () => _openForm(uid: u.uid),
                ),
              if (_canDelete)
                IconButton(
                  icon: const Icon(Iconsax.trash),
                  tooltip: 'Delete $_pageTitle',
                  color: Theme.of(context).colorScheme.error,
                  splashRadius: 20,
                  onPressed: () => _delete(u),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full updation history of one project, with total count and total value.
/// Drop this into a project detail screen / sheet.
class ProjectUpdationHistory extends StatelessWidget {
  final String projectId;
  const ProjectUpdationHistory({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return FutureBuilder<List<ProjectUpdationModel>>(
      future: ProjectUpdationService.getAllUpdations(projectId: projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snap.data ?? [];
        final total = list.fold<double>(0, (s, u) => s + (u.value ?? 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Updation history - ${list.length} updations, total value ${total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              Text('No updations yet', style: Theme.of(context).textTheme.bodySmall),
            for (final u in list)
              ListTile(
                dense: true,
                title: Row(
                  children: [
                    CopyableId(id: u.updationCode),
                    Expanded(child: Text(u.title, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                subtitle: Text(
                  '${u.status.label} - requested ${fmt.format(u.requestedDate)}'
                  '${u.value == null ? '' : ' - ${u.value!.toStringAsFixed(2)}'}',
                ),
              ),
          ],
        );
      },
    );
  }
}