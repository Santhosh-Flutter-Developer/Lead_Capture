import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/views/views.dart';
import '/utils/utils.dart' hide timeago;
import '/models/models.dart';
import '/services/services.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late UserDataModel _userDataModel;
  List<ActivityItem> _recentActivityList = [];
  late Future _future;

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future _init() async {
    try {
      _userDataModel = await Spdb.getUser();
      _recentActivityList = await RecentActivityService().getRecentActivities();

      setState(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> crmWidgets = [
      {
        'icon': Iconsax.message,
        'title': 'Messages',
        'route': 'Chats',
        'color': Colors.blueAccent,
      },
      {
        'icon': Iconsax.activity,
        'title': 'Feed',
        'route': 'Feed',
        'color': Colors.orangeAccent,
      },
      {
        'icon': Iconsax.calendar,
        'title': 'Calendar',
        'route': 'Calendar',
        'color': Colors.purpleAccent,
      },
      {
        'icon': Iconsax.check,
        'title': 'Tasks',
        'route': 'Tasks',
        'color': Colors.greenAccent,
      },
      {
        'icon': Iconsax.graph,
        'title': 'CRM',
        'route': 'Leads',
        'color': Colors.redAccent,
      },
      // {
      //   'icon': Iconsax.building,
      //   'title': 'Companies',
      //   'route': 'Companies',
      //   'color': Colors.indigoAccent,
      // },
      // {
      //   'icon': Iconsax.calendar_2,
      //   'title': 'Holidays',
      //   'route': 'Holidays',
      //   'color': Colors.purpleAccent,
      // },
      {
        'icon': Iconsax.setting,
        'title': 'Settings',
        'route': 'Settings',
        'color': Colors.tealAccent,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          // Maintaining your original loading/error logic
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
                opacity: 0.8, // Slight dimming for better text contrast
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // --- TOP NAVIGATION BAR ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Container(
                          //   padding: const EdgeInsets.all(8),
                          //   decoration: BoxDecoration(
                          //     color: Colors.white.withValues(alpha: 0.1),
                          //     shape: BoxShape.circle,
                          //   ),
                          //   child: const Icon(
                          //     Iconsax.menu,
                          //     color: Colors.white,
                          //     size: 20,
                          //   ),
                          // ),
                          SizedBox(),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => Navigate.route(
                                  context,
                                  NotificationsListing(),
                                ),
                                child: const Icon(
                                  Iconsax.notification,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 15),
                              UserAvatar(userData: _userDataModel),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                  letterSpacing: 1.1,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userDataModel.name,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _userDataModel.desc ?? '',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.white60),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  var isAdmin = await Spdb.isAdminLoggedIn();
                                  Navigate.routeReplace(
                                    context,
                                    MainScreen(isAdmin: isAdmin),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Go to Dashboard',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.white60),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- SECTION: CRM ACTIONS ---
                  _buildSectionHeader("Your Workspace"),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: getCrossAxisCount(context),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.8,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = crmWidgets[index];
                        return GlassContainer(
                          onTap: () async {
                            var isAdmin = await Spdb.isAdminLoggedIn();
                            Navigate.routeReplace(
                              context,
                              MainScreen(
                                isAdmin: isAdmin,
                                selectedMenu: item['route'],
                              ),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item['icon'],
                                color: item['color'],
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['title'],
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }, childCount: crmWidgets.length),
                    ),
                  ),
                  _buildSectionHeader("Recent Activity"),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: _recentActivityList.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Text(
                                "No recent activity",
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white38),
                              ),
                            ),
                          )
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final activity = _recentActivityList[index];

                              return InkWell(
                                onTap: () async {
                                  final isAdmin = await Spdb.isAdminLoggedIn();
                                  Navigate.routeReplace(
                                    context,
                                    MainScreen(
                                      isAdmin: isAdmin,
                                      selectedMenu: activity.page,
                                    ),
                                  );
                                },
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.06,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Iconsax.document_text,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  activity.page,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Viewed recently",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        timeago.format(
                                          activity.visitedAt,
                                          locale: 'en_short',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }, childCount: _recentActivityList.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _getGridCount(context),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 4,
                                ),
                          ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 15, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            InkWell(
              onTap: () async {
                var isAdmin = await Spdb.isAdminLoggedIn();
                Navigate.routeReplace(context, MainScreen(isAdmin: isAdmin));
              },
              child: Text(
                "See all",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getGridCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) {
      return 4; // Desktop
    } else if (width >= 600) {
      return 3; // Tablet
    } else {
      return 3; // Mobile
    }
  }
}

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 20,
    this.opacity = 0.1,
    this.borderRadius = 24,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                // Multi-layered gradient for depth
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: opacity + 0.05),
                    Colors.white.withValues(alpha: opacity),
                  ],
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

int getCrossAxisCount(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 1200) return 6;
  if (width >= 800) return 4;
  if (width >= 600) return 3;
  return 2; // Default to 2 for mobile for better visibility of grid icons
}
