// ─────────────────────────────────────────────────────────────────────────────
// desktop_notifier_native.dart  — NEW FILE
// Used on native desktop platforms via conditional import in main.dart.
// Wraps the original local_notifier setup so the import never reaches web.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import '/services/firebase/src/windows_notification_service.dart';

/// Sets up local_notifier, registers Mini CRM to auto-launch at system
/// startup, and starts the Firestore notification listener. Called only
/// from native desktop platforms (Windows / macOS / Linux).
Future<void> setupDesktopNotifier() async {
  // Required before any windowManager.* call — windows_notification_service
  // uses windowManager.focus()/.show() in its notification click handler,
  // and calling those without this first throws.
  await windowManager.ensureInitialized();
  await localNotifier.setup(appName: 'LeadcaptureCRM');
  FirestoreNotificationListener.listenForNotifications();

  // Auto-launch on system startup, so the app (and its Firestore
  // notification listener) is running in the background without the user
  // having to remember to open it manually. Combined with the tray_native
  // "minimize to tray on close" behavior, this means Mini CRM effectively
  // stays alive from boot until the user explicitly chooses Exit from the
  // tray menu. NOTE: on first boot after enabling, the OS will show the
  // window normally (auto-launch doesn't start it pre-hidden) — the user
  // clicking X once sends it to the tray, same as any other launch.
  try {
    launchAtStartup.setup(
      appName: 'LeadcaptureCRM',
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  } catch (e) {
    // Non-fatal — auto-start is a convenience, not required for the app
    // (or reminder notifications) to function while it IS running.
  }
}
