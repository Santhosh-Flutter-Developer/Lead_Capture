part of 'main_screen.dart';

class DesktopMainScreen extends StatefulWidget {
  final bool isAdmin;
  final String? selectedMenu;
  final String? selectedChatUid;
  const DesktopMainScreen({
    super.key,
    required this.isAdmin,
    this.selectedMenu,
    this.selectedChatUid,
  });

  @override
  State<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends State<DesktopMainScreen> {
  bool _isSidebarCollapsed = false;
  bool _userToggledSidebar = false;
  bool _wasBelowBreakpoint = false;
  static const double collapseWidth = 1100;

  late Future _future;
  late String _currentUserUid;
  String? _companyLogo;
  final List<UserDataModel> _users = [];

  final List<Map<String, dynamic>> items = [
    {"icon": Iconsax.message, "label": "Messenger"},
    {"icon": Iconsax.graph, "label": "Leads"},
    {"icon": Iconsax.grid_lock, "label": "Deals"},
    {"icon": Iconsax.menu, "label": "Menu"},
  ];

  @override
  void initState() {
    _future = _init();
    _selectedMenu = widget.selectedMenu ?? 'Dashboard';
    _pendingChatUid = widget.selectedChatUid;
    // Open any chat parked from a notification tap that arrived before the UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.markAppReady();
    });
    // WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // @override
  // void didChangeMetrics() {
  //   final width =
  //       WidgetsBinding
  //           .instance
  //           .platformDispatcher
  //           .views
  //           .first
  //           .physicalSize
  //           .width /
  //       WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  //   final shouldCollapse = width < collapseWidth;

  //   if (shouldCollapse != _isSidebarCollapsed) {
  //     setState(() {
  //       _isSidebarCollapsed = shouldCollapse;
  //     });
  //   }

  //   debugPrint('Window width: $width | collapsed: $shouldCollapse');
  // }

  Future<void> _init() async {
    try {
      _users.clear();
      _currentUserUid = await Spdb.getUid() ?? '';
      _companyLogo = await Spdb.getCompanyLogo();

      var employees = await EmployeeService.getAllEmployees(
        excludeCurrentUser: true,
      );
      _users.addAll(
        employees
            .map(
              (e) => UserDataModel(
                name: e.name,
                uid: e.uid ?? '',
                userType: UserType.employee,
                profilePic: e.profileImageUrl,
              ),
            )
            .toList(),
      );

      var admins = await AdminService.getAllAdmins(excludeCurrentUser: true);
      _users.addAll(
        admins
            .map(
              (e) => UserDataModel(
                name: e.name,
                uid: e.uid ?? '',
                userType: UserType.admin,
                profilePic: e.profileImageUrl,
              ),
            )
            .toList(),
      );

      _users.sort((a, b) => a.name.compareTo(b.name));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  String _selectedMenu = 'Dashboard';
  // Chat to pre-select when opened from a notification tap (used once).
  String? _pendingChatUid;

  void _onMenuItemSelected(String title) async {
    setState(() {
      _selectedMenu = title;
      _pendingChatUid = null;
    });
    RecentActivityService().addActivity(page: _selectedMenu);
  }

  Widget _buildMainContent() {
    switch (_selectedMenu) {
      case 'Dashboard':
        return BlocProvider(
          create: (context) => DashboardBloc(
            dashboard: DashboardService(),
            userId: _currentUserUid,
            isAdmin: widget.isAdmin,
          )..add(LoadDashboardEvent(filter: '')),
          child: Dashboard(isAdmin: widget.isAdmin),
        );
      case 'Admin':
        return const AdminListing();
      case 'Role':
        return const RolesListing();
      case 'Designation':
        return const DesignationListing();
      case 'Department':
        return const DepartmentListing();
      case 'Sub Department':
        return const SubDepartmentListing();
      case 'Employees':
        return const EmployeeListing();
      case 'Lead Category':
        return const LeadCategoryListing();
      case 'Lead Status':
        return const LeadStatusListing();
      case 'Lead Source':
        return const LeadSourceListing();
      case 'Payment Mode':
        return const PaymentModeListing();
      case 'Lead Priority':
        return const LeadPriorityListing();
      case 'Deal Status':
        return const DealStatusListing();
      case 'Leads':
        return const LeadsListing();
      case 'Deals':
        return const DealsListing();
      case 'Master Client':
        return const MasterClientListing();
      case 'Our Company':
        return const MasterCompanyListing();
      case 'Payment':
        return const PaymentListing();
      case 'Payment Report':
        return const PaymentReportPage();
      case 'Project Updation':
        return const ProjectUpdationListing();
      // case 'Companies':
      //   return const CompaniesListing();
      case 'Projects':
        return const ProjectsListing();
      case 'Tasks':
        return const TasksListing();
      case 'Tickets':
        return const TicketsListing();
      case 'Chats':
        return ChatListing(
          key: ValueKey('chats_${_pendingChatUid ?? ''}'),
          currentUserUid: _currentUserUid,
          selectedChatUid: _pendingChatUid,
        );
      case 'Calendar':
        return const CalendarEventScreen();
      case 'Notifications':
        return const NotificationsListing(showAppbar: false);
      case 'Developer Area':
        return const Developer(showAppbar: false);
      case 'Settings':
        return Settings(showAppbar: false);
      case 'Login Logs':
        return const LoginLogsListing(showAppbar: false);
      case 'Activity Logs':
        return const ActivityLogsListing(showAppbar: false);
      case 'Downloads':
        return BlocProvider(
          create: (context) => DownloadHistoryBloc(),
          child: const DownloadHistory(showAppbar: false),
        );

      case 'Feed':
        return BlocProvider(
          create: (context) => FeedBloc(),
          child: const FeedListing(),
        );

      default:
        return Center(
          child: Text(
            "Content for $_selectedMenu",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const WaitingLoading();
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Sync Error: ${snapshot.error}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isBelowBreakpoint = constraints.maxWidth < collapseWidth;

              // final shouldCollapse = constraints.maxWidth < collapseWidth;

              // /// AUTO collapse ONLY if user has NOT manually toggled
              // if (!_userToggledSidebar &&
              //     _isSidebarCollapsed != shouldCollapse) {
              //   _isSidebarCollapsed = shouldCollapse;
              // }

              // /// RESET manual override when window grows
              // if (_userToggledSidebar &&
              //     constraints.maxWidth >= collapseWidth) {
              //   _userToggledSidebar = false;
              //   _isSidebarCollapsed = false;
              // }

              /// AUTO collapse ONLY when breakpoint is crossed
              if (!_userToggledSidebar &&
                  isBelowBreakpoint != _wasBelowBreakpoint) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isSidebarCollapsed = isBelowBreakpoint;
                    });
                  }
                });
              }

              /// Reset manual override ONLY when window expands back
              if (_userToggledSidebar &&
                  !isBelowBreakpoint &&
                  _wasBelowBreakpoint) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _userToggledSidebar = false;
                      _isSidebarCollapsed = false;
                    });
                  }
                });
              }

              /// update last width state
              _wasBelowBreakpoint = isBelowBreakpoint;

              return Row(
                children: [
                  SelectionContainer.disabled(
                    child: DesktopSidebar(
                    isCollapsed: _isSidebarCollapsed,
                    onCollapseChanged: (v) {
                      setState(() {
                        _isSidebarCollapsed = v;
                        _userToggledSidebar = true;
                      });
                    },
                    selectedMenu: _selectedMenu,
                    onMenuSelected: _onMenuItemSelected,
                    isAdmin: widget.isAdmin,
                    companyLogo: _companyLogo,
                  ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SelectionContainer.disabled(
                          child: Header(
                            selectedMenu: _selectedMenu,
                            onNavigate: _onMenuItemSelected,
                          ),
                        ),
                        Expanded(
                          // No Scrollbar here: this wraps whichever screen
                          // `_buildMainContent()` returns, and each of those
                          // screens (Dashboard, the listing pages, etc.)
                          // already owns its own scroll view + ScrollController
                          // and renders its own working, draggable Scrollbar.
                          // A Scrollbar here had no controller to attach to
                          // (it can't see a descendant screen's own
                          // ScrollController through that screen's Scaffold),
                          // so it rendered a thumb that looked interactive but
                          // couldn't actually be dragged.
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildMainContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedMenu != 'Chats') _buildGlassNavigationRail(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGlassNavigationRail() {
    return ValueListenableBuilder<bool>(
      valueListenable: PanelSettingsNotifier.hidePanel,
      builder: (context, hidePanel, _) {
        if (hidePanel) {
          return const SizedBox.shrink();
        }
        return Container(
          width: 50, // Comfortable modern width
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // User count badge / Action
              _buildRailTopAction(),
              const SizedBox(height: 12),
              const Divider(indent: 16, endIndent: 16, thickness: 0.5),
              const SizedBox(height: 12),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _users.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final userData = _users[index];

                      return StreamBuilder<UserStatusModel?>(
                        stream: UserStatusService.streamStatus(userData.uid),
                        builder: (context, snapshot) {
                          return _buildRailAvatar(userData, snapshot.data);
                        },
                      );
                    },
                  ),
                ),
              ),
              // _buildRailBottomActions(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRailTopAction() {
    return Tooltip(
      message: "Direct Messages",
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Iconsax.messages_1,
          color: Color(0xFF2563EB),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRailAvatar(UserDataModel userData, UserStatusModel? status) {
    final bool isOnline = status?.isOnline == true;
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.transparent, width: 2),
            ),
            child: UserAvatar(userData: userData, size: 36),
          ),
          // Online Indicator
          if (isOnline)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildRailBottomActions() {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 24, top: 12),
  //     child: Column(
  //       children: [
  //         const Divider(indent: 16, endIndent: 16, thickness: 0.5),
  //         const SizedBox(height: 12),
  //         _buildRailItem(
  //           icon: Iconsax.setting_2,
  //           label: 'Panel Settings',
  //           onTap: () => showPanelSettingsGeneralDialog(context),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildRailItem({
  //   required IconData icon,
  //   required String label,
  //   required VoidCallback onTap,
  // }) {
  //   return Tooltip(
  //     message: label,
  //     child: InkWell(
  //       onTap: onTap,
  //       borderRadius: BorderRadius.circular(12),
  //       child: Container(
  //         padding: const EdgeInsets.all(10),
  //         child: Icon(icon, color: const Color(0xFF64748B), size: 22),
  //       ),
  //     ),
  //   );
  // }
}