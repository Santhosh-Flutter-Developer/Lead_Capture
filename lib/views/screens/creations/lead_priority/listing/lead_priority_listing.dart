import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/lead_priority_bloc.dart';

const String _pageTitle = "Lead Priority";
const double _wideBreakpoint = 900;

class LeadPriorityListing extends StatelessWidget {
  const LeadPriorityListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeadPriorityBloc()..add(StreamLeadPriority()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<LeadPriorityModel>(
          initialSortColumnIndex: 1,
          filterLogic: (leadPriority, query) {
            final q = query.toLowerCase();
            return leadPriority.name.toLowerCase().contains(q) ||
                leadPriority.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 2:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (leadPriority) => leadPriority.uid ?? '',
        ),
        child: const LeadPriorityListingView(),
      ),
    );
  }
}

class LeadPriorityListingView extends StatefulWidget {
  const LeadPriorityListingView({super.key});

  @override
  State<LeadPriorityListingView> createState() =>
      _LeadPriorityListingViewState();
}

class _LeadPriorityListingViewState extends State<LeadPriorityListingView> {
  final List<LeadPriorityModel> _selectedLeadPriorities = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  final ScrollController _hScrollController = ScrollController();
final ScrollController _vScrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {  
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

  Future<void> _refreshLeadPriority() async {
    context.read<LeadPriorityBloc>().add(StreamLeadPriority());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead =
        context.read<PaginatedDataController<LeadPriorityModel>>();
    final controllerWatch =
        context.watch<PaginatedDataController<LeadPriorityModel>>();
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
      body: BlocListener<LeadPriorityBloc, LeadPriorityState>(
        listenWhen: (previous, current) => current is LeadPriorityLoaded,
        listener: (context, state) {
          if (state is LeadPriorityLoaded) {
            controllerRead.setData(state.leadPriority);
          }
        },
        child: BlocBuilder<LeadPriorityBloc, LeadPriorityState>(
          builder: (context, state) {
            if (state is LeadPriorityLoading) {
              return const WaitingLoading();
            }

            if (state is LeadPriorityLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: _refreshLeadPriority,
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
                        _buildHeaderBanner(context, state.leadPriority.length),
                        const SizedBox(height: 20),
                      ],
                      _buildToolbar(
                        context,
                        controllerRead,
                        state.leadPriority.length,
                      ),
                      const SizedBox(height: 18),
                      controllerWatch.paginatedItems.isEmpty
                          ? NoData(
                              text: state.leadPriority.isEmpty
                                  ? "No lead priorities available"
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
            }

            if (state is LeadPriorityError) {
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
  // Header banner (desktop only)
  // ---------------------------------------------------------------------
  Widget _buildHeaderBanner(BuildContext context, int totalPriorities) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
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
              Iconsax.flag,
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
                  "Lead Priority Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Define priority levels to triage your leads",
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
                  '$totalPriorities',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalPriorities == 1 ? "Priority" : "Priorities",
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
    PaginatedDataController<LeadPriorityModel> controllerRead,
    int totalPriorities,
  ) {
    final isWide = _isWide(context);

    final buttons = <Widget>[
      if (permissions?.canCreate ?? false) _gradientButton(
              context: context,
              icon: Icons.add_rounded,
              label: "Add $_pageTitle",
              colors: const [
                Color(0xFF0052D4),
                Color(0xFF4364F7),
                Color(0xFF6FB1FC),
              ],
              onPressed: () {
                if (kIsMobile || !isWide) {
                  Sheet.showSheet(context, widget: const LeadPriorityCreate());
                } else {
                  GeneralDialog.showRTLSheet(
                    context,
                    const LeadPriorityCreate(),
                  );
                }
              },
            ),
      if (_selectedLeadPriorities.isNotEmpty &&
          (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedLeadPriorities.length})",
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
          onPressed: _refreshLeadPriority,
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
                _priorityCountChip(context, totalPriorities),
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

  Widget _priorityCountChip(BuildContext context, int totalPriorities) {
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
            Iconsax.flag,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "$totalPriorities total",
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
    return _LeadPrioritySearchField(
      pageTitle: _pageTitle,
      onChanged: context
          .read<PaginatedDataController<LeadPriorityModel>>()
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
  // Desktop / wide layout: table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<LeadPriorityModel> controllerWatch,
    PaginatedDataController<LeadPriorityModel> controllerRead,
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
                            label: const Text("Name"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Color")),
                          const DataColumn(label: Text("Created")),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(
                          controllerWatch.paginatedItems.length,
                          (index) {
                            final leadPriority =
                                controllerWatch.paginatedItems[index];
                            return _buildDataRow(
                              context,
                              leadPriority,
                              controllerWatch,
                              controllerRead,
                              index,
                            );
                          },
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
            child: PaginationControls<LeadPriorityModel>(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    LeadPriorityModel leadPriority,
    PaginatedDataController<LeadPriorityModel> controllerWatch,
    PaginatedDataController<LeadPriorityModel> controllerRead,
    int index,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(leadPriority.uid);
    final priorityColor = Color(leadPriority.color);
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
        controllerRead.onSelected(leadPriority.uid ?? '', selected);
        if (selected ?? false) {
          _selectedLeadPriorities.add(leadPriority);
        } else {
          _selectedLeadPriorities.remove(leadPriority);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                leadPriority.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: priorityColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
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
                leadPriority.createdAt.listingDateTime,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DataCell(CreatedByWidget(userData: leadPriority.createdBy)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (permissions?.canEdit ?? false) _iconCircleButton(
                      context,
                      icon: Iconsax.edit,
                      tooltip: "Edit",
                      background: AppColors.info.withValues(alpha: 0.12),
                      iconColor: AppColors.info,
                      onPressed: () => _onEditTap(leadPriority),
                    ),
              if ((permissions?.canEdit ?? false) && (permissions?.canDelete ?? false))
                const SizedBox(width: 8),
              if (permissions?.canDelete ?? false) _iconCircleButton(
                      context,
                      icon: Iconsax.trash,
                      tooltip: "Delete",
                      background: AppColors.danger.withValues(alpha: 0.12),
                      iconColor: AppColors.danger,
                      onPressed: () => _onDeleteTap(leadPriority),
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
  void _onEditTap(LeadPriorityModel leadPriority) {
    final isWide = _isWide(context);
    if (!isWide) {
      Sheet.showSheet(
        context,
        widget: LeadPriorityEdit(uid: leadPriority.uid ?? ''),
      );
    } else {
      GeneralDialog.showRTLSheet(
        context,
        LeadPriorityEdit(uid: leadPriority.uid ?? ''),
      );
    }
  }

  Future<void> _onDeleteTap(LeadPriorityModel leadPriority) async {
    final isAssigned = await LeadPriorityService.isLeadPriorityAssigned(
      leadPriority.uid ?? '',
    );

    if (isAssigned) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text(
            'This lead priority is associated with one or more leads and cannot be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
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
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedPriority = leadPriority.copyWith();

      await LeadPriorityService.deleteLeadPriority(
        uid: leadPriority.uid ?? '',
      );

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          if (deletedPriority.uid == null) return;
          await LeadPriorityService.restoreLeadPriority(deletedPriority);
          if (!mounted) return;
          context.read<LeadPriorityBloc>().add(StreamLeadPriority());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedLeadPriorities.isEmpty) return;

    for (var priority in _selectedLeadPriorities) {
      final isAssigned = await LeadPriorityService.isLeadPriorityAssigned(
        priority.uid ?? '',
      );

      if (isAssigned) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: const Text(
              'One or more selected priorities are associated with leads.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
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

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedPriorities = _selectedLeadPriorities
          .map((e) => e.copyWith())
          .toList();

      futureLoading(context);

      for (var priority in deletedPriorities) {
        await LeadPriorityService.deleteLeadPriority(uid: priority.uid ?? '');
      }

      if (Navigator.canPop(context)) Navigator.pop(context);

      _selectedLeadPriorities.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var priority in deletedPriorities) {
            if (priority.uid == null) continue;
            await LeadPriorityService.restoreLeadPriority(priority);
          }
          if (!mounted) return;
          context.read<LeadPriorityBloc>().add(StreamLeadPriority());
        },
      );
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
// A more polished, colorful search field for the Lead Priority toolbar.
// ---------------------------------------------------------------------
class _LeadPrioritySearchField extends StatefulWidget {
  final String pageTitle;
  final ValueChanged<String> onChanged;
  const _LeadPrioritySearchField({
    required this.pageTitle,
    required this.onChanged,
  });

  @override
  State<_LeadPrioritySearchField> createState() =>
      _LeadPrioritySearchFieldState();
}

class _LeadPrioritySearchFieldState extends State<_LeadPrioritySearchField> {
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