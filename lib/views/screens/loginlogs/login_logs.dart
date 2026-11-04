import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '/models/models.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import 'bloc/login_log_bloc.dart';

class LoginLogsListing extends StatefulWidget {
  final bool showAppbar;

  const LoginLogsListing({super.key, required this.showAppbar});

  @override
  State<LoginLogsListing> createState() => _LoginLogsListingState();
}

class _LoginLogsListingState extends State<LoginLogsListing> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    context.read<LoginLogsBloc>().add(StreamLoginLogs());
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Map<String, List<LoginLogsModel>> _groupByDay(List<LoginLogsModel> items) {
    final Map<String, List<LoginLogsModel>> map = {};
    final now = DateTime.now();
    for (final item in items) {
      final dt = item.loginTime;
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
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginLogsBloc()..add(StreamLoginLogs()),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: widget.showAppbar
            ? AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Back(color: Theme.of(context).colorScheme.onSurface),
                ),
                centerTitle: false,
                title: Text(
                  "Access Logs",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: _buildHeaderSearch(),
                ),
              )
            : null,
        body: BlocBuilder<LoginLogsBloc, LoginLogsState>(
          builder: (context, state) {
            if (state is LoginLogsLoading) {
              return const Center(child: WaitingLoading());
            }
            if (state is LoginLogsError) {
              return ErrorDisplay(error: state.message);
            }
            if (state is LoginLogsLoaded) {
              final filteredList = state.loginLog.where((it) {
                if (_search.isEmpty) return true;
                final device = it.loginAlert.device.toLowerCase();
                final ip = it.loginAlert.ipAddress.toLowerCase();
                final location = it.loginAlert.location.toLowerCase();
                final name = it.user.name.toLowerCase();
                return device.contains(_search) ||
                    ip.contains(_search) ||
                    location.contains(_search) ||
                    name.contains(_search);
              }).toList();

              final grouped = _groupByDay(filteredList);

              return RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: ListView(
                      controller: _vScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (!widget.showAppbar) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                            child: _buildHeaderBanner(context),
                          ),
                        ],
                        if (filteredList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 100),
                            child: NoData(
                              text: "No login records found for this query",
                            ),
                          )
                        else
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: grouped.entries.map((entry) {
                                    return _buildSection(entry.key, entry.value);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052D4).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Iconsax.security_user,
                  color: AppColors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Access Logs",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Review recent sign-ins across every device",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filter by user, device, or IP address...',
                hintStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.grey500),
                prefixIcon: const Icon(
                  Iconsax.search_normal_1,
                  size: 16,
                  color: AppColors.grey500,
                ),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        splashRadius: 16,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.grey500,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSearch() {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.outlineVariant,
          height: 1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Iconsax.search_normal,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                hintText: 'Filter by user, device, or IP address...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String label, List<LoginLogsModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const double spacing = 16;
            const double minCardWidth = 380;

            final double width = constraints.maxWidth;
            int columns = (width / (minCardWidth + spacing)).floor();
            columns = columns.clamp(1, 3);

            final double itemWidth =
                (width - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: _buildLoginCard(item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoginCard(LoginLogsModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UserAvatar(userData: item.user, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.user.name.isNotEmpty
                            ? item.user.name
                            : 'Unknown User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        item.user.desc ?? 'Active Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _timeAgo(item.loginTime),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getDeviceIcon(item.loginAlert.device),
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.loginAlert.device,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(Iconsax.global, item.loginAlert.ipAddress),
                      const SizedBox(height: 4),
                      _buildInfoRow(Iconsax.location, item.loginAlert.location),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(String device) {
    final d = device.toLowerCase();
    if (d.contains('iphone') || d.contains('android') || d.contains('mobile')) {
      return Iconsax.mobile;
    }
    if (d.contains('mac') || d.contains('windows') || d.contains('linux')) {
      return Iconsax.monitor;
    }
    return Iconsax.device_message;
  }
}
