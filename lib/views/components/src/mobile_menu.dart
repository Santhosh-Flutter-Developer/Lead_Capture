import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/views/screens/chat/listing/bloc/chat_bloc.dart';
import 'package:leadcapture/views/screens/companies/listing/companies_listing.dart';
import 'package:leadcapture/views/screens/download/download_history.dart';
import 'package:url_launcher/url_launcher.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/services/others/src/menu_service.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/theme/theme.dart';
import '/constants/constants.dart';

class MobileMenu extends StatefulWidget {
  const MobileMenu({super.key});

  @override
  State<MobileMenu> createState() => _MobileMenuState();
}

class _MobileMenuState extends State<MobileMenu> {
  EmployeeModel? _employeeModel;
  AdminModel? _adminModel;
  RoleModel? _roleModel;
  UserDataModel? _userDataModel;
  late Future _future;
  VersionModel? _versionModel;
  List<MenuItem> _menuItems = [];
  bool _isAdmin = false;
  String? _companyLogo;

  @override
  void initState() {
    super.initState();
    _future = _getUser();
    _versionModel = VersionService.version;
  }

  Future<void> _getUser() async {
    final (user) = await Spdb.getUser();

    if (mounted) {
      if (user.userType == UserType.employee) {
        _employeeModel = await EmployeeService.getEmployee(uid: user.uid);
      } else {
        _adminModel = await AdminService.getAdmin(uid: user.uid);
      }

      _userDataModel = user;
      _isAdmin = await Spdb.isAdminLoggedIn();
      _companyLogo = await Spdb.getCompanyLogo();

      setState(() {});
    }

    // Load menu items using MenuService
    final settings = await SettingsService().fetchSettings();
    final bool payrollEnabled = settings.payrollEnabled;
    final userPermissions = await MenuService.getUserPermissions();

    _menuItems = await MenuService.filterMenuItems(
      isAdmin: _isAdmin,
      userPermissions: userPermissions,
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const WaitingLoading();
          } else if (snapshot.hasError) {
            return ErrorDisplay(error: snapshot.error.toString());
          } else {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 8),
                    ..._buildMenuItems(),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final widgets = <Widget>[];

    for (final item in _menuItems) {
      if (item.isStatic) {
        widgets.add(
          _buildListTile(
            icon: item.icon,
            title: 'App Version',
            subtitle: '${AppPackageInfo.version}+${AppPackageInfo.buildNumber}',
            onTap: () {},
            showTrailing: false,
          ),
        );
        continue;
      }

      if (item.children != null && item.children!.isNotEmpty) {
        // Add section header
        widgets.add(SizedBox(height: 8));
        widgets.add(
          Text(
            item.title,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        );

        // Add children
        for (final child in item.children!) {
          if (child.children != null && child.children!.isNotEmpty) {
            // Handle nested menu (like Clients)
            widgets.add(
              _buildListTile(
                icon: child.icon,
                title: child.title,
                onTap: () => _handleNestedMenu(child),
              ),
            );
          } else {
            widgets.add(
              _buildListTile(
                icon: child.icon,
                title: child.title,
                onTap: () => _handleMenuTap(child),
              ),
            );
          }
        }
      } else {
        // Simple menu item
        widgets.add(
          _buildListTile(
            icon: item.icon,
            title: item.title,
            onTap: () => _handleMenuTap(item),
          ),
        );
      }
    }

    // Add system items at the end
    widgets.add(SizedBox(height: 8));
    widgets.add(
      Text(
        "Others",
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
    widgets.add(
      _buildListTile(
        icon: Iconsax.recovery_convert,
        title: 'Sync',
        onTap: () async {
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
          FlushBar.show(context, 'Synced Successfully');
        },
        showTrailing: false,
      ),
    );
    widgets.add(
      _buildListTile(
        icon: Iconsax.trash,
        title: 'Trash',
        onTap: () => Navigate.route(context, const TrashScreen()),
        showTrailing: false,
      ),
    );
    widgets.add(
      _buildListTile(
        icon: Iconsax.logout,
        title: 'Logout',
        onTap: () => logout(context),
        showTrailing: false,
        isLogout: true,
      ),
    );

    if (_versionModel != null && (_versionModel?.isUpdateNeed ?? false)) {
      widgets.add(_buildAppUpdateContainer());
    }

    return widgets;
  }

  void _handleMenuTap(MenuItem item) {
    switch (item.id) {
      case 'dashboard':
        Navigate.routeReplace(context, MobileMainScreen(isAdmin: _isAdmin));
        break;
      case 'feed':
        Navigate.route(
          context,
          BlocProvider(create: (context) => FeedBloc(), child: FeedListing()),
        );
        break;
      case 'chats':
        Navigate.route(
          context,
          BlocProvider(
            create: (context) => ChatBloc(),
            child: ChatListing(currentUserUid: _userDataModel?.uid ?? ''),
          ),
        );
        break;
      case 'calendar':
        Navigate.route(context, const CalendarEventScreen(showAppbar: true));
        break;
      case 'downloads':
        Navigate.route(context, DownloadHistory(showAppbar: true));
        break;
      case 'settings':
        Navigate.route(context, const Settings());
        break;
      case 'developer_area':
        Navigate.route(context, const Developer());
        break;
      // Creation section
      case 'role':
        Navigate.route(context, const RolesListing());
        break;
      case 'designation':
        Navigate.route(context, const DesignationListing());
        break;
      case 'department':
        Navigate.route(context, const DepartmentListing());
        break;
      case 'sub_department':
        Navigate.route(context, const SubDepartmentListing());
        break;
      case 'employee_status':
        FlushBar.show(context, '${item.title} - Coming soon', isSuccess: false);
        break;
      case 'employees':
        Navigate.route(context, const EmployeeListing());
        break;
      // CRM section
      case 'lead_category':
        Navigate.route(context, const LeadCategoryListing());
        break;
      case 'lead_source':
        Navigate.route(context, const LeadSourceListing());
        break;
      case 'payment_mode':
        Navigate.route(context, const PaymentModeListing());
        break;
      case 'lead_priority':
        Navigate.route(context, const LeadPriorityListing());
        break;
      case 'lead_status':
        Navigate.route(context, const LeadStatusListing());
        break;
      case 'deal_status':
        Navigate.route(context, const DealStatusListing());
        break;
      case 'leads':
        Navigate.route(context, const LeadsListing());
        break;
      case 'deals':
        Navigate.route(context, const DealsListing());
        break;
      case 'master_client':
        Navigate.route(context, const MasterClientListing());
        break;
      case 'master_company':
        Navigate.route(context, const MasterCompanyListing());
        break;
      case 'payment':
        Navigate.route(context, const PaymentListing());
        break;
      case 'payment_report':
        Navigate.route(context, const PaymentReportPage());
        break;
      case 'project_updation':
        Navigate.route(context, const ProjectUpdationListing());
        break;
      case 'companies':
        Navigate.route(context, const CompaniesListing());
        break;
      case 'projects':
        Navigate.route(context, const ProjectsListing());
        break;
      case 'tasks':
        Navigate.route(context, const TasksListing());
        break;
      case 'tickets':
        Navigate.route(context, const TicketsListing());
        break;
      case 'login_logs':
        Navigate.route(context, LoginLogsListing(showAppbar: true));
        break;
      case 'activity_logs':
        Navigate.route(context, ActivityLogsListing(showAppbar: true));
        break;
      case 'backup':
        Navigate.route(context, BackupListing());
        break;
      default:
        // For now, just show a placeholder
        FlushBar.show(context, '${item.title} - Coming soon', isSuccess: false);
    }
  }

  void _handleNestedMenu(MenuItem item) {}

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showTrailing = true,
    bool isLogout = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            height: 35,
            width: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isLogout
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isLogout
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: isLogout
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: subtitle != null
              ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall)
              : null,
          onTap: onTap,
          trailing: showTrailing ? const Icon(Iconsax.arrow_right_3) : null,
        ),
        Divider(indent: 0, endIndent: 0, height: 1, thickness: 1),
      ],
    );
  }

  Widget _buildHeader() {
    // Use the non-null _employeeModel
    final employee = _employeeModel;
    final admin = _adminModel;

    return
    // Column(
    // children: [
    //   // Company Logo
    //   if (_companyLogo != null)
    //     Padding(
    //       padding: const EdgeInsets.only(bottom: 16),
    //       child: SizedBox(
    //         height: 60,
    //         child: Image.network(
    //           _companyLogo!,
    //           fit: BoxFit.contain,
    //           errorBuilder: (context, error, stackTrace) =>
    //               _buildDefaultLogo(),
    //         ),
    //       ),
    //     )
    //   else
    //     Padding(
    //       padding: const EdgeInsets.only(bottom: 16),
    //       child: _buildDefaultLogo(),
    //     ),
    // User profile
    InkWell(
      onTap: () => Navigate.route(context, const Profile()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surfaceContainer,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userDataModel != null)
              UserAvatar(userData: _userDataModel!, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    employee?.name ?? admin?.name ?? 'User',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee != null
                        ? (CacheService.designationByUid(
                                employee.designation,
                              )?.name) ??
                              ''
                        : "Administartor",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    //   ],
    // );
  }

  Widget _buildDefaultLogo() {
    return SizedBox(
      height: 60,
      child: Image.asset(ImageAssets.logoTransparent, fit: BoxFit.contain),
    );
  }

  Widget _buildAppUpdateContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A90E2).withValues(alpha: 0.18),
            const Color(0xFF7F53AC).withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.system_update_alt_rounded,
              color: AppColors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Available (v${_versionModel?.version})",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222B45),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "A newer version of the app is available. Update now for better performance, features and stability.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        if (Platform.isAndroid) {
                          Navigate.route(context, AndroidUpdate());
                        } else {
                          Uri url = Uri.parse(_versionModel?.url ?? '');
                          if (await canLaunchUrl(url)) {
                            launchUrl(url);
                          }
                        }
                      } catch (e, st) {
                        FlushBar.show(context, e.toString(), isSuccess: false);
                        await ErrorService.recordError(e, st);
                      }
                    },
                    child: Text(
                      "Update Now",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
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