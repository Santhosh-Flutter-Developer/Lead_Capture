import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iconsax/iconsax.dart';

import 'package:provider/provider.dart';

import '/services/services.dart';

import '/views/views.dart';

import '/constants/constants.dart';

import '/models/models.dart';

import '/theme/theme.dart';

import '/utils/utils.dart';

import 'bloc/company_bloc.dart';



class CompaniesListing extends StatelessWidget {

  const CompaniesListing({super.key});



  @override

  Widget build(BuildContext context) {

    return BlocProvider(

      create: (_) => CompanyBloc()..add(LoadCompanies()),

      child: const CompanyListView(),

    );

  }

}



class CompanyListView extends StatelessWidget {

  const CompanyListView({super.key});



  @override

  Widget build(BuildContext context) {

    return ChangeNotifierProvider(

      create: (context) => PaginatedDataController<CompanyModel>(

        initialSortColumnIndex: 0,

        filterLogic: (company, query) {

          final q = query.toLowerCase();

          return company.name.toLowerCase().contains(q) ||

              (company.email?.toLowerCase().contains(q) ?? false) ||

              (company.phone?.toLowerCase().contains(q) ?? false);

        },

        sortLogic: (a, b, col, asc) {

          int compare;

          switch (col) {

            case 0:

              compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());

              break;

            case 1:

              compare = (a.email ?? '').toLowerCase().compareTo(

                (b.email ?? '').toLowerCase(),

              );

              break;

            case 2:

              compare = (a.phone ?? '').compareTo(b.phone ?? '');

              break;

            case 3:

              compare = a.isActive.toString().compareTo(b.isActive.toString());

              break;

            default:

              compare = (a.uid ?? '').compareTo(b.uid ?? '');

              break;

          }

          return asc ? compare : -compare;

        },

        getItemId: (company) => company.uid ?? '',

      ),

      child: const CompanyListingView(),

    );

  }

}



class CompanyListingView extends StatefulWidget {

  const CompanyListingView({super.key});



  @override

  State<CompanyListingView> createState() => _CompanyListingViewState();

}



class _CompanyListingViewState extends State<CompanyListingView> {

  final List<CompanyModel> _selectedCompanies = [];

  PermissionModel? permissions;
  bool _permissionsLoaded = false;

  bool _isAdmin = false;

  final ScrollController _hScrollController = ScrollController();



  @override

  void initState() {

    super.initState();

    _loadPermissions();

  }



  Future<void> _loadPermissions() async {

    permissions = await PermissionService.getPermissions('Companies');

    _isAdmin = await Spdb.isAdminLoggedIn();

    _permissionsLoaded = true;

    setState(() {});

  }



  Future<void> _refreshCompanies(BuildContext context) async {

    context.read<CompanyBloc>().add(LoadCompanies());

  }



  @override

  Widget build(BuildContext context) {

    final controllerRead = Provider.of<PaginatedDataController<CompanyModel>>(

      context,

      listen: false,

    );

    final controllerWatch = Provider.of<PaginatedDataController<CompanyModel>>(

      context,

      listen: true,

    );



    return Scaffold(

      appBar: kIsMobile

          ? AppBar(leading: const Back(), title: const Text('Companies'))

          : null,

      body: BlocListener<CompanyBloc, CompanyState>(

        listenWhen: (previous, current) => current is CompanyLoaded,

        listener: (context, state) {

          if (state is CompanyLoaded) {

            controllerRead.setData(state.companies);

          }

        },

        child: BlocBuilder<CompanyBloc, CompanyState>(

          builder: (context, state) {

            if (state is CompanyLoading) {

              return const WaitingLoading();

            }



            if (state is CompanyLoaded) {

              if (!_permissionsLoaded) {

                return const WaitingLoading();

              }

              if (!(permissions?.canView ?? false)) {

                return buildNoPermissionView(context);

              }

              return RefreshIndicator(

                onRefresh: () => _refreshCompanies(context),

                child: ListView(

                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.all(24.0),

                  children: [

                    _buildFilterRow(onSearchChanged: controllerRead.setSearch),

                    const SizedBox(height: 10),

                    _buildActionRow(context),

                    const SizedBox(height: 20),

                    if (controllerWatch.paginatedItems.isEmpty)

                      const NoData(text: "No matching records found")

                    else

                      Container(

                        decoration: BoxDecoration(

                          color: Theme.of(context).colorScheme.surface,

                          borderRadius: BorderRadius.circular(8),

                          boxShadow: [

                            BoxShadow(

                              color: Theme.of(

                                context,

                              ).colorScheme.shadow.withValues(alpha: 0.1),

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

                                        sortColumnIndex:

                                            controllerWatch.sortColumnIndex,

                                        sortAscending:

                                            controllerWatch.sortAscending,

                                        headingRowColor:

                                            WidgetStateProperty.all(

                                              Theme.of(context)

                                                  .colorScheme

                                                  .surfaceContainerHighest,

                                            ),

                                        headingTextStyle: Theme.of(context)

                                            .textTheme

                                            .bodySmall

                                            ?.copyWith(

                                              fontWeight: FontWeight.bold,

                                              color: Theme.of(

                                                context,

                                              ).colorScheme.onSurface,

                                            ),

                                        columns: _buildColumns(controllerRead),

                                        rows: controllerWatch.paginatedItems

                                            .map(

                                              (company) => _buildDataRow(

                                                context,

                                                company,

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

                              child: PaginationControls<CompanyModel>(),

                            ),

                          ],

                        ),

                      ),

                  ],

                ),

              );

            }



            if (state is CompanyError) {

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



  List<DataColumn> _buildColumns(

    PaginatedDataController<CompanyModel> controller,

  ) {

    return [

      DataColumn(

        label: _sortableHeader("Name", controller),

        onSort: controller.setSort,

      ),

      DataColumn(

        label: _sortableHeader("Email", controller),

        onSort: controller.setSort,

      ),

      DataColumn(

        label: Text("Phone", style: Theme.of(context).textTheme.bodySmall),

      ),

      DataColumn(

        label: Text(

          "Branch Code",

          style: Theme.of(context).textTheme.bodySmall,

        ),

      ),

      DataColumn(

        label: Text("Status", style: Theme.of(context).textTheme.bodySmall),

      ),

      DataColumn(

        label: Text("Created By", style: Theme.of(context).textTheme.bodySmall),

      ),

      DataColumn(

        label: Text("Action", style: Theme.of(context).textTheme.bodySmall),

      ),

    ];

  }



  Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [_searchBox(onSearchChanged: onSearchChanged)],

    );

  }



  Widget _buildActionRow(context) {

    final controllerWatch = Provider.of<PaginatedDataController<CompanyModel>>(

      context,

      listen: true,

    );

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [

        Row(

          children: [

            if (permissions?.canCreate ?? false) ...[

              ElevatedButton.icon(

                onPressed: () {

                  final form = const CompaniesCreate();



                  if (kIsMobile) {

                    Sheet.showSheet(context, widget: form);

                  } else {

                    GeneralDialog.showRTLSheet(context, form);

                  }

                },

                icon: const Icon(Icons.add, size: 18),

                label: Text(

                  "Add Branch",

                  style: Theme.of(context).textTheme.bodySmall?.copyWith(

                    color: Theme.of(context).colorScheme.onPrimary,

                  ),

                ),

                style: ElevatedButton.styleFrom(

                  backgroundColor: Theme.of(context).colorScheme.primary,

                  foregroundColor: Theme.of(context).colorScheme.onPrimary,

                ),

              ),

            ],

            // const SizedBox(width: 10),

            // ElevatedButton.icon(

            //   label: Text("Export"),

            //   icon: const Icon(Iconsax.export_3),

            //   onPressed: controllerWatch.paginatedItems.isEmpty

            //       ? null

            //       : () async {

            //           try {

            //             List<List<String>> exportData = [];



            //             // Add header row

            //             exportData.add([

            //               'Name',

            //               'Email',

            //               'Phone',

            //               'Branch Code',

            //               'GSTIN',

            //               'Status',

            //               'Created By',

            //             ]);



            //             final controller =

            //                 Provider.of<PaginatedDataController<CompanyModel>>(

            //                   context,

            //                   listen: false,

            //                 );

            //             for (var company in controller.paginatedItems) {

            //               exportData.add([

            //                 company.name,

            //                 company.email ?? '',

            //                 company.phone ?? '',

            //                 company.branchCode ?? '',

            //                 company.gstin ?? '',

            //                 company.isActive ? 'Active' : 'Inactive',

            //                 company.createdBy.name,

            //               ]);

            //             }



            //             // Generate Excel

            //             var fileBytes = await XlsxWriter().create(exportData);



            //             // Save to downloads

            //             var filePath = await saveFileToDownloads(

            //               fileBytes,

            //               fileName: 'Companies List.xlsx',

            //             );



            //             // Open file

            //             openfile(filePath, context);

            //           } catch (e) {

            //             FlushBar.show(context, e.toString(), isSuccess: false);

            //           }

            //         },

            //   style: ElevatedButton.styleFrom(

            //     backgroundColor: Theme.of(context).colorScheme.secondary,

            //     foregroundColor: Theme.of(context).colorScheme.onSecondary,

            //   ),

            // ),

            const SizedBox(width: 10),

            if (_isAdmin && _selectedCompanies.isNotEmpty) ...[

              ElevatedButton.icon(

                label: Text(

                  "Delete",

                  style: Theme.of(

                    context,

                  ).textTheme.bodySmall?.copyWith(color: Colors.white),

                ),

                icon: const Icon(Iconsax.trash),

                onPressed: () async {

                  if (_selectedCompanies.isEmpty) return;



                  // Confirm

                  final confirm = await showDialog<bool>(

                    context: context,

                    builder: (context) => ConfirmDialog(

                      title: 'Delete',

                      content: 'Are you sure want to delete these companies?',

                    ),

                    barrierDismissible: false,

                  );



                  if (confirm != true) return;



                  try {

                    // Backup

                    final deletedCompanies = _selectedCompanies

                        .map((e) => e.copyWith())

                        .toList();



                    // Loader

                    futureLoading(context);



                    // Delete

                    for (var company in deletedCompanies) {

                      await CompanyService.deleteCompany(

                        uid: company.uid ?? '',

                      );

                    }



                    // Close loader

                    if (Navigator.canPop(context)) Navigator.pop(context);



                    // Clear selection

                    _selectedCompanies.clear();

                    setState(() {});



                    // UNDO

                    FlushBar.show(

                      context,

                      'Companies deleted successfully',

                      actionLabel: 'UNDO',

                      onActionPressed: () async {

                        for (var _ in deletedCompanies) {

                          // Restore logic would go here

                          // For now, just refresh

                        }



                        if (!context.mounted) return;



                        context.read<CompanyBloc>().add(LoadCompanies());

                      },

                    );

                  } catch (e, st) {

                    if (Navigator.canPop(context)) Navigator.pop(context);



                    await ErrorService.recordError(e, st);



                    FlushBar.show(

                      context,

                      'Failed to delete companies: $e',

                      isSuccess: false,

                    );

                  }

                },

                style: ElevatedButton.styleFrom(

                  backgroundColor: Theme.of(context).colorScheme.error,

                  foregroundColor: Theme.of(context).colorScheme.onError,

                ),

              ),

            ],

            const SizedBox(width: 10),

            if (permissions?.canDelete ?? false) ...[

              if (_selectedCompanies.isNotEmpty)

                ElevatedButton.icon(

                  label: Text(

                    "Delete",

                    style: Theme.of(

                      context,

                    ).textTheme.bodySmall?.copyWith(color: Colors.white),

                  ),

                  icon: const Icon(Iconsax.trash),

                  onPressed: () async {

                    if (_selectedCompanies.isEmpty) return;



                    // Confirm

                    final confirm = await showDialog<bool>(

                      context: context,

                      builder: (context) => ConfirmDialog(

                        title: 'Delete',

                        content: 'Are you sure want to delete these companies?',

                      ),

                      barrierDismissible: false,

                    );



                    if (confirm != true) return;



                    try {

                      // Backup

                      final deletedCompanies = _selectedCompanies

                          .map((e) => e.copyWith())

                          .toList();



                      // Loader

                      futureLoading(context);



                      // Delete

                      for (var company in deletedCompanies) {

                        await CompanyService.deleteCompany(

                          uid: company.uid ?? '',

                        );

                      }



                      // Close loader

                      if (Navigator.canPop(context)) Navigator.pop(context);



                      // Clear selection

                      _selectedCompanies.clear();

                      setState(() {});



                      // UNDO

                      FlushBar.show(

                        context,

                        'Companies deleted successfully',

                        actionLabel: 'UNDO',

                        onActionPressed: () async {

                          for (var _ in deletedCompanies) {

                            // Restore logic would go here

                            // For now, just refresh

                          }



                          if (!context.mounted) return;



                          context.read<CompanyBloc>().add(LoadCompanies());

                        },

                      );

                    } catch (e, st) {

                      if (Navigator.canPop(context)) Navigator.pop(context);



                      await ErrorService.recordError(e, st);



                      FlushBar.show(

                        context,

                        'Failed to delete companies: $e',

                        isSuccess: false,

                      );

                    }

                  },

                  style: ElevatedButton.styleFrom(

                    backgroundColor: Theme.of(context).colorScheme.error,

                    foregroundColor: Theme.of(context).colorScheme.onError,

                  ),

                ),

            ],

          ],

        ),

        if (kIsDesktop)

          IconButton(

            tooltip: "Refresh",

            icon: const Icon(Iconsax.refresh),

            onPressed: () => _refreshCompanies(context),

            iconSize: 18,

          ),

      ],

    );

  }



  Widget _sortableHeader(String label, controllerRead) {

    return Row(

      children: [

        Text(label, style: Theme.of(context).textTheme.bodySmall),

        const SizedBox(width: 4),

        Icon(

          Icons.arrow_upward,

          size: 14,

          color: Theme.of(context).colorScheme.onSurfaceVariant,

        ),

      ],

    );

  }



  DataRow _buildDataRow(

    BuildContext context,

    CompanyModel company,

    PaginatedDataController<CompanyModel> controllerWatch,

    PaginatedDataController<CompanyModel> controllerRead,

  ) {

    final isSelected = controllerWatch.selectedIds.contains(company.uid);



    return DataRow(

      selected: isSelected,

      onSelectChanged: (selected) {

        controllerRead.onSelected(company.uid!, selected);

        selected == true

            ? _selectedCompanies.add(company)

            : _selectedCompanies.remove(company);

        setState(() {});

      },

      cells: [

        /// Name

        DataCell(_nameCell(context, company)),



        /// Email

        DataCell(

          Text(

            company.email ?? '-',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),



        /// Phone

        DataCell(

          Text(

            company.phone ?? '-',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),



        /// Branch Code

        DataCell(

          Text(

            company.branchCode ?? '-',

            style: Theme.of(context).textTheme.bodySmall,

          ),

        ),



        /// Status

        DataCell(_statusCell(company.isActive)),



        /// Created By

        DataCell(CreatedByWidget(userData: company.createdBy)),



        /// Actions

        DataCell(_actionButtons(context, company)),

      ],

    );

  }



  Widget _nameCell(BuildContext context, CompanyModel company) {

    return InkWell(

      onTap: () {

        final profile = CompanyProfile(company: company);

        kIsMobile

            ? Sheet.showSheet(context, widget: profile)

            : GeneralDialog.showRTLSheet(context, profile);

      },

      child: Row(

        children: [

          ClipRRect(

            borderRadius: BorderRadius.circular(16),

            child: CachedNetworkImage(

              imageUrl: company.logoUrl ?? AppStrings.emptyProfilePhotoUrl,

              height: 30,

              width: 30,

              fit: BoxFit.cover,

              errorWidget: (context, url, error) => Container(

                height: 30,

                width: 30,

                color: Theme.of(context).colorScheme.surfaceContainerHighest,

                child: Icon(

                  Icons.business,

                  size: 16,

                  color: Theme.of(context).colorScheme.onSurfaceVariant,

                ),

              ),

            ),

          ),

          const SizedBox(width: 8),

          Text(

            company.name,

            style: Theme.of(

              context,

            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),

          ),

        ],

      ),

    );

  }



  Widget _statusCell(bool isActive) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(

        color: isActive ? AppColors.success : AppColors.danger,

        borderRadius: BorderRadius.circular(6),

      ),

      child: Text(

        isActive ? 'Active' : 'Inactive',

        style: Theme.of(

          context,

        ).textTheme.bodySmall?.copyWith(color: Colors.white),

      ),

    );

  }



  Widget _actionButtons(BuildContext context, CompanyModel company) {

    return Row(

      children: [

        if (permissions?.canEdit ?? false) ...[

          IconButton(

            icon: const Icon(Iconsax.edit),

            color: Theme.of(context).colorScheme.primary,

            splashRadius: 20,

            onPressed: () {

              final form = CompanyEdit(uid: company.uid!);



              if (kIsMobile) {

                Sheet.showSheet(context, widget: form);

              } else {

                GeneralDialog.showRTLSheet(context, form);

              }

            },

          ),

        ],

        if (permissions?.canDelete ?? false) ...[

          IconButton(

            icon: const Icon(Iconsax.trash),

            color: Theme.of(context).colorScheme.error,

            splashRadius: 20,

            onPressed: () async {

              // Confirm

              final confirm = await showDialog<bool>(

                context: context,

                builder: (_) => const ConfirmDialog(

                  title: 'Delete Company',

                  content: 'Are you sure you want to delete this company?',

                ),

              );



              if (confirm != true) return;



              try {

                // Backup

                // final deletedCompany = company.copyWith();



                // Delete

                await CompanyService.deleteCompany(uid: company.uid ?? '');



                if (!context.mounted) return;



                // UNDO

                FlushBar.show(

                  context,

                  'Company deleted successfully',

                  actionLabel: 'UNDO',

                  onActionPressed: () async {

                    // Restore logic would go here

                    if (!context.mounted) return;

                    context.read<CompanyBloc>().add(LoadCompanies());

                  },

                );

              } catch (e, st) {

                await ErrorService.recordError(e, st);



                FlushBar.show(

                  context,

                  'Failed to delete company: $e',

                  isSuccess: false,

                );

              }

            },

          ),

        ],

      ],

    );

  }



  Widget _searchBox({required ValueChanged<String> onSearchChanged}) {

    return SizedBox(

      width: 200,

      child: ListingSearchField(onChanged: onSearchChanged),

    );

  }

}

