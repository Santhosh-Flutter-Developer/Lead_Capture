import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '/utils/src/download_io.dart'
    if (dart.library.html) '/utils/src/download_web.dart'
    show saveFileToDownloads;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '/services/services.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import 'bloc/admin_bloc.dart';

const String _pageTitle = "Admin";

class AdminListing extends StatelessWidget {
  const AdminListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdminBloc()..add(StreamAdmins()),
      child: const AdminListView(),
    );
  }
}

class AdminListView extends StatelessWidget {
  const AdminListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PaginatedDataController<AdminModel>(
        initialSortColumnIndex: 1,
        filterLogic: (admin, query) {
          final q = query.toLowerCase();
          return admin.name.toLowerCase().contains(q) ||
              admin.email.toLowerCase().contains(q) ||
              admin.mobileNumber.toLowerCase().contains(q);
        },
        sortLogic: (a, b, col, asc) {
          int compare;
          switch (col) {
            case 0:
              compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
              break;
            case 1:
              compare = a.email.toLowerCase().compareTo(b.email.toLowerCase());
              break;
            case 2:
              compare = a.mobileNumber.toLowerCase().compareTo(
                b.mobileNumber.toLowerCase(),
              );
              break;
            case 3:
              compare = a.isActive.toString().compareTo(b.isActive.toString());
              break;
            default:
              compare = a.uid!.compareTo(b.uid!);
          }
          return asc ? compare : -compare;
        },
        getItemId: (admin) => admin.uid!,
      ),
      child: const AdminListingView(),
    );
  }
}

class AdminListingView extends StatefulWidget {
  const AdminListingView({super.key});

  @override
  State<AdminListingView> createState() => _AdminListingViewState();
}

class _AdminListingViewState extends State<AdminListingView> {
  PermissionModel? permissions;
  bool _permissionsLoaded = false;
  final List<AdminModel> _adminList = [];
  final ScrollController _hScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    permissions = await PermissionService.getPermissions(_pageTitle);
    if (!mounted) return;
    _permissionsLoaded = true;
    setState(() {});
  }

  final List<AdminModel> _selectedAdmins = [];

  @override
  Widget build(BuildContext context) {
    final controllerRead = context.read<PaginatedDataController<AdminModel>>();
    final controllerWatch = context
        .watch<PaginatedDataController<AdminModel>>();

    return Scaffold(
      appBar: kIsMobile
          ? AppBar(leading: Back(), title: Text(_pageTitle))
          : null,
      body: BlocListener<AdminBloc, AdminState>(
        listenWhen: (previous, current) => current is AdminLoaded,
        listener: (context, state) {
          if (state is AdminLoaded) {
            controllerRead.setData(state.admins);
            _adminList.addAll(state.admins);
          }
        },
        child: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            if (state is AdminLoading) {
              return const WaitingLoading();
            }

            if (state is AdminLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildFilterRow(
                        onSearchChanged: controllerRead.setSearch,
                      ),
                      const SizedBox(height: 10),
                      _buildActionRow(context),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.grey.withValues(alpha: 0.1),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Scrollbar(
                                  controller: _hScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  thickness: 4,
                                  radius: const Radius.circular(6),
                                  scrollbarOrientation:
                                      ScrollbarOrientation.bottom,
                                  child: SingleChildScrollView(
                                    controller: _hScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: DataTable(
                                        showCheckboxColumn: true,

                                        // MIN WIDTH SETTINGS
                                        columnSpacing: 12,
                                        horizontalMargin: 8,
                                        headingRowHeight: 40,

                                        sortColumnIndex:
                                            controllerWatch.sortColumnIndex,
                                        sortAscending:
                                            controllerWatch.sortAscending,

                                        headingRowColor:
                                            WidgetStateProperty.all(
                                              AppColors.grey100,
                                            ),
                                        headingTextStyle: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.black,
                                            ),

                                        columns: [
                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: _sortableHeader(
                                                "Name",
                                                controllerRead,
                                              ),
                                            ),
                                            onSort: controllerRead.setSort,
                                          ),

                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: _sortableHeader(
                                                "Email",
                                                controllerRead,
                                              ),
                                            ),
                                            onSort: controllerRead.setSort,
                                          ),

                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: _sortableHeader(
                                                "Mobile No",
                                                controllerRead,
                                              ),
                                            ),
                                            onSort: controllerRead.setSort,
                                          ),

                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: _sortableHeader(
                                                "Status",
                                                controllerRead,
                                              ),
                                            ),
                                            onSort: controllerRead.setSort,
                                          ),

                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "Created At",
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.arrow_upward,
                                                    size: 14,
                                                    color: AppColors.grey400,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            onSort: controllerRead.setSort,
                                          ),

                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: Text(
                                                "Created By",
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                          ),

                                          DataColumn(
                                            label: IntrinsicWidth(
                                              child: Text(
                                                "Action",
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                          ),
                                        ],

                                        rows: controllerWatch.paginatedItems
                                            .map(
                                              (admin) => _buildDataRow(
                                                context,
                                                admin,
                                                controllerWatch,
                                                controllerRead,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: PaginationControls<AdminModel>(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is AdminError) {
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

  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 250,
          child: TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: AppColors.grey, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: AppColors.blue, width: 1.5),
              ),
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    if (permissions == null) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (permissions?.canCreate ?? false) ...[
          ElevatedButton.icon(
            onPressed: () {
              if (kIsMobile) {
                Sheet.showSheet(context, widget: const AdminCreate());
              } else {
                GeneralDialog.showRTLSheet(context, const AdminCreate());
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
            ),
          ),
          const SizedBox(width: 10),
        ],
        if ((permissions?.canDelete ?? false) &&
            _selectedAdmins.isNotEmpty) ...[
          ElevatedButton.icon(
            label: Text(
              "Delete",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.white),
            ),
            icon: const Icon(Iconsax.trash),
            onPressed: () async {
              var result = await showDialog(
                context: context,
                builder: (context) => ConfirmDialog(
                  title: 'Delete',
                  content: 'Are you sure want to delete this $_pageTitle?',
                ),
                barrierDismissible: false,
              );
              if (result != null && result) {
                try {
                  futureLoading(context);
                  for (var i in _selectedAdmins) {
                    await AdminService.deleteAdmin(uid: i.uid ?? '');
                  }
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  FlushBar.show(context, '$_pageTitle deleted successfully');
                  _selectedAdmins.clear();
                  setState(() {});
                } catch (e) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  FlushBar.show(context, e.toString(), isSuccess: false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
            ),
          ),
          const SizedBox(width: 10),
        ],
        if (permissions?.canExport ?? false) ...[
          ElevatedButton.icon(
            label: Text(
              "Export",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.white),
            ),
            icon: const Icon(Iconsax.export_3),
            onPressed: () async {
              List<List<String>> exportData = [];
              exportData.add([
                'Name',
                'Email',
                'Mobile Number',
                'Created At',
                'Profile Picture',
              ]);
              for (var i in _adminList) {
                List<String> row = [];
                row.addAll([
                  i.name,
                  i.email,
                  i.mobileNumber,
                  i.createdAt.listingDateTime,
                  i.profileImageUrl ?? '',
                ]);
                exportData.add(row);
              }
              var fileBytes = await XlsxWriter().create(exportData);
              var filePath = await saveFileToDownloads(
                fileBytes,
                fileName: 'Admin List.xlsx',
              );
              if (!kIsWeb) openfile(filePath, context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.grey600,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sortableHeader(String label, controllerRead) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 4),
        Icon(Icons.arrow_upward, size: 14, color: AppColors.grey400),
      ],
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    AdminModel admin,
    PaginatedDataController<AdminModel> controllerWatch,
    PaginatedDataController<AdminModel> controllerRead,
  ) {
    bool isSelected = controllerWatch.selectedIds.contains(admin.uid);
    void openAdmin(BuildContext context, AdminModel admin) {
      if (kIsMobile) {
        Sheet.showSheet(context, widget: AdminProfile(admin: admin));
      } else {
        GeneralDialog.showRTLSheet(context, AdminProfile(admin: admin));
      }
    }

    DataCell dataCell(BuildContext context, Widget child, AdminModel admin) {
      return DataCell(
        InkWell(
          onTap: () => openAdmin(context, admin),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: child,
          ),
        ),
      );
    }

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        controllerRead.onSelected(admin.uid!, selected);
        if (selected ?? false) {
          _selectedAdmins.add(admin);
        } else {
          _selectedAdmins.remove(admin);
        }
        setState(() {});
      },
      cells: [
        dataCell(
          context,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl:
                      admin.profileImageUrl ?? AppStrings.emptyProfilePhotoUrl,
                  height: 30,
                  width: 30,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Shimmer.fromColors(
                    baseColor: AppColors.grey300,
                    highlightColor: AppColors.grey200,
                    child: Container(color: AppColors.white),
                  ),
                  errorWidget: (_, _, _) => const Icon(Iconsax.danger),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                admin.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          admin,
        ),

        /// Email
        dataCell(
          context,
          Text(admin.email, style: Theme.of(context).textTheme.bodySmall),
          admin,
        ),

        /// Mobile
        dataCell(
          context,
          Text(
            admin.mobileNumber,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          admin,
        ),

        /// Status
        dataCell(
          context,
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: admin.isActive ? AppColors.success : AppColors.danger,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              admin.isActive ? 'Active' : 'Inactive',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          admin,
        ),

        /// Created Date
        dataCell(
          context,
          Text(
            admin.createdAt.listingDateTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          admin,
        ),

        /// Created By
        dataCell(context, CreatedByWidget(userData: admin.createdBy), admin),

        DataCell(
          Row(
            children: [
              if (permissions?.canEdit ?? false)
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  onPressed: () {
                    if (kIsMobile) {
                      Sheet.showSheet(
                        context,
                        widget: AdminUpdate(id: admin.uid!, admin: admin),
                      );
                    } else {
                      GeneralDialog.showRTLSheet(
                        context,
                        AdminUpdate(id: admin.uid!, admin: admin),
                      );
                    }
                  },
                  color: AppColors.info,
                  splashRadius: 20,
                ),
              if (permissions?.canDelete ?? false)
                IconButton(
                  icon: const Icon(Iconsax.trash),
                  onPressed: () async {
                    var result = await showDialog(
                      context: context,
                      builder: (context) {
                        return const ConfirmDialog(
                          title: 'Delete $_pageTitle',
                          content:
                              'Are you sure want to delete this $_pageTitle',
                        );
                      },
                    );
                    if (result != null && result) {
                      try {
                        await AdminService.deleteAdmin(uid: admin.uid ?? '');
                        FlushBar.show(
                          context,
                          '$_pageTitle deleted successfully',
                        );
                      } catch (e, st) {
                        await ErrorService.recordError(e, st);
                        debugPrint("${e.toString()}, ${st.toString()}");
                        FlushBar.show(
                          context,
                          e.toString(),
                          isSuccess: false,
                          error: e,
                          stackTrace: st,
                        );
                      }
                    }
                  },
                  color: AppColors.danger,
                  splashRadius: 20,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
