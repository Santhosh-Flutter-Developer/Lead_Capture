import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '/theme/theme.dart';
import '/views/views.dart';
import '/services/services.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String? _apnsToken;
  String? _fcmToken;
  String? _error;
  bool _loading = false;
  AuthorizationStatus? _authStatus;
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    super.initState();
    _initFirebaseMessaging();
  }

  @override
  void dispose() {
    _vScrollController.dispose();
    super.dispose();
  }

  Future<void> _initFirebaseMessaging() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Check current permission
      NotificationSettings currentSettings = await messaging
          .getNotificationSettings();
      _authStatus = currentSettings.authorizationStatus;

      // Request permission if not determined or denied
      if (_authStatus == AuthorizationStatus.notDetermined ||
          _authStatus == AuthorizationStatus.denied) {
        NotificationSettings newSettings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _authStatus = newSettings.authorizationStatus;
      }

      if (_authStatus == AuthorizationStatus.denied) {
        setState(() {
          _error = kIsWeb
              ? 'Notifications are blocked for this site in your browser. '
                    'Click the padlock icon next to the address bar → Site '
                    'settings → Notifications → Allow, then refresh this page.'
              : 'Notification permission denied by user.';
          _loading = false;
        });
        return;
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // Get APNs token (for iOS only)
      String? apns;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        apns = await messaging.getAPNSToken();
      }

      // Get FCM token (web requires the VAPID key)
      String? fcm = await messaging.getToken(
        vapidKey: kIsWeb ? kVapidKey : null,
      );

      if (fcm == null) {
        setState(() {
          _error = 'Failed to retrieve FCM token.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _apnsToken = apns;
        _fcmToken = fcm;
        _loading = false;
      });
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  void _copyToken(String token) {
    Clipboard.setData(ClipboardData(text: token));
    FlushBar.show(context, 'Token copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: WaitingLoading())
                : Padding(
                  padding: const EdgeInsets.only(right: 8.0),
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
                        child: SingleChildScrollView(
                          controller: _vScrollController,
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_error != null) _buildErrorBanner(_error!),
                                  if (_error != null) const SizedBox(height: 20),
                                  _buildTokenCard(
                                    icon: Iconsax.mobile,
                                    iconColor: const Color(0xFF3B82F6),
                                    title: "FCM Token",
                                    subtitle:
                                        "Used to send push notifications via Firebase",
                                    token: _fcmToken,
                                    emptyText: "No FCM token retrieved yet.",
                                    onCopy: _fcmToken != null
                                        ? () => _copyToken(_fcmToken!)
                                        : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTokenCard(
                                    icon: Iconsax.mobile,
                                    iconColor: const Color(0xFFF59E0B),
                                    title: "APNs Token",
                                    subtitle: "iOS only, managed by Firebase",
                                    token: _apnsToken,
                                    emptyText: "No APNs token retrieved.",
                                    onCopy: _apnsToken != null
                                        ? () => _copyToken(_apnsToken!)
                                        : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildStatusAndRefreshRow(),
                                  const SizedBox(height: 20),
                                  _buildTipsCard(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
        ),
      ),
      child: Row(
        children: [
          Back(color: AppColors.white),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Iconsax.notification,
              color: AppColors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notification Test",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Trigger and verify push notification flows",
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

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.warning_2, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String? token,
    required String emptyText,
    VoidCallback? onCopy,
  }) {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: token != null
                  ? SelectableText(
                      token,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  : Text(
                      emptyText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _actionButton(
                icon: Iconsax.copy,
                label: "Copy $title",
                onTap: onCopy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final color = enabled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;
    return Material(
      color: enabled
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusAndRefreshRow() {
    return Row(
      children: [
        if (_authStatus != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.shield_tick,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Permission: ${_authStatus.toString().split('.').last}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _brandGradient),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _initFirebaseMessaging,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.refresh, size: 15, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      "Refresh Tokens",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    final tips = kIsWeb
        ? const [
            'FCM token is used to send notifications via Firebase.',
            'Web push requires the browser notification permission to be Allowed for this site.',
            'If tokens are empty, check the padlock icon → Site settings → Notifications, then refresh.',
          ]
        : const [
            'FCM token is used to send notifications via Firebase.',
            'APNs token is managed internally by Firebase for iOS.',
            'If tokens are empty, reinstall app or restart device.',
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.lamp_on,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                "TIPS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
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
