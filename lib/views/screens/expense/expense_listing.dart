import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import 'expense_form.dart';
import 'expense_ui.dart';

const String _pageTitle = 'Expenses';
const double _wideBreakpoint = 900;
const Color _cancelledRed = Color(0xFFDC3545);

/// Expense bills. Access follows the role's "Expenses" permission:
/// view = see the list, create = Add Expense, edit = edit (active bills only),
/// delete = cancel with remarks, export = Export Excel. Admin has everything.
class ExpenseListing extends StatefulWidget {
  const ExpenseListing({super.key});

  @override
  State<ExpenseListing> createState() => _ExpenseListingState();
}

class _ExpenseListingState extends State<ExpenseListing> {
  late final PaginatedDataController<ExpenseModel> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();

  List<ExpenseModel> _items = [];
  ExpenseStats _stats = const ExpenseStats();
  List<MasterCompanyModel> _companies = [];
  List<ExpenseCategoryModel> _categories = [];
  List<String> _modes = [];
  PermissionModel? _permissions;

  // filters
  DateTime? _from;
  DateTime? _to;
  MasterCompanyModel? _company;
  ExpenseCategoryModel? _category;
  String? _mode;
  int _filterTick = 0;

  bool _loading = true;
  bool _refreshing = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<ExpenseModel>(
      initialSortColumnIndex: 5,
      filterLogic: (e, q) {
        final s = q.toLowerCase();
        return e.expenseNumber.toLowerCase().contains(s) ||
            e.masterCompanyName.toLowerCase().contains(s) ||
            e.categoryName.toLowerCase().contains(s) ||
            e.paymentMode.toLowerCase().contains(s) ||
            e.description.toLowerCase().contains(s) ||
            e.upiNumber.toLowerCase().contains(s) ||
            e.amount.toString().contains(s);
      },
      sortLogic: (a, b, col, asc) {
        int r;
        switch (col) {
          case 0:
            r = a.expenseNumber.compareTo(b.expenseNumber);
            break;
          case 1:
            r = a.masterCompanyName.toLowerCase().compareTo(b.masterCompanyName.toLowerCase());
            break;
          case 2:
            r = a.categoryName.toLowerCase().compareTo(b.categoryName.toLowerCase());
            break;
          case 3:
            r = a.amount.compareTo(b.amount);
            break;
          case 4:
            r = a.paymentMode.toLowerCase().compareTo(b.paymentMode.toLowerCase());
            break;
          case 5:
            r = a.expenseDate.compareTo(b.expenseDate);
            if (r == 0) r = a.createdAt.compareTo(b.createdAt);
            break;
          case 6:
            r = a.description.toLowerCase().compareTo(b.description.toLowerCase());
            break;
          default:
            r = a.uid.compareTo(b.uid);
        }
        return asc ? r : -r;
      },
      getItemId: (e) => e.uid,
    );
    _controller.setSort(5, false);
    _load(initial: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  bool get _canView => _permissions?.canView ?? false;
  bool get _canCreate => _permissions?.canCreate ?? false;
  bool get _canEdit => _permissions?.canEdit ?? false;
  bool get _canDelete => _permissions?.canDelete ?? false;
  bool get _canExport => _permissions?.canExport ?? false;
  bool get _hasFilters =>
      _from != null || _to != null || _company != null || _category != null || _mode != null;

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchList() async {
    final res = await ExpenseService.list(
      from: _from,
      to: _to,
      masterCompanyId: _company?.uid,
      categoryId: _category?.uid,
      paymentMode: _mode,
    );
    _items = res.items;
    _stats = res.stats;
    _controller.setData(_items);
    _controller.clearSelection();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      _permissions = await PermissionService.getPermissions(_pageTitle);
      if (_canView) {
        if (initial || _companies.isEmpty) {
          final lookups = await Future.wait([
            MasterCompanyService.getAll(),
            ExpenseCategoryService.getAll(),
            PaymentModeService.getAllPaymentMode(),
          ]);
          _companies = lookups[0] as List<MasterCompanyModel>;
          _categories = lookups[1] as List<ExpenseCategoryModel>;
          _modes = (lookups[2] as List<PaymentModeModel>).map((m) => m.name).toList();
        }
        await _fetchList();
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.toString();
      });
    }
  }

  /// Manual refresh: reloads lookups + list (filters stay), shows a spinner
  /// while it runs and confirms when done.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _load(initial: true);
    if (mounted && _error == null) FlushBar.show(context, 'Expenses refreshed');
  }

  Future<void> _applyFilters() async {
    setState(() => _refreshing = true);
    try {
      await _fetchList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _reset() async {
    _from = null;
    _to = null;
    _company = null;
    _category = null;
    _mode = null;
    _filterTick++;
    await _applyFilters();
  }

  // ── actions ───────────────────────────────────────────────────────────────

  Future<void> _openForm(BuildContext context, {String? uid}) async {
    final form = ExpenseForm(uid: uid);
    final dynamic val = _isWide(context)
        ? await GeneralDialog.showRTLSheet(context, form)
        : await Sheet.showSheet(context, widget: form);
    if (val is Map && val['status'] == true) await _applyFilters();
  }

  Future<void> _cancel(ExpenseModel e) async {
    final remarks = await askCancellationRemarks(
      context,
      title: 'Cancel ${e.expenseNumber}',
      message:
          'This expense (${expenseMoney.format(e.amount)}) will be marked as cancelled and excluded from spend totals.',
    );
    if (remarks == null || !mounted) return;
    try {
      futureLoading(context);
      try {
        await ExpenseService.cancel(uid: e.uid, remarks: remarks);
      } finally {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      await _applyFilters();
      if (mounted) FlushBar.show(context, 'Expense cancelled successfully');
    } catch (err, st) {
      await ErrorService.recordError(err, st);
      if (mounted) FlushBar.show(context, err.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkCancel() async {
    final ids = _items
        .where((e) => !e.isCancelled && _controller.selectedIds.contains(e.uid))
        .map((e) => e.uid)
        .toList();
    if (ids.isEmpty) return;
    final remarks = await askCancellationRemarks(
      context,
      title: 'Cancel ${ids.length} expenses',
      message: 'The selected expenses will be marked as cancelled.',
    );
    if (remarks == null || !mounted) return;
    try {
      futureLoading(context);
      try {
        await ExpenseService.bulkCancel(uids: ids, remarks: remarks);
      } finally {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      await _applyFilters();
      if (mounted) FlushBar.show(context, '${ids.length} expenses cancelled');
    } catch (err, st) {
      await ErrorService.recordError(err, st);
      if (mounted) FlushBar.show(context, err.toString(), isSuccess: false);
    }
  }

  Future<void> _saveAndOpen(Uint8List bytes, String name) async {
    final path = await saveFileToDownloads(bytes, fileName: name);
    if (!mounted) return;
    FlushBar.show(context, 'Downloaded $name');
    if (!kIsWeb) openfile(path, context);
  }

  Future<void> _exportExcel() async {
    final rows = _controller.filteredItems;
    if (rows.isEmpty) {
      FlushBar.show(context, 'No expenses to export', isSuccess: false);
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = ExpenseExportService.buildListExcel(rows);
      await _saveAndOpen(
        bytes,
        'Expenses_Export_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, 'Export failed: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _voucher(ExpenseModel e) async {
    try {
      final bytes = await ExpenseExportService.buildVoucherPdf(e);
      await _saveAndOpen(bytes, 'Expense_Voucher_${e.expenseNumber}.pdf');
    } catch (err, st) {
      await ErrorService.recordError(err, st);
      if (mounted) FlushBar.show(context, 'Could not create voucher: $err', isSuccess: false);
    }
  }

  Future<void> _view(ExpenseModel e) async {
    final scheme = Theme.of(context).colorScheme;
    final r = await RecordViewSheet.show(
      context,
      RecordViewSheet(
        title: e.expenseNumber,
        subtitle: e.masterCompanyName,
        icon: Iconsax.wallet_3,
        badge: e.isCancelled ? 'Cancelled' : 'Active',
        canEdit: _canEdit && !e.isCancelled,
        editLabel: 'Edit Expense',
        summary: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: e.isCancelled
                  ? const [Color(0xFFB02A37), Color(0xFFDC3545)]
                  : const [Color(0xFF0052D4), Color(0xFF4364F7)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXPENSE AMOUNT',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                expenseMoney.format(e.amount),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  decoration: e.isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${e.categoryName} • ${DateFormat('dd MMM yyyy').format(e.expenseDate)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        sections: [
          RecordViewSection('Expense Details', [
            RecordViewField('Expense No', e.expenseNumber),
            RecordViewField('Expense Date', DateFormat('dd MMM yyyy').format(e.expenseDate)),
            RecordViewField('Our Company', RecordViewSheet.dash(e.masterCompanyName)),
            RecordViewField('Category', RecordViewSheet.dash(e.categoryName)),
            RecordViewField('Payment Mode', RecordViewSheet.dash(e.paymentMode)),
            if (e.upiNumber.isNotEmpty) RecordViewField('UPI Number', e.upiNumber),
            RecordViewField('Description', RecordViewSheet.dash(e.description)),
          ]),
          RecordViewSection('Record Info', [
            RecordViewField('Recorded By', RecordViewSheet.dash(e.createdBy.name)),
            RecordViewField('Recorded On', e.createdAt.listingDateTime),
            if (e.isCancelled) ...[
              RecordViewField('Cancelled By', RecordViewSheet.dash(e.cancelledByName)),
              if (e.cancelledAt != null)
                RecordViewField('Cancelled On', e.cancelledAt!.listingDateTime),
              RecordViewField('Cancellation Remarks', RecordViewSheet.dash(e.cancellationRemarks)),
            ],
          ]),
        ],
        extra: [
          if (e.attachments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Bill & Receipt Attachments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in e.attachments)
                  AttachmentPill(name: f.name, onOpen: () => previewAttachment(context, f)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
            ),
            onPressed: () => _voucher(e),
            icon: const Icon(Iconsax.document_download, size: 18),
            label: const Text('Download Voucher (PDF)'),
          ),
        ],
      ),
    );
    if (r == 'edit' && mounted) await _openForm(context, uid: e.uid);
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
          if (!_canView) return buildNoPermissionView(context);
          return ChangeNotifierProvider<PaginatedDataController<ExpenseModel>>.value(
            value: _controller,
            child: Consumer<PaginatedDataController<ExpenseModel>>(
              builder: (context, controller, _) => RefreshIndicator(
                onRefresh: _refresh,
                child: Scrollbar(
                  controller: _vScroll,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _vScroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      _header(context, isWide),
                      const SizedBox(height: 18),
                      _toolbar(context, controller, isWide),
                      const SizedBox(height: 12),
                      _filters(context, isWide),
                      const SizedBox(height: 18),
                      if (_refreshing)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (controller.paginatedItems.isEmpty)
                        NoData(
                          text: _items.isEmpty
                              ? 'No expenses found'
                              : 'No matching records found',
                        )
                      else if (isWide)
                        _table(context, controller)
                      else
                        _cards(context, controller),
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

  Widget _header(BuildContext context, bool isWide) {
    final boxes = [
      ExpenseStatBox(label: 'Total Bills', value: '${_stats.totalCount}'),
      ExpenseStatBox(
        label: 'Total Active Spent',
        value: expenseMoney.format(_stats.totalActiveAmount),
      ),
      ExpenseStatBox(
        label: 'Cancelled (${_stats.cancelledCount})',
        value: expenseMoney.format(_stats.totalCancelledAmount),
        tint: _cancelledRed,
      ),
    ];
    if (isWide) {
      return ExpenseBanner(
        title: 'Expenses',
        subtitle: 'Manage company expenditures, expense category allocation, and bills',
        icon: Iconsax.wallet_3,
        trailing: boxes,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ExpenseStatBox(
          label: 'Bills',
          value: '${_stats.totalCount}',
          onLight: true,
        ),
        ExpenseStatBox(
          label: 'Active Spent',
          value: expenseMoney.format(_stats.totalActiveAmount),
          onLight: true,
        ),
        ExpenseStatBox(
          label: 'Cancelled (${_stats.cancelledCount})',
          value: expenseMoney.format(_stats.totalCancelledAmount),
          tint: _cancelledRed,
          onLight: true,
        ),
      ],
    );
  }

  Widget _toolbar(
    BuildContext context,
    PaginatedDataController<ExpenseModel> controller,
    bool isWide,
  ) {
    final selected = _items
        .where((e) => !e.isCancelled && controller.selectedIds.contains(e.uid))
        .length;
    final buttons = <Widget>[
      IconButton(
        tooltip: 'Refresh',
        onPressed: _refreshing ? null : _refresh,
        icon: _refreshing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Iconsax.refresh),
      ),
      if (_canExport)
        OutlinedButton.icon(
          onPressed: _exporting ? null : _exportExcel,
          icon: _exporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Iconsax.export_3, size: 18),
          label: const Text('Export Excel'),
        ),
      if (selected > 0 && _canDelete)
        expenseGradientButton(
          context,
          icon: Icons.block_rounded,
          label: 'Cancel ($selected)',
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkCancel,
        ),
      if (_canCreate)
        expenseGradientButton(
          context,
          icon: Icons.add_rounded,
          label: 'Add Expense',
          onPressed: () => _openForm(context),
        ),
    ];
    final search = SizedBox(
      width: isWide ? 320 : double.infinity,
      child: ExpenseSearchField(
        hint: 'Search expense no, company...',
        onChanged: controller.setSearch,
      ),
    );
    return expenseCard(
      context,
      isWide
          ? Row(
              children: [
                search,
                const SizedBox(width: 12),
                expenseChip(
                  '${controller.filteredItems.length} total',
                  Theme.of(context).colorScheme.primary,
                ),
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
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onPicked,
  ) {
    final c = TextEditingController(
      text: value == null ? '' : DateFormat('dd-MM-yyyy').format(value),
    );
    return FormFields(
      key: ValueKey('${label}_${value?.toIso8601String()}_$_filterTick'),
      label: label,
      controller: c,
      hintText: 'dd-mm-yyyy',
      readOnly: true,
      suffixIcon: const Icon(Iconsax.calendar_1, size: 18),
      onTap: () async {
        final p = await pickDate(context, initialDate: value);
        if (p != null) {
          onPicked(DateFormat('dd-MM-yyyy').parse(p));
          await _applyFilters();
        }
      },
    );
  }

  Widget _filters(BuildContext context, bool isWide) {
    final from = _dateField('From Date', _from, (d) => setState(() => _from = d));
    final to = _dateField('To Date', _to, (d) => setState(() => _to = d));
    final company = FormDropdownSearch(
      key: ValueKey('f_comp_$_filterTick'),
      label: 'Our Company',
      initialItem: _company?.companyName,
      items: _companies.map((c) => c.companyName).toList(),
      onChanged: (v) {
        _company = _companies.where((c) => c.companyName == v).firstOrNull;
        _applyFilters();
      },
    );
    final category = FormDropdownSearch(
      key: ValueKey('f_cat_$_filterTick'),
      label: 'Expense Category',
      initialItem: _category?.name,
      items: _categories.map((c) => c.name).toList(),
      onChanged: (v) {
        _category = _categories.where((c) => c.name == v).firstOrNull;
        _applyFilters();
      },
    );
    final mode = FormDropdownSearch(
      key: ValueKey('f_mode_$_filterTick'),
      label: 'Payment Mode',
      initialItem: _mode,
      items: _modes,
      onChanged: (v) {
        _mode = v as String?;
        _applyFilters();
      },
    );
    final reset = _hasFilters
        ? TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Reset'),
          )
        : const SizedBox.shrink();
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
                const SizedBox(width: 8),
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

  // ── table (wide) ──────────────────────────────────────────────────────────

  Widget _actions(BuildContext context, ExpenseModel e) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        expenseIconButton(
          context,
          icon: Iconsax.eye,
          tooltip: 'View',
          color: AppColors.primary,
          onPressed: () => _view(e),
        ),
        if (_canEdit && !e.isCancelled) ...[
          const SizedBox(width: 8),
          expenseIconButton(
            context,
            icon: Iconsax.edit,
            tooltip: 'Edit',
            color: AppColors.info,
            onPressed: () => _openForm(context, uid: e.uid),
          ),
        ],
        if (_canDelete && !e.isCancelled) ...[
          const SizedBox(width: 8),
          expenseIconButton(
            context,
            icon: Iconsax.trash,
            tooltip: 'Cancel expense',
            color: AppColors.danger,
            onPressed: () => _cancel(e),
          ),
        ],
      ],
    );
  }

  Widget _table(BuildContext context, PaginatedDataController<ExpenseModel> controller) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall;
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
                      showCheckboxColumn: _canDelete,
                      sortColumnIndex: controller.sortColumnIndex,
                      sortAscending: controller.sortAscending,
                      headingRowColor: WidgetStateProperty.all(scheme.primary.withValues(alpha: 0.06)),
                      headingTextStyle: style?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                      columns: [
                        DataColumn(label: const Text('EXPENSE NO'), onSort: controller.setSort),
                        DataColumn(label: const Text('OUR COMPANY'), onSort: controller.setSort),
                        DataColumn(label: const Text('CATEGORY'), onSort: controller.setSort),
                        DataColumn(
                          label: const Text('AMOUNT'),
                          numeric: true,
                          onSort: controller.setSort,
                        ),
                        DataColumn(label: const Text('PAYMENT MODE'), onSort: controller.setSort),
                        DataColumn(label: const Text('EXPENSE DATE'), onSort: controller.setSort),
                        DataColumn(label: const Text('DESCRIPTION'), onSort: controller.setSort),
                        const DataColumn(label: Text('ACTION')),
                      ],
                      rows: [
                        for (final e in controller.paginatedItems)
                          DataRow(
                            selected: controller.selectedIds.contains(e.uid),
                            onSelectChanged: (_canDelete && !e.isCancelled)
                                ? (v) => controller.onSelected(e.uid, v)
                                : null,
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _view(e),
                                  child: Text(
                                    e.expenseNumber,
                                    style: style?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(e.masterCompanyName, style: style)),
                              DataCell(expenseChip(e.categoryName, e.categoryColor)),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      expenseMoney.format(e.amount),
                                      style: style?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: e.isCancelled ? scheme.outline : null,
                                        decoration:
                                            e.isCancelled ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    if (e.isCancelled)
                                      Text(
                                        'CANCELLED',
                                        style: style?.copyWith(
                                          fontSize: 9,
                                          color: _cancelledRed,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(expenseChip(e.paymentMode, scheme.onSurfaceVariant)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Iconsax.calendar_1, size: 13),
                                    const SizedBox(width: 5),
                                    Text(DateFormat('dd MMM yyyy').format(e.expenseDate), style: style),
                                  ],
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 220),
                                  child: Text(
                                    RecordViewSheet.dash(e.description),
                                    overflow: TextOverflow.ellipsis,
                                    style: style,
                                  ),
                                ),
                              ),
                              DataCell(_actions(context, e)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<ExpenseModel>(),
          ),
        ],
      ),
    );
  }

  // ── cards (mobile / narrow) ───────────────────────────────────────────────

  Widget _cards(BuildContext context, PaginatedDataController<ExpenseModel> controller) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final e in controller.paginatedItems)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: e.isCancelled ? _cancelledRed.withValues(alpha: 0.4) : scheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _view(e),
                        child: Text(
                          e.expenseNumber,
                          style: t.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      expenseMoney.format(e.amount),
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        decoration: e.isCancelled ? TextDecoration.lineThrough : null,
                        color: e.isCancelled ? scheme.outline : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(e.masterCompanyName, style: t.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    expenseChip(e.categoryName, e.categoryColor),
                    expenseChip(e.paymentMode, scheme.onSurfaceVariant),
                    if (e.isCancelled) expenseChip('Cancelled', _cancelledRed),
                  ],
                ),
                if (e.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    e.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelSmall,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Iconsax.calendar_1, size: 13),
                    const SizedBox(width: 5),
                    Text(DateFormat('dd MMM yyyy').format(e.expenseDate), style: t.labelSmall),
                    const Spacer(),
                    _actions(context, e),
                  ],
                ),
              ],
            ),
          ),
        const PaginationControls<ExpenseModel>(),
      ],
    );
  }
}