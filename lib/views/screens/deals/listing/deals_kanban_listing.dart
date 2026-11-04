import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';

class DealKanbanListing extends StatefulWidget {
  final List<DealModel> dealList;

  /// Called after a deal was deleted / restored from the detail sheet so the
  /// parent can refresh its stream.
  final VoidCallback? onDealDeleted;
  const DealKanbanListing({
    super.key,
    required this.dealList,
    this.onDealDeleted,
  });

  @override
  State<DealKanbanListing> createState() => _DealKanbanListingState();
}

class _DealKanbanListingState extends State<DealKanbanListing> {
  late Future _future;
  late Map<DealStatusModel, List<DealModel>> _dealList;

  DealModel? _draggedDeal;
  DealStatusModel? _draggedFromList;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  PermissionModel? _permissions;

  @override
  void initState() {
    super.initState();
    _future = _initializeBoard();
    _loadPermissions();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Deals');
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DealKanbanListing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dealList != widget.dealList) {
      _future = _initializeBoard();
      setState(() {});
    }
  }

  Future<void> _initializeBoard() async {
    _dealList = await DealService.getDealByGroup(dealList: widget.dealList);
  }

  void _handleDragStarted(DealModel task, DealStatusModel fromList) {
    setState(() {
      _draggedDeal = task;
      _draggedFromList = fromList;
    });
  }

  void _handleDragEnd(DraggableDetails details) {
    if (!details.wasAccepted &&
        _draggedDeal != null &&
        _draggedFromList != null) {
      setState(() {
        if (!_dealList[_draggedFromList]!.any(
          (t) => t.uid == _draggedDeal!.uid,
        )) {
          _dealList[_draggedFromList]!.add(_draggedDeal!);
        }
      });
    }
    setState(() {
      _draggedDeal = null;
      _draggedFromList = null;
    });
  }

  void _startEdgeScrolling(DragUpdateDetails details) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scrollThreshold = 100.0; // Distance from edge to trigger scroll
    double scrollSpeed = 15.0; // How fast to scroll

    _scrollTimer?.cancel();

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_scrollController.hasClients) {
        timer.cancel();
        return;
      }
      if (details.globalPosition.dx < scrollThreshold) {
        // Scroll Left
        if (_scrollController.offset > 0) {
          _scrollController.animateTo(
            _scrollController.offset - scrollSpeed,
            duration: const Duration(milliseconds: 20),
            curve: Curves.linear,
          );
        }
      } else if (details.globalPosition.dx > screenWidth - scrollThreshold) {
        // Scroll Right
        if (_scrollController.offset <
            _scrollController.position.maxScrollExtent) {
          _scrollController.animateTo(
            _scrollController.offset + scrollSpeed,
            duration: const Duration(milliseconds: 20),
            curve: Curves.linear,
          );
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _openDeal(DealModel deal) async {
    final result = kIsDesktop
        ? await GeneralDialog.showRTLSheet(context, DealsViewPage(deal: deal))
        : await Sheet.showSheet(context, widget: DealsViewPage(deal: deal));
    if ((result == 'deleted' || result == 'restored') && mounted) {
      widget.onDealDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const WaitingLoading();
        } else if (snapshot.hasError) {
          return ErrorDisplay(error: snapshot.error.toString());
        } else if (_dealList.isEmpty) {
          return const NoData(
            text:
                'No deal statuses found. Add a deal status first to use the board.',
          );
        } else {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12.0),
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _dealList.entries.map((entry) {
                  return _buildKanbanColumn(entry.key, entry.value);
                }).toList(),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildKanbanColumn(DealStatusModel list, List<DealModel> deals) {
    return DragTarget<DealModel>(
      onWillAcceptWithDetails: (details) {
        // Prevent dragging locked deals
        if (details.data.isLocked) {
          return false;
        }
        return (_permissions?.canEdit ?? false) && details.data.uid != null;
      },
      onAcceptWithDetails: (details) async {
        final deal = details.data;

        if (_draggedFromList == list) return;

        final originalDeal = deal.copyWith();

        _dealList[_draggedFromList!] = List.from(_dealList[_draggedFromList]!)
          ..removeWhere((t) => t.uid == deal.uid);

        _dealList[list] = List.from(_dealList[list]!)..add(deal);

        setState(() {});

        try {
          await DealService.updateDealStatus(
            uid: deal.uid!,
            dealStatus: list.uid!,
          );
        } catch (e) {
          _dealList[_draggedFromList!] = List.from(_dealList[_draggedFromList]!)
            ..add(originalDeal);
          _dealList[list] = List.from(_dealList[list]!)
            ..removeWhere((l) => l.uid == deal.uid);

          setState(() {});

          FlushBar.show(context, e.toString(), isSuccess: false);
        }
      },
      builder: (context, candidateData, rejectedData) {
        bool isHovering = candidateData.isNotEmpty;
        double totalValue = deals.fold(
          0.0,
          (sum, item) => sum + item.dealValue,
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: MediaQuery.of(context).size.width < 700
              ? MediaQuery.of(context).size.width * 0.8
              : 260,
          height: MediaQuery.of(context).size.height * 0.72,
          margin: const EdgeInsets.only(right: 12.0),
          decoration: BoxDecoration(
            color: isHovering
                ? Color(list.color).withValues(alpha: 0.1)
                : Color(list.color).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: isHovering
                  ? Theme.of(context).colorScheme.primary
                  : Color(list.color).withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKanbanColumnHeader(list, deals.length, totalValue),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 10,
                  ),
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    return _buildKanbanCard(deals[index], list);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumnHeader(
    DealStatusModel list,
    int count,
    double totalValue,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color(list.color),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surface,
          child: Text(
            _currencyFormat.format(totalValue),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanCard(DealModel task, DealStatusModel list) {
    final isLocked = task.isLocked;

    if (isLocked || !(_permissions?.canEdit ?? false)) {
      return _buildStaticCard(task, list, locked: isLocked);
    }

    // Draggable card for unlocked deals
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Draggable<DealModel>(
        data: task,
        onDragStarted: () => _handleDragStarted(task, list),
        onDragUpdate: (details) {
          _startEdgeScrolling(details);
        },
        onDragEnd: (details) {
          _scrollTimer?.cancel();
          _handleDragEnd(details);
        },
        feedback: Material(
          elevation: 8.0,
          borderRadius: BorderRadius.circular(12.0),
          color: Colors.transparent,
          child: Transform.rotate(
            angle: 0.05,
            child: Container(
              width: 244,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
              child: _buildCardContent(task),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.2,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        child: InkWell(
          onTap: () => _openDeal(task),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12.0),
            child: _buildCardContent(task),
          ),
        ),
      ),
    );
  }

  /// Locked deals (and users without edit permission) get a static card that
  /// still opens the detail view but can not be dragged.
  Widget _buildStaticCard(
    DealModel task,
    DealStatusModel list, {
    required bool locked,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => _openDeal(task),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: locked
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
                : scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: locked
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(opacity: locked ? 0.85 : 1, child: _buildCardContent(task)),
              if (locked) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.lock, size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(DealModel deal) {
    final scheme = Theme.of(context).colorScheme;
    final status = CacheService.dealStatusByUid(deal.dealStatus ?? '');
    final statusColor = status != null ? Color(status.color) : AppColors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// HEADER ROW (Avatar + Name + Value)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                deal.dealName.isNotEmpty ? deal.dealName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),

            /// Name + Email + Company + Contact
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deal.dealName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),

                  if (deal.dealEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      deal.dealEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  if (deal.companyName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      deal.companyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (deal.clientName?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            deal.clientName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            /// Deal Value
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currencyFormat.format(deal.dealValue),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        /// STATUS
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [_chip(status?.name ?? '', statusColor)],
        ),

        const SizedBox(height: 12),

        /// FOOTER META
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: AppColors.grey600,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM').format(deal.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.grey600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 12,
                    color: AppColors.grey600,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      deal.createdBy.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}