import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/theme/theme.dart';
import '/models/models.dart';
import '/views/views.dart';

Color updationStatusColor(UpdationStatus s) {
  switch (s) {
    case UpdationStatus.pending:
      return const Color(0xFFF59E0B);
    case UpdationStatus.inProgress:
      return const Color(0xFF4364F7);
    case UpdationStatus.completed:
      return AppColors.success;
  }
}

/// Board view with the same look and behaviour as the Leads board: coloured
/// status columns with count + total value, drag a card to another column to
/// change its status.
class ProjectUpdationKanban extends StatefulWidget {
  final List<ProjectUpdationModel> items;
  final bool canEdit;
  final bool canCreate;

  /// Persists the new status. Throw to make the card jump back.
  final Future<void> Function(ProjectUpdationModel u, UpdationStatus status)
  onMove;
  final void Function(ProjectUpdationModel u) onOpen;
  final VoidCallback? onCreate;

  const ProjectUpdationKanban({
    super.key,
    required this.items,
    required this.canEdit,
    required this.canCreate,
    required this.onMove,
    required this.onOpen,
    this.onCreate,
  });

  @override
  State<ProjectUpdationKanban> createState() => _ProjectUpdationKanbanState();
}

class _ProjectUpdationKanbanState extends State<ProjectUpdationKanban> {
  late Map<UpdationStatus, List<ProjectUpdationModel>> _board;

  ProjectUpdationModel? _dragged;
  UpdationStatus? _draggedFrom;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _board = _group(widget.items);
  }

  @override
  void didUpdateWidget(covariant ProjectUpdationKanban oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _board = _group(widget.items);
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Map<UpdationStatus, List<ProjectUpdationModel>> _group(
    List<ProjectUpdationModel> list,
  ) => {
    for (final s in UpdationStatus.values)
      s: list.where((u) => u.status == s).toList(),
  };

  void _handleDragStarted(ProjectUpdationModel u, UpdationStatus from) {
    setState(() {
      _dragged = u;
      _draggedFrom = from;
    });
  }

  void _handleDragEnd(DraggableDetails details) {
    if (!details.wasAccepted && _dragged != null && _draggedFrom != null) {
      setState(() {
        if (!_board[_draggedFrom]!.any((t) => t.uid == _dragged!.uid)) {
          _board[_draggedFrom!] = [..._board[_draggedFrom]!, _dragged!];
        }
      });
    }
    setState(() {
      _dragged = null;
      _draggedFrom = null;
    });
  }

  void _startEdgeScrolling(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    const threshold = 100.0;
    const speed = 15.0;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_scrollController.hasClients) {
        timer.cancel();
        return;
      }
      if (details.globalPosition.dx < threshold) {
        if (_scrollController.offset > 0) {
          _scrollController.animateTo(
            _scrollController.offset - speed,
            duration: const Duration(milliseconds: 20),
            curve: Curves.linear,
          );
        }
      } else if (details.globalPosition.dx > screenWidth - threshold) {
        if (_scrollController.offset <
            _scrollController.position.maxScrollExtent) {
          _scrollController.animateTo(
            _scrollController.offset + speed,
            duration: const Duration(milliseconds: 20),
            curve: Curves.linear,
          );
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12.0),
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in UpdationStatus.values)
              _buildColumn(s, _board[s] ?? const []),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(
    UpdationStatus status,
    List<ProjectUpdationModel> items,
  ) {
    final color = updationStatusColor(status);
    return DragTarget<ProjectUpdationModel>(
      onWillAcceptWithDetails: (d) => widget.canEdit && d.data.uid != null,
      onAcceptWithDetails: (details) async {
        final u = details.data;
        final from = _draggedFrom;
        if (from == null || from == status) return;

        final original = u.copyWith();
        setState(() {
          _board[from] = [..._board[from]!]..removeWhere((t) => t.uid == u.uid);
          _board[status] = [..._board[status]!, u.copyWith(status: status)];
        });

        try {
          await widget.onMove(u, status);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _board[status] = [..._board[status]!]
              ..removeWhere((t) => t.uid == u.uid);
            _board[from] = [..._board[from]!, original];
          });
          FlushBar.show(context, e.toString(), isSuccess: false);
        }
      },
      builder: (context, candidate, rejected) {
        final hovering = candidate.isNotEmpty;
        final total = items.fold<double>(0, (s, u) => s + (u.value ?? 0));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: MediaQuery.of(context).size.width < 700
              ? MediaQuery.of(context).size.width * 0.8
              : 260,
          height: MediaQuery.of(context).size.height * 0.72,
          margin: const EdgeInsets.only(right: 12.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: hovering ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: hovering
                  ? Theme.of(context).colorScheme.primary
                  : color.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _columnHeader(status, items.length, total),
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
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildCard(items[i], status),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _columnHeader(UpdationStatus status, int count, double total) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: updationStatusColor(status),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                  if (widget.canCreate && widget.onCreate != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: widget.onCreate,
                      child: const Icon(
                        Iconsax.add_circle,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Theme.of(context).colorScheme.surface,
          child: Text(
            _currency.format(total),
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

  Widget _buildCard(ProjectUpdationModel u, UpdationStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Draggable<ProjectUpdationModel>(
        data: u,
        maxSimultaneousDrags: widget.canEdit ? 1 : 0,
        onDragStarted: () => _handleDragStarted(u, status),
        onDragUpdate: _startEdgeScrolling,
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
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
              ),
              child: _cardContent(u),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.2,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        child: InkWell(
          onTap: () => widget.onOpen(u),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12.0),
            child: _cardContent(u),
          ),
        ),
      ),
    );
  }

  Widget _cardContent(ProjectUpdationModel u) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = updationStatusColor(u.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                u.title.isNotEmpty ? u.title[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    u.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if ((u.companyName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      u.companyName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.grey600,
                      ),
                    ),
                  ],
                  if ((u.contactName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 10,
                          color: AppColors.grey600,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            u.contactName!,
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
            if ((u.value ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _currency.format(u.value),
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
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(u.status.label, statusColor),
            _chip(u.updationCode, AppColors.orange),
          ],
        ),
        const SizedBox(height: 12),
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
                  DateFormat('dd MMM').format(u.requestedDate),
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
                      u.createdBy.name,
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