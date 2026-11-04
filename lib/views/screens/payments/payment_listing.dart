import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/views/screens/project_updations/project_updation_form.dart'
    show masterClientLabel;
import '/theme/theme.dart';
import 'package:intl/intl.dart';

const double _wideBreakpoint = 900;

final NumberFormat _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// Payment list: one row per allocation (Master Client, Project, Deal Value,
/// Allocated Value, Payment Mode). Create / edit / delete / export / view
/// follow the role; superadmin has everything.
class PaymentListing extends StatefulWidget {
  const PaymentListing({super.key});

  @override
  State<PaymentListing> createState() => _PaymentListingState();
}

class _PaymentListingState extends State<PaymentListing> {
  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  late final PaginatedDataController<PaymentGroup> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  List<PaymentGroup> _all = [];
  List<PaymentGroup> _filtered = [];
  List<ClientModel> _clients = [];
  List<DealModel> _deals = [];
  String? _fClient; // master client uid
  String? _fProject; // deal uid
  String? _fMode;
  List<String> _modeNames = []; // every Payment Mode master item
  double? _fValue;
  String _search = '';
  final _valueCtrl = TextEditingController();
  int _filterTick = 0;
  PermissionModel? _permissions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<PaymentGroup>(
      initialSortColumnIndex: 0,
      filterLogic: (c, query) {
        final q = query.toLowerCase();
        return c.clientLabel.toLowerCase().contains(q) ||
            c.projectName.toLowerCase().contains(q) ||
            c.companiesText.toLowerCase().contains(q) ||
            c.modesText.toLowerCase().contains(q);
      },
      sortLogic: (a, b, col, asc) {
        int compare;
        switch (col) {
          case 0:
            compare = a.clientLabel.toLowerCase().compareTo(
              b.clientLabel.toLowerCase(),
            );
            break;
          case 1:
            compare = a.projectName.toLowerCase().compareTo(
              b.projectName.toLowerCase(),
            );
            break;
          case 2:
            compare = a.totalValue.compareTo(b.totalValue);
            break;
          case 3:
            compare = a.allocatedValue.compareTo(b.allocatedValue);
            break;
          case 4:
            compare = a.modesText.toLowerCase().compareTo(
              b.modesText.toLowerCase(),
            );
            break;
          default:
            compare = a.uid.compareTo(b.uid);
        }
        return asc ? compare : -compare;
      },
      getItemId: (c) => c.uid,
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  /// Refresh button: show the loader, then reload clients, stats and
  /// permissions (the search text stays as typed).
  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _load() async {
    try {
      _permissions = await PermissionService.getPermissions('Payment');
      final results = await Future.wait([
        PaymentService.getAll(),
        ClientService.getMasterClients(),
        DealService.getAllDeals(),
        PaymentModeService.getAllPaymentMode(),
      ]);
      _modeNames = (results[3] as List<PaymentModeModel>)
          .map((m) => m.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final clients = PaymentGroup.group(results[0] as List<PaymentModel>);
      _clients = results[1] as List<ClientModel>;
      _deals = results[2] as List<DealModel>;
      if (!mounted) return;
      _all = clients;
      _applyFilters();
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  Future<void> _openForm(BuildContext context, {String? uid}) async {
    final form = PaymentForm(uid: uid);
    dynamic val;
    if (_isWide(context)) {
      val = await GeneralDialog.showRTLSheet(context, form);
    } else {
      val = await Sheet.showSheet(context, widget: form);
    }
    if (val is Map && val['status'] == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text('Payment'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const WaitingLoading();
          if (_error != null) {
            return Center(
              child: Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            );
          }
          if (!(_permissions?.canView ?? false)) {
            return buildNoPermissionView(context);
          }
          return ChangeNotifierProvider<PaginatedDataController<PaymentGroup>>.value(
            value: _controller,
            child: Consumer<PaginatedDataController<PaymentGroup>>(
              builder: (context, controller, _) => RefreshIndicator(
                onRefresh: _load,
                child: Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _vScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      if (isWide) ...[
                        _banner(context),
                        const SizedBox(height: 20),
                      ],
                      _toolbar(context, controller, isWide),
                      const SizedBox(height: 18),
                      controller.paginatedItems.isEmpty
                          ? NoData(
                              text: _all.isEmpty
                                  ? 'No payments available'
                                  : 'No matching records found',
                            )
                          : _tableCard(context, controller),
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

  Widget _banner(BuildContext context) {
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
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Iconsax.wallet_3, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allocate completed deals to our companies and track payment modes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  '${_all.length}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Payments',
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

  Widget _toolbar(
    BuildContext context,
    PaginatedDataController<PaymentGroup> controller,
    bool isWide,
  ) {
    final selected = controller.selectedIds.length;
    final buttons = <Widget>[
      if (_permissions?.canCreate ?? false)
        FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Payment'),
        ),
      if ((_permissions?.canExport ?? false) &&
          _filtered.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => _export(context, controller),
          icon: const Icon(Iconsax.export_3, size: 18),
          label: const Text('Export'),
        ),
      if (selected > 0 && (_permissions?.canDelete ?? false))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => _bulkDelete(context, controller),
          icon: const Icon(Iconsax.trash, size: 18),
          label: Text('Delete ($selected)'),
        ),
      IconButton(
        tooltip: 'Refresh',
        onPressed: _refresh,
        icon: const Icon(Iconsax.refresh),
      ),
    ];

    final search = SizedBox(
      width: isWide ? 300 : double.infinity,
      child: TextField(
        onChanged: (v) {
          _search = v;
          controller.setSearch(v);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search client, project, company, mode',
          prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isWide
              ? Row(
                  children: [
                    search,
                    const Spacer(),
                    Wrap(spacing: 10, runSpacing: 10, children: buttons),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 10, children: buttons),
                  ],
                ),
          const SizedBox(height: 14),
          _filters(context, isWide),
        ],
      ),
    );
  }

  List<String> _distinct(Iterable<String> v) =>
      (v.where((e) => e.trim().isNotEmpty).toSet().toList()..sort());

  void _applyFilters() {
    var list = _all.where((p) {
      if (_fClient != null && p.clientId != _fClient) return false;
      if (_fProject != null && p.projectId != _fProject) return false;
      if (_fMode != null && !p.modes.contains(_fMode)) return false;
      if (_fValue != null && (p.totalValue - _fValue!).abs() > 0.0001) {
        return false;
      }
      return true;
    }).toList();
    _filtered = list;
    _controller.setData(list);
    if (_search.isNotEmpty) _controller.setSearch(_search);
    if (mounted) setState(() {});
  }

  void _resetFilters() {
    _fClient = null;
    _fProject = null;
    _fMode = null;
    _fValue = null;
    _valueCtrl.clear();
    _filterTick++;
    _applyFilters();
  }

  Widget _filters(BuildContext context, bool isWide) {
    final width = isWide ? 220.0 : double.infinity;
    Widget dd(String label, String? value, List<String> items,
        ValueChanged<String?> onChanged) {
      return SizedBox(
        width: width,
        child: FormDropdownSearch(
          key: ValueKey('${label}_$_filterTick'),
          label: label,
          items: items,
          initialItem: value,
          allowClear: true,
          onChanged: (dynamic v) {
            _fClientSafe(() => onChanged(v as String?));
          },
          validator: (v) => null,
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        dd(
          'Master Clients',
          _clients.where((c) => c.uid == _fClient).map(masterClientLabel).firstOrNull,
          _distinct(_clients.map(masterClientLabel)),
          (v) {
            _fClient = _clients
                .where((c) => masterClientLabel(c) == v)
                .firstOrNull
                ?.uid;
            // A project that belongs to another client no longer applies.
            if (_fProject != null &&
                _fClient != null &&
                _deals.where((d) => d.uid == _fProject).firstOrNull?.clientId !=
                    _fClient) {
              _fProject = null;
            }
            _filterTick++;
          },
        ),
        dd(
          'Projects',
          _projectLabels().entries
              .where((e) => e.value == _fProject)
              .map((e) => e.key)
              .firstOrNull,
          _projectLabels().keys.toList()..sort(),
          (v) => _fProject = v == null ? null : _projectLabels()[v],
        ),
        SizedBox(
          width: width,
          child: FormFields(
            label: 'Deal Value',
            controller: _valueCtrl,
            hintText: 'Exact deal value',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              _fValue = double.tryParse(v.trim());
              _applyFilters();
            },
          ),
        ),
        dd(
          'Payment Mode',
          _fMode,
          {..._modeNames, ..._all.expand((p) => p.modes)}.toList()..sort(),
          (v) => _fMode = v,
        ),
        OutlinedButton.icon(
          onPressed: _resetFilters,
          icon: const Icon(Iconsax.refresh, size: 16),
          label: const Text('Reset Filters'),
        ),
      ],
    );
  }

  /// label -> deal uid for every completed deal (of the selected client
  /// when one is chosen).
  Map<String, String> _projectLabels() {
    final deals = _deals.where(
      (d) => d.uid != null && (_fClient == null || d.clientId == _fClient),
    );
    String nameOf(DealModel d) =>
        (d.projectName ?? '').trim().isEmpty ? d.dealName : d.projectName!;
    final counts = <String, int>{};
    for (final d in deals) {
      counts[nameOf(d)] = (counts[nameOf(d)] ?? 0) + 1;
    }
    return {
      for (final d in deals)
        counts[nameOf(d)]! > 1 && d.dealNumber != null
            ? '${nameOf(d)} (#${d.dealNumber})'
            : nameOf(d): d.uid!,
    };
  }

  void _fClientSafe(VoidCallback set) {
    set();
    _applyFilters();
  }

  Widget _tableCard(
    BuildContext context,
    PaginatedDataController<PaymentGroup> controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: LayoutBuilder(
              builder: (context, constraints) => Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: true,
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
                        DataColumn(
                          label: const Text('Master Client'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Projects'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Deal Value'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Payment Value'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Payment Mode'),
                          onSort: controller.setSort,
                        ),
                        const DataColumn(label: Text('Our Company')),
                        const DataColumn(label: Text('Created By')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: controller.paginatedItems
                          .map((c) => _row(context, c, controller))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<PaymentGroup>(),
          ),
        ],
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    PaymentGroup c,
    PaginatedDataController<PaymentGroup> controller,
  ) {
    final style = Theme.of(context).textTheme.bodySmall;
    return DataRow(
      selected: controller.selectedIds.contains(c.uid),
      onSelectChanged: (v) => controller.onSelected(c.uid, v),
      cells: [
        DataCell(
          Text(
            c.clientLabel.isNotEmpty ? c.clientLabel : '-',
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          onTap: (_permissions?.canEdit ?? false)
              ? () => _openForm(context, uid: c.first.uid)
              : null,
        ),
        DataCell(Text(c.projectName.isNotEmpty ? c.projectName : '-', style: style)),
        DataCell(Text(_money.format(c.totalValue), style: style)),
        DataCell(Text(_money.format(c.allocatedValue), style: style)),
        DataCell(Text(c.modesText.isNotEmpty ? c.modesText : '-', style: style)),
        DataCell(Text(c.companiesText.isNotEmpty ? c.companiesText : '-', style: style)),
        DataCell(CreatedByWidget(userData: c.createdBy)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_permissions?.canEdit ?? false)
                IconButton(
                  tooltip: 'Edit',
                  color: AppColors.info,
                  icon: const Icon(Iconsax.edit),
                  onPressed: () => _openForm(context, uid: c.first.uid),
                ),
              if (_permissions?.canDelete ?? false)
                IconButton(
                  tooltip: 'Delete',
                  color: AppColors.danger,
                  icon: const Icon(Iconsax.trash),
                  onPressed: () => _delete(context, c),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(
    BuildContext context,
    PaginatedDataController<PaymentGroup> controller,
  ) async {
    try {
      final rows = <List<String>>[
        [
          'Master Client',
          'Project',
          'Deal Value',
          'Our Company',
          'Payment Value',
          'Payment Mode',
          'Created By',
        ],
        for (final c in _filtered)
          [
            c.clientLabel,
            c.projectName,
            c.totalValue.toStringAsFixed(2),
            c.companiesText,
            c.allocatedValue.toStringAsFixed(2),
            c.modesText,
            c.createdBy.name,
          ],
      ];
      final bytes = await XlsxWriter().create(rows);
      final path = await saveFileToDownloads(
        bytes,
        fileName: 'Payment List.xlsx',
      );
      if (!kIsWeb && context.mounted) openfile(path, context);
    } catch (e) {
      if (!context.mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete Payment',
        content: count == 1
            ? 'Are you sure you want to delete this payment?'
            : 'Are you sure you want to delete $count payments?',
      ),
    );
    return ok == true;
  }

  Future<void> _delete(BuildContext context, PaymentGroup c) async {
    if (!context.mounted || !await _confirmDelete(context, 1)) return;
    try {
      final deleted = [...c.lines];
      futureLoading(context);
      try {
        for (final l in c.lines) {
          await PaymentService.delete(uid: l.uid ?? '');
        }
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      await _load();
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Payment deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (final l in deleted) {
            await PaymentService.restore(l);
          }
          await _load();
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }

  Future<void> _bulkDelete(
    BuildContext context,
    PaginatedDataController<PaymentGroup> controller,
  ) async {
    final chosen = _all
        .where((c) => controller.selectedIds.contains(c.uid))
        .toList();
    if (chosen.isEmpty) return;
    if (!context.mounted || !await _confirmDelete(context, chosen.length)) {
      return;
    }
    try {
      final deleted = chosen.expand((e) => e.lines).toList();
      futureLoading(context);
      try {
        for (final c in chosen) {
          for (final l in c.lines) {
            await PaymentService.delete(uid: l.uid ?? '');
          }
        }
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      controller.clearSelection();
      await _load();
      if (!context.mounted) return;
      FlushBar.show(
        context,
        'Payments deleted',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (final c in deleted) {
            await PaymentService.restore(c);
          }
          await _load();
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (context.mounted) FlushBar.show(context, '$e', isSuccess: false);
    }
  }
}