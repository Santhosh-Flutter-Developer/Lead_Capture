import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/views/views.dart';

class Developer extends StatefulWidget {
  final bool showAppbar;
  const Developer({super.key, this.showAppbar = true});

  @override
  State<Developer> createState() => _DeveloperState();
}

class _DeveloperState extends State<Developer> {
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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Iconsax.code_circle,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Developer Console",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Debugging tools and system utilities",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
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
                "Developer Console",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  height: 1,
                ),
              ),
            )
          : null,
      body: Center(
        child: Scrollbar(
          controller: _vScrollController,
          thumbVisibility: true,
          interactive: true,
          trackVisibility: true,
          radius: const Radius.circular(8),
          thickness: 8,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListView(
              controller: _vScrollController,
              padding: const EdgeInsets.all(24),
              children: [
                if (!widget.showAppbar) _buildHeaderBanner(context),
                _buildSectionHeader("Tools & Debugging", Iconsax.setting_4),
                const SizedBox(height: 16),
                _buildToolGrid([
                  _toolCard(
                    context,
                    "Notification Test",
                    "Trigger and verify push notification flows",
                    Iconsax.notification,
                    () async {
                      if (kIsDesktop) {
                        try {
                          await FirestoreNotificationListener.sendTestNotification();
                        } catch (e) {
                          FlushBar.show(context, e.toString(), isSuccess: true);
                        }
                      } else {
                        Navigate.route(context, const NotificationTestPage());
                      }
                    },
                  ),
                  _toolCard(
                    context,
                    "Shared Prefs",
                    "Inspect and edit local key-value storage",
                    Iconsax.data,
                    () => Navigate.route(context, const SharedprefsData()),
                  ),
                ]),
                const SizedBox(height: 32),
                _buildSectionHeader("System & Stability", Iconsax.status),
                const SizedBox(height: 16),
                _buildToolGrid([
                  _toolCard(
                    context,
                    "App Errors",
                    "Review recorded crashes and system logs",
                    Iconsax.close_circle,
                    () => Navigate.route(context, const AppErrors()),
                    isWarning: true,
                  ),
                  _toolCard(
                    context,
                    "Backup Listing",
                    "Manage cloud backups and data snapshots",
                    Iconsax.cloud,
                    () => Navigate.route(context, const BackupListing()),
                  ),
                ]),
                const SizedBox(height: 40),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildToolGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((card) {
            return SizedBox(
              width: isWide
                  ? (constraints.maxWidth / 2) - 8
                  : constraints.maxWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _toolCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isWarning = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isWarning
                    ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isWarning
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              size: 16,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Debug Mode Active",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Version ${VersionService.version?.version ?? 'N/A'} (Stable Build)",
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
