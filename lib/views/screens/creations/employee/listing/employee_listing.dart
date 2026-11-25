import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/views/screens/creations/employee/form/employee_upload.dart';
import 'package:provider/provider.dart';
import '../form/employee_create.dart';
import '../form/employee_details.dart';
import '../form/employee_edit.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/views/views.dart';
import 'package:flutter/foundation.dart';
import '/utils/utils.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import '/theme/theme.dart';
import 'bloc/employee_bloc.dart';

const String _pageTitle = "Employees";

/// Role-filter value used for administrators (they have no role row).
const String _kAdminRole = '__admin__';

// Sort column ids (what `PaginatedDataController.sortColumnIndex` holds).
const int _sId = 0;
const int _sName = 1;
const int _sDept = 2;
const int _sEmail = 3;
const int _sStatus = 4;

/// One table column: header label, relative width and (optional) sort id.
class _Col {
  final String label;
  final double flex;
  final int? sortId;
  const _Col(this.label, this.flex, [this.sortId]);
}

const _cId = _Col('Employee ID', 1.1, _sId);
const _cName = _Col('Name', 1.9, _sName);
const _cDept = _Col('Department', 1.7, _sDept);
const _cRole = _Col('Role', 1.2);
const _cEmail = _Col('Email', 1.9, _sEmail);
const _cMobile = _Col('Mobile app', 1.35);
const _cDesktop = _Col('Desktop app', 1.35);
const _cStatus = _Col('Status', 0.95, _sStatus);
const _cCreated = _Col('Created By', 1.6);
const _cAction = _Col('Action', 1.3);
const List<_Col> _columns = [
  _cId,
  _cName,
  _cDept,
  _cRole,
  _cEmail,
  _cMobile,
  _cDesktop,
  _cStatus,
  _cCreated,
  _cAction,
];

const double _kCheckW = 48;
const double _kMinTableWidth = 1640;

class EmployeeListing extends StatelessWidget {
  const EmployeeListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UsersBloc()..add(StreamUsers()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<UserRowModel>(
          initialSortColumnIndex: _sId,
          filterLogic: (employee, query) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) return true;
            return employee.name.toLowerCase().contains(q) ||
                employee.email.toLowerCase().contains(q) ||
                (employee.employeeId ?? '').toLowerCase().contains(q) ||
                employee.mobileNumber.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case _sId:
                compare = (a.employeeId ?? '').toLowerCase().compareTo(
                  (b.employeeId ?? '').toLowerCase(),
                );
                break;
              case _sName:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              case _sDept:
                compare = _departmentText(a).toLowerCase().compareTo(
                  _departmentText(b).toLowerCase(),
                );
                break;
              case _sEmail:
                compare = a.email.toLowerCase().compareTo(
                  b.email.toLowerCase(),
                );
                break;
              case _sStatus:
                compare = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
                break;
              default:
                compare = a.uid.compareTo(b.uid);
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (employee) => employee.uid,
        )..setSort(_sId, false), // newest / highest Employee ID first
        child: const EmployeeListingView(),
      ),
    );
  }
}

/// "Sales & Marketing, Finance" - names of every department of [u].
String _departmentText(UserRowModel u) {
  final d = u.department;
  if (d == null || d.isEmpty) return '';
  return d
      .map((uid) => CacheService.departmentByUid(uid)?.name ?? '')
      .where((n) => n.isNotEmpty)
      .join(', ');
}

class EmployeeListingView extends StatefulWidget {
  const EmployeeListingView({super.key});

  @override
  State<EmployeeListingView> createState() => _EmployeeListingViewState();
}

class _EmployeeListingViewState extends State<EmployeeListingView> {
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  PermissionModel? tasksPermissions;
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chatMessage = TextEditingController();

  // ── Filters ('' = "All") ──
  String _fRole = '';
  String _fDept = '';
  String _fStatus = ''; // '', 'active', 'inactive'

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    _scrollController.dispose();
    _chatMessage.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    tasksPermissions = await PermissionService.getPermissions('Tasks');
    if (!mounted) return;
    _permissionsLoaded = true;
    setState(() {});
  }

  Future<void> _refreshUsers() async {
    context.read<UsersBloc>().add(StreamUsers());
  }

  // ───────────────────────── filters ─────────────────────────

  bool get _hasActiveFilters =>
      _fRole.isNotEmpty || _fDept.isNotEmpty || _fStatus.isNotEmpty;

  bool _matches(UserRowModel u) {
    if (_fRole.isNotEmpty) {
      if (_fRole == _kAdminRole) {
        if (!u.isAdmin) return false;
      } else if ((u.role ?? '') != _fRole) {
        return false;
      }
    }
    if (_fDept.isNotEmpty &&
        !(u.department ?? const <String>[]).contains(_fDept)) {
      return false;
    }
    if (_fStatus == 'active' && !u.isActive) return false;
    if (_fStatus == 'inactive' && u.isActive) return false;
    return true;
  }

  /// Re-applies the filters. The selection is cleared because ticked rows may
  /// no longer be visible (and must not be bulk-deleted unseen).
  void _applyFilters(PaginatedDataController<UserRowModel> c) {
    c.clearSelection();
    c.setFilter(_hasActiveFilters ? _matches : null);
  }

  static Map<String, String> _sortedByLabel(Map<String, String> m) {
    final entries = m.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return {for (final e in entries) e.key: e.value};
  }

  /// Only roles that at least one listed user has (a filter with no rows
  /// behind it is useless), plus "Admin" when an administrator is listed.
  Map<String, String> _roleOptions(List<UserRowModel> users) {
    final m = <String, String>{};
    for (final u in users) {
      if (u.isAdmin) {
        m[_kAdminRole] = 'Admin';
        continue;
      }
      final uid = u.role ?? '';
      if (uid.isEmpty) continue;
      final name = CacheService.roleByUid(uid)?.name ?? '';
      if (name.isNotEmpty) m[uid] = name;
    }
    return _sortedByLabel(m);
  }

  Map<String, String> _departmentOptions(List<UserRowModel> users) {
    final m = <String, String>{};
    for (final u in users) {
      for (final uid in u.department ?? const <String>[]) {
        final name = CacheService.departmentByUid(uid)?.name ?? '';
        if (name.isNotEmpty) m[uid] = name;
      }
    }
    return _sortedByLabel(m);
  }

  // ───────────────────────── styles ─────────────────────────

  TextStyle _primaryCellStyle(BuildContext context, {FontWeight? fontWeight}) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
      color: context.colors.textPrimary,
      fontWeight: fontWeight,
    );
  }

  TextStyle _secondaryCellStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: context.colors.textSecondary);
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final controllerRead = context
        .read<PaginatedDataController<UserRowModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<UserRowModel>>();
    final width = MediaQuery.of(context).size.width;
    final isWide = !kIsMobile && width >= 1000;
    final selected = controllerWatch.filteredItems
        .where((u) => controllerWatch.selectedIds.contains(u.uid))
        .toList();

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
      body: BlocListener<UsersBloc, UsersState>(
        listenWhen: (previous, current) => current is UsersLoaded,
        listener: (context, state) {
          if (state is UsersLoaded) {
            controllerRead.retainSelection(
              state.users.map((u) => u.uid).toSet(),
            );
            controllerRead.setData(state.users);
          }
        },
        child: BlocBuilder<UsersBloc, UsersState>(
          builder: (context, state) {
            if (state is UsersLoading) {
              return const WaitingLoading();
            }

            if (state is UsersLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: () => _refreshUsers(),
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
                        _buildHeaderBanner(context, state.users.length),
                        const SizedBox(height: 20),
                      ],
                      _buildToolbarCard(
                        context,
                        state.users,
                        controllerRead,
                        controllerWatch,
                        selected,
                      ),
                      const SizedBox(height: 18),
                      controllerWatch.paginatedItems.isEmpty
                          ? NoData(
                              text: state.users.isEmpty
                                  ? "No employees available"
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

            if (state is UsersError) {
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

  // ───────────────────────── toolbar card ─────────────────────────

  BoxDecoration _cardDecoration(BuildContext context, {double shadow = 0.05}) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: shadow),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildToolbarCard(
    BuildContext context,
    List<UserRowModel> all,
    PaginatedDataController<UserRowModel> cr,
    PaginatedDataController<UserRowModel> cw,
    List<UserRowModel> selected,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final compact = kIsMobile || MediaQuery.of(context).size.width < 1000;

    final roleDd = _FilterDropdown(
      allLabel: 'All Roles',
      value: _fRole,
      options: _roleOptions(all),
      width: 160,
      onChanged: (v) {
        setState(() => _fRole = v);
        _applyFilters(cr);
      },
    );
    final deptDd = _FilterDropdown(
      allLabel: 'All Departments',
      value: _fDept,
      options: _departmentOptions(all),
      width: 190,
      onChanged: (v) {
        setState(() => _fDept = v);
        _applyFilters(cr);
      },
    );
    final statusDd = _FilterDropdown(
      allLabel: 'All Status',
      value: _fStatus,
      options: const {'active': 'Active', 'inactive': 'Inactive'},
      width: 140,
      onChanged: (v) {
        setState(() => _fStatus = v);
        _applyFilters(cr);
      },
    );
    final totalChip = _TotalChip(count: cw.totalEntries);

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            Row(
              children: [
                Expanded(child: _EmployeeSearchField(onChanged: cr.setSearch)),
                const SizedBox(width: 10),
                _buildRefreshButton(),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [roleDd, deptDd, statusDd, totalChip],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap: on a narrow desktop window the filters flow onto a
                // second line instead of overflowing.
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _EmployeeSearchField(onChanged: cr.setSearch, width: 250),
                      roleDd,
                      deptDd,
                      statusDd,
                      totalChip,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildRefreshButton(),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: scheme.outlineVariant),
          ),
          _buildActionRow(selected, cr),
        ],
      ),
    );
  }

  // ───────────────────────── table card ─────────────────────────

  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<UserRowModel> cw,
    PaginatedDataController<UserRowModel> cr,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(context, shadow: 0.06),
      child: Column(
        children: [
          _buildTable(context, cw, cr),
          _buildFooter(context, cw, cr),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    PaginatedDataController<UserRowModel> cw,
    PaginatedDataController<UserRowModel> cr,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, _kMinTableWidth);
        final flexTotal = _columns.fold<double>(0, (s, c) => s + c.flex);
        final usable = tableWidth - _kCheckW;
        double widthOf(_Col c) => usable * c.flex / flexTotal;

        final pageIds = cw.paginatedItems.map((u) => u.uid).toList();
        final selectedOnPage = pageIds
            .where((id) => cw.selectedIds.contains(id))
            .length;
        final bool? allValue = selectedOnPage == 0
            ? false
            : (selectedOnPage == pageIds.length ? true : null);

        final header = Container(
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant),
              bottom: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _kCheckW,
                child: Center(
                  child: Checkbox(
                    value: allValue,
                    tristate: true,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) {
                      if (allValue == true) {
                        cr.deselectAll(pageIds);
                      } else {
                        cr.selectAll(pageIds);
                      }
                    },
                  ),
                ),
              ),
              for (final col in _columns)
                _headerCell(context, col, widthOf(col), cw, cr),
            ],
          ),
        );

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
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  header,
                  for (final user in cw.paginatedItems)
                    _buildRow(context, user, cw, cr, widthOf),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(
    BuildContext context,
    _Col col,
    double width,
    PaginatedDataController<UserRowModel> cw,
    PaginatedDataController<UserRowModel> cr,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final sortId = col.sortId;
    final active = sortId != null && cw.sortColumnIndex == sortId;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            col.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ),
        if (sortId != null) ...[
          const SizedBox(width: 4),
          Icon(
            active
                ? (cw.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded)
                : Icons.swap_vert_rounded,
            size: 14,
            color: active
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ],
      ],
    );

    return SizedBox(
      width: width,
      child: sortId == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(alignment: Alignment.centerLeft, child: label),
            )
          : InkWell(
              onTap: () => cr.setSort(sortId, active ? !cw.sortAscending : true),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: label,
              ),
            ),
    );
  }

  // ───────────────────────── row ─────────────────────────

  Widget _buildRow(
    BuildContext context,
    UserRowModel user,
    PaginatedDataController<UserRowModel> cw,
    PaginatedDataController<UserRowModel> cr,
    double Function(_Col) widthOf,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isSelected = cw.selectedIds.contains(user.uid);

    void openUser() {
      final Widget page = user.isAdmin
          ? AdminProfile(admin: user.toAdminModel())
          : EmployeeDetails(employee: user.toEmployeeModel());
      if (kIsMobile || width < 1000) {
        Sheet.showSheet(context, widget: page);
      } else {
        GeneralDialog.showRTLSheet(context, page);
      }
    }

    Widget cell(_Col col, Widget child) => SizedBox(
      width: widthOf(col),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );

    final designation =
        CacheService.designationByUid(user.designation ?? '')?.name ??
        (user.isAdmin ? 'Administrator' : '');
    final deptText = _departmentText(user);
    final subDept = (user.subDepartment ?? '').isEmpty
        ? ''
        : (CacheService.subDepartmentByUid(user.subDepartment!)?.name ?? '');

    return Material(
      color: isSelected
          ? scheme.primary.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: openUser,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _kCheckW,
                child: Center(
                  child: Checkbox(
                    value: isSelected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => cr.onSelected(user.uid, v),
                  ),
                ),
              ),

              /// Employee ID
              cell(
                _cId,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    user.employeeId ?? '',
                    style: _primaryCellStyle(
                      context,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              /// Name + designation
              cell(
                _cName,
                Row(
                  children: [
                    UserAvatar(
                      size: 32,
                      showCrown: true,
                      userData: UserDataModel(
                        uid: user.uid,
                        name: user.name,
                        profilePic: user.profileImageUrl,
                        userType: user.isAdmin
                            ? UserType.admin
                            : UserType.employee,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _primaryCellStyle(
                              context,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (designation.isNotEmpty)
                            Text(
                              designation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _secondaryCellStyle(
                                context,
                              ).copyWith(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              /// Department + sub department
              cell(
                _cDept,
                deptText.isEmpty
                    ? Text('—', style: _secondaryCellStyle(context))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            deptText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _primaryCellStyle(
                              context,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subDept.isNotEmpty)
                            Text(
                              subDept,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _secondaryCellStyle(
                                context,
                              ).copyWith(fontSize: 11),
                            ),
                        ],
                      ),
              ),

              /// Role badge
              cell(_cRole, _roleBadge(context, user)),

              /// Email
              cell(
                _cEmail,
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _primaryCellStyle(context),
                ),
              ),

              /// Mobile app activity
              cell(
                _cMobile,
                _activityCell(context, user, 'mobile', Icons.smartphone),
              ),

              /// Desktop app activity
              cell(
                _cDesktop,
                _activityCell(context, user, 'desktop', Icons.laptop_mac),
              ),

              /// Status
              cell(_cStatus, _statusPill(context, user.isActive)),

              /// Created by
              cell(_cCreated, _createdByCell(context, user)),

              /// Actions
              cell(_cAction, _actionButtons(context, user, width)),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── cells ─────────────────────────

  static const List<Color> _roleColors = [
    Color(0xFF4F46E5),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0284C7),
  ];

  Widget _roleBadge(BuildContext context, UserRowModel user) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 11);

    if (user.isAdmin) {
      const c = Color(0xFFD97706);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 13, color: c),
            const SizedBox(width: 4),
            Text('Admin', style: textStyle?.copyWith(color: c)),
          ],
        ),
      );
    }

    final name = CacheService.roleByUid(user.role ?? '')?.name ?? '';
    if (name.isEmpty) return Text('—', style: _secondaryCellStyle(context));
    final color = _roleColors[name.codeUnits.fold<int>(0, (s, c) => s + c) %
        _roleColors.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle?.copyWith(color: color),
      ),
    );
  }

  /// Latest login of [user] on a [kind] ('mobile' | 'desktop') device.
  /// Fed by `mobile_login` / `desktop_login` of employees.php `list`
  /// (see ApiMappers.devicesFrom).
  Widget _activityCell(
    BuildContext context,
    UserRowModel user,
    String kind,
    IconData icon,
  ) {
    Map<String, dynamic>? device;
    for (final d in user.devices ?? const <Map<String, dynamic>>[]) {
      if (d['kind'] == kind) {
        device = d;
        break;
      }
    }
    if (device == null) {
      return Text('No activity', style: _secondaryCellStyle(context));
    }

    var label = (device['model'] ?? device['platform'] ?? '').toString().trim();
    if (label.isEmpty || label.toLowerCase() == 'unknown') {
      label = kind == 'mobile' ? 'Mobile' : 'Desktop';
    }
    final ms = device['lastLoginAt'];
    final at = ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _primaryCellStyle(context, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (at != null)
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              DateFormat('dd MMM, hh:mm a').format(at),
              style: _secondaryCellStyle(context).copyWith(fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _statusPill(BuildContext context, bool active) {
    final color = active ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar + creator name. Unlike CreatedByWidget the name is ellipsized, so
  /// a long name can never overflow the column.
  Widget _createdByCell(BuildContext context, UserRowModel user) {
    return Row(
      children: [
        UserAvatar(size: 28, userData: user.createdBy),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            user.createdBy.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _primaryCellStyle(context, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons(BuildContext context, UserRowModel user, double width) {
    final canEdit = permissions?.canEdit ?? false;
    final canDelete = permissions?.canDelete ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          _ActionIcon(
            tooltip: 'Edit',
            icon: Iconsax.edit,
            color: AppColors.info,
            onTap: () {
              final page = EmployeeEdit(
                uid: user.uid,
                admin: user.isAdmin ? user.toAdminModel() : null,
              );
              if (kIsMobile || width < 1000) {
                Sheet.showSheet(context, widget: page);
              } else {
                GeneralDialog.showRTLSheet(context, page);
              }
            },
          ),
        if (!user.isAdmin && canEdit) ...[
          const SizedBox(width: 6),
          _ActionIcon(
            tooltip: user.isActive ? 'Block' : 'Unblock',
            icon: user.isActive ? Icons.block_rounded : Icons.lock_open_rounded,
            color: AppColors.orange,
            circle: true,
            onTap: () => _toggleBlock(user),
          ),
        ],
        if (!user.isAdmin && canDelete) ...[
          const SizedBox(width: 6),
          _ActionIcon(
            tooltip: 'Delete',
            icon: Iconsax.trash,
            color: AppColors.danger,
            onTap: () => handleDelete(context, user),
          ),
        ],
      ],
    );
  }

  /// employees.php `block` / `unblock` (blocked users cannot log in).
  Future<void> _toggleBlock(UserRowModel user) async {
    final block = user.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: block ? 'Block Employee' : 'Unblock Employee',
        content:
            'Are you sure you want to ${block ? 'block' : 'unblock'} ${user.name}?',
      ),
    );
    if (confirm != true) return;

    try {
      final res = block
          ? await EmployeesApiService.block(user.uid)
          : await EmployeesApiService.unblock(user.uid);
      res.ensureSuccess();
      ApiLive.changed({'employee', 'role'});
      if (!mounted) return;
      FlushBar.show(
        context,
        block ? 'Employee blocked successfully' : 'Employee unblocked successfully',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(
        context,
        e is ApiException ? e.message : e.toString(),
        isSuccess: false,
      );
    }
  }

  // ───────────────────────── footer / pagination ─────────────────────────

  List<int> _pageWindow(int current, int total) {
    if (total <= 5) return List.generate(total, (i) => i + 1);
    var start = math.max(1, current - 2);
    final end = math.min(total, start + 4);
    start = math.max(1, end - 4);
    return [for (var p = start; p <= end; p++) p];
  }

  Widget _buildFooter(
    BuildContext context,
    PaginatedDataController<UserRowModel> cw,
    PaginatedDataController<UserRowModel> cr,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final compact = kIsMobile || MediaQuery.of(context).size.width < 1000;
    final small = _secondaryCellStyle(context);

    final info = Text(
      'Showing ${cw.startEntry} to ${cw.endEntry} of ${cw.totalEntries} entries',
      style: small,
    );

    final rowsPerPage = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Rows per page:', style: small),
        const SizedBox(width: 8),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: cw.rowsPerPage,
              isDense: true,
              borderRadius: BorderRadius.circular(8),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: Theme.of(context).textTheme.bodySmall,
              items: const [10, 25, 50, 100]
                  .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v')))
                  .toList(),
              onChanged: cr.setRowsPerPage,
            ),
          ),
        ),
      ],
    );

    Widget pageButton({
      required Widget child,
      required bool enabled,
      required VoidCallback onTap,
      bool selected = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onTap : null,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? null
                    : Border.all(color: scheme.outlineVariant),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pageButton(
          enabled: cw.currentPage > 1,
          onTap: cr.previousPage,
          child: Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: cw.currentPage > 1
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
        for (final p in _pageWindow(cw.currentPage, cw.totalPages))
          pageButton(
            enabled: true,
            selected: p == cw.currentPage,
            onTap: () => cr.goToPage(p),
            child: Text(
              '$p',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: p == cw.currentPage ? AppColors.white : scheme.onSurface,
              ),
            ),
          ),
        pageButton(
          enabled: cw.currentPage < cw.totalPages,
          onTap: cr.nextPage,
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: cw.currentPage < cw.totalPages
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                info,
                const SizedBox(height: 10),
                rowsPerPage,
                const SizedBox(height: 10),
                pager,
              ],
            )
          : Row(
              children: [
                info,
                const SizedBox(width: 24),
                rowsPerPage,
                const Spacer(),
                pager,
              ],
            ),
    );
  }


  Future<void> handleDelete(BuildContext context, UserRowModel user) async {
    // ❌ prevent admin delete
    if (!user.isEmployee) {
      FlushBar.show(context, 'Admin cannot be deleted', isSuccess: false);
      return;
    }

    // ✅ STEP 1: CHECK ASSIGNED
    final isAssigned = await EmployeeService.isEmployeeAssigned(
      user.employeeId ?? '',
    );

    if (isAssigned) {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text(
            'This employee is associated with chats/projects/tasks.',
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

    // ✅ STEP 2: CONFIRM
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Delete Employee',
        content: 'Are you sure you want to delete ${user.name}?',
      ),
    );

    if (confirm != true) return;

    try {
      // ✅ STEP 3: BACKUP
      final deletedEmployee = user.toEmployeeModel();

      // ✅ STEP 4: DELETE
      await EmployeeService.deleteEmployee(uid: user.uid);

      if (!context.mounted) return;

      // ✅ STEP 5: UNDO
      FlushBar.show(
        context,
        'Employee deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          await EmployeeService.restoreEmployee(deletedEmployee);

          if (!context.mounted) return;

          // 🔥 refresh list
          context.read<UsersBloc>().add(StreamUsers());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);

      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }

  Widget _buildHeaderBanner(BuildContext context, int total) {
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
              Iconsax.people,
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
                  "Employees",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage your team, their roles, and their access in one place",
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
                  total == 1 ? "Employee" : "Employees",
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

  Widget _buildActionRow(
    List<UserRowModel> selected,
    PaginatedDataController<UserRowModel> controller,
  ) {
    final width = MediaQuery.of(context).size.width;
    // Single source of truth for "mobile / narrow" layout
    final bool isCompact = kIsMobile || width < 1000;
    return LayoutBuilder(
      builder: (context, constraints) {

        final buttons = <Widget>[];

        // Add Employee Button
        if (permissions?.canCreate ?? false) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: () {
                if (kIsMobile || width < 1000) {
                  Sheet.showSheet(context, widget: const EmployeeCreate());
                } else {
                  GeneralDialog.showRTLSheet(context, const EmployeeCreate());
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                "Add $_pageTitle",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          );
        }
        if (!isCompact) buttons.add(const SizedBox(width: 10));

        // Upload Button (Gated by canImport)
        if (permissions?.canImport ?? false) {
          buttons.add(
            OutlinedButton.icon(
              onPressed: () {
                if (kIsMobile || width < 1000) {
                  Sheet.showSheet(context, widget: const EmployeeUploadPage());
                } else {
                  GeneralDialog.showRTLSheet(
                    context,
                    const EmployeeUploadPage(),
                  );
                }
              },
              icon: const Icon(Iconsax.cloud_plus, size: 16),
              label: Text(
                "Upload",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
            ),
          );

        if (!isCompact) buttons.add(const SizedBox(width: 8));

        buttons.add(
          OutlinedButton.icon(
            onPressed: () async {
              await Download.downloadFromAsset(
                context,
                "assets/templates/employee_upload_template.xlsx",
                "Employee_Template.xlsx",
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(
              "Template",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const StadiumBorder(),
            ),
          ),
        );
        if (!isCompact) buttons.add(const SizedBox(width: 8));
        buttons.add(
          OutlinedButton.icon(
            onPressed: () async {
              await Download.downloadFromAsset(
                context,
                "assets/templates/employee_upload_template_with_data.xlsx",
                "Employee_Sample_Data.xlsx",
              );
            },
            icon: const Icon(Icons.contact_page_outlined, size: 16),
            label: Text(
              "Sample Data",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const StadiumBorder(),
            ),
          ),
        );
        }
        if (!isCompact) buttons.add(const SizedBox(width: 10));
        if (permissions?.canExport ?? false) {
        buttons.add(
          ElevatedButton.icon(
            label: Text(
              "Export",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            icon: Icon(Iconsax.export_3, size: 16),
            onPressed: controller.filteredItems.isEmpty
                ? null
                : () async {
                    try {
                      List<List<String>> exportData = [];
                      exportData.add([
                        'Employee Id',
                        'Name',
                        'Email',
                        'Designation',
                        'Department',
                        'Sub Department',
                        'Mobile Number',
                        'Profile Image',
                        'Gender',
                        'Date Of Joining',
                        'Date Of Birth',
                        'Role',
                        'Address',
                        'About',
                        'Login Allowed',
                        'Receive Email Notifications',
                        'Employee Type',
                        'Reporting To',
                        'Marital Status',
                        'Is Active',
                        'Created At',
                      ]);
                      for (var i in controller.filteredItems) {
                        List<String> row = [];
                        row.addAll([
                          i.employeeId ?? "",
                          i.name,
                          i.email,
                          CacheService.designationByUid(
                                i.designation ?? "",
                              )?.name ??
                              '',
                          i.department != null && i.department!.isNotEmpty
                              ? i.department!
                                    .map(
                                      (uid) =>
                                          CacheService.departmentByUid(
                                            uid,
                                          )?.name ??
                                          '',
                                    )
                                    .join(', ')
                              : '',
                          i.subDepartment != null
                              ? CacheService.subDepartmentByUid(
                                      i.subDepartment!,
                                    )?.name ??
                                    ''
                              : '',
                          i.mobileNumber,
                          i.profileImageUrl ?? '',
                          i.gender ?? "",
                          i.dateOfJoining?.formatDate ?? '',
                          i.dateOfBirth?.formatDate ?? '',
                          CacheService.roleByUid(i.role ?? "")?.name ?? '',
                          i.address ?? "",
                          i.about ?? "",
                          (i.loginAllowed ?? false) ? "Yes" : "No",
                          (i.receiveEmailNotifications ?? false) ? "Yes" : "No",
                          i.employeeType ?? '',

                          i.reportingTo != null && i.reportingTo!.isNotEmpty
                              ? i.reportingTo!
                                    .map(
                                      (uid) =>
                                          CacheService.getUserByUid(
                                            uid,
                                          )?.name ??
                                          '',
                                    )
                                    .join(', ')
                              : '',
                          i.maritalStatus ?? "",
                          i.isActive ? "Yes" : "No",
                          i.createdAt.formatDateTime,
                        ]);
                        exportData.add(row);
                      }
                      var fileBytes = await XlsxWriter().create(exportData);
                      var filePath = await saveFileToDownloads(
                        fileBytes,
                        fileName: '$_pageTitle List.xlsx',
                      );
                      if (!kIsWeb) openfile(filePath, context);
                    } catch (e) {
                      FlushBar.show(context, e.toString(), isSuccess: false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
        );
        }

        /*buttons.add(
          ElevatedButton.icon(
            label: Text(
              "Worflow",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            icon: Icon(Iconsax.data),
            onPressed: () async {
              try {
                futureLoading(context);
                var resultMap = [];
                var employees = await EmployeeService.getAllEmployees();
                for (var i in employees) {
                  var result = await EmployeeService.getUserWorkflow(
                    userId: i.uid,
                  );
                  var subResultMap = {};
                  for (var i = 0; i < result.length; i++) {
                    subResultMap[i.toString()] = result[i];
                  }

                  resultMap.add({i.uid: subResultMap});
                }
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                if (kIsDesktop || (kIsWeb && width >= 1000)) {
                  GeneralDialog.showRTLSheet(
                    context,
                    OrgChart(rawData: resultMap),
                  );
                } else if (kIsMobile || (kIsWeb && width < 1000)) {
                  Sheet.showSheet(
                    context,
                    widget: OrgChart(rawData: resultMap),
                  );
                }
              } catch (e) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                FlushBar.show(context, e.toString(), isSuccess: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        );*/
        if (!isCompact) buttons.add(const SizedBox(width: 10));
        if (selected.isNotEmpty && (permissions?.canDelete ?? false)) {
          buttons.add(
                  ElevatedButton.icon(
                    label: Text(
                      "Delete",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                    ),
                    icon: const Icon(Iconsax.trash, size: 16),
                    onPressed: () async {
                      if (selected.isEmpty) return;

                      // ✅ STEP 1: check assigned
                      for (final employee in selected) {
                        final isAssigned =
                            await EmployeeService.isEmployeeAssigned(
                              employee.employeeId ?? '',
                            );

                        if (isAssigned) {
                          if (!context.mounted) return;

                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Cannot Delete'),
                              content: Text(
                                'One or more selected employees are associated and cannot be deleted.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                      }

                      // ✅ STEP 2: confirm
                      final confirm = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ConfirmDialog(
                          title: 'Delete',
                          content:
                              'Are you sure you want to delete $_pageTitle?',
                        ),
                      );

                      if (confirm != true) return;

                      try {
                        // ✅ STEP 3: BACKUP
                        final deletedEmployees = selected
                            .where((e) => e.isEmployee)
                            .map((e) => e.toEmployeeModel())
                            .toList();

                        // ✅ STEP 4: LOADER
                        futureLoading(context);

                        // ✅ STEP 5: DELETE
                        for (final emp in selected) {
                          if (emp.uid.isNotEmpty && emp.isEmployee) {
                            await EmployeeService.deleteEmployee(uid: emp.uid);
                          }
                        }

                        // ✅ STEP 6: CLOSE LOADER
                        if (Navigator.canPop(context)) Navigator.pop(context);

                        // ✅ STEP 7: CLEAR SELECTION
                        controller.clearSelection();

                        // ✅ STEP 8: SHOW UNDO
                        FlushBar.show(
                          context,
                          'Employee deleted successfully',
                          actionLabel: 'UNDO',
                          onActionPressed: () async {
                            for (final emp in deletedEmployees) {
                              await EmployeeService.restoreEmployee(emp);
                            }

                            if (!context.mounted) return;

                            // 🔥 refresh users
                            context.read<UsersBloc>().add(StreamUsers());
                          },
                        );
                      } catch (e, st) {
                        if (Navigator.canPop(context)) Navigator.pop(context);

                        await ErrorService.recordError(e, st);

                        FlushBar.show(context, e.toString(), isSuccess: false);
                      }
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
          );
        }
        if (!isCompact) buttons.add(const SizedBox(width: 10));
        if (selected.isNotEmpty) {
          // Chat Button
          buttons.add(
            ElevatedButton.icon(
              onPressed: () async {
                if (selected.isEmpty) {
                  FlushBar.show(
                    context,
                    "Please select at least one employee.",
                    isSuccess: false,
                  );
                  return;
                }
                final bool isSingle = selected.length == 1;
                final GlobalKey<FormState> formKey = GlobalKey<FormState>();

                final bool? confirm = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: Text(
                      isSingle ? "Create Chat" : "Create Group Chat",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    content: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSingle
                                ? "Do you want to start a chat with ${selected.first.name}?"
                                : "Do you want to create a group chat with ${selected.length} employees?",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          FormFields(
                            label: 'Enter chat message',
                            controller: _chatMessage,
                            hintText: 'Enter Description',
                            maxLines: 3,
                            isRequired: true,
                            valid: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Chat message is required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          "Cancel",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          Navigator.pop(context, true);
                        },
                        child: Text(
                          "Confirm",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  futureLoading(context);

                  final sessionUser = await Spdb.getUser();
                  final creator = CacheService.getUserByUid(sessionUser.uid);

                  final creatorUid = creator?.uid ?? sessionUser.uid ?? '';
                  final creatorName = creator?.name ?? "";

                  if (isSingle) {
                    final emp = selected.first;

                    if (emp.uid.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }

                    // if (_chatMessage.text.isEmpty) {
                    //   FlushBar.show(
                    //     context,
                    //     "Please enter the chat message.",
                    //     isSuccess: false,
                    //   );
                    //   return;
                    // }

                    var chatId = await ChatService.createIndividualChat(
                      userId: emp.uid,
                    );

                    await ChatService.sendChatMessage(
                      chatId: chatId,
                      message: _chatMessage.text,
                      attachments: [],
                      replyFor: null,
                    );

                    Navigator.pop(context);
                    var currentUserUid = await Spdb.getUid();
                    if (currentUserUid != null) {
                      if (!mounted) return;
                      if (kIsDesktop) {
                        GeneralDialog.showRTLSheet(
                          context,
                          ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      } else if (kIsMobile) {
                        Sheet.showSheet(
                          context,
                          widget: ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      }
                    }
                    _chatMessage.clear();
                    setState(() {});
                    FlushBar.show(context, "Chat created");
                    return;
                  }

                  var groupUsers = [
                    ...selected
                        .map((e) => e.uid)
                        .where((id) => id.isNotEmpty),
                    sessionUser.uid,
                  ];

                  final chatModel = ChatModel(
                    createdBy: creatorUid,
                    participants: groupUsers,
                    participantsKey: groupUsers.join('_'),
                    title: "Group Chat",
                    description: "",
                    isGroupChat: true,
                    isPinned: false,
                    isFavorite: false,
                    lastMessage: LastMessageModel(
                      message: "$creatorName created group",
                      timestamp: DateTime.now(),
                      senderId: creatorUid,
                    ),
                  );

                  var chatId = await ChatService.createGroupChat(
                    model: chatModel,
                  );
                  Navigator.pop(context);

                  if (chatId != null) {
                    var currentUserUid = await Spdb.getUid();
                    if (currentUserUid != null) {
                      if (!mounted) return;
                      if (kIsDesktop) {
                        GeneralDialog.showRTLSheet(
                          context,
                          ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      } else if (kIsMobile) {
                        Sheet.showSheet(
                          context,
                          widget: ChatListing(
                            currentUserUid: currentUserUid,
                            selectedChatUid: chatId,
                          ),
                        );
                      }
                    }
                  }

                  FlushBar.show(context, "Group chat created");
                } catch (e, st) {
                  await ErrorService.recordError(e, st);
                  Navigator.pop(context);
                  FlushBar.show(
                    context,
                    e.toString(),
                    isSuccess: false,
                    error: e,
                    stackTrace: st,
                  );
                }
              },
              icon: const Icon(Icons.chat, size: 16),
              label: Text(
                selected.length == 1
                    ? 'Chat'
                    : 'Group Chat (${selected.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onTertiaryContainer,
                elevation: 0,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
            ),
          );
          if (!isCompact) buttons.add(const SizedBox(width: 10));
          if (tasksPermissions?.canCreate ?? false) {
          buttons.add(
                ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskCreate(
                            employees: selected
                                .map((e) => e.toEmployeeModel())
                                .toList(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.task, size: 16),
                    label: Text(
                      "Create Task",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
          );
          }
        }

        // ---------- MOBILE / NARROW: neat 2-column grid ----------
        // Every button gets the SAME width and height so rows line up.
        // (Refresh button lives next to the search field on mobile.)
        if (isCompact) {
          const double spacing = 10.0;
          final double itemWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: 10,
            children: buttons
                // skip desktop-only spacer boxes so they never become empty cells
                .where((b) => b is! SizedBox)
                .map(
                  (b) => SizedBox(
                    width: itemWidth,
                    height: 44,
                    child: b,
                  ),
                )
                .toList(),
          );
        }

        // ---------- DESKTOP / WIDE: single scrollable row + refresh ----------
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: buttons),
        );
      },
    );
  }

  Widget _buildRefreshButton() {
    return Tooltip(
      message: "Refresh",
      child: Material(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _refreshUsers,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(
              Iconsax.refresh,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Toolbar widgets
// ---------------------------------------------------------------------

/// Searchable dropdown ("All Roles", "All Departments", "All Status"): the
/// app's CustomSearchableDropdown (search box + list). [value] is the option
/// key, '' means "All".
class _FilterDropdown extends StatelessWidget {
  final String allLabel;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final double width;

  const _FilterDropdown({
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final current = options[value] ?? allLabel;
    return SizedBox(
      width: width,
      child: CustomSearchableDropdown<String>(
        key: ValueKey('flt_${allLabel}_${options.length}'),
        items: [allLabel, ...options.values],
        initialValue: current,
        itemAsString: (s) => s,
        hintText: allLabel,
        showClearButton: false,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onChanged: (label) {
          if (label == null || label == allLabel) {
            onChanged('');
            return;
          }
          final key = options.entries
              .firstWhere(
                (e) => e.value == label,
                orElse: () => const MapEntry('', ''),
              )
              .key;
          onChanged(key);
        },
      ),
    );
  }
}

/// Blue "8 total" pill showing how many rows pass search + filters.
class _TotalChip extends StatelessWidget {
  final int count;
  const _TotalChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.people, size: 14, color: primary),
          const SizedBox(width: 6),
          Text(
            '$count total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tinted icon button used in the Action column.
class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool circle;

  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(circle ? 20 : 10);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Search field of the Employees toolbar.
// ---------------------------------------------------------------------
class _EmployeeSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  /// Fixed width; null = fill the available width.
  final double? width;
  const _EmployeeSearchField({required this.onChanged, this.width});

  @override
  State<_EmployeeSearchField> createState() => _EmployeeSearchFieldState();
}

class _EmployeeSearchFieldState extends State<_EmployeeSearchField> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
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
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: widget.width,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _focused
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.outlineVariant,
          width: _focused ? 1.4 : 1,
        ),
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
          hintText: 'Search Employees...',
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 38,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  splashRadius: 16,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _hasText = false);
                    widget.onChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}