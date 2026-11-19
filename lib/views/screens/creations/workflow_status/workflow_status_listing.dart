import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'workflow_status_form.dart';

const double _wideBreakpoint = 900;

/// Creation -> Task Status.
class TaskStatusListing extends StatelessWidget {
  const TaskStatusListing({super.key});
  @override
  Widget build(BuildContext context) =>
      const WorkflowStatusListing(service: WorkflowStatusService.task);
}

/// Creation -> Ticket Status.
class TicketStatusListing extends StatelessWidget {
  const TicketStatusListing({super.key});
  @override
  Widget build(BuildContext context) =>
      const WorkflowStatusListing(service: WorkflowStatusService.ticket);
}

/// Task Status / Ticket Status master. Same UI pattern as Lead Status / Deal
/// Status (banner, toolbar, DataTable, pagination, side form). Access is
/// role based through the page names "Task Status" / "Ticket Status".
class WorkflowStatusListing extends StatelessWidget {
  final WorkflowStatusService service;
  const WorkflowStatusListing({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PaginatedDataController<WorkflowStatus>(
        initialSortColumnIndex: 1,
        filterLogic: (s, query) {
          final q = query.toLowerCase();
          return s.name.toLowerCase().contains(q) ||
              s.statusKey.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q);
        },
        sortLogic: (a, b, col, asc) {
          int compare;
          switch (col) {
            case 1:
              compare = a.orderIndex.compareTo(b.orderIndex);
              break;
            case 2:
              compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
              break;
            default:
              compare = a.uid.compareTo(b.uid);
              break;
          }
          return asc ? compare : -compare;
        },
        getItemId: (s) => s.uid,
      ),
      child: WorkflowStatusListingView(service: service),
    );
  }
}

class WorkflowStatusListingView extends StatefulWidget {
  final WorkflowStatusService service;
  const WorkflowStatusListingView({super.key, required this.service});

  @override
  State<WorkflowStatusListingView> createState() =>
      _WorkflowStatusListingViewState();
}

class _WorkflowStatusListingViewState extends State<WorkflowStatusListingView> {
  final List<WorkflowStatus> _selected = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  StreamSubscription<List<WorkflowStatus>>? _sub;
  List<WorkflowStatus>? _list;
  Object? _error;

  String get _pageTitle => widget.service.label;
  bool get _isTicket => widget.service.isTicket;
  String get _noun => _isTicket ? 'ticket' : 'task';

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    // Reloads when the master (or the tasks / tickets using it) change.
    final controller = context.read<PaginatedDataController<WorkflowStatus>>();
    _sub = ApiLive.watch({
      widget.service.type,
      _isTicket ? 'tickets' : 'tasks',
    }, () => widget.service.getAll()).listen(
      (l) {
        if (!mounted) return;
        controller.setData(l);
        setState(() {
          _list = l;
          _error = null;
        });
      },
      onError: (e) {
        if (mounted) setState(() => _error = e);
      },
    );
    _loadPermissions();
  }

  @override
  void dispose() {
    _sub?.cancel();
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

  Future<void> _refresh() async {
    ApiLive.changed({widget.service.type});
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<WorkflowStatus>>();
    final controllerWatch = context.watch<PaginatedDataController<WorkflowStatus>>();
    final isWide = _isWide(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: Text(_pageTitle),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: Builder(
        builder: (context) {
          if (_error != null && _list == null) {
            return Center(
              child: Text(
                '$_error',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          if (_list == null || !_permissionsLoaded) {
            return const WaitingLoading();
          }
          if (!(permissions?.canView ?? false)) {
            return buildNoPermissionView(context);
          }
          final list = _list!;
          return RefreshIndicator(
            onRefresh: _refresh,
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
                    _buildHeaderBanner(context, list.length),
                    const SizedBox(height: 20),
                  ],
                  _buildToolbar(context, controllerRead, list),
                  const SizedBox(height: 18),
                  controllerWatch.paginatedItems.isEmpty
                      ? NoData(
                          text: list.isEmpty
                              ? "No ${_pageTitle.toLowerCase()} available"
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
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header banner (desktop only)
  // ---------------------------------------------------------------------
  Widget _buildHeaderBanner(BuildContext context, int totalStatuses) {
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
            child: Icon(
              (widget.service.isTicket ? Iconsax.ticket : Iconsax.task),
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
                  "$_pageTitle Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Define the statuses your ${_noun}s move through",
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
                  '$totalStatuses',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalStatuses == 1 ? "Status" : "Statuses",
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
    PaginatedDataController<WorkflowStatus> controllerRead,
    List<WorkflowStatus> list,
  ) {
    final isWide = _isWide(context);

    final buttons = <Widget>[
      if (permissions?.canCreate ?? false)
        _gradientButton(
          context: context,
          icon: Icons.add_rounded,
          label: "Add $_pageTitle",
          colors: _brandGradient,
          onPressed: () => _openForm(null),
        ),
      if (_selected.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selected.length})",
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
          onPressed: _refresh,
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
                _statusCountChip(context, list.length),
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

  Widget _statusCountChip(BuildContext context, int totalStatuses) {
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
            (widget.service.isTicket ? Iconsax.ticket : Iconsax.task),
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "$totalStatuses total",
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
    return _WorkflowStatusSearchField(
      pageTitle: _pageTitle,
      onChanged: context
          .read<PaginatedDataController<WorkflowStatus>>()
          .setSearch,
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

  // ---------------------------------------------------------------------
  // Table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<WorkflowStatus> controllerWatch,
    PaginatedDataController<WorkflowStatus> controllerRead,
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
                            label: const Text("No"),
                            onSort: controllerRead.setSort,
                          ),
                          DataColumn(
                            label: const Text("Name"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("System Key")),
                          const DataColumn(label: Text("Color")),
                          DataColumn(
                            label: Text(
                              _isTicket
                                  ? "Closure / Finalization"
                                  : "Completion Flag",
                            ),
                          ),
                          DataColumn(label: Text(_isTicket ? "Tickets" : "Tasks")),
                          const DataColumn(label: Text("Created")),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(
                          controllerWatch.paginatedItems.length,
                          (index) => _buildDataRow(
                            context,
                            controllerWatch.paginatedItems[index],
                            controllerWatch,
                            controllerRead,
                            index,
                          ),
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
            child: PaginationControls<WorkflowStatus>(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    WorkflowStatus status,
    PaginatedDataController<WorkflowStatus> controllerWatch,
    PaginatedDataController<WorkflowStatus> controllerRead,
    int index,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(status.uid);
    final statusColor = Color(status.color);
    final flagColor = status.isFinal ? AppColors.success : Colors.blueGrey;
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
        controllerRead.onSelected(status.uid, selected);
        if (selected ?? false) {
          _selected.add(status);
        } else {
          _selected.remove(status);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${status.orderIndex}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                status.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (status.isFinal) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.tick_circle,
                        size: 11,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Final",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.statusKey.isEmpty ? '-' : status.statusKey,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${(status.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: flagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.isFinal
                  ? (_isTicket ? "Closes Ticket" : "Completes Task")
                  : "Active State",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: flagColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            '${status.usageCount} $_noun(s)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: status.isAssigned ? AppColors.primary : null,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.calendar_1,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                status.createdAt?.listingDateTime ?? '-',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DataCell(
          CreatedByWidget(
            userData: UserDataModel(
              uid: '',
              name: status.createdByName,
              profilePic: status.createdByPhoto,
              userType: UserType.employee,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (permissions?.canEdit ?? false)
                _iconCircleButton(
                  context,
                  icon: Iconsax.edit,
                  tooltip: "Edit",
                  background: AppColors.info.withValues(alpha: 0.12),
                  iconColor: AppColors.info,
                  onPressed: () => _openForm(status),
                ),
              if ((permissions?.canEdit ?? false) &&
                  (permissions?.canDelete ?? false))
                const SizedBox(width: 8),
              if (permissions?.canDelete ?? false)
                _iconCircleButton(
                  context,
                  icon: Iconsax.trash,
                  tooltip: status.isAssigned
                      ? "Assigned to ${status.usageCount} $_noun(s) - cannot delete"
                      : "Delete",
                  background: AppColors.danger.withValues(
                    alpha: status.isAssigned ? 0.05 : 0.12,
                  ),
                  iconColor: status.isAssigned
                      ? AppColors.danger.withValues(alpha: 0.35)
                      : AppColors.danger,
                  onPressed: () => _onDeleteTap(status),
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
  void _openForm(WorkflowStatus? status) {
    final form = WorkflowStatusForm(service: widget.service, status: status);
    if (kIsMobile || !_isWide(context)) {
      Sheet.showSheet(context, widget: form);
    } else {
      GeneralDialog.showRTLSheet(context, form);
    }
  }

  Future<void> _cannotDelete(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot Delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _onDeleteTap(WorkflowStatus status) async {
    // An assigned status can never be deleted.
    if (status.isAssigned) {
      await _cannotDelete(
        'This ${_pageTitle.toLowerCase()} is assigned to ${status.usageCount} $_noun(s) and cannot be deleted.',
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
      barrierDismissible: false,
    );
    if (result != true || !mounted) return;

    try {
      await widget.service.delete(status.uid);
      if (!mounted) return;
      FlushBar.show(context, '$_pageTitle deleted successfully');
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      // The server also blocks statuses that were assigned in the past.
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;

    if (_selected.any((s) => s.isAssigned)) {
      await _cannotDelete(
        'One or more selected statuses are assigned to ${_noun}s and cannot be deleted.',
      );
      return;
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
    if (result != true || !mounted) return;

    try {
      final items = List<WorkflowStatus>.from(_selected);
      futureLoading(context);
      for (final s in items) {
        await widget.service.delete(s.uid);
      }
      if (Navigator.canPop(context)) Navigator.pop(context);

      _selected.clear();
      context.read<PaginatedDataController<WorkflowStatus>>().clearSelection();
      setState(() {});

      if (!mounted) return;
      FlushBar.show(context, '$_pageTitle deleted successfully');
    } catch (e, st) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(
        context,
        'Failed to delete $_pageTitle: $e',
        isSuccess: false,
      );
    }
  }
}

// ---------------------------------------------------------------------
// A more polished, colorful search field for the Lead Status toolbar.
// ---------------------------------------------------------------------
class _WorkflowStatusSearchField extends StatefulWidget {
  final String pageTitle;
  final ValueChanged<String> onChanged;
  const _WorkflowStatusSearchField({
    required this.pageTitle,
    required this.onChanged,
  });

  @override
  State<_WorkflowStatusSearchField> createState() =>
      _WorkflowStatusSearchFieldState();
}

class _WorkflowStatusSearchFieldState extends State<_WorkflowStatusSearchField> {
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