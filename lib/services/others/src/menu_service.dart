import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/constants/src/enum.dart';
import '/services/services.dart';

/// Menu item configuration with role-based access control
class MenuItem {
  final String id;
  final String title;
  final IconData icon;
  final String? route;
  final List<MenuItem>? children;
  final bool isAdminOnly;
  final bool hideForAdmin;
  final bool requiresPayroll;
  final List<String> requiredPermissions;
  final bool isDivider;
  final bool isStatic;

  MenuItem({
    required this.id,
    required this.title,
    required this.icon,
    this.route,
    this.children,
    this.isAdminOnly = false,
    this.hideForAdmin = false,
    this.requiresPayroll = false,
    this.requiredPermissions = const [],
    this.isDivider = false,
    this.isStatic = false,
  });

  /// Check if menu item is accessible based on user role and permissions
  Future<bool> isAccessible({
    required bool isAdmin,
    // required bool payrollEnabled,
    required List<String> userPermissions,
  }) async {
    if (isStatic) return true;
    if (isDivider) return true;
    if (isAdminOnly && !isAdmin) return false;
    // Hidden for the super admin; other users are controlled by role permissions
    if (hideForAdmin && isAdmin) return false;
    // if (requiresPayroll && !payrollEnabled) return false;

    if (requiredPermissions.isNotEmpty) {
      final hasPermission = requiredPermissions.any(
        (permission) => userPermissions.contains(permission),
      );
      if (!hasPermission && !isAdmin) return false;
    }

    return true;
  }
}

/// Service for managing menu configurations and access control
class MenuService {
  /// Get all menu items for the application
  static List<MenuItem> getAllMenuItems() {
    return [
      // Main Navigation
      MenuItem(
        id: 'dashboard',
        title: 'Dashboard',
        icon: Iconsax.home_2,
        route: '/dashboard',
        requiredPermissions: ['Dashboard'],
      ),
      MenuItem(
        id: 'feed',
        title: 'Feed',
        icon: Iconsax.activity,
        route: '/feed',
      ),

      // Creation Section
      MenuItem(
        id: 'creation',
        title: 'Creation',
        icon: Iconsax.element_plus,
        children: [
          MenuItem(
            id: 'role',
            title: 'Role',
            icon: Iconsax.user_square,
            route: '/role',
            requiredPermissions: ['Role'],
          ),
          MenuItem(
            id: 'designation',
            title: 'Designation',
            icon: Iconsax.tick_circle,
            route: '/designation',
            requiredPermissions: ['Designation'],
          ),
          MenuItem(
            id: 'department',
            title: 'Department',
            icon: Iconsax.building,
            route: '/department',
            requiredPermissions: ['Department'],
          ),
          MenuItem(
            id: 'sub_department',
            title: 'Sub Department',
            icon: Iconsax.building_3,
            route: '/sub-department',
            requiredPermissions: ['Sub Department'],
          ),

          // MenuItem(
          //   id: 'employee_status',
          //   title: 'Employee Status',
          //   icon: Iconsax.tag,
          //   route: '/employee-status',
          //   requiredPermissions: ['Employee Status'],
          // ),
          MenuItem(
            id: 'employees',
            title: 'Employees',
            icon: Iconsax.security_user,
            route: '/employees',
            requiredPermissions: ['Employees'],
          ),
        ],
      ),

      // Chats
      MenuItem(
        id: 'chats',
        title: 'Chats',
        icon: Iconsax.message,
        route: '/chats',
        requiredPermissions: ['Chats'],
      ),

      // CRM Section
      MenuItem(
        id: 'crm',
        title: 'CRM',
        icon: Iconsax.graph,
        children: [
          MenuItem(
            id: 'lead_category',
            title: 'Lead Category',
            icon: Iconsax.category,
            route: '/lead-category',
            requiredPermissions: ['Lead Category'],
          ),
          MenuItem(
            id: 'lead_source',
            title: 'Lead Source',
            icon: Iconsax.share,
            route: '/lead-source',
            requiredPermissions: ['Lead Source'],
          ),
          MenuItem(
            id: 'lead_priority',
            title: 'Lead Priority',
            icon: Iconsax.flag,
            route: '/lead-priority',
            requiredPermissions: ['Lead Priority'],
          ),
          MenuItem(
            id: 'lead_status',
            title: 'Lead Status',
            icon: Iconsax.link_circle,
            route: '/lead-status',
            requiredPermissions: ['Lead Status'],
          ),
          MenuItem(
            id: 'deal_status',
            title: 'Deal Status',
            icon: Iconsax.activity,
            route: '/deal-status',
            requiredPermissions: ['Deal Status'],
          ),
          // Company + Contact captured once; Leads and Deals link to it.
          // Roles created before this menu existed only carry the old
          // Company / Contact pages, so those still grant access.
          MenuItem(
            id: 'master_client',
            title: 'Master Client',
            icon: Iconsax.people,
            route: '/master-client',
            requiredPermissions: ['Master Client', 'Company', 'Contact'],
          ),
          MenuItem(
            id: 'leads',
            title: 'Leads',
            icon: Iconsax.graph,
            route: '/leads',
            requiredPermissions: ['Leads'],
          ),
          MenuItem(
            id: 'deals',
            title: 'Deals',
            icon: Iconsax.lock,
            route: '/deals',
            requiredPermissions: ['Deals'],
          ),
          MenuItem(
            id: 'project_updation',
            title: 'Project Updation',
            icon: Iconsax.refresh_circle,
            route: '/project-updation',
            requiredPermissions: ['Project Updation'],
          ),
          MenuItem(
            id: 'master_company',
            title: 'Our Company',
            icon: Iconsax.building_4,
            route: '/master-company',
            requiredPermissions: ['Our Company', 'Master Company'],
          ),
          MenuItem(
            id: 'payment_mode',
            title: 'Payment Mode',
            icon: Iconsax.card,
            route: '/payment-mode',
            requiredPermissions: ['Payment Mode'],
          ),
          MenuItem(
            id: 'payment',
            title: 'Payment',
            icon: Iconsax.wallet_3,
            route: '/payment',
            requiredPermissions: ['Payment'],
          ),
          MenuItem(
            id: 'payment_report',
            title: 'Payment Report',
            icon: Iconsax.chart_21,
            route: '/payment-report',
            requiredPermissions: ['Payment Report'],
          ),
        ],
      ),

      // Companies
      // MenuItem(
      //   id: 'companies',
      //   title: 'Companies',
      //   icon: Iconsax.building,
      //   route: '/companies',
      //   requiredPermissions: ['Company'],
      // ),

      // Calendar
      MenuItem(
        id: 'calendar',
        title: 'Calendar',
        icon: Iconsax.calendar_1,
        route: '/calendar',
        requiredPermissions: ['Calendar'],
      ),

      // Projects
      MenuItem(
        id: 'projects',
        title: 'Projects',
        icon: Iconsax.airdrop,
        route: '/projects',
        requiredPermissions: ['Projects'],
      ),

      // Tasks
      MenuItem(
        id: 'tasks',
        title: 'Tasks',
        icon: Iconsax.check,
        route: '/tasks',
        requiredPermissions: ['Tasks'],
      ),
      // Customer Tickets
      MenuItem(
        id: 'tickets',
        title: 'Tickets',
        icon: Iconsax.ticket,
        route: '/tickets',
        requiredPermissions: ['Tickets'],
      ),

      // Settings
      MenuItem(
        id: 'settings',
        title: 'Settings',
        icon: Iconsax.setting_2,
        route: '/settings',
      ),

      // Admin Only Section
      MenuItem(
        id: 'admin_section',
        title: 'Admin',
        icon: Iconsax.shield,
        isAdminOnly: true,
        children: [
          MenuItem(
            id: 'login_logs',
            title: 'Login Logs',
            icon: Iconsax.login,
            route: '/login-logs',
            requiredPermissions: ['Login Logs'],
          ),
          MenuItem(
            id: 'activity_logs',
            title: 'Activity Logs',
            icon: Iconsax.activity,
            route: '/activity-logs',
            requiredPermissions: ['Activity Logs'],
          ),
        ],
      ),

      // Downloads
      MenuItem(
        id: 'downloads',
        title: 'Downloads',
        icon: Iconsax.document_download,
        route: '/downloads',
        requiredPermissions: ['Downloads'],
      ),

      // Developer Area
      MenuItem(
        id: 'developer_area',
        title: 'Developer Area',
        icon: Iconsax.code,
        route: '/developer-area',
        requiredPermissions: ['Developer Area'],
        hideForAdmin: true,
      ),

      // Static items (always visible)
      MenuItem(
        id: 'app_version',
        title: 'App Version',
        icon: Iconsax.info_circle,
        isStatic: true,
      ),
    ];
  }

  /// Filter menu items based on user role and permissions (handles nested children recursively)
  static Future<List<MenuItem>> filterMenuItems({
    required bool isAdmin,
    // required bool payrollEnabled,
    required List<String> userPermissions,
  }) async {
    final allItems = getAllMenuItems();
    final filteredItems = <MenuItem>[];

    Future<List<MenuItem>> filterChildren(List<MenuItem> children) async {
      final filtered = <MenuItem>[];
      for (final child in children) {
        final childAccessible = await child.isAccessible(
          isAdmin: isAdmin,
          // payrollEnabled: payrollEnabled,
          userPermissions: userPermissions,
        );

        if (child.children != null) {
          final grandChildren = await filterChildren(child.children!);
          if (grandChildren.isNotEmpty) {
            filtered.add(
              MenuItem(
                id: child.id,
                title: child.title,
                icon: child.icon,
                route: child.route,
                children: grandChildren,
                isAdminOnly: child.isAdminOnly,
                requiresPayroll: child.requiresPayroll,
                requiredPermissions: child.requiredPermissions,
                isDivider: child.isDivider,
                isStatic: child.isStatic,
              ),
            );
          }
        } else if (childAccessible) {
          filtered.add(child);
        }
      }
      return filtered;
    }

    for (final item in allItems) {
      final accessible = await item.isAccessible(
        isAdmin: isAdmin,
        // payrollEnabled: payrollEnabled,
        userPermissions: userPermissions,
      );

      if (item.children != null) {
        final filteredChildren = await filterChildren(item.children!);
        if (filteredChildren.isNotEmpty) {
          filteredItems.add(
            MenuItem(
              id: item.id,
              title: item.title,
              icon: item.icon,
              route: item.route,
              children: filteredChildren,
              isAdminOnly: item.isAdminOnly,
              requiresPayroll: item.requiresPayroll,
              requiredPermissions: item.requiredPermissions,
              isDivider: item.isDivider,
              isStatic: item.isStatic,
            ),
          );
        }
      } else if (accessible) {
        filteredItems.add(item);
      }
    }

    return filteredItems;
  }

  /// Get user permissions from role
  static Future<List<String>> getUserPermissions() async {
    final user = await Spdb.getUser();

    if (user.userType == UserType.admin) {
      // Admin has all permissions
      return getAllPermissions();
    }

    // Get employee role
    final employee = await EmployeeService.getEmployee(uid: user.uid);
    if (employee?.role == null) return [];

    final role = await RoleService.getRole(uid: employee!.role);

    // Extract permission names from role permissions.
    // Only pages the user can actually VIEW should surface a menu entry —
    // having create/edit/delete/export/import rights without view access
    // must not make the menu item appear.
    return role.permissions
        .where((p) => p.canView)
        .map((p) => p.page)
        .toList();
  }

  /// Get all available permissions
  static List<String> getAllPermissions() {
    return [
      'Role',
      'Designation',
      'Department',
      'Sub Department',
      'Employees',
      'Chats',
      'Lead Category',
      'Lead Source',
      'Lead Priority',
      'Lead Status',
      'Deal Status',
      'Payment Mode',
      'Leads',
      'Deals',
      'Project Updation',
      'Master Client',
      'Our Company',
      'Payment',
      'Payment Report',
      'Calendar',
      'Projects',
      'Tasks',
      'Tickets',
      'Downloads',
      'Developer Area',
      'Login Logs',
      'Activity Logs',
    ];
  }
}