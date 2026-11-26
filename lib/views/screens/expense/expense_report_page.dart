import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import 'expense_ui.dart';

const String _pageTitle = 'Expense Report';
const double _wideBreakpoint = 900;

/// Expense Report: filtered list + category breakdown, exportable to Excel /
/// PDF. Access follows the role's "Expense Report" permission, falling back to
/// "Expenses" (same rule as the server). Admin has everything.
class ExpenseReportPage extends StatefulWidget {
  const ExpenseReportPage({super.key});

  @override
  State<ExpenseReportPage> createState() => _ExpenseReportPageState();
}

class _ExpenseReportPageState extends State<ExpenseReportPage> {
  final ScrollController _vScroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  PermissionModel? _reportPerm;
  PermissionModel? _expensesPerm;
  ExpenseReportData? _data;

  DateTime? _from;
  DateTime? _to;
  ExpenseLookupItem? _company;
  ExpenseLookupItem? _category;
  String? _mode;
  int _tick = 0;

  bool _loading = true;
  bool _refreshing = false;
  bool _exporting = false;
  String? _error;

  bool get _canView => (_reportPerm?.canView ?? false) || (_expensesPerm?.canView ?? false);
  bool get _canExport =>
      (_reportPerm?.canExport ?? false) || (_expensesPerm?.canExport ?? false);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _vScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  Future<ExpenseReportData> _fetch() => ExpenseReportService.fetch(
    from: _from,
    to: _to,
    masterCompanyId: _company?.id,
    categoryId: _category?.id,
    paymentMode: _mode,
  );

  Future<void> _init() async {
    try {
      _reportPerm = await PermissionService.getPermissions(_pageTitle);
      _expensesPerm = await PermissionService.getPermissions('Expenses');
      if (_canView) {
        var d = await _fetch();
        // Like the web report: start on the server's suggested date range.
        if (d.defaultFrom != null && d.defaultTo != null) {
          _from = d.defaultFrom;
          _to = d.defaultTo;
          d = await _fetch();
        }
        _data = d;
      }
      if (!mounted) return;
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

  Future<void> _apply() async {
    setState(() => _refreshing = true);
    try {
      _data = await _fetch();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _reset() async {
    final d = _data;
    _from = d?.defaultFrom;
    _to = d?.defaultTo;
    _company = null;
    _category = null;
    _mode = null;
    _tick++;
    await _apply();
  }

  // ── export ────────────────────────────────────────────────────────────────

  Future<void> _export({required bool pdf}) async {
    final d = _data;
    if (d == null || d.items.isEmpty) {
      FlushBar.show(context, 'No expenses to export', isSuccess: false);
      return;
    }
    setState(() => _exporting = true);
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final companyName = _company?.name ?? 'All Companies';
      final categoryName = _category?.name ?? 'All Categories';
      final modeName = _mode ?? 'All Modes';
      final Uint8List bytes;
      if (pdf) {
        bytes = await ExpenseExportService.buildReportPdf(
          rows: d.items,
          summary: d.summary,
          filters: ExpenseExportService.filterSummary(
            company: companyName,
            category: categoryName,
            mode: modeName,
            period:
                '${_from == null ? 'Start' : fmt.format(_from!)} to ${_to == null ? 'Today' : fmt.format(_to!)}',
          ),
        );
      } else {
        bytes = ExpenseExportService.buildReportExcel(
          rows: d.items,
          summary: d.summary,
          from: _from == null ? 'All' : fmt.format(_from!),
          to: _to == null ? 'All' : fmt.format(_to!),
          company: companyName,
          category: categoryName,
          mode: modeName,
        );
      }
      final name = 'Expense_Report_${fmt.format(DateTime.now())}.${pdf ? 'pdf' : 'xlsx'}';
      final path = await saveFileToDownloads(bytes, fileName: name);
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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
      body: Builder(
        builder: (context) {
          if (_loading) return const WaitingLoading();
          if (_error != null) {
            return Center(child: Text(_error!, style: Theme.of(context).textTheme.bodySmall));
          }
          if (!_canView || _data == null) return buildNoPermissionView(context);
          final d = _data!;
          return RefreshIndicator(
            onRefresh: _apply,
            child: Scrollbar(
              controller: _vScroll,
              thumbVisibility: true,
              child: ListView(
                controller: _vScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                children: [
                  _banner(context, d, isWide),
                  const SizedBox(height: 18),
                  _filters(context, d, isWide),
                  const SizedBox(height: 18),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _summary(context, d),
                    const SizedBox(height: 18),
                    if (d.byCategory.isNotEmpty) ...[
                      _breakdown(context, d),
                      const SizedBox(height: 18),
                    ],
                    _table(context, d),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pillButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(BuildContext context, ExpenseReportData d, bool isWide) {
    final buttons = <Widget>[
      if (_canExport) ...[
        _pillButton(
          context,
          icon: Iconsax.document_download,
          label: 'Excel',
          color: const Color(0xFF198754),
          onPressed: _exporting ? null : () => _export(pdf: false),
        ),
        _pillButton(
          context,
          icon: Iconsax.document_text,
          label: 'PDF',
          color: const Color(0xFFDC3545),
          onPressed: _exporting ? null : () => _export(pdf: true),
        ),
      ],
      IconButton(
        tooltip: 'Refresh',
        onPressed: _apply,
        icon: const Icon(Iconsax.refresh, color: AppColors.white),
      ),
    ];
    final total = ExpenseStatBox(
      label: 'Total',
      value: expenseMoney.format(d.summary.totalSpent),
    );
    if (isWide) {
      return ExpenseBanner(
        title: _pageTitle,
        subtitle: 'Complete expenditure listing filtered by date range, company, category and payment mode',
        icon: Iconsax.chart_21,
        trailing: [total, ...buttons],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ExpenseStatBox(
          label: 'Total Spent',
          value: expenseMoney.format(d.summary.totalSpent),
          onLight: true,
        ),
        if (_canExport)
          for (final b in buttons.take(2))
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: b,
            ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return FormFields(
      key: ValueKey('${label}_${value?.toIso8601String()}_$_tick'),
      label: label,
      controller: TextEditingController(
        text: value == null ? '' : DateFormat('dd-MM-yyyy').format(value),
      ),
      hintText: 'dd-mm-yyyy',
      readOnly: true,
      suffixIcon: const Icon(Iconsax.calendar_1, size: 18),
      onTap: () async {
        final p = await pickDate(context, initialDate: value);
        if (p != null) {
          onPicked(DateFormat('dd-MM-yyyy').parse(p));
          await _apply();
        }
      },
    );
  }

  Widget _filters(BuildContext context, ExpenseReportData d, bool isWide) {
    final from = _dateField('From Date', _from, (v) => setState(() => _from = v));
    final to = _dateField('To Date', _to, (v) => setState(() => _to = v));
    final company = FormDropdownSearch(
      key: ValueKey('r_comp_$_tick'),
      label: 'Company',
      initialItem: _company?.name,
      items: d.companies.map((c) => c.name).toList(),
      onChanged: (v) {
        _company = d.companies.where((c) => c.name == v).firstOrNull;
        _apply();
      },
    );
    final category = FormDropdownSearch(
      key: ValueKey('r_cat_$_tick'),
      label: 'Expense Category',
      initialItem: _category?.name,
      items: d.categories.map((c) => c.name).toList(),
      onChanged: (v) {
        _category = d.categories.where((c) => c.name == v).firstOrNull;
        _apply();
      },
    );
    final mode = FormDropdownSearch(
      key: ValueKey('r_mode_$_tick'),
      label: 'Payment Mode',
      initialItem: _mode,
      items: d.paymentModes,
      onChanged: (v) {
        _mode = v as String?;
        _apply();
      },
    );
    final reset = IconButton(
      tooltip: 'Reset filters',
      onPressed: _reset,
      icon: const Icon(Icons.filter_alt_off_rounded),
    );
    return expenseCard(
      context,
      isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: from),
                const SizedBox(width: 12),
                Expanded(child: to),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: company),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: category),
                const SizedBox(width: 12),
                Expanded(child: mode),
                const SizedBox(width: 4),
                reset,
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: from),
                    const SizedBox(width: 10),
                    Expanded(child: to),
                  ],
                ),
                company,
                category,
                mode,
                Align(alignment: Alignment.centerRight, child: reset),
              ],
            ),
    );
  }

  Widget _summary(BuildContext context, ExpenseReportData d) {
    final s = d.summary;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ExpenseStatBox(
          label: 'Total Spent',
          value: expenseMoney.format(s.totalSpent),
          onLight: true,
        ),
        ExpenseStatBox(
          label: 'Active Bills',
          value: '${s.activeCount}',
          onLight: true,
          tint: const Color(0xFF198754),
        ),
        ExpenseStatBox(
          label: 'Avg Bill',
          value: expenseMoney.format(s.avgBillAmount),
          onLight: true,
          tint: const Color(0xFF6F42C1),
        ),
        ExpenseStatBox(
          label: 'Top Category',
          value: s.topCategory,
          onLight: true,
          tint: const Color(0xFFFD7E14),
        ),
      ],
    );
  }

  Widget _breakdown(BuildContext context, ExpenseReportData d) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return expenseCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spend by Category', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final b in d.byCategory)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${b.name}  •  ${b.billCount} ${b.billCount == 1 ? 'bill' : 'bills'}',
                          style: t.bodySmall,
                        ),
                      ),
                      Text(
                        '${expenseMoney.format(b.amount)}  (${b.percent.toStringAsFixed(1)}%)',
                        style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (b.percent / 100).clamp(0.0, 1.0),
                      minHeight: 7,
                      color: b.color,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, ExpenseReportData d) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
    if (d.items.isEmpty) {
      return const NoData(text: 'No expenses found for the selected filters');
    }
    final total = d.items.fold<double>(0, (a, e) => a + e.amount);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  'All Expense Bills',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                expenseChip('${d.items.length} bills', scheme.primary),
              ],
            ),
          ),
          LayoutBuilder(
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
                    headingRowColor: WidgetStateProperty.all(scheme.primary.withValues(alpha: 0.06)),
                    headingTextStyle: style?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                    columns: const [
                      DataColumn(label: Text('S.NO')),
                      DataColumn(label: Text('EXPENSE DATE')),
                      DataColumn(label: Text('EXPENSE NUMBER')),
                      DataColumn(label: Text('COMPANY NAME')),
                      DataColumn(label: Text('CATEGORY NAME')),
                      DataColumn(label: Text('DESCRIPTION')),
                      DataColumn(label: Text('PAYMENT MODE')),
                      DataColumn(label: Text('AMOUNT'), numeric: true),
                    ],
                    rows: [
                      for (var i = 0; i < d.items.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}', style: style)),
                            DataCell(
                              Text(DateFormat('dd MMM yyyy').format(d.items[i].expenseDate), style: style),
                            ),
                            DataCell(
                              Text(
                                d.items[i].expenseNumber,
                                style: style?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            DataCell(Text(d.items[i].masterCompanyName, style: style)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: d.items[i].categoryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(d.items[i].categoryName, style: style),
                                ],
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: Text(
                                  RecordViewSheet.dash(d.items[i].description),
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                              ),
                            ),
                            DataCell(Text(d.items[i].paymentMode, style: style)),
                            DataCell(
                              Text(
                                expenseMoney.format(d.items[i].amount),
                                style: style?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Total:', style: style?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 14),
                Text(
                  expenseMoney.format(total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}