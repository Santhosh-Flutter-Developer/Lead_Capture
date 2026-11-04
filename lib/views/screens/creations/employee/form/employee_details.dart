import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/services/services.dart';
import '/models/models.dart';
import '/views/views.dart';
import '/theme/theme.dart';

class EmployeeDetails extends StatefulWidget {
  final EmployeeModel employee;

  const EmployeeDetails({super.key, required this.employee});

  @override
  State<EmployeeDetails> createState() => _EmployeeDetailsState();
}

class _EmployeeDetailsState extends State<EmployeeDetails> {
  late Future _future;
  int _taskCount = 0;
  int _projectCount = 0;
  int _leadsCount = 0;
  int _dealsCount = 0;
  final ScrollController _scrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    final taskCount = await TaskService.getUserTaskCount(
      userId: widget.employee.uid ?? '',
    );
    final projectCount = await ProjectService.getUserProjectsCount(
      userId: widget.employee.uid ?? '',
    );
    final leadsCount = await LeadService.getUserLeadsCount(
      userId: widget.employee.uid ?? '',
    );
    final dealsCount = await DealService.getUserDealsCount(
      userId: widget.employee.uid ?? '',
    );

    if (mounted) {
      setState(() {
        _taskCount = taskCount;
        _projectCount = projectCount;
        _leadsCount = leadsCount;
        _dealsCount = dealsCount;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
              Iconsax.medal_star,
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
                  "Employee Portfolio",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Overview, activity and personal details",
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const WaitingLoading();
                } else if (snapshot.hasError) {
                  return ErrorDisplay(error: snapshot.error.toString());
                } else {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth > 600;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          interactive: true,
                          trackVisibility: true,
                          radius: const Radius.circular(8),
                          thickness: 8,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 1300,
                                ),
                                padding: EdgeInsets.all(isDesktop ? 20 : 16),
                                child: isDesktop
                                    ? _buildDesktopLayout(context)
                                    : _buildMobileLayout(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// DESKTOP LAYOUT: Dashboard Grid Arrangement
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildIdentityCard(context)),
        const SizedBox(width: 20),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildQuickStats(context),
              const SizedBox(height: 20),
              _buildInformationGrid(context, 2),
            ],
          ),
        ),
      ],
    );
  }

  /// MOBILE LAYOUT: Vertical List View
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildIdentityCard(context),
        const SizedBox(height: 16),
        _buildQuickStats(context),
        const SizedBox(height: 20),
        _buildInformationGrid(context, 1),
      ],
    );
  }

  /// PRIMARY IDENTITY CARD
  Widget _buildIdentityCard(BuildContext context) {
    final designation =
        CacheService.designationByUid(widget.employee.designation)?.name ??
        'N/A';
    final department = widget.employee.department != null
        ? widget.employee.department!
              .map((d) => CacheService.departmentByUid(d)?.name ?? '')
              .join(', ')
        : 'General';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: _glassDecoration(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _brandGradient,
              ),
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              backgroundImage:
                  (widget.employee.profileImageUrl != null &&
                      widget.employee.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(widget.employee.profileImageUrl!)
                  : null,
              child:
                  (widget.employee.profileImageUrl == null ||
                      widget.employee.profileImageUrl!.isEmpty)
                  ? Text(
                      widget.employee.name.isNotEmpty
                          ? widget.employee.name[0].toUpperCase()
                          : "?",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.employee.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              designation,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            department,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: 20),
          _buildCompactTile(
            Iconsax.personalcard,
            "Employee ID",
            widget.employee.employeeId,
          ),
          _buildCompactTile(Iconsax.sms, "Work Email", widget.employee.email),
          _buildCompactTile(
            Iconsax.call,
            "Phone",
            widget.employee.mobileNumber,
          ),
        ],
      ),
    );
  }

  /// QUICK STATS SECTION
  Widget _buildQuickStats(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Activity Overview",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            "A snapshot of this employee's workload",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _statItem(
                "Tasks",
                _taskCount,
                AppColors.orange,
                Iconsax.task_square,
              ),
              _vDivider(),
              _statItem(
                "Projects",
                _projectCount,
                Theme.of(context).colorScheme.primary,
                Iconsax.briefcase,
              ),
              _vDivider(),
              _statItem(
                "Leads",
                _leadsCount,
                AppColors.secondary,
                Iconsax.chart_2,
              ),
              _vDivider(),
              _statItem(
                "Deals",
                _dealsCount,
                AppColors.success,
                Iconsax.dollar_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// INFORMATION GRID: Literal GridView for desktop alignment
  Widget _buildInformationGrid(BuildContext context, int columns) {
    final infoItems = [
      {
        "label": "Official Name",
        "value": widget.employee.name,
        "icon": Iconsax.user,
      },
      {
        "label": "Employee Type",
        "value": widget.employee.employeeType ?? "Permanent",
        "icon": Iconsax.briefcase,
      },
      {
        "label": "Joining Date",
        "value": widget.employee.dateOfJoining.toLocal().toString().split(
          ' ',
        )[0],
        "icon": Iconsax.calendar_1,
      },
      {
        "label": "Date of Birth",
        "value":
            widget.employee.dateOfBirth?.toLocal().toString().split(' ')[0] ??
            "-",
        "icon": Iconsax.cake,
      },
      {"label": "Gender", "value": widget.employee.gender, "icon": Iconsax.man},
      {
        "label": "Marital Status",
        "value": widget.employee.maritalStatus,
        "icon": Iconsax.heart,
      },
    ];

    return _buildSectionCard(
      title: "Personal Information",
      subtitle: "Basic details on file for this employee",
      icon: Iconsax.personalcard,
      accentColor: AppColors.secondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 20.0;
          final double itemWidth = columns <= 1
              ? constraints.maxWidth
              : (constraints.maxWidth - spacing * (columns - 1)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: 18,
            children: infoItems
                .map(
                  (item) => SizedBox(
                    width: itemWidth,
                    child: _buildDataPoint(
                      item["label"].toString(),
                      item["value"].toString(),
                      item["icon"] as IconData,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  // --- REUSABLE WIDGETS ---
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Color? accentColor,
  }) {
    final Color badgeColor = accentColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _glassDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: badgeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.grey200, thickness: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDataPoint(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value.isEmpty ? "-" : value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.transparent
              : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 40, color: Theme.of(context).dividerColor);
}