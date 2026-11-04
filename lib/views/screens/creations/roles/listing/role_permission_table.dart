import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/theme/theme.dart';

/// Maps an access-page name to a representative icon for the permissions UI.
IconData rolePageIcon(String page) {
  switch (page) {
    case 'Role':
      return Iconsax.shield_tick;
    case 'Designation':
      return Iconsax.medal_star;
    case 'Department':
      return Iconsax.buildings_2;
    case 'Sub Department':
      return Iconsax.building;
    case 'Employees':
      return Iconsax.people;
    case 'Chats':
      return Iconsax.message;
    case 'Lead Category':
      return Iconsax.category;
    case 'Lead Source':
      return Iconsax.share;
    case 'Payment Mode':
      return Iconsax.card;
    case 'Lead Status':
      return Iconsax.status_up;
    case 'Lead Priority':
      return Iconsax.flag;
    case 'Deal Status':
      return Iconsax.chart_success;
    case 'Leads':
      return Iconsax.personalcard;
    case 'Deals':
      return Iconsax.dollar_circle;
    case 'Master Client':
      return Iconsax.people;
    case 'Our Company':
      return Iconsax.building_4;
    case 'Payment':
      return Iconsax.wallet_3;
    case 'Payment Report':
      return Iconsax.chart_21;
    case 'Project Updation':
      return Iconsax.refresh_circle;
    case 'Company':
      return Iconsax.building_4;
    case 'Contact':
      return Iconsax.call;
    case 'Calendar':
      return Iconsax.calendar_1;
    case 'Projects':
      return Iconsax.briefcase;
    case 'Tasks':
      return Iconsax.task_square;
    case 'Tickets':
      return Iconsax.ticket;
    case 'Downloads':
      return Iconsax.document_download;
    case 'Admin':
      return Iconsax.user_octagon;
    case 'Clients':
      return Iconsax.profile_2user;
    default:
      return Iconsax.document_text;
  }
}

/// Responsive permission matrix shared by the Create Role and Edit Role
/// screens. Mutates the [PermissionModel] rows it is given in place, so the
/// caller can read the same `rows` list back on submit.
class RolePermissionTable extends StatefulWidget {
  final List<PermissionModel> rows;
  const RolePermissionTable({super.key, required this.rows});

  @override
  State<RolePermissionTable> createState() => _RolePermissionTableState();
}

class _RolePermissionTableState extends State<RolePermissionTable> {
  final ScrollController _hScrollController = ScrollController();

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  bool _hasImportExport(String page) =>
      AppStrings.pagesWithImportExport.contains(page);

  void _recomputeSelectAll(PermissionModel row) {
    bool allSelected = row.canView && row.canCreate && row.canEdit && row.canDelete;
    if (_hasImportExport(row.page)) {
      allSelected = allSelected && row.canExport && row.canImport;
    }
    row.selectAll = allSelected;
  }

  void _toggleSelectAll(PermissionModel row, bool value) {
    setState(() {
      row.selectAll = value;
      row.canView = value;
      row.canCreate = value;
      row.canEdit = value;
      row.canDelete = value;
      if (_hasImportExport(row.page)) {
        row.canExport = value;
        row.canImport = value;
      }
    });
  }

  void _toggleView(PermissionModel row, bool value) {
    setState(() {
      row.canView = value;
      if (!value) {
        row.canCreate = false;
        row.canEdit = false;
        row.canDelete = false;
        row.canExport = false;
        row.canImport = false;
        row.selectAll = false;
      } else {
        _recomputeSelectAll(row);
      }
    });
  }

  void _toggleField(PermissionModel row, void Function(bool) apply, bool value) {
    setState(() {
      apply(value);
      _recomputeSelectAll(row);
    });
  }

  @override
  Widget build(BuildContext context) {
    // A single, consistent checkbox-table layout on every screen size —
    // horizontally scrollable on narrow widths, stretched to fill on wide
    // ones — so mobile and web always show the exact same permission grid.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  headingRowHeight: 46,
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 52,
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  ),
                  headingTextStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  columns: const [
                    DataColumn(label: Text('Page')),
                    DataColumn(label: Text('All')),
                    DataColumn(label: Text('View')),
                    DataColumn(label: Text('Create')),
                    DataColumn(label: Text('Edit')),
                    DataColumn(label: Text('Delete')),
                    DataColumn(label: Text('Export')),
                    DataColumn(label: Text('Import')),
                  ],
                  rows: List.generate(widget.rows.length, (index) {
                    final row = widget.rows[index];
                    final hasImportExport = _hasImportExport(row.page);

                    Widget cb(
                      bool value,
                      ValueChanged<bool> onChanged, {
                      Color? color,
                    }) {
                      return Checkbox(
                        value: value,
                        activeColor: color ?? Theme.of(context).colorScheme.primary,
                        onChanged: (val) => onChanged(val ?? false),
                      );
                    }

                    Widget blank() => Center(
                      child: Icon(
                        Icons.remove_rounded,
                        size: 14,
                        color: AppColors.grey300,
                      ),
                    );

                    return DataRow(
                      color: WidgetStateProperty.all(
                        index.isEven
                            ? Colors.transparent
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                      ),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                rolePageIcon(row.page),
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                row.page,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          cb(
                            row.selectAll,
                            (val) => _toggleSelectAll(row, val),
                            color: AppColors.accent,
                          ),
                        ),
                        DataCell(cb(row.canView, (val) => _toggleView(row, val))),
                        DataCell(
                          row.canView
                              ? cb(
                                  row.canCreate,
                                  (val) =>
                                      _toggleField(row, (v) => row.canCreate = v, val),
                                )
                              : blank(),
                        ),
                        DataCell(
                          row.canView
                              ? cb(
                                  row.canEdit,
                                  (val) =>
                                      _toggleField(row, (v) => row.canEdit = v, val),
                                )
                              : blank(),
                        ),
                        DataCell(
                          row.canView
                              ? cb(
                                  row.canDelete,
                                  (val) =>
                                      _toggleField(row, (v) => row.canDelete = v, val),
                                )
                              : blank(),
                        ),
                        DataCell(
                          row.canView && hasImportExport
                              ? cb(
                                  row.canExport,
                                  (val) =>
                                      _toggleField(row, (v) => row.canExport = v, val),
                                )
                              : blank(),
                        ),
                        DataCell(
                          row.canView && hasImportExport
                              ? cb(
                                  row.canImport,
                                  (val) =>
                                      _toggleField(row, (v) => row.canImport = v, val),
                                )
                              : blank(),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}