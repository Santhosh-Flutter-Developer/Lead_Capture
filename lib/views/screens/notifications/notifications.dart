import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:leadcapture/constants/src/enum.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import 'bloc/notifications_bloc.dart';

/// Visual metadata (icon + accent color) per notification type.
/// Keeps the list, the badges and the detail view perfectly in sync.
class _TypeMeta {
  final IconData icon;
  final Color color;
  final String label;
  const _TypeMeta(this.icon, this.color, this.label);
}

_TypeMeta _typeMeta(NotificationType? type) {
  switch (type) {
    case NotificationType.chat:
      return const _TypeMeta(Iconsax.message, AppColors.blue600, 'Chat');
    case NotificationType.task:
      return const _TypeMeta(Iconsax.task_square, Color(0xFF7C3AED), 'Task');
    case NotificationType.ticket:
      return const _TypeMeta(Iconsax.ticket, Color(0xFFDB2777), 'Ticket');
    case NotificationType.lead:
      return const _TypeMeta(Iconsax.chart_21, Color(0xFF0891B2), 'Lead');
    case NotificationType.deal:
      return const _TypeMeta(Iconsax.briefcase, AppColors.success, 'Deal');
    case NotificationType.eventReminder:
    case NotificationType.eventStarted:
      return const _TypeMeta(Iconsax.calendar_1, AppColors.orange, 'Event');
    case NotificationType.feed:
      return const _TypeMeta(Iconsax.global, Color(0xFF0EA5E9), 'Feed');
    case NotificationType.project:
      return const _TypeMeta(Iconsax.folder_2, Color(0xFF854D0E), 'Project');
    case NotificationType.permissionRequest:
      return const _TypeMeta(
        Iconsax.security_user,
        Color(0xFF9333EA),
        'Permission',
      );
    case NotificationType.success:
      return const _TypeMeta(Iconsax.tick_circle, AppColors.success, 'Success');
    case NotificationType.warning:
      return const _TypeMeta(Iconsax.warning_2, AppColors.warning, 'Warning');
    case NotificationType.error:
    case NotificationType.alert:
      return const _TypeMeta(Iconsax.danger, AppColors.danger, 'Alert');
    case NotificationType.openFile:
      return const _TypeMeta(Iconsax.document, AppColors.grey600, 'File');
    case NotificationType.info:
    default:
      return const _TypeMeta(Iconsax.info_circle, AppColors.primary, 'Info');
  }
}

class NotificationsListing extends StatefulWidget {
  /// `true` (default): standalone page with its own AppBar + back button
  /// (used by the mobile flow, unchanged).
  /// `false`: embedded inside the desktop shell, which already provides the
  /// side menu and top header, so no AppBar is drawn here.
  final bool showAppbar;
  const NotificationsListing({super.key, this.showAppbar = true});

  @override
  State<NotificationsListing> createState() => _NotificationsListingState();
}

class _NotificationsListingState extends State<NotificationsListing> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  // Grouped by display label (not raw enum) so types that share one label/
  // icon, e.g. eventReminder & eventStarted -> "Event", collapse into a
  // single filter chip instead of showing duplicates.
  String? _typeFilterLabel;
  NotificationModel? _selectedNotification;
  bool _isAdmin = false;
  final ScrollController _vScrollController = ScrollController();

  // Width at which the list + detail split view is used. When embedded in the
  // desktop shell the sidebar and right rail already take ~350px, so the
  // split view switches on earlier.
  double get _splitBreakpoint => widget.showAppbar ? 1100 : 800;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await Spdb.isAdminLoggedIn();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    context.read<NotificationsBloc>().add(StreamNotifications());
  }

  Future<void> _deleteNotification(NotificationModel item) async {
    final confirm = await _showDeleteDialog();
    if (confirm != true) return;

    final deletedItem = item;

    await deleteNotification(item.uid ?? '');

    if (!mounted) return;

    if (_selectedNotification?.uid == item.uid) {
      setState(() => _selectedNotification = null);
    }

    FlushBar.show(
      context,
      'Notification deleted',
      actionLabel: 'UNDO',
      onActionPressed: () async {
        await restoreNotification(deletedItem);
        if (mounted) setState(() {});
      },
    );
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Map<String, List<NotificationModel>> _groupByDay(
    List<NotificationModel> items,
  ) {
    final Map<String, List<NotificationModel>> map = {};
    final now = DateTime.now();
    for (final item in items) {
      final dt = item.createdAt ?? DateTime.now();
      final difference = DateTime(
        dt.year,
        dt.month,
        dt.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;

      String label;
      if (difference == 0) {
        label = 'Today';
      } else if (difference == -1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('dd MMM yyyy').format(dt);
      }
      map.putIfAbsent(label, () => []).add(item);
    }
    return map;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd MMM').format(dt);
  }

  Future<dynamic> _resolveProfileByUid(String uid) async {
    if (uid.trim().isEmpty) return null;

    final cached = CacheService.getUserByUid(uid);
    if (cached is EmployeeModel || cached is AdminModel) {
      return cached;
    }

    try {
      final employee = await EmployeeService.getEmployee(uid: uid);
      if (employee != null) return employee;
    } catch (_) {}

    try {
      final admin = await AdminService.getAdmin(uid: uid);
      if (admin != null) return admin;
    } catch (_) {}

    return null;
  }

  Future<void> _openSenderProfile(NotificationModel item) async {
    final senderUid = item.senderId?.trim() ?? '';
    if (senderUid.isEmpty) return;

    final profile = await _resolveProfileByUid(senderUid);
    if (!mounted) return;

    if (profile is EmployeeModel) {
      if (kIsMobile) {
        await Sheet.showSheet(
          context,
          widget: EmployeeDetails(employee: profile),
        );
      } else {
        await GeneralDialog.showRTLSheet(
          context,
          EmployeeDetails(employee: profile),
        );
      }
      return;
    }

    if (profile is AdminModel) {
      if (kIsMobile) {
        await Sheet.showSheet(context, widget: AdminProfile(admin: profile));
      } else {
        await GeneralDialog.showRTLSheet(context, AdminProfile(admin: profile));
      }
      return;
    }
    if (!mounted) return;
    FlushBar.show(context, 'User profile not found', isSuccess: false);
  }

  Future<void> _openPlatformSheet(Widget widget) async {
    if (kIsDesktop) {
      await GeneralDialog.showRTLSheet(context, widget);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => widget));
    }
  }

  Future<void> _handleNotificationTap(
    NotificationModel item,
    bool isDesktop,
  ) async {
    if (!mounted) return;
    final id = item.collectionId;

    try {
      if (item.payload['ticketId'] != null &&
          (item.payload['ticketId'] as String).isNotEmpty) {
        if (!mounted) return;
        await _openPlatformSheet(
          TicketView(uid: item.payload['ticketId'] as String),
        );
        return;
      }

      switch (item.type) {
        case NotificationType.chat:
          if (!mounted) return;
          await _openPlatformSheet(
            ChatListing(
              currentUserUid: item.senderId ?? '',
              selectedChatUid: id,
            ),
          );
          break;

        /// TASK -> SHEET
        case NotificationType.task:
          final taskId = item.payload['taskId'] as String?;
          if (taskId != null && taskId.isNotEmpty) {
            if (!mounted) return;
            await _openPlatformSheet(TaskView(uid: taskId));
          } else {
            if (!mounted) return;
            await _openPlatformSheet(TasksListing());
          }
          break;

        /// TICKET -> SHEET
        case NotificationType.ticket:
          final ticketId = item.payload['ticketId'] as String?;
          if (ticketId != null && ticketId.isNotEmpty) {
            if (!mounted) return;
            await _openPlatformSheet(TicketView(uid: ticketId));
          } else {
            if (!mounted) return;
            await _openPlatformSheet(const TicketsListing());
          }
          break;

        /// LEAD -> SHEET
        case NotificationType.lead:
          final leadId = item.payload['leadId'] as String?;
          if (leadId != null && leadId.isNotEmpty) {
            try {
              final lead = await LeadService.getLead(uid: leadId);
              if (!mounted) return;
              await _openPlatformSheet(LeadsViewPage(lead: lead));
            } catch (_) {
              if (!mounted) return;
              await _openPlatformSheet(LeadsListing(showAppBar: true));
            }
          } else {
            if (!mounted) return;
            await _openPlatformSheet(LeadsListing(showAppBar: true));
          }
          break;

        /// DEAL -> SHEET
        case NotificationType.deal:
          final dealId = item.payload['dealId'] as String?;
          if (dealId != null && dealId.isNotEmpty) {
            try {
              final deal = await DealService.getDeal(uid: dealId);
              if (!mounted) return;
              await _openPlatformSheet(DealsViewPage(deal: deal));
            } catch (_) {
              if (!mounted) return;
              await _openPlatformSheet(DealsListing(showAppBar: true));
            }
          } else {
            if (!mounted) return;
            await _openPlatformSheet(DealsListing(showAppBar: true));
          }
          break;

        /// EVENT -> SHEET
        case NotificationType.eventReminder:
        case NotificationType.eventStarted:
          if (!mounted) return;
          await _openPlatformSheet(CalendarEventScreen());
          break;

        /// FEED -> SHEET
        case NotificationType.feed:
          if (!mounted) return;
          await _openPlatformSheet(FeedListing());
          break;

        /// DEFAULT -> DETAIL VIEW
        default:
          if (isDesktop) {
            setState(() => _selectedNotification = item);
          } else {
            _openDetailSheet(item);
          }
      }
    } catch (e) {
      if (!mounted) return;
      FlushBar.show(
        context,
        'Could not open this notification. Please try again.',
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsBloc()..add(StreamNotifications()),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: !widget.showAppbar
            ? null
            : AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: Back(color: Theme.of(context).colorScheme.onSurface),
          centerTitle: false,
          title: Text(
            "Notifications Center",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => _refresh(context),
              icon: Icon(
                Iconsax.refresh,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: Theme.of(context).colorScheme.outlineVariant,
              height: 1,
            ),
          ),
        ),
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state is NotificationsLoading) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth > _splitBreakpoint;
                  return _buildSkeletonLoading(isDesktop);
                },
              );
            }

            if (state is NotificationsError) {
              return ErrorDisplay(error: state.message);
            }

            if (state is NotificationsLoaded) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth > _splitBreakpoint;
                  final notifications = state.notification;
                  return isDesktop
                      ? _buildDesktopLayout(notifications)
                      : _buildMobileLayout(notifications);
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // LAYOUTS
  // ------------------------------------------------------------------

  /// DESKTOP LAYOUT: Master-Detail Split Pane
  Widget _buildDesktopLayout(List<NotificationModel> notifications) {
    final filteredList = _filterList(notifications);
    final grouped = _groupByDay(filteredList);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Side: Search, filters & list
        Container(
          width: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildHeaderSearch(notifications),
              Expanded(
                child: filteredList.isEmpty
                    ? const NoData(text: "No matching notifications found")
                    : Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ListView.builder(
                          controller: _vScrollController,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ).copyWith(right: 6),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final entry = grouped.entries.elementAt(index);
                            return _buildSection(
                              entry.key,
                              entry.value,
                              isDesktop: true,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        // Right Side: Detail View
        Expanded(
          child: _selectedNotification == null
              ? _buildEmptyDetailView()
              : _buildDetailContent(_selectedNotification!),
        ),
      ],
    );
  }

  /// MOBILE LAYOUT: Traditional List
  Widget _buildMobileLayout(List<NotificationModel> notifications) {
    final filteredList = _filterList(notifications);
    final grouped = _groupByDay(filteredList);

    return Column(
      children: [
        _buildHeaderSearch(notifications),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: filteredList.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      NoData(text: "No notifications found"),
                    ],
                  )
                : Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ListView.builder(
                    controller: _vScrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        return _buildSection(
                          entry.key,
                          entry.value,
                          isDesktop: false,
                        );
                      },
                    ),
                ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // SKELETON LOADING
  // ------------------------------------------------------------------

  Widget _buildSkeletonLoading(bool isDesktop) {
    final baseColor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: 0.4);
    final highlightColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    Widget rows = ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 12 : 16,
        vertical: 12,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    Widget shimmerList = Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: rows,
    );

    if (!isDesktop) return shimmerList;

    return Row(
      children: [
        SizedBox(
          width: 400,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: shimmerList,
          ),
        ),
        Expanded(child: _buildEmptyDetailView()),
      ],
    );
  }

  // ------------------------------------------------------------------
  // FILTERING
  // ------------------------------------------------------------------

  List<NotificationModel> _filterList(List<NotificationModel> list) {
    final query = _search.toLowerCase();

    return list.where((it) {
      if (_typeFilterLabel != null &&
          _typeMeta(it.type).label != _typeFilterLabel) {
        return false;
      }
      if (query.isEmpty) return true;

      return it.title.toLowerCase().contains(query) ||
          it.body.toLowerCase().contains(query);
    }).toList();
  }

  // ------------------------------------------------------------------
  // HEADER: SEARCH + TYPE FILTER CHIPS
  // ------------------------------------------------------------------

  Widget _buildHeaderSearch(List<NotificationModel> allNotifications) {
    // Only show chips for types that actually appear in the current data,
    // in a stable order, so the row never feels random or empty. Grouped by
    // label so types that share one badge (e.g. eventReminder/eventStarted
    // both showing as "Event") only produce a single chip.
    final labelOrder = <String, int>{};
    final labelMeta = <String, _TypeMeta>{};
    for (final n in allNotifications) {
      if (n.type == null) continue;
      final meta = _typeMeta(n.type);
      labelOrder.putIfAbsent(meta.label, () => n.type!.index);
      labelMeta.putIfAbsent(meta.label, () => meta);
    }
    final presentLabels = labelOrder.keys.toList()
      ..sort((a, b) => labelOrder[a]!.compareTo(labelOrder[b]!));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Iconsax.search_normal,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Iconsax.close_circle, size: 18),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: () => _searchController.clear(),
                      ),
                hintText: 'Search alerts...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (presentLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presentLabels.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildFilterChip(
                      label: 'All',
                      selected: _typeFilterLabel == null,
                      color: Theme.of(context).colorScheme.primary,
                      onTap: () => setState(() => _typeFilterLabel = null),
                    );
                  }
                  final label = presentLabels[index - 1];
                  final meta = labelMeta[label]!;
                  return _buildFilterChip(
                    label: label,
                    icon: meta.icon,
                    selected: _typeFilterLabel == label,
                    color: meta.color,
                    onTap: () => setState(
                      () => _typeFilterLabel = _typeFilterLabel == label
                          ? null
                          : label,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // LIST: SECTION + CARD
  // ------------------------------------------------------------------

  Widget _buildSection(
    String label,
    List<NotificationModel> items, {
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items.map((item) => _buildNotificationCard(item, isDesktop)),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationModel item, bool isDesktop) {
    final isSelected = _selectedNotification?.uid == item.uid;
    final hasSender = (item.senderId?.trim().isNotEmpty ?? false);
    final titleText = item.title.isNotEmpty
        ? item.title
        : (item.type?.name.toUpperCase() ?? 'Alert');
    final meta = _typeMeta(item.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Dismissible(
        key: ValueKey(item.uid ?? item.hashCode),
        direction: _isAdmin
            ? DismissDirection.endToStart
            : DismissDirection.none,
        confirmDismiss: (_) async {
          if (!_isAdmin) return false;

          final confirm = await _showDeleteDialog();
          if (confirm != true) return false;

          final deletedItem = item;

          await deleteNotification(item.uid ?? '');

          if (!mounted) return false;
          if (_selectedNotification?.uid == item.uid) {
            setState(() => _selectedNotification = null);
          }

          FlushBar.show(
            context,
            'Notification deleted',
            actionLabel: 'UNDO',
            onActionPressed: () async {
              await restoreNotification(deletedItem);
              if (mounted) setState(() {});
            },
          );

          return true;
        },
        onDismissed: (_) {},
        background: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Iconsax.trash, color: Colors.white, size: 20),
        ),
        child: InkWell(
          onTap: () => _handleNotificationTap(item, isDesktop),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hasSender
                    ? InkWell(
                        onTap: () => _openSenderProfile(item),
                        borderRadius: BorderRadius.circular(12),
                        child: _typeAvatar(item, meta),
                      )
                    : _typeAvatar(item, meta),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              titleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.createdAt != null
                                ? _timeAgo(item.createdAt!)
                                : '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _typeTag(meta),
                          const Spacer(),
                          _iconAction(
                            icon: Iconsax.info_circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            onTap: () {
                              if (isDesktop) {
                                setState(() => _selectedNotification = item);
                              } else {
                                _openDetailSheet(item);
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          _iconAction(
                            icon: Iconsax.trash,
                            color: Theme.of(context).colorScheme.error,
                            onTap: () => _deleteNotification(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeTag(_TypeMeta meta) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 11, color: meta.color),
          const SizedBox(width: 4),
          Text(
            meta.label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: meta.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }

  // ------------------------------------------------------------------
  // DETAIL VIEWS
  // ------------------------------------------------------------------

  Widget _buildEmptyDetailView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.notification_bing,
              size: 40,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Select a notification",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Choose an item from the list to view its full details here",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContent(NotificationModel item) {
    final meta = _typeMeta(item.type);
    final hasSender = (item.senderId?.trim().isNotEmpty ?? false);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hasSender
                        ? InkWell(
                            onTap: () => _openSenderProfile(item),
                            borderRadius: BorderRadius.circular(18),
                            child: _typeAvatar(item, meta, size: 60),
                          )
                        : _typeAvatar(item, meta, size: 60),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.isNotEmpty ? item.title : meta.label,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _typeTag(meta),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () =>
                          setState(() => _selectedNotification = null),
                      icon: Icon(
                        Iconsax.close_circle,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 74),
                  child: Text(
                    DateFormat(
                      'MMMM dd, yyyy • hh:mm a',
                    ).format(item.createdAt ?? DateTime.now()),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 24),
                Text(
                  "MESSAGE CONTENT",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _secondaryActionButton(
                      icon: Iconsax.copy,
                      label: "Copy Data",
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: json.encode(item.payload)),
                        );
                        FlushBar.show(context, 'Payload copied');
                      },
                    ),
                    const SizedBox(width: 14),
                    _primaryActionButton(
                      icon: Iconsax.tick_circle,
                      label: "Dismiss Detail",
                      onTap: () {
                        setState(() => _selectedNotification = null);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Outlined pill button — same look as the secondary ("Cancel") action
  /// used on the create/edit forms (e.g. Lead Category create page), kept
  /// here so this page's buttons stay visually consistent with the rest of
  /// the app.
  Widget _secondaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gradient pill button — same brand gradient + shadow used for the
  /// primary submit action on the create/edit forms, reused here for the
  /// primary "Dismiss Detail" / "Close" action.
  Widget _primaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _brandGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4364F7).withValues(alpha: 0.35),
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Colored initials avatar with a small type-icon badge in the corner.
  Widget _typeAvatar(
    NotificationModel item,
    _TypeMeta meta, {
    double size = 40,
  }) {
    final title = item.title;
    final initial = title.isNotEmpty
        ? title[0]
        : (item.type?.name.isNotEmpty ?? false)
        ? item.type!.name[0]
        : '?';
    final bg = LetterColors.getColor(initial);
    final badgeSize = size * 0.42;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(size / 3.3),
            ),
            alignment: Alignment.center,
            child: Text(
              initial.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.4,
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: meta.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                meta.icon,
                size: badgeSize * 0.55,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetailSheet(NotificationModel item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildMobileDetailSheet(item, ctx),
    );
  }

  Widget _buildMobileDetailSheet(NotificationModel item, BuildContext ctx) {
    final hasSender = (item.senderId?.trim().isNotEmpty ?? false);
    final meta = _typeMeta(item.type);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: hasSender
                  ? InkWell(
                      onTap: () => _openSenderProfile(item),
                      borderRadius: BorderRadius.circular(20),
                      child: _typeAvatar(item, meta, size: 60),
                    )
                  : _typeAvatar(item, meta, size: 60),
            ),
            const SizedBox(height: 14),
            Center(child: _typeTag(meta)),
            const SizedBox(height: 12),
            Center(
              child: hasSender
                  ? InkWell(
                      onTap: () => _openSenderProfile(item),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    )
                  : Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                DateFormat(
                  'MMMM dd, yyyy • hh:mm a',
                ).format(item.createdAt ?? DateTime.now()),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 20),
            Text(
              item.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _secondaryActionButton(
                    icon: Iconsax.copy,
                    label: "Copy",
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: json.encode(item.payload)),
                      );
                      FlushBar.show(context, 'Payload copied');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _primaryActionButton(
                    icon: Iconsax.tick_circle,
                    label: "Close",
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}