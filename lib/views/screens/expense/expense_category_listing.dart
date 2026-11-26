import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import 'expense_category_form.dart';
import 'expense_ui.dart';

const String _pageTitle = 'Expense Category';
const double _wideBreakpoint = 900;

/// Expense Category master. Access follows the role's "Expense Category"
/// permission (view / create / edit / delete); admin has everything.
class ExpenseCategoryListing extends StatefulWidget {
  const ExpenseCategoryListing({super.key});

  @override
  State<ExpenseCategoryListing> createState() => _ExpenseCategoryListingState();
}

class _ExpenseCategoryListingState extends State<ExpenseCategoryListing> {
  late final PaginatedDataController<ExpenseCategoryModel> _controller;
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();
  List<ExpenseCategoryModel> _all = [];
  PermissionModel? _permissions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = PaginatedDataController<ExpenseCategoryModel>(
      initialSortColumnIndex: 2,
      filterLogic: (c, q) {
        final s = q.toLowerCase();
        return c.name.toLowerCase().contains(s) ||
            c.description.toLowerCase().contains(s) ||
            c.createdBy.name.toLowerCase().contains(s);
      },
      sortLogic: (a, b, col, asc) {
        int r;
        switch (col) {
          case 0:
            r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 1:
            r = a.expenseCount.compareTo(b.expenseCount);
            break;
          case 2:
            r = a.createdAt.compareTo(b.createdAt);
            break;
          default:
            r = (a.uid ?? '').compareTo(b.uid ?? '');
        }
        return asc ? r : -r;
      },
      getItemId: (c) => c.uid ?? '',
    );
    _controller.setSort(2, false);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  Future<void> _load() async {
    try {
      _permissions = await PermissionService.getPermissions(_pageTitle);
      if (_permissions?.canView ?? false) {
        _all = await ExpenseCategoryService.getAll();
        _controller.setData(_all);
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

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _openForm(BuildContext context, {ExpenseCategoryModel? category}) async {
    final form = ExpenseCategoryForm(category: category);
    final dynamic val = _isWide(context)
        ? await GeneralDialog.showRTLSheet(context, form)
        : await Sheet.showSheet(context, widget: form);
    if (val is Map && val['status'] == true) await _load();
  }

  Future<void> _delete(ExpenseCategoryModel c) async {
    if (c.expenseCount > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Text(
            '"${c.name}" is used in ${c.expenseCount} expense bill(s) and cannot be deleted.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete $_pageTitle',
        content: 'Are you sure you want to delete "${c.name}"?',
      ),
    );
    if (ok != true || !mounted) return;
    try {
      futureLoading(context);
      try {
        await ExpenseCategoryService.delete(c.uid ?? '');
      } finally {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      await _load();
      if (mounted) FlushBar.show(context, 'Expense category deleted');
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    final chosen = _all.where((c) => _controller.selectedIds.contains(c.uid)).toList();
    if (chosen.isEmpty) return;
    final used = chosen.where((c) => c.expenseCount > 0).toList();
    if (used.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Text(
            'These categories are used in expense bills: ${used.map((e) => e.name).join(', ')}.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Delete $_pageTitle',
        content: 'Are you sure you want to delete ${chosen.length} categories?',
      ),
    );
    if (ok != true || !mounted) return;
    try {
      futureLoading(context);
      try {
        for (final c in chosen) {
          await ExpenseCategoryService.delete(c.uid ?? '');
        }
      } finally {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      _controller.clearSelection();
      await _load();
      if (mounted) FlushBar.show(context, 'Expense categories deleted');
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (mounted) FlushBar.show(context, e.toString(), isSuccess: false);
    }
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
          if (!(_permissions?.canView ?? false)) return buildNoPermissionView(context);
          return ChangeNotifierProvider<PaginatedDataController<ExpenseCategoryModel>>.value(
            value: _controller,
            child: Consumer<PaginatedDataController<ExpenseCategoryModel>>(
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
                        ExpenseBanner(
                          title: _pageTitle,
                          subtitle: 'Organize company expenses and financial tracking categories',
                          icon: Iconsax.category,
                          trailing: [
                            ExpenseStatBox(label: 'Categories', value: '${_all.length}'),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      _toolbar(context, controller, isWide),
                      const SizedBox(height: 18),
                      controller.paginatedItems.isEmpty
                          ? NoData(
                              text: _all.isEmpty
                                  ? 'No expense categories available'
                                  : 'No matching records found',
                            )
                          : isWide
                              ? _table(context, controller)
                              : _cards(context, controller),
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

  Widget _toolbar(
    BuildContext context,
    PaginatedDataController<ExpenseCategoryModel> controller,
    bool isWide,
  ) {
    final selected = controller.selectedIds.length;
    final buttons = <Widget>[
      if (_permissions?.canCreate ?? false)
        expenseGradientButton(
          context,
          icon: Icons.add_rounded,
          label: 'Add Category',
          onPressed: () => _openForm(context),
        ),
      if (selected > 0 && (_permissions?.canDelete ?? false))
        expenseGradientButton(
          context,
          icon: Iconsax.trash,
          label: 'Delete ($selected)',
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkDelete,
        ),
      IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Iconsax.refresh)),
    ];
    final search = SizedBox(
      width: isWide ? 300 : double.infinity,
      child: ExpenseSearchField(hint: 'Search category...', onChanged: controller.setSearch),
    );
    return expenseCard(
      context,
      isWide
          ? Row(
              children: [
                search,
                const SizedBox(width: 12),
                expenseChip('${_all.length} total', Theme.of(context).colorScheme.primary),
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
    );
  }

  Widget _avatar(ExpenseCategoryModel c, {double size = 32}) {
    final letter = c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        letter,
        style: TextStyle(color: c.color, fontWeight: FontWeight.bold, fontSize: size * 0.45),
      ),
    );
  }

  Widget _actions(BuildContext context, ExpenseCategoryModel c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_permissions?.canEdit ?? false)
          expenseIconButton(
            context,
            icon: Iconsax.edit,
            tooltip: 'Edit',
            color: AppColors.info,
            onPressed: () => _openForm(context, category: c),
          ),
        if ((_permissions?.canEdit ?? false) && (_permissions?.canDelete ?? false))
          const SizedBox(width: 8),
        if (_permissions?.canDelete ?? false)
          expenseIconButton(
            context,
            icon: Iconsax.trash,
            tooltip: 'Delete',
            color: AppColors.danger,
            onPressed: () => _delete(c),
          ),
      ],
    );
  }

  Widget _table(BuildContext context, PaginatedDataController<ExpenseCategoryModel> controller) {
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
                      showCheckboxColumn: _permissions?.canDelete ?? false,
                      sortColumnIndex: controller.sortColumnIndex,
                      sortAscending: controller.sortAscending,
                      headingRowColor: WidgetStateProperty.all(scheme.primary.withValues(alpha: 0.06)),
                      headingTextStyle: style?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                      columns: [
                        DataColumn(label: const Text('CATEGORY NAME'), onSort: controller.setSort),
                        DataColumn(label: const Text('EXPENSES BILL'), onSort: controller.setSort),
                        DataColumn(label: const Text('CREATED DATE'), onSort: controller.setSort),
                        const DataColumn(label: Text('CREATED BY')),
                        const DataColumn(label: Text('ACTION')),
                      ],
                      rows: [
                        for (final c in controller.paginatedItems)
                          DataRow(
                            selected: controller.selectedIds.contains(c.uid),
                            onSelectChanged: (_permissions?.canDelete ?? false)
                                ? (v) => controller.onSelected(c.uid ?? '', v)
                                : null,
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _avatar(c),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: style?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        if (c.description.isNotEmpty)
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 240),
                                            child: Text(
                                              c.description,
                                              overflow: TextOverflow.ellipsis,
                                              style: style?.copyWith(
                                                fontSize: 10,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                expenseChip(
                                  '${c.expenseCount} ${c.expenseCount == 1 ? 'bill' : 'bills'}',
                                  scheme.onSurfaceVariant,
                                ),
                              ),
                              DataCell(Text(c.createdAt.listingDateTime, style: style)),
                              DataCell(CreatedByWidget(userData: c.createdBy)),
                              DataCell(_actions(context, c)),
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
            child: PaginationControls<ExpenseCategoryModel>(),
          ),
        ],
      ),
    );
  }

  Widget _cards(BuildContext context, PaginatedDataController<ExpenseCategoryModel> controller) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final c in controller.paginatedItems)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                _avatar(c, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${c.expenseCount} ${c.expenseCount == 1 ? 'bill' : 'bills'} • ${c.createdAt.listingDateTime}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                _actions(context, c),
              ],
            ),
          ),
        const PaginationControls<ExpenseCategoryModel>(),
      ],
    );
  }
}