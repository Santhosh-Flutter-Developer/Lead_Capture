import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/services/services.dart';
import 'bloc/payment_mode_bloc.dart';

const String _pageTitle = "Payment Mode";
const double _wideBreakpoint = 900;

class PaymentModeListing extends StatelessWidget {
  const PaymentModeListing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentModeBloc()..add(StreamPaymentMode()),
      child: ChangeNotifierProvider(
        create: (context) => PaginatedDataController<PaymentModeModel>(
          initialSortColumnIndex: 1,
          filterLogic: (paymentMode, query) {
            final q = query.toLowerCase();
            return paymentMode.name.toLowerCase().contains(q) ||
                paymentMode.name.toLowerCase().contains(q);
          },
          sortLogic: (a, b, col, asc) {
            int compare;
            switch (col) {
              case 2:
                compare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                break;
              case 3:
                compare = a.description.toLowerCase().compareTo(
                  b.description.toLowerCase(),
                );
                break;
              default:
                compare = (a.uid ?? '').compareTo(b.uid ?? '');
                break;
            }
            return asc ? compare : -compare;
          },
          getItemId: (paymentMode) => paymentMode.uid ?? '',
        ),
        child: const PaymentModeListingView(),
      ),
    );
  }
}

class PaymentModeListingView extends StatefulWidget {
  const PaymentModeListingView({super.key});

  @override
  State<PaymentModeListingView> createState() => _PaymentModeListingViewState();
}

class _PaymentModeListingViewState extends State<PaymentModeListingView> {
  final List<PaymentModeModel> _selectedPaymentModes = [];
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

  Future<void> _refreshPaymentMode() async {
    context.read<PaymentModeBloc>().add(StreamPaymentMode());
  }

  bool _isWide(BuildContext context) =>
      !kIsMobile && MediaQuery.of(context).size.width >= _wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final controllerRead =
        context.read<PaginatedDataController<PaymentModeModel>>();
    final controllerWatch =
        context.watch<PaginatedDataController<PaymentModeModel>>();
    final isWide = _isWide(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isWide
          ? null
          : AppBar(
              leading: const Back(),
              title: const Text("Payment Mode"),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
            ),
      body: BlocListener<PaymentModeBloc, PaymentModeState>(
        listenWhen: (previous, current) => current is PaymentModeLoaded,
        listener: (context, state) {
          if (state is PaymentModeLoaded) {
            controllerRead.setData(state.paymentMode);
          }
        },
        child: BlocBuilder<PaymentModeBloc, PaymentModeState>(
          builder: (context, state) {
            if (state is PaymentModeLoading) {
              return const WaitingLoading();
            }

            if (state is PaymentModeLoaded) {
              if (!_permissionsLoaded) {
                return const WaitingLoading();
              }
              if (!(permissions?.canView ?? false)) {
                return buildNoPermissionView(context);
              }
              return RefreshIndicator(
                onRefresh: _refreshPaymentMode,
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
                        _buildHeaderBanner(context, state.paymentMode.length),
                        const SizedBox(height: 20),
                      ],
                      _buildToolbar(
                        context,
                        controllerRead,
                        state.paymentMode.length,
                      ),
                      const SizedBox(height: 18),
                      controllerWatch.paginatedItems.isEmpty
                          ? NoData(
                              text: state.paymentMode.isEmpty
                                  ? "No payment modes available"
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

            if (state is PaymentModeError) {
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
  Widget _buildHeaderBanner(BuildContext context, int totalSources) {
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
              Iconsax.global,
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
                  "Payment Mode Management",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage the payment modes used in payments",
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
                  '$totalSources',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  totalSources == 1 ? "Payment Mode" : "Payment Modes",
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
    PaginatedDataController<PaymentModeModel> controllerRead,
    int totalSources,
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
                  Sheet.showSheet(context, widget: const PaymentModeCreate());
                } else {
                  GeneralDialog.showRTLSheet(
                    context,
                    const PaymentModeCreate(),
                  );
                }
              },
            ),
      if (_selectedPaymentModes.isNotEmpty &&
          (permissions?.canDelete ?? false))
        _gradientButton(
          context: context,
          icon: Iconsax.trash,
          label: "Delete (${_selectedPaymentModes.length})",
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
          onPressed: _refreshPaymentMode,
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
                _sourceCountChip(context, totalSources),
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

  Widget _sourceCountChip(BuildContext context, int totalSources) {
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
            Iconsax.global,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "$totalSources total",
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
    return _PaymentModeSearchField(
      pageTitle: _pageTitle,
      onChanged:
          context.read<PaginatedDataController<PaymentModeModel>>().setSearch,
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

  // ---------------------------------------------------------------------
  // Desktop / wide layout: table card
  // ---------------------------------------------------------------------
  Widget _buildTableCard(
    BuildContext context,
    PaginatedDataController<PaymentModeModel> controllerWatch,
    PaginatedDataController<PaymentModeModel> controllerRead,
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
                          DataColumn(
                            label: const Text("Created"),
                            onSort: controllerRead.setSort,
                          ),
                          const DataColumn(label: Text("Created By")),
                          const DataColumn(label: Text("Action")),
                        ],
                        rows: List.generate(
                          controllerWatch.paginatedItems.length,
                          (index) {
                            final paymentMode =
                                controllerWatch.paginatedItems[index];
                            return _buildDataRow(
                              context,
                              paymentMode,
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
            child: PaginationControls<PaymentModeModel>(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(
    BuildContext context,
    PaymentModeModel paymentMode,
    PaginatedDataController<PaymentModeModel> controllerWatch,
    PaginatedDataController<PaymentModeModel> controllerRead,
    int index,
  ) {
    final isSelected = controllerWatch.selectedIds.contains(paymentMode.uid);
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
        controllerRead.onSelected(paymentMode.uid ?? '', selected);
        if (selected ?? false) {
          _selectedPaymentModes.add(paymentMode);
        } else {
          _selectedPaymentModes.remove(paymentMode);
        }
        setState(() {});
      },
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _avatarCircle(paymentMode.name, size: 32),
              const SizedBox(width: 10),
              Text(
                paymentMode.name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              paymentMode.description.isNotEmpty
                  ? paymentMode.description
                  : "—",
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                paymentMode.createdAt.listingDateTime,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DataCell(CreatedByWidget(userData: paymentMode.createdBy)),
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
                      onPressed: () => _onEditTap(paymentMode),
                    ),
              if ((permissions?.canEdit ?? false) && (permissions?.canDelete ?? false))
                const SizedBox(width: 8),
              if (permissions?.canDelete ?? false) _iconCircleButton(
                      context,
                      icon: Iconsax.trash,
                      tooltip: "Delete",
                      background: AppColors.danger.withValues(alpha: 0.12),
                      iconColor: AppColors.danger,
                      onPressed: () => _onDeleteTap(paymentMode),
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
  void _onEditTap(PaymentModeModel paymentMode) {
    final isWide = _isWide(context);
    if (!isWide) {
      Sheet.showSheet(
        context,
        widget: PaymentModeEdit(uid: paymentMode.uid ?? ''),
      );
    } else {
      GeneralDialog.showRTLSheet(
        context,
        PaymentModeEdit(uid: paymentMode.uid ?? ''),
      );
    }
  }

  Future<void> _onDeleteTap(PaymentModeModel paymentMode) async {
    final isAssigned = await PaymentModeService.isPaymentModeAssigned(
      paymentMode.uid ?? '',
    );

    if (isAssigned) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: const Text(
            'This payment mode is used in one or more payments and cannot be deleted.',
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
      final deletedSource = paymentMode.copyWith();

      await PaymentModeService.deletePaymentMode(uid: paymentMode.uid ?? '');

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          if (deletedSource.uid == null) return;
          await PaymentModeService.restorePaymentMode(deletedSource);
          if (!mounted) return;
          context.read<PaymentModeBloc>().add(StreamPaymentMode());
        },
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      FlushBar.show(context, e.toString(), isSuccess: false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedPaymentModes.isEmpty) return;

    for (var source in _selectedPaymentModes) {
      final isAssigned = await PaymentModeService.isPaymentModeAssigned(
        source.uid ?? '',
      );

      if (isAssigned) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cannot Delete'),
            content: const Text(
              'One or more selected payment modes are used in payments.',
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
      final deletedSources = _selectedPaymentModes
          .map((e) => e.copyWith())
          .toList();

      futureLoading(context);

      for (var source in deletedSources) {
        await PaymentModeService.deletePaymentMode(uid: source.uid ?? '');
      }

      if (Navigator.canPop(context)) Navigator.pop(context);

      _selectedPaymentModes.clear();
      setState(() {});

      if (!mounted) return;

      FlushBar.show(
        context,
        '$_pageTitle deleted successfully',
        actionLabel: 'UNDO',
        onActionPressed: () async {
          for (var source in deletedSources) {
            if (source.uid == null) continue;
            await PaymentModeService.restorePaymentMode(source);
          }
          if (!mounted) return;
          context.read<PaymentModeBloc>().add(StreamPaymentMode());
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
// A more polished, colorful search field for the Payment Mode toolbar.
// ---------------------------------------------------------------------
class _PaymentModeSearchField extends StatefulWidget {
  final String pageTitle;
  final ValueChanged<String> onChanged;
  const _PaymentModeSearchField({
    required this.pageTitle,
    required this.onChanged,
  });

  @override
  State<_PaymentModeSearchField> createState() =>
      _PaymentModeSearchFieldState();
}

class _PaymentModeSearchFieldState extends State<_PaymentModeSearchField> {
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