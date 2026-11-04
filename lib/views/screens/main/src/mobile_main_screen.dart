part of 'main_screen.dart';

class MobileMainScreen extends StatefulWidget {
  final bool isAdmin;

  const MobileMainScreen({super.key, required this.isAdmin});

  @override
  State<MobileMainScreen> createState() => _MobileMainScreenState();
}

class _MobileMainScreenState extends State<MobileMainScreen> {
  late Future _future;
  late String _currentUserUid;
  EmployeeModel? _employeeModel;
  AdminModel? _adminModel;
  int _currentIndex = 0;
  String? _companyLogoUrl;

  final items = [
    {"icon": Iconsax.status_up, "label": "Dashboard"},
    {"icon": Iconsax.graph, "label": "Leads"},
    {"icon": Iconsax.grid_lock, "label": "Deals"},
    {"icon": Iconsax.menu, "label": "Menu"},
  ];

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    try {
      if (mounted) {
        _currentUserUid = await Spdb.getUid() ?? '';
        var user = await Spdb.getUser();

        _companyLogoUrl = await Spdb.getCompanyLogo();

        if (user.userType == UserType.admin) {
          _adminModel = await Spdb.getAdmin();
        } else {
          _employeeModel = await Spdb.getEmployee();
        }
        setState(() {});
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  final String _selectedMenu = 'Dashboard';

  Widget _buildMainContentMobile() {
    switch (_currentIndex) {
      case 0:
        return BlocProvider(
          create: (context) => DashboardBloc(
            dashboard: DashboardService(),
            userId: _currentUserUid,
            isAdmin: widget.isAdmin,
          )..add(LoadDashboardEvent(filter: 'all')),
          child: Dashboard(isAdmin: widget.isAdmin),
        );
      case 1:
        return const LeadsListing(showAppBar: false);
      case 2:
        return const DealsListing(showAppBar: false);
      case 3:
        return const MobileMenu();
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
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Splash();
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            leadingWidth: 50,
            leading: InkWell(
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
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Center(
                  child: CircleAvatar(
                    radius: 20, // Slightly smaller for standard AppBar leading
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    // 1. Try to load the Network Image
                    backgroundImage:
                        (_companyLogoUrl != null && _companyLogoUrl!.isNotEmpty)
                        ? NetworkImage(_companyLogoUrl!)
                        : null,
                    // 2. Fallback child if backgroundImage is null or loading
                    child: (_companyLogoUrl == null || _companyLogoUrl!.isEmpty)
                        ? Text(
                            _employeeModel?.name.isNotEmpty == true
                                ? _employeeModel!.name[0].toUpperCase()
                                : _adminModel?.name.isNotEmpty == true
                                ? _adminModel!.name[0].toUpperCase()
                                : 'U',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            title: Text(items[_currentIndex]['label'] as String),
            actions: [
              IconButton(
                icon: Icon(Iconsax.logout),
                onPressed: () => logout(context),
                tooltip: 'Logout',
              ),
              IconButton(
                icon: Icon(Iconsax.notification),
                onPressed: () =>
                    Navigate.route(context, NotificationsListing()),
                tooltip: 'Notifications',
              ),
            ],
          ),
          // drawer: const MobileSidebar(),
          body: _buildMainContentMobile(),
          bottomNavigationBar: SelectionContainer.disabled(
            child: BottomAppBar(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: List.generate(
                    items.length,
                    (index) => _navItem(index),
                  ),
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _navItem(int index) {
    final bool selected = index == _currentIndex;
    final icon = items[index]["icon"] as IconData;
    final label = items[index]["label"] as String;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Icon(
                icon,
                size: 24,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: 6),
            Flexible(
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 220),
                opacity: selected ? 1.0 : 0.0,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  height: 6,
                  width: 6,
                  transform: Matrix4.diagonal3Values(
                    selected ? 1.0 : 0.4,
                    selected ? 1.0 : 0.4,
                    1.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}