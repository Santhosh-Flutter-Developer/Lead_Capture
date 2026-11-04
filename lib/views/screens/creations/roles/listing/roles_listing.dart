import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/models/models.dart';
import 'bloc/roles_bloc.dart';

const String _pageTitle = "Role";
const double _wideBreakpoint = 900;

class RolesListing extends StatelessWidget {
  const RolesListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RolesBloc()..add(StreamRoles()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<RoleModel>(
          initialSortColumnIndex: 1,
          filterLogic: (role, query) {
            final q = query.toLowerCase();
            return role.name.toLowerCase().contains(q) ||
                role.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 0:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              case 1:
                compare = a.description.toLowerCase().compareTo(
                  b.description.toLowerCase(),
                );
                break;
              case 3:
                compare = a.createdAt.compareTo(b.createdAt);
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (role) => role.uid ?? '',
        ),
        child: const RolesListingView(),
      ),
    );
  }
}

class RolesListingView extends StatefulWidget {
  const RolesListingView({super.key});

  @override
  State<RolesListingView> createState() => _RolesListingViewState();
}

class _RolesListingViewState extends State<RolesListingView> {
  final List<RoleModel> _selectedRoles = [];
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  final ScrollController _hScrollController = ScrollController();
final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    if (!mounted) return;
    setState(() => _permissionsLoaded = true);
  }

  Future<void> _refreshRoles() async {
    context.read<RolesBloc>().add(StreamRoles());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<RoleModel>>();
    final controllerWatch =
        context.watch<PaginatedDataController<RoleModel>>();
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
      body: BlocListener<RolesBloc, RolesState>(
        listenWhen: (previous, current) => current is RolesLoaded,
        listener: (context, state) {
          if (state is RolesLoaded) {
            controllerRead.setData(state.roles);
          }
        },
        child: BlocBuilder<RolesBloc, RolesState>(
          builder: (context, state) {
            if (state is RolesLoading) {
              return const WaitingLoading();
            }

            if (state is RolesLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshRoles(),
                child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 24.0 : 14.0),
                    children: [
                      if (isWide) ...[
                        _buildHeaderBanner(context, state.roles.length),
                        const SizedBox(height: 20),
                      ],
                      _buildToolbar(context, controllerRead, state.roles.length),
                      const SizedBox(height: 18),
                      controllerWatch.paginatedItems.isEmpty
                          ? NoData(
                              text: state.roles.isEmpty
                                  ? "No roles available"
                                  : "No matching records found",
                            )
                          : _buildTableCard(
                              context,
                              controllerWatch,
                              controllerRead,
                              state.employeeCounts,
                            ),
                    ],
                  ),
                ),
              );
            }

            if (state is RolesError) {
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
  Widget _buildHeaderBanner(BuildContext context, int totalRoles) {
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
              Iconsax.shield_tick,
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
                  "Role Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Create roles and fine-tune what each team member can access",
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
                  '$totalRoles',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalRoles == 1 ? "Role" : "Roles",
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
    PaginatedDataController<RoleModel> controllerRead,
    int totalRoles,
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
                  Sheet.showSheet(context, widget: const RoleCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const RoleCreate());
                }
              },
            ),
      if (_selectedRoles.isNotEmpty && (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedRoles.length})",
          colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
          onPressed: _bulkDelete,
        ),
      if (isWide)
        _iconCircleButton(
          context,
          icon: Iconsax.refresh,
          tooltip: "Refresh",
          background: Theme.of(context).colorScheme.primary.withValues(
            alpha: 0.1,
          ),
          iconColor: Theme.of(context).colorScheme.primary,
          onPressed: _refreshRoles,
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
                _roleCountChip(context, totalRoles),
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

  Widget _roleCountChip(BuildContext context, int totalRoles) {
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
            Iconsax.security_user,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "$totalRoles total",
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
    return _RoleSearchField(
      pageTitle: _pageTitle,
      onChanged: context.read<PaginatedDataController<RoleModel>>().setSearch,
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

  Widget _avatarCircle(String name, {double size = 38}) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = LetterColors.getColor(letter);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  Widget _employeeCountChip(BuildContext context, int count) {
    final color = count > 0
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.people, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _superAdminBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.crown_1, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            "Protected",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Desktop / wide layout: table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<RoleModel> controllerWatch,
    PaginatedDataController<RoleModel> controllerRead,
    Map<String, int> employeeCounts,
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
                          DataColumn(
                            label: const Text("Description"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(
                            label: Text("Employees"),
                            numeric: true,
                          ),
                          DataColumn(
                            label: const Text("Created"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(controllerWatch.paginatedItems.length, (
                          index,
                        ) {
                          final role = controllerWatch.paginatedItems[index];
                          return _buildDataRow(
                            context,
                            role,
                            controllerWatch,
                            controllerRead,
                            index,
                            employeeCounts[role.uid ?? ''] ?? 0,
                          );
                        }),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: PaginationControls<RoleModel>(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    RoleModel role,
    PaginatedDataController<RoleModel> controllerWatch,
    PaginatedDataController<RoleModel> controllerRead,
    int index,
    int employeeCount,
  ) {
    final isSuperAdmin = role.isSuperAdmin;
    final isSelected = controllerWatch.selectedIds.contains(role.uid);
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
      onSelectChanged: isSuperAdmin
          ? null
          : (selected) {
              controllerRead.onSelected(role.uid ?? '', selected);
              if (selected ?? false) {
                _selectedRoles.add(role);
              } else {
                _selectedRoles.remove(role);
              }
              setState(() {});
            },
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatarCircle(role.name, size: 32),
              const SizedBox(width: 10),
              Text(
                role.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (isSuperAdmin) ...[
                const SizedBox(width: 8),
                _superAdminBadge(context),
              ],
            ],
          ),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              role.description.isNotEmpty ? role.description : "—",
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        DataCell(_employeeCountChip(context, employeeCount)),
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
                role.createdAt.listingDateTime,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DataCell(CreatedByWidget(userData: role.createdBy)),
        DataCell(
          isSuperAdmin
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (permissions?.canEdit ?? false) _iconCircleButton(
                            context,
                            icon: Iconsax.edit,
                            tooltip: "Edit",
                            background: AppColors.info.withValues(alpha: 0.12),
                            iconColor: AppColors.info,
                            onPressed: () => _onEditTap(role),
                          ),
                    if ((permissions?.canEdit ?? false) && (permissions?.canDelete ?? false))
                      const SizedBox(width: 8),
                    if (permissions?.canDelete ?? false) _iconCircleButton(
                            context,
                            icon: Iconsax.trash,
                            tooltip: "Delete",
                            background: AppColors.danger.withValues(
                              alpha: 0.12,
                            ),
                            iconColor: AppColors.danger,
                            onPressed: () => _onDeleteTap(role),
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
  void _onEditTap(RoleModel role) {
    final isWide = _isWide(context);
    if (!isWide) {
      Sheet.showSheet(context, widget: RoleEdit(uid: role.uid ?? ''));
    } else {
      GeneralDialog.showRTLSheet(context, RoleEdit(uid: role.uid ?? ''));
    }
  }

  Future<void> _onDeleteTap(RoleModel role) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete $_pageTitle',
        content: 'Are you sure want to delete this $_pageTitle?',
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedRole = role.copyWith();

      await RoleService.deleteRole(uid: role.uid ?? '');

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          if (deletedRole.uid == null) return;
          await RoleService.restoreRole(deletedRole);
          if (!mounted) return;
          context.read<RolesBloc>().add(StreamRoles());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false, error: e, stackTrace: st);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedRoles.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete',
        content: 'Are you sure want to delete this $_pageTitle?',
      ),
      barrierDismissible: false,
    );

    if (result != true) return;
    if (!mounted) return;

    try {
      final deletedRoles = _selectedRoles.map((e) => e.copyWith()).toList();

      futureLoading(context);

      for (var role in deletedRoles) {
        if (role.isSuperAdmin) continue;
        await RoleService.deleteRole(uid: role.uid ?? '');
      }

      if (Navigator.canPop(context)) Navigator.pop(context);

      _selectedRoles.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var role in deletedRoles) {
            if (role.uid == null) continue;
            await RoleService.restoreRole(role);
          }
          if (!mounted) return;
          context.read<RolesBloc>().add(StreamRoles());
        },
      );
    } catch (e, st) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }
}

// ---------------------------------------------------------------------
// A more polished, colorful search field for the Role listing toolbar.
// ---------------------------------------------------------------------
class _RoleSearchField extends StatefulWidget {
  final String pageTitle;
  final ValueChanged<String> onChanged;
  const _RoleSearchField({required this.pageTitle, required this.onChanged});

  @override
  State<_RoleSearchField> createState() => _RoleSearchFieldState();
}

class _RoleSearchFieldState extends State<_RoleSearchField> {
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
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}