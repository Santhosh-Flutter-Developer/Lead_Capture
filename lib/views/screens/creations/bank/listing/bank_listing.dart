// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:iconsax/iconsax.dart';
// import 'package:provider/provider.dart';
// import '/models/models.dart';
// import '/views/views.dart';
// import '/utils/utils.dart';
// import '/theme/theme.dart';
// import '/services/services.dart';
// import 'bloc/bank_bloc.dart';

// const String _pageTitle = "Bank";

// class BankListing extends StatelessWidget {
//   const BankListing({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => BankBloc()..add(StreamBanks()),
//       child: ChangeNotifierProvider(
//         create: (context) => PaginatedDataController<BankModel>(
//           initialSortColumnIndex: 1,
//           filterLogic: (bank, query) {
//             final q = query.toLowerCase();
//             return bank.bankName.toLowerCase().contains(q) ||
//                 bank.shortCode.toLowerCase().contains(q) ||
//                 bank.ifscCode.toLowerCase().contains(q) ||
//                 bank.place.toLowerCase().contains(q);
//           },
//           sortLogic: (a, b, col, asc) {
//             int compare;
//             switch (col) {
//               case 1:
//                 compare = a.shortCode
//                     .toLowerCase()
//                     .compareTo(b.shortCode.toLowerCase());
//                 break;
//               case 2:
//                 compare = a.bankName
//                     .toLowerCase()
//                     .compareTo(b.bankName.toLowerCase());
//                 break;
//               case 3:
//                 compare = a.ifscCode
//                     .toLowerCase()
//                     .compareTo(b.ifscCode.toLowerCase());
//                 break;
//               case 4:
//                 compare =
//                     a.place.toLowerCase().compareTo(b.place.toLowerCase());
//                 break;
//               default:
//                 compare = (a.uid ?? '').compareTo(b.uid ?? '');
//                 break;
//             }
//             return asc ? compare : -compare;
//           },
//           getItemId: (bank) => bank.uid ?? '',
//         ),
//         child: const BankListingView(),
//       ),
//     );
//   }
// }

// class BankListingView extends StatefulWidget {
//   const BankListingView({super.key});

//   @override
//   State<BankListingView> createState() => _BankListingViewState();
// }

// class _BankListingViewState extends State<BankListingView> {
//   final List<BankModel> _selectedBanks = [];
//   PermissionModel? permissions;
//   final ScrollController _hScrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     _loadPermissions();
//   }

//   @override
//   void dispose() {
//     _hScrollController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadPermissions() async {
//     permissions = await PermissionService.getPermissions(_pageTitle);
//     setState(() {});
//   }

//   Future<void> _refreshBanks() async {
//     context.read<BankBloc>().add(StreamBanks());
//   }

//   @override
//   Widget build(BuildContext context) {
//     final controllerRead = context.read<PaginatedDataController<BankModel>>();
//     final controllerWatch =
//         context.watch<PaginatedDataController<BankModel>>();

//     return Scaffold(
//       appBar: kIsMobile
//           ? AppBar(leading: const Back(), title: const Text(_pageTitle))
//           : null,
//       body: BlocListener<BankBloc, BankState>(
//         listenWhen: (previous, current) => current is BankLoaded,
//         listener: (context, state) {
//           if (state is BankLoaded) {
//             controllerRead.setData(state.banks);
//           }
//         },
//         child: BlocBuilder<BankBloc, BankState>(
//           builder: (context, state) {
//             if (state is BankLoading) {
//               return const WaitingLoading();
//             }

//             if (state is BankLoaded) {
//               if (!(permissions?.canView ?? false)) {
//                 return buildNoPermissionView(context);
//               }
//               return RefreshIndicator(
//                 onRefresh: _refreshBanks,
//                 child: ListView(
//                   physics: const AlwaysScrollableScrollPhysics(),
//                   padding: const EdgeInsets.all(24.0),
//                   children: [
//                     _buildFilterRow(
//                         onSearchChanged: controllerRead.setSearch),
//                     const SizedBox(height: 10),
//                     _buildActionRow(context),
//                     const SizedBox(height: 20),
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Theme.of(context).colorScheme.surface,
//                         borderRadius: BorderRadius.circular(8),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Theme.of(context)
//                                 .colorScheme
//                                 .shadow
//                                 .withValues(alpha: 0.1),
//                             spreadRadius: 2,
//                             blurRadius: 5,
//                             offset: const Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: Column(
//                         children: [
//                           LayoutBuilder(
//                             builder: (context, constraints) {
//                               return Scrollbar(
//                                 controller: _hScrollController,
//                                 thumbVisibility: true,
//                                 trackVisibility: true,
//                                 thickness: 4,
//                                 radius: const Radius.circular(6),
//                                 scrollbarOrientation:
//                                     ScrollbarOrientation.bottom,
//                                 child: SingleChildScrollView(
//                                   controller: _hScrollController,
//                                   scrollDirection: Axis.horizontal,
//                                   child: ConstrainedBox(
//                                     constraints: BoxConstraints(
//                                       minWidth: constraints.maxWidth,
//                                     ),
//                                     child: DataTable(
//                                       showCheckboxColumn: true,
//                                       sortColumnIndex:
//                                           controllerWatch.sortColumnIndex,
//                                       sortAscending:
//                                           controllerWatch.sortAscending,
//                                       headingRowColor:
//                                           WidgetStateProperty.all(
//                                         Theme.of(context)
//                                             .colorScheme
//                                             .surfaceContainerHighest,
//                                       ),
//                                       headingTextStyle: Theme.of(context)
//                                           .textTheme
//                                           .bodySmall
//                                           ?.copyWith(
//                                             fontWeight: FontWeight.bold,
//                                             color: Theme.of(context)
//                                                 .colorScheme
//                                                 .onSurface,
//                                           ),
//                                       columns: [
//                                         DataColumn(
//                                           label: _sortableHeader(
//                                               context, "Short Code"),
//                                           onSort: controllerRead.setSort,
//                                         ),
//                                         DataColumn(
//                                           label: _sortableHeader(
//                                               context, "Bank Name"),
//                                           onSort: controllerRead.setSort,
//                                         ),
//                                         DataColumn(
//                                           label: _sortableHeader(
//                                               context, "IFSC Code"),
//                                           onSort: controllerRead.setSort,
//                                         ),
//                                         DataColumn(
//                                           label: _sortableHeader(
//                                               context, "Place"),
//                                           onSort: controllerRead.setSort,
//                                         ),
//                                         const DataColumn(
//                                             label: Text("Created By")),
//                                         const DataColumn(
//                                             label: Text("Action")),
//                                       ],
//                                       rows: controllerWatch.paginatedItems
//                                           .map(
//                                             (bank) => _buildDataRow(
//                                               context,
//                                               bank,
//                                               controllerWatch,
//                                               controllerRead,
//                                             ),
//                                           )
//                                           .toList(),
//                                     ),
//                                   ),
//                                 ),
//                               );
//                             },
//                           ),
//                           const Padding(
//                             padding: EdgeInsets.symmetric(
//                               horizontal: 16.0,
//                               vertical: 12.0,
//                             ),
//                             child: PaginationControls<BankModel>(),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             }

//             if (state is BankError) {
//               return Center(child: Text(state.message));
//             }
//             return const SizedBox.shrink();
//           },
//         ),
//       ),
//     );
//   }

//   Widget _sortableHeader(BuildContext context, String label) {
//     return Row(
//       children: [
//         Text(label),
//         const SizedBox(width: 4),
//         Icon(
//           Icons.arrow_upward,
//           size: 14,
//           color: Theme.of(context).colorScheme.onSurfaceVariant,
//         ),
//       ],
//     );
//   }

//   Widget _buildFilterRow({required ValueChanged<String> onSearchChanged}) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [_searchBox(onSearchChanged: onSearchChanged)],
//     );
//   }

//   Widget _buildActionRow(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Row(
//           children: [
//             (permissions?.canCreate ?? false)
//                 ? ElevatedButton.icon(
//                     onPressed: () {
//                       if (kIsMobile) {
//                         Sheet.showSheet(
//                           context,
//                           widget: const BankCreate(),
//                         );
//                       } else {
//                         GeneralDialog.showRTLSheet(
//                           context,
//                           const BankCreate(),
//                         );
//                       }
//                     },
//                     icon: const Icon(Icons.add, size: 18),
//                     label: Text(
//                       "Add $_pageTitle",
//                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                             color:
//                                 Theme.of(context).colorScheme.onPrimary,
//                           ),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor:
//                           Theme.of(context).colorScheme.primary,
//                       foregroundColor:
//                           Theme.of(context).colorScheme.onPrimary,
//                     ),
//                   )
//                 : ElevatedButton.icon(
//                     onPressed: null,
//                     icon: Icon(Icons.add,
//                         size: 18, color: AppColors.grey600),
//                     label: Text(
//                       "Add $_pageTitle",
//                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                             color: Theme.of(context)
//                                 .colorScheme
//                                 .onSurfaceVariant,
//                           ),
//                     ),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Theme.of(context)
//                           .colorScheme
//                           .surfaceContainer,
//                       side: BorderSide(
//                         color: Theme.of(context)
//                             .colorScheme
//                             .outlineVariant,
//                       ),
//                     ),
//                   ),
//             const SizedBox(width: 10),
//             if (_selectedBanks.isNotEmpty) ...[
//               (permissions?.canDelete ?? false)
//                   ? ElevatedButton.icon(
//                       label: Text(
//                         "Delete",
//                         style:
//                             Theme.of(context).textTheme.bodySmall?.copyWith(
//                                   color: Theme.of(context)
//                                       .colorScheme
//                                       .onPrimary,
//                                 ),
//                       ),
//                       icon: const Icon(Iconsax.trash),
//                       onPressed: () async {
//                         if (_selectedBanks.isEmpty) return;

//                         final result = await showDialog<bool>(
//                           context: context,
//                           builder: (context) => ConfirmDialog(
//                             title: 'Delete',
//                             content:
//                                 'Are you sure want to delete selected banks?',
//                           ),
//                           barrierDismissible: false,
//                         );

//                         if (result != true) return;

//                         try {
//                           final deletedBanks = _selectedBanks
//                               .map((e) => e.copyWith())
//                               .toList();

//                           futureLoading(context);

//                           for (var bank in deletedBanks) {
//                             await BankService.deleteBank(
//                                 uid: bank.uid ?? '');
//                           }

//                           if (Navigator.canPop(context)) {
//                             Navigator.pop(context);
//                           }

//                           _selectedBanks.clear();
//                           setState(() {});

//                           FlushBar.show(
//                             context,
//                             '$_pageTitle deleted successfully',
//                             actionLabel: 'UNDO',
//                             onActionPressed: () async {
//                               for (var bank in deletedBanks) {
//                                 if (bank.uid == null) continue;
//                                 await BankService.restoreBank(bank);
//                               }
//                               if (!context.mounted) return;
//                               context
//                                   .read<BankBloc>()
//                                   .add(StreamBanks());
//                             },
//                           );
//                         } catch (e, st) {
//                           if (Navigator.canPop(context)) {
//                             Navigator.pop(context);
//                           }
//                           await ErrorService.recordError(e, st);
//                           FlushBar.show(
//                             context,
//                             e.toString(),
//                             isSuccess: false,
//                           );
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor:
//                             Theme.of(context).colorScheme.error,
//                         foregroundColor:
//                             Theme.of(context).colorScheme.onError,
//                       ),
//                     )
//                   : ElevatedButton.icon(
//                       label: Text(
//                         "Delete",
//                         style:
//                             Theme.of(context).textTheme.bodySmall?.copyWith(
//                                   color: Theme.of(context)
//                                       .colorScheme
//                                       .onSurfaceVariant,
//                                 ),
//                       ),
//                       icon: Icon(
//                         Iconsax.trash,
//                         color: Theme.of(context)
//                             .colorScheme
//                             .onSurfaceVariant,
//                       ),
//                       onPressed: () {},
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Theme.of(context)
//                             .colorScheme
//                             .surfaceContainer,
//                         foregroundColor: Theme.of(context)
//                             .colorScheme
//                             .onSurfaceVariant,
//                       ),
//                     ),
//             ],
//           ],
//         ),
//         if (kIsDesktop)
//           IconButton(
//             tooltip: "Refresh",
//             icon: const Icon(Iconsax.refresh),
//             onPressed: _refreshBanks,
//             iconSize: 18,
//           ),
//       ],
//     );
//   }

//   DataRow _buildDataRow(
//     BuildContext context,
//     BankModel bank,
//     PaginatedDataController<BankModel> controllerWatch,
//     PaginatedDataController<BankModel> controllerRead,
//   ) {
//     bool isSelected = controllerWatch.selectedIds.contains(bank.uid);
//     return DataRow(
//       selected: isSelected,
//       onSelectChanged: (selected) {
//         controllerRead.onSelected(bank.uid ?? '', selected);
//         if (selected ?? false) {
//           _selectedBanks.add(bank);
//         } else {
//           _selectedBanks.remove(bank);
//         }
//         setState(() {});
//       },
//       cells: [
//         DataCell(
//           Text(
//             bank.shortCode,
//             style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                   fontWeight: FontWeight.w600,
//                   color: Theme.of(context).colorScheme.primary,
//                 ),
//           ),
//         ),
//         DataCell(
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 bank.bankName,
//                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                       fontWeight: FontWeight.w500,
//                     ),
//               ),
//               Text(
//                 'creator : ${bank.createdBy.name}',
//                 style: Theme.of(context).textTheme.labelSmall?.copyWith(
//                       color:
//                           Theme.of(context).colorScheme.onSurfaceVariant,
//                     ),
//               ),
//             ],
//           ),
//         ),
//         DataCell(
//           Text(
//             bank.ifscCode,
//             style: Theme.of(context).textTheme.bodySmall,
//           ),
//         ),
//         DataCell(
//           Text(
//             bank.place,
//             style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                   color: Theme.of(context).colorScheme.primary,
//                 ),
//           ),
//         ),
//         DataCell(CreatedByWidget(userData: bank.createdBy)),
//         DataCell(
//           Row(
//             children: [
//               (permissions?.canEdit ?? false)
//                   ? IconButton(
//                       icon: const Icon(Iconsax.edit),
//                       onPressed: () {
//                         if (kIsMobile) {
//                           Sheet.showSheet(
//                             context,
//                             widget: BankEdit(uid: bank.uid ?? ''),
//                           );
//                         } else {
//                           GeneralDialog.showRTLSheet(
//                             context,
//                             BankEdit(uid: bank.uid ?? ''),
//                           );
//                         }
//                       },
//                       color: AppColors.info,
//                       splashRadius: 20,
//                     )
//                   : IconButton(
//                       icon:
//                           Icon(Iconsax.edit, color: AppColors.grey400),
//                       onPressed: null,
//                     ),
//               (permissions?.canDelete ?? false)
//                   ? IconButton(
//                       icon: const Icon(Iconsax.trash),
//                       color: AppColors.danger,
//                       splashRadius: 20,
//                       onPressed: () async {
//                         final result = await showDialog<bool>(
//                           context: context,
//                           builder: (context) => ConfirmDialog(
//                             title: 'Delete $_pageTitle',
//                             content:
//                                 'Are you sure want to delete this $_pageTitle?',
//                           ),
//                         );

//                         if (result != true) return;

//                         try {
//                           final deletedBank = bank.copyWith();

//                           await BankService.deleteBank(
//                               uid: bank.uid ?? '');

//                           if (!context.mounted) return;

//                           FlushBar.show(
//                             context,
//                             '$_pageTitle deleted successfully',
//                             actionLabel: 'UNDO',
//                             onActionPressed: () async {
//                               if (deletedBank.uid == null) return;
//                               await BankService.restoreBank(deletedBank);
//                               if (!context.mounted) return;
//                               context
//                                   .read<BankBloc>()
//                                   .add(StreamBanks());
//                             },
//                           );
//                         } catch (e, st) {
//                           await ErrorService.recordError(e, st);
//                           debugPrint(
//                               "${e.toString()}, ${st.toString()}");
//                           FlushBar.show(
//                             context,
//                             e.toString(),
//                             isSuccess: false,
//                             error: e,
//                             stackTrace: st,
//                           );
//                         }
//                       },
//                     )
//                   : IconButton(
//                       icon: Icon(Iconsax.trash,
//                           color: AppColors.grey400),
//                       onPressed: null,
//                     ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _searchBox({required ValueChanged<String> onSearchChanged}) {
//     return SizedBox(
//       width: 250,
//       child: ListingSearchField(
//         onChanged: onSearchChanged,
//         pageTitle: _pageTitle,
//       ),
//     );
//   }
// }
