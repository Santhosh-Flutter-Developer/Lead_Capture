import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';

const double _wideBreakpoint = 900;

final NumberFormat _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final DateFormat _day = DateFormat('dd MMM yyyy');

enum _StatusFilter { all, pending, completed }

/// Payment Report: one row per Master Client with its deals, project
/// updations, deal value, received value and Pending / Completed status.
/// Filter by client, date and status; export the result to PDF or Excel.
class PaymentReportPage extends StatefulWidget {
  const PaymentReportPage({super.key});

  @override
  State<PaymentReportPage> createState() => _PaymentReportPageState();
}

class _PaymentReportPageState extends State<PaymentReportPage> {
  late final PaginatedDataController<PaymentReportRow> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  PaymentReportSource? _source;
  List<PaymentReportRow> _rows = []; // after every filter
  PaymentReportSummary _summary = PaymentReportSummary.of(const []);
  int _baseCount = 0; // rows before the status / client filters

  String? _fClient; // master client uid
  PaymentReportPeriod _period = PaymentReportPeriod.allTime;
  DateTimeRange? _customRange;
  _StatusFilter _status = _StatusFilter.all;
  String _search = '';
  int _filterTick = 0;

  PermissionModel? _permissions;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<PaymentReportRow>(
      initialSortColumnIndex: 1,
      filterLogic: (r, query) {
        final q = query.toLowerCase();
        return r.clientName.toLowerCase().contains(q) ||
            r.dealNames.toLowerCase().contains(q) ||
            r.updationNames.toLowerCase().contains(q);
      },
      sortLogic: (a, b, col, asc) {
        int c;
        switch (col) {
          case 1:
            c = a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
            break;
          case 2:
            c = a.deals.length.compareTo(b.deals.length);
            break;
          case 3:
            c = a.updations.length.compareTo(b.updations.length);
            break;
          case 4:
            c = a.dealValue.compareTo(b.dealValue);
            break;
          case 5:
            c = a.receivedValue.compareTo(b.receivedValue);
            break;
          case 6:
            c = a.status.index.compareTo(b.status.index);
            break;
          default:
            c = a.clientName.compareTo(b.clientName);
        }
        return asc ? c : -c;
      },
      getItemId: (r) => r.clientId.isEmpty ? r.clientName : r.clientId,
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  // ───────────────────────────── data ─────────────────────────────

  Future<void> _load() async {
    try {
      _permissions = await PermissionService.getPermissions('Payment Report');
      if (!(_permissions?.canView ?? false)) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _source = await PaymentReportService.load();
      if (!mounted) return;
      _recalculate();
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

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  ({DateTime from, DateTime to})? get _range {
    if (_period == PaymentReportPeriod.custom) {
      final r = _customRange;
      if (r == null) return null;
      return (
        from: DateTime(r.start.year, r.start.month, r.start.day),
        to: DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999),
      );
    }
    return _period.range();
  }

  void _recalculate() {
    final src = _source;
    if (src == null) return;
    final range = _range;
    var rows = PaymentReportService.build(
      src,
      from: range?.from,
      to: range?.to,
    );
    if (_fClient != null) {
      rows = rows.where((r) => r.clientId == _fClient).toList();
    }
    _baseCount = rows.length;
    if (_status != _StatusFilter.all) {
      final want = _status == _StatusFilter.completed;
      rows = rows.where((r) => r.isCompleted == want).toList();
    }
    _rows = rows;
    _summary = PaymentReportSummary.of(rows);
    _controller.setData(rows);
    if (_search.isNotEmpty) _controller.setSearch(_search);
    if (mounted) setState(() {});
  }

  void _resetFilters() {
    _fClient = null;
    _period = PaymentReportPeriod.allTime;
    _customRange = null;
    _status = _StatusFilter.all;
    _filterTick++;
    _recalculate();
  }

  bool get _hasFilters =>
      _fClient != null ||
      _period != PaymentReportPeriod.allTime ||
      _status != _StatusFilter.all;

  String get _periodText {
    final r = _range;
    if (_period == PaymentReportPeriod.allTime) return 'All Time';
    if (r == null) return _period.label;
    final a = _day.format(r.from);
    final b = _day.format(r.to);
    return a == b ? a : '$a – $b';
  }

  String get _clientText {
    if (_fClient == null) return 'All Clients';
    final c = _source?.clients.where((c) => c.uid == _fClient).firstOrNull;
    return c == null ? 'All Clients' : PaymentReportService.clientLabel(c);
  }

  String get _statusText => switch (_status) {
    _StatusFilter.all => 'All',
    _StatusFilter.pending => 'Pending',
    _StatusFilter.completed => 'Completed',
  };

  Future<void> _pickPeriod(PaymentReportPeriod p) async {
    if (p == PaymentReportPeriod.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 5, 12, 31),
        initialDateRange:
            _customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month, now.day),
            ),
        helpText: 'Select date range (From – To)',
        saveText: 'Apply',
      );
      if (picked == null) {
        // Keep the previous selection and put the dropdown back to it.
        _filterTick++;
        if (mounted) setState(() {});
        return;
      }
      _customRange = picked;
    }
    _period = p;
    _recalculate();
  }

  // ───────────────────────────── export ─────────────────────────────

  Future<void> _export(bool pdf) async {
    if (_rows.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    try {
      final filters = PaymentReportExportService.filterSummary(
        client: _clientText,
        period: _periodText,
        status: _statusText,
      );
      final bytes = pdf
          ? await PaymentReportExportService.buildPdf(
              rows: _rows,
              summary: _summary,
              filters: filters,
            )
          : PaymentReportExportService.buildExcel(
              rows: _rows,
              summary: _summary,
              filters: filters,
            );
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final path = await saveFileToDownloads(
        bytes,
        fileName: 'Payment Report $stamp.${pdf ? 'pdf' : 'xlsx'}',
      );
      if (!mounted) return;
      FlushBar.show(context, '${pdf ? 'PDF' : 'Excel'} report exported');
      if (!kIsWeb) openfile(path, context);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, 'Export failed: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ───────────────────────────── build ─────────────────────────────

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text('Payment Report'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: Builder(
        builder: (context) {
          if (_loading) return const WaitingLoading();
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Iconsax.refresh, size: 16),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!(_permissions?.canView ?? false)) {
            return buildNoPermissionView(context);
          }
          return ChangeNotifierProvider<
            PaginatedDataController<PaymentReportRow>
          >.value(
            value: _controller,
            child: Consumer<PaginatedDataController<PaymentReportRow>>(
              builder: (context, controller, _) => RefreshIndicator(
                onRefresh: _load,
                child: Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: isWide,
                  child: ListView(
                    controller: _vScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24 : 14),
                    children: [
                      if (isWide) ...[
                        _banner(context),
                        const SizedBox(height: 18),
                      ],
                      _filterCard(context, isWide),
                      const SizedBox(height: 16),
                      _summaryCards(context, isWide),
                      const SizedBox(height: 16),
                      controller.paginatedItems.isEmpty
                          ? NoData(
                              text: _baseCount == 0 && !_hasFilters
                                  ? 'No deals or payments to report yet'
                                  : 'No records match these filters',
                            )
                          : _table(context, controller),
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

  bool get _canExport => (_permissions?.canExport ?? false);

  // ───────────────────────────── banner ─────────────────────────────

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  Widget _banner(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
            child: const Icon(Iconsax.chart_21, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Report',
                  style: t.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'See what each client owes, what has been received and what is still pending',
                  style: t.bodyMedium?.copyWith(
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
                  '${_summary.clients}',
                  style: t.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Clients',
                  style: t.bodySmall?.copyWith(
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

  Widget _exportMenu() {
    final enabled = _rows.isNotEmpty && !_exporting;
    return PopupMenuButton<bool>(
      tooltip: _rows.isEmpty ? 'Nothing to export' : 'Export',
      enabled: enabled,
      onSelected: _export,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: true,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Iconsax.document_text, color: AppColors.danger),
            title: Text('Export as PDF'),
          ),
        ),
        PopupMenuItem(
          value: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Iconsax.document_download, color: AppColors.success),
            title: Text('Export as Excel'),
          ),
        ),
      ],
      child: IgnorePointer(
        child: OutlinedButton.icon(
          onPressed: enabled ? () {} : null,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Iconsax.export_3, size: 18),
          label: Text(_exporting ? 'Exporting…' : 'Export'),
        ),
      ),
    );
  }

  // ───────────────────────────── filters ─────────────────────────────

  Widget _filterCard(BuildContext context, bool isWide) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final clients = _source?.clients ?? const <ClientModel>[];
    final labels = clients.map(PaymentReportService.clientLabel).toSet().toList()
      ..sort();
    final width = isWide ? 220.0 : double.infinity;

    final buttons = <Widget>[
      if (_canExport) _exportMenu(),
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
          _controller.setSearch(v);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search client, deal, updation',
          prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    Widget dd(
      String label,
      String? value,
      List<String> items,
      ValueChanged<String?> onChanged,
    ) => SizedBox(
      width: width,
      child: FormDropdownSearch(
        key: ValueKey('${label}_$_filterTick'),
        label: label,
        items: items,
        initialItem: value,
        allowClear: true,
        onChanged: (dynamic v) => onChanged(v as String?),
        validator: (v) => null,
      ),
    );

    final rangeText = _customRange == null
        ? 'Select From – To'
        : '${_day.format(_customRange!.start)} – ${_day.format(_customRange!.end)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isWide
              ? Row(
                  children: [
                    search,
                    const Spacer(),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: buttons,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    search,
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: buttons,
                    ),
                  ],
                ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              dd(
                'Master Client',
                _fClient == null ? null : _clientText,
                labels,
                (v) {
                  _fClient = clients
                      .where((c) => PaymentReportService.clientLabel(c) == v)
                      .firstOrNull
                      ?.uid;
                  _recalculate();
                },
              ),
              dd(
                'Date',
                _period == PaymentReportPeriod.allTime ? null : _period.label,
                [for (final p in PaymentReportPeriod.values) p.label],
                (v) {
                  final p = PaymentReportPeriod.values
                      .where((p) => p.label == v)
                      .firstOrNull;
                  _pickPeriod(p ?? PaymentReportPeriod.allTime);
                },
              ),
              if (_period == PaymentReportPeriod.custom)
                SizedBox(
                  width: isWide ? 270 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Range (From – To)',
                        style: t.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pickPeriod(PaymentReportPeriod.custom),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: scheme.outline),
                          ),
                          child: Row(
                            children: [
                              const Icon(Iconsax.calendar_1, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rangeText,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              dd(
                'Status',
                _status == _StatusFilter.all ? null : _statusText,
                const ['Pending', 'Completed'],
                (v) {
                  _status = v == 'Pending'
                      ? _StatusFilter.pending
                      : v == 'Completed'
                      ? _StatusFilter.completed
                      : _StatusFilter.all;
                  _recalculate();
                },
              ),
              OutlinedButton.icon(
                onPressed: _hasFilters ? _resetFilters : null,
                icon: const Icon(Iconsax.refresh, size: 16),
                label: const Text('Reset Filters'),
              ),
            ],
          ),
          if (_period != PaymentReportPeriod.allTime) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Iconsax.info_circle, size: 14, color: AppColors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _period == PaymentReportPeriod.custom && _customRange == null
                        ? 'Pick a From – To range to filter.'
                        : '$_periodText · covers deals and project updations raised in this period. '
                              'Payments received against them are counted in full.',
                    style: t.bodySmall?.copyWith(color: AppColors.grey),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────── summary ─────────────────────────────

  Widget _summaryCards(BuildContext context, bool isWide) {
    final s = _summary;
    final cards = <Widget>[
      _StatCard(
        icon: Iconsax.receipt_2_1,
        color: AppColors.primary,
        label: 'Total Deal Value',
        value: _money.format(s.dealValue),
        hint: 'Projects + project updations',
      ),
      _StatCard(
        icon: Iconsax.wallet_check,
        color: AppColors.success,
        label: 'Received',
        value: _money.format(s.receivedValue),
        hint: 'Payments + updation payments',
      ),
      _StatCard(
        icon: Iconsax.wallet_minus,
        color: s.balance > 0.01 ? AppColors.warning : AppColors.success,
        label: 'Balance Due',
        value: _money.format(s.balance),
        hint: '${s.pendingClients} pending · ${s.completedClients} completed',
      ),
      _StatCard(
        icon: Iconsax.chart_success,
        color: AppColors.info,
        label: 'Collected',
        value: '${(s.progress * 100).toStringAsFixed(0)}%',
        hint: '${s.clients} client${s.clients == 1 ? '' : 's'}',
        progress: s.progress,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
        final w = (c.maxWidth - (perRow - 1) * 12) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: w, child: card)],
        );
      },
    );
  }

  // ───────────────────────────── table (wide) ─────────────────────────────

  Widget _table(
    BuildContext context,
    PaginatedDataController<PaymentReportRow> controller,
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
                      showCheckboxColumn: false,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 76,
                      columnSpacing: 28,
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
                        const DataColumn(label: Text('S.No')),
                        DataColumn(
                          label: const Text('Client'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Client Deals'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Project Updations'),
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Deal Value'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Received Value'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(
                          label: const Text('Status'),
                          onSort: controller.setSort,
                        ),
                        const DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (var i = 0; i < controller.paginatedItems.length; i++)
                          _row(
                            context,
                            controller.paginatedItems[i],
                            (controller.currentPage - 1) * controller.rowsPerPage +
                                i + 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: PaginationControls<PaymentReportRow>(),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, PaymentReportRow r, int sno) {
    final t = Theme.of(context).textTheme;
    return DataRow(
      onSelectChanged: (_) => _showDetail(r),
      cells: [
        DataCell(Text('$sno', style: t.bodySmall)),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              r.clientName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        DataCell(_namesCell(context, r.deals.map((d) => d.name).toList(), 'deal')),
        DataCell(
          _namesCell(
            context,
            r.updations
                .map((u) => u.title.isEmpty ? u.code : '${u.code} · ${u.title}')
                .toList(),
            'updation',
          ),
        ),
        DataCell(
          Text(
            _money.format(r.dealValue),
            style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money.format(r.receivedValue),
                  style: t.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 5),
                _ProgressBar(value: r.progress, done: r.isCompleted),
                if (!r.isCompleted) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${_money.format(r.balance)} due',
                    style: t.labelSmall?.copyWith(color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ),
        DataCell(_StatusChip(status: r.status)),
        const DataCell(Icon(Iconsax.arrow_right_3, size: 16)),
      ],
    );
  }

  Widget _namesCell(BuildContext context, List<String> names, String noun) {
    final t = Theme.of(context).textTheme;
    if (names.isEmpty) {
      return Text('-', style: t.bodySmall?.copyWith(color: AppColors.grey));
    }
    return Tooltip(
      message: names.join('\n'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              names.first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall,
            ),
            if (names.length > 1)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${names.length - 1} more $noun${names.length - 1 == 1 ? '' : 's'}',
                  style: t.labelSmall?.copyWith(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────── detail ─────────────────────────────

  Future<void> _showDetail(PaymentReportRow r) {
    if (_isWide(context)) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: _ClientDetail(row: r),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scroll) => _ClientDetail(row: r, controller: scroll),
      ),
    );
  }
}

// ═══════════════════════════ small widgets ═══════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String hint;
  final double? progress;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.hint,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelMedium?.copyWith(color: AppColors.grey)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  _ProgressBar(value: progress!, done: progress! >= 0.9999),
                ],
                const SizedBox(height: 4),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(color: AppColors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final bool done;
  const _ProgressBar({required this.value, required this.done});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 6,
      backgroundColor: AppColors.grey200,
      color: done ? AppColors.success : AppColors.warning,
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final PaymentReportStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final done = status == PaymentReportStatus.completed;
    final color = done ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Iconsax.tick_circle : Iconsax.clock, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Breakdown of one client: every deal and project updation with its own
/// value, received amount and status.
class _ClientDetail extends StatelessWidget {
  final PaymentReportRow row;
  final ScrollController? controller;
  const _ClientDetail({required this.row, this.controller});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Widget metric(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelSmall?.copyWith(color: AppColors.grey)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: t.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget item({
      required IconData icon,
      required String title,
      String? subtitle,
      required double value,
      required double received,
      required PaymentReportStatus status,
    }) {
      final done = status == PaymentReportStatus.completed;
      final progress = value <= 0 ? 0.0 : (received / value).clamp(0.0, 1.0);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: t.labelSmall?.copyWith(color: AppColors.grey),
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 4,
              children: [
                Text('Value  ${_money.format(value)}', style: t.bodySmall),
                Text(
                  'Received  ${_money.format(received)}',
                  style: t.bodySmall?.copyWith(color: AppColors.success),
                ),
                if (!done)
                  Text(
                    'Due  ${_money.format(value - received)}',
                    style: t.bodySmall?.copyWith(color: AppColors.warning),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ProgressBar(value: progress, done: done),
          ],
        ),
      );
    }

    Widget section(String title, int count) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        '$title ($count)',
        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.clientName,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _StatusChip(status: row.status),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              metric('Deal Value', _money.format(row.dealValue), AppColors.primary),
              const SizedBox(width: 10),
              metric('Received', _money.format(row.receivedValue), AppColors.success),
              const SizedBox(width: 10),
              metric(
                'Balance',
                _money.format(row.balance),
                row.balance > 0.01 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              section('Deals', row.deals.length),
              if (row.deals.isEmpty)
                Text('No deals in this period', style: t.bodySmall),
              for (final d in row.deals)
                item(
                  icon: Iconsax.dollar_circle,
                  title: d.name,
                  subtitle: d.dealNumber == null ? null : 'Deal #${d.dealNumber}',
                  value: d.value,
                  received: d.received,
                  status: d.status,
                ),
              section('Project Updations', row.updations.length),
              if (row.updations.isEmpty)
                Text('No project updations in this period', style: t.bodySmall),
              for (final u in row.updations)
                item(
                  icon: Iconsax.refresh_circle,
                  title: u.title.isEmpty ? u.code : '${u.code} · ${u.title}',
                  subtitle: u.projectName,
                  value: u.value,
                  received: u.received,
                  status: u.status,
                ),
            ],
          ),
        ),
      ],
    );
  }
}