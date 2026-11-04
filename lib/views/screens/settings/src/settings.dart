import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import '/app/app.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/services/services.dart';
import '/theme/theme.dart';

class SettingsColors {
  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color surface = Colors.white;
}

class Settings extends StatelessWidget {
  final bool showAppbar;
  final Function(bool)? onThemeChanged;

  const Settings({super.key, this.showAppbar = true, this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsBloc()..add(LoadSettingsEvent())),
      ],
      child: SettingsListing(
        showAppbar: showAppbar,
        onThemeChanged: onThemeChanged,
      ),
    );
  }
}

class SettingsListing extends StatefulWidget {
  final bool showAppbar;
  final Function(bool)? onThemeChanged;

  const SettingsListing({
    super.key,
    this.showAppbar = true,
    this.onThemeChanged,
  });

  @override
  State<SettingsListing> createState() => _SettingsListingState();
}

class _SettingsListingState extends State<SettingsListing> {
  final ScrollController _vScrollController = ScrollController();
  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Widget _buildHeaderBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Iconsax.setting_2,
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
                  "Preferences",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage notifications, appearance and system settings",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    final themeProvider = context.read<ThemeProvider>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showAppbar
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              centerTitle: false,
              leading: Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Back(color: Theme.of(context).colorScheme.onSurface),
              ),
              title: Text(
                "Preferences",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Theme.of(context).dividerColor,
                  height: 1,
                ),
              ),
            )
          : null,
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state is SettingsLoading) {
            return const Center(child: WaitingLoading());
          }
          if (state is SettingsLoaded) {
            final settings = state.settings;

            final notificationsCard = _buildGroupCard(
              context,
              icon: Iconsax.notification,
              iconColor: Colors.blueAccent,
              title: "Notifications",
              subtitle: "Choose how you want to be kept in the loop",
              children: [
                _buildSwitchTile(
                  icon: Iconsax.sms,
                  iconColor: Colors.blueAccent,
                  title: "Email Notifications",
                  subtitle: "Receive daily summaries via email",
                  value: settings.emailNotification,
                  onChanged: (val) => context.read<SettingsBloc>().add(
                    UpdateSettingsEvent("emailNotification", val),
                  ),
                ),
                _buildSwitchTile(
                  icon: Iconsax.notification,
                  iconColor: Colors.orangeAccent,
                  title: "Push Notifications",
                  subtitle: "Instant alerts on your device",
                  value: settings.pushNotification,
                  onChanged: (val) => context.read<SettingsBloc>().add(
                    UpdateSettingsEvent("pushNotification", val),
                  ),
                ),
                _buildSwitchTile(
                  icon: Iconsax.message,
                  iconColor: Colors.greenAccent,
                  title: "In-App Alerts",
                  subtitle: "Banners and indicators within the app",
                  value: settings.inAppNotification,
                  onChanged: (val) => context.read<SettingsBloc>().add(
                    UpdateSettingsEvent("inAppNotification", val),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: PanelSettingsNotifier.hidePanel,
                  builder: (context, hidePanel, _) {
                    return _buildSwitchTile(
                      icon: hidePanel ? Iconsax.lamp_slash : Iconsax.lamp_on,
                      iconColor: Colors.purple,
                      title: "Hide Chat Panel",
                      subtitle: "Enable to hide the side panel",
                      value: hidePanel,
                      onChanged: (val) async {
                        await Spdb.savePanelSettings(val);
                      },
                    );
                  },
                ),
              ],
            );

            final appearanceCard = _buildGroupCard(
              context,
              icon: Iconsax.brush,
              iconColor: const Color(0xFF34495E),
              title: "App Appearance",
              subtitle: "Personalize how the workspace looks",
              children: [
                _buildSwitchTile(
                  icon: isDark ? Iconsax.moon : Iconsax.sun_1,
                  iconColor: const Color(0xFF34495E),
                  title: "Dark Theme",
                  subtitle: "Reduce eye strain in low light",
                  value: isDark,
                  onChanged: (value) => themeProvider.setDarkMode(value),
                  isInDevelop: false,
                ),
              ],
            );

            final systemCard = _buildGroupCard(
              context,
              icon: Iconsax.status,
              iconColor: Colors.purpleAccent,
              title: "System & Data",
              subtitle: "Application details and data management",
              children: [
                _buildInteractiveTile(
                  icon: Iconsax.mobile_programming,
                  iconColor: Colors.purpleAccent,
                  title: "Application Name",
                  trailing: SizedBox(
                    width: 140,
                    child: TextField(
                      onChanged: (val) => context.read<SettingsBloc>().add(
                        UpdateSettingsEvent("appName", val),
                      ),
                      controller: TextEditingController(text: settings.appName)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: settings.appName.length),
                        ),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: SettingsColors.primary,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "Enter Name",
                        hintStyle: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: SettingsColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildSwitchTile(
                  icon: Iconsax.cloud_notif,
                  iconColor: Colors.cyan,
                  title: "Cloud Auto-Backup",
                  subtitle: "Secure your data automatically",
                  value: settings.autoBackup,
                  onChanged: (val) => context.read<SettingsBloc>().add(
                    UpdateSettingsEvent("autoBackup", val),
                  ),
                ),
                _buildInteractiveTile(
                  icon: Iconsax.trash,
                  iconColor: Colors.redAccent,
                  title: "Trash Manager",
                  onTap: () => Navigate.route(context, const TrashScreen()),
                  trailing: const Icon(
                    Iconsax.arrow_right_3,
                    size: 16,
                    color: SettingsColors.border,
                  ),
                ),
              ],
            );

            return ScrollConfiguration(
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
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (!widget.showAppbar) _buildHeaderBanner(context),
                    notificationsCard,
                    const SizedBox(height: 28),
                    appearanceCard,
                    const SizedBox(height: 28),
                    systemCard,
                    const SizedBox(height: 40),
                    _buildFooter(),
                  ],
                ),
              ),
            );
          }
          if (state is SettingsError) {
            return ErrorDisplay(error: state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  /// Lays out a section's items as a responsive grid of equal-width
  /// tiles: 1 column on narrow screens, more as space allows.
  Widget _buildTileGrid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16;
        const double minTileWidth = 300;

        final double width = constraints.maxWidth;
        int columns = (width / (minTileWidth + spacing)).floor();
        columns = columns.clamp(1, 4);

        final double itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles
              .map((tile) => SizedBox(width: itemWidth, child: tile))
              .toList(),
        );
      },
    );
  }

  /// A section: icon-badge + title + subtitle header, followed by its
  /// items laid out as a responsive grid of equal tiles.
  Widget _buildGroupCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 4),
          child: Row(
            children: [
              _buildIconContainer(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
        ),
        _buildTileGrid(children),
      ],
    );
  }

  /// Shared card decoration for a single settings tile.
  Widget _tileCard(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isInDevelop = false,
  }) {
    return _tileCard(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildIconContainer(icon, iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isInDevelop)
              MorphSwitch(value: value, onChanged: onChanged)
            else
              Text(
                "In Development",
                style: TextStyle(
                  fontSize: 10,
                  color: SettingsColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _tileCard(
      context,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildIconContainer(icon, iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // Widget _buildDropdown({
  //   required String value,
  //   required List<String> options,
  //   required ValueChanged<String?> onChanged,
  // }) {
  //   final validValue = options.contains(value) ? value : options.first;
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //     decoration: BoxDecoration(
  //       color: SettingsColors.background,
  //       borderRadius: BorderRadius.circular(8),
  //       border: Border.all(color: SettingsColors.border),
  //     ),
  //     child: DropdownButtonHideUnderline(
  //       child: DropdownButton<String>(
  //         value: validValue,
  //         icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: SettingsColors.textSecondary),
  //         isDense: true,
  //         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SettingsColors.textPrimary),
  //         items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
  //         onChanged: onChanged,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          const Text(
            "Syncing with Cloud Vault",
            style: TextStyle(
              fontSize: 11,
              color: SettingsColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Workspace Version ${VersionService.version?.version ?? 'N/A'} (LTS)",
            style: TextStyle(fontSize: 10, color: SettingsColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class MorphSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const MorphSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.decelerate,
        width: 48,
        height: 26,
        decoration: BoxDecoration(
          color: value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.decelerate,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
