import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:leadcapture/constants/src/enum.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';

class Header extends StatefulWidget {
  final String selectedMenu;

  /// When provided (desktop shell), tapping the bell opens the Notification
  /// Center INSIDE the shell (side menu + header stay visible) instead of
  /// pushing a full-screen route.
  final ValueChanged<String>? onNavigate;

  const Header({super.key, required this.selectedMenu, this.onNavigate});

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  // String _selectedFilter = "Today";
  bool _isRefreshing = false;

  // Created once. Calling getNotificationCount() inside build() would open
  // a brand-new Firestore listener on every rebuild.
  late final Stream<int> _notificationCountStream = getNotificationCount();

  String formatRelativeTime(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays <= 7) {
      return "${difference.inDays} days ago";
    } else if (difference.inDays <= 30) {
      final weeks = (difference.inDays / 7).floor();
      return "$weeks week${weeks > 1 ? 's' : ''} ago";
    } else {
      final months = (difference.inDays / 30).floor();
      return "$months month${months > 1 ? 's' : ''} ago";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF212121) : AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // --- Page Title ---
          Text(
            widget.selectedMenu,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : AppColors.grey900,
              letterSpacing: -0.5,
            ),
          ),

          const Spacer(),

          // --- Time & Sync Status ---
          _buildStatusSection(isDark),

          const SizedBox(width: 16),
          // Vertical Divider
          Container(
            height: 32,
            width: 1,
            color: isDark ? Color(0xff303030) : AppColors.grey200,
          ),
          const SizedBox(width: 16),

          // --- Date Filter ---
          // _buildDateFilter(isDark),
          const SizedBox(width: 16),

          // --- Action Buttons ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                icon: _isRefreshing ? Icons.autorenew : Iconsax.refresh,
                color: _isRefreshing ? AppColors.grey500 : AppColors.blue,
                tooltip: _isRefreshing ? "Refreshing..." : "Refresh",
                onTap: _isRefreshing ? () {} : _manualSync,
                isLoading: _isRefreshing,
                isDark: isDark,
              ),
              // const SizedBox(width: 8),
              // _actionButton(
              //   icon: Iconsax.recovery_convert,
              //   color: AppColors.blue,
              //   tooltip: "Sync",
              //   onTap: _manualSync,
              // ),
              const SizedBox(width: 8),
              _buildNotificationButton(isDark),
              const SizedBox(width: 8),
              _actionButton(
                icon: Iconsax.user,
                color: AppColors.teal,
                tooltip: "Profile",
                onTap: () async {
                  final user = await Spdb.getUser();

                  if (user.userType == UserType.admin) {
                    final admin = await Spdb.getAdmin();

                    if (admin != null && context.mounted) {
                      Navigate.route(context, AdminProfile(admin: admin));
                    }
                  } else {
                    Navigate.route(context, const Profile());
                  }
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _actionButton(
                icon: Iconsax.logout,
                color: AppColors.orange,
                tooltip: "Logout",
                onTap: () => logout(context),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Status Section (Clock + Last Sync) ---
  Widget _buildStatusSection(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Live Clock
        StreamBuilder<String>(
          stream: Stream.periodic(const Duration(seconds: 1), (_) {
            return DateFormat('hh:mm:ss a').format(DateTime.now());
          }),
          builder: (context, snapshot) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.clock, color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text(
                  snapshot.data ?? '...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white : AppColors.grey800,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 2),
        // Last Sync Info
         // Reads the REAL persisted sync timestamp (CacheService's meta box)
        // on every tick, instead of a local "app opened" placeholder, so
        // this label actually reflects whether/when a background or
        // manual sync last completed.
        StreamBuilder(
          stream: Stream.periodic(const Duration(minutes: 1)),
          builder: (context, snapshot) {
            final lastSync = CacheService().getLastSyncTime();
            if (lastSync == null) {
              return Text(
                "Not synced yet",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w500,
                ),
              );
            }
            final formattedTime = DateFormat('hh:mm a').format(lastSync);
            final relativeTime = formatRelativeTime(lastSync);
            return Text(
              "Synced: $formattedTime ($relativeTime)",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.grey500,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }

  // Widget _buildDateFilter(bool isDark) {
  //   return StatefulBuilder(
  //     builder: (context, setStateSB) {
  //       return Container(
  //         height: 38,
  //         padding: const EdgeInsets.symmetric(horizontal: 12),
  //         decoration: BoxDecoration(
  //           color: isDark ? Color(0xff303030) : AppColors.grey50,
  //           borderRadius: BorderRadius.circular(20),
  //           border: Border.all(color: AppColors.grey200),
  //         ),
  //         child: DropdownButtonHideUnderline(
  //           child: DropdownButton<String>(
  //             value: _selectedFilter,
  //             icon: Padding(
  //               padding: const EdgeInsets.only(left: 8),
  //               child: Icon(
  //                 Iconsax.arrow_down_1,
  //                 size: 16,
  //                 color: isDark ? Colors.white : AppColors.grey600,
  //               ),
  //             ),
  //             dropdownColor: isDark ? Color(0xff303030) : AppColors.white,
  //             borderRadius: BorderRadius.circular(16),
  //             elevation: 2,
  //             style: Theme.of(context).textTheme.bodySmall?.copyWith(
  //               color: isDark ? Colors.white : AppColors.grey800,
  //               fontWeight: FontWeight.w600,
  //             ),
  //             onTap: () {}, // Handled by onChanged
  //             items: ["Today", "This Week", "This Month", "Custom Date"]
  //                 .map(
  //                   (item) => DropdownMenuItem<String>(
  //                     value: item,
  //                     child: Text(
  //                       item,
  //                       style: Theme.of(context).textTheme.bodySmall,
  //                     ),
  //                   ),
  //                 )
  //                 .toList(),
  //             onChanged: (value) async {
  //               if (value == null) return;
  //               setState(() => _selectedFilter = value);

  //               if (value == "Custom Date") {
  //                 DateTime? picked = await showDatePicker(
  //                   context: context,
  //                   initialDate: DateTime.now(),
  //                   firstDate: DateTime(2020),
  //                   lastDate: DateTime(2035),
  //                 );
  //                 if (picked != null) debugPrint("Custom date: $picked");
  //               }
  //               HeaderFilterBus.broadcast(_selectedFilter);
  //             },
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildNotificationButton(bool isDark) {
    return Stack(
      children: [
        _actionButton(
          icon: Iconsax.notification,
          color: AppColors.danger,
          tooltip: 'Notifications',
          onTap: () {
            if (widget.onNavigate != null) {
              widget.onNavigate!('Notifications');
            } else {
              Navigate.route(context, NotificationsListing());
            }
          },
          isDark: isDark,
        ),
        StreamBuilder<int>(
          stream: _notificationCountStream,
          builder: (context, snapshot) {
            int notificationCount = snapshot.data ?? 0;

            if (notificationCount != 0) {
              return Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.white, width: 1),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12, // 🔽 reduced
                    minHeight: 12,
                  ),
                  child: Center(
                    child: Text(
                      notificationCount > 99 ? '99+' : '$notificationCount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9, // 🔽 smaller font
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  // --- Generic Action Button (Small & Circular) ---
  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
    bool isLoading = false,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          hoverColor: color.withValues(alpha: 0.1),
          child: Container(
            width: 36, // Compact Size
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Color(0xff303030)
                  : AppColors.grey50, // Subtle background
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.grey200),
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white : color,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    color: isDark ? Colors.white : color,
                    size: 18, // Small Icon Size
                  ),
          ),
        ),
      ),
    );
  }

  // --- Manual Sync Logic ---
  Future<void> _manualSync() async {
    setState(() => _isRefreshing = true);

    await CacheService().init();
    await CacheService.syncAllCollections();
    var result = await AuthService.refreshLogin();

    if (result['userData'] != null) {
      var data = result["userData"];
      var uid = result["uid"];

      EmployeeModel emp = EmployeeModel.fromMap(uid, data);
      await Spdb.setEmployeeLogin(
        model: emp,
        cid: result["collectionId"],
        logoUrl: result["companyLogo"],
      );

      RoleModel role = await RoleService.getRole(uid: emp.role);
      await PermissionService.savePermissions(role.permissions);
    }

 // The "Synced" label now reads CacheService().getLastSyncTime() directly,
    // so there's no local timestamp field to update here anymore - the
    // setState below is enough to make the StreamBuilder repaint with the
    // fresh persisted value.
    setState(() => _isRefreshing = false);

    if (mounted) {
      FlushBar.show(context, "Synced Successfully");
    }
  }
}

// // --- Event Bus ---
// class HeaderFilterBus {
//   static final StreamController<String> _controller =
//       StreamController.broadcast();

//   static Stream<String> get stream => _controller.stream;

//   static void broadcast(String filter) {
//     _controller.add(filter);
//   }
// }