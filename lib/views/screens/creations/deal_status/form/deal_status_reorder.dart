import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '/models/models.dart';
import '/services/firebase/firebase.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class DealStatusReorder extends StatefulWidget {
  final List<DealStatusModel> dealStatusList;
  const DealStatusReorder({super.key, required this.dealStatusList});

  @override
  State<DealStatusReorder> createState() => _DealStatusReorderState();
}

class _DealStatusReorderState extends State<DealStatusReorder> {
  // Local list to manage the reordering
  final List<DealStatusModel> _dealStatusList = [];
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF7B2FF7),
    Color(0xFFB620E0),
  ];

  @override
  void initState() {
    super.initState();
    // 1. Clone the widget list into the state list
    _dealStatusList.addAll(widget.dealStatusList);

    // 2. IMPORTANT: Ensure list is sorted by orderNumber initially
    _dealStatusList.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    // 3. Re-sync order numbers in case they are sparse (e.g., 1, 5, 10)
    _syncOrderNumbers();
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  /// Iterates through the list and assigns a new, sequential order number
  void _syncOrderNumbers() {
    final List<DealStatusModel> updatedList = [];
    for (int i = 0; i < _dealStatusList.length; i++) {
      updatedList.add(_dealStatusList[i].copyWith(orderNumber: i + 1));
    }
    _dealStatusList
      ..clear()
      ..addAll(updatedList);
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Iconsax.arrange_circle,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Reorder Deal Status",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Drag to change the order deals move through",
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),

            // --- LIST VIEW ---
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Scrollbar(
                  controller: _vScrollController,
                  thumbVisibility: true,
                  interactive: true,
                  trackVisibility: true,
                  radius: const Radius.circular(8),
                  thickness: 8,
                  child: ReorderableListView(
                    scrollController: _vScrollController,
                    physics: const BouncingScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (int oldIndex, int newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final DealStatusModel item = _dealStatusList.removeAt(
                          oldIndex,
                        );
                        _dealStatusList.insert(newIndex, item);
                        _syncOrderNumbers();
                      });
                    },
                    children: [
                      for (final (index, status) in _dealStatusList.indexed)
                        Container(
                          key: ValueKey(status.uid),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 16,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Color(status.color),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                status.orderNumber.toString(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Color(status.color).computeLuminance() >
                                              0.5
                                          ? AppColors.black
                                          : AppColors.white,
                                    ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  status.name,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                ),
                                if (status.isFinal) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "Final",
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              "Drag to reorder",
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // --- FOOTER BUTTON ---
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB620E0).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _submitForm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Iconsax.tick_circle,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Save Order",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    try {
      futureLoading(context);

      await DealStatusService.updateDealStatusReorder(
        dealStatusList: _dealStatusList,
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Navigator.pop(context, true);

      FlushBar.show(context, 'Status updated successfully', isSuccess: true);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      FlushBar.show(
        context,
        e.toString(),
        isSuccess: false,
        error: e,
        stackTrace: st,
      );
    }
  }
}