import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class EventViewPage extends StatelessWidget {
  final EventModel event;

  const EventViewPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return EventView(event: event);
  }
}

class EventView extends StatefulWidget {
  final EventModel event;
  const EventView({super.key, required this.event});

  @override
  State<EventView> createState() => _EventViewState();
}

class _EventViewState extends State<EventView> {
  PermissionModel? _permissions;
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    _permissions = await PermissionService.getPermissions('Calendar');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _brandGradient,
              ),
            ),
            child: Row(
              children: [
                Material(
                  color: AppColors.white.withValues(alpha: 0.18),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Iconsax.calendar_1,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Event Details",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.event.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_permissions?.canEdit ?? false)
                  Material(
                    color: AppColors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.pop(context);
                        if (kIsDesktop) {
                          GeneralDialog.showRTLSheet(
                            context,
                            EventEdit(uid: widget.event.uid ?? ''),
                          );
                        } else {
                          Sheet.showSheet(
                            context,
                            widget: EventEdit(uid: widget.event.uid ?? ''),
                          );
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.edit,
                          color: AppColors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Scrollbar(
                      controller: _vScrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                  controller: _vScrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailCard(
                        context,
                        'Event Name',
                        widget.event.eventName,
                        Iconsax.calendar,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'Description',
                        widget.event.eventDescription.isNotEmpty
                            ? widget.event.eventDescription
                            : 'No description',
                        Iconsax.document_text,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'Start Time',
                        widget.event.eventDateTime.formatDateTime,
                        Iconsax.clock,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'End Time',
                        widget.event.eventEndDateTime.formatDateTime,
                        Iconsax.clock,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'Repeat Type',
                        widget.event.eventRepeatType.name.capitalizeFirst,
                        Iconsax.repeat,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'Status',
                        widget.event.completed ? 'Completed' : 'Pending',
                        widget.event.completed
                            ? Iconsax.tick_circle
                            : Iconsax.timer,
                        valueColor: widget.event.completed
                            ? AppColors.success
                            : AppColors.warning,
                        iconBgColor: widget.event.completed
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'Created By',
                        widget.event.createdBy.name,
                        Iconsax.user,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailCard(
                        context,
                        'Created At',
                        widget.event.createdAt.formatDateTime,
                        Iconsax.calendar_tick,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
    Color? iconBgColor,
  }) {
    final Color badgeColor =
        iconBgColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: badgeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
