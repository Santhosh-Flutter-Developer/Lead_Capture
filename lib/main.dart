// ─────────────────────────────────────────────────────────────────────────────
// main.dart
// CHANGED:
//   • Removed `import 'package:local_notifier/local_notifier.dart'`
//     (not web-compatible — crashes on web at compile time)
//   • Added conditional import for DesktopNotificationSetup stub/native
//   • Added kIsWeb branch: initialises web FCM push notifications
//   • LifecycleHandler guarded behind !kIsWeb (AppLifecycle API is
//     not fully supported on web)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import '/firebase_options.dart';
import '/app/app.dart';
import '/services/services.dart';
import '/utils/utils.dart';

// Conditional import for desktop-only notification setup.
// On web → stub (does nothing). On native → real local_notifier setup.
import 'services/firebase/src/desktop_notifier_stub.dart'
    if (dart.library.io) 'services/firebase/src/desktop_notifier_native.dart';

// ─── Lifecycle handler (online / offline status) ─────────────────────────────
// Only registered on non-web platforms where AppLifecycle works reliably.
class LifecycleHandler extends WidgetsBindingObserver {
  final String uid;
  LifecycleHandler(this.uid);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (uid.isEmpty) return;
    switch (state) {
      case AppLifecycleState.resumed:
        try {
          UserStatusService.setOnline(uid);
        } catch (e) {
          debugPrint("Failed to set user online: $e");
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        try {
          UserStatusService.setOffline(uid);
        } catch (e) {
          debugPrint("Failed to set user offline: $e");
        }
        break;
      default:
        try {
          UserStatusService.setOffline(uid);
        } catch (e) {
          debugPrint("Failed to set user offline: $e");
        }
    }
  }
}

// ─── Entry point ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web: replace the browser's right-click menu by Flutter's own text
  // selection toolbar (Copy / Select all), which the browser menu cannot
  // offer for canvas-rendered text.
  if (kIsWeb) BrowserContextMenu.disableContextMenu();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  if (kIsWeb) {
    // ── Web: use Firebase Messaging web push (VAPID) ──────────────────────
    // NotificationService.instance.initalize() uses flutter_local_notifications
    // which is NOT web-compatible. On web we call initializeForWeb() instead,
    // which requests browser permission and obtains the FCM web token.
    await NotificationService.instance.initializeForWeb();
  } else if (kIsMobile) {
    // ── Mobile (Android / iOS) ────────────────────────────────────────────
    NotificationService.instance.initalize();
  } else if (kIsDesktop) {
    // ── Desktop (Windows / macOS / Linux) ────────────────────────────────
    // setupDesktopNotifier() is the conditional import:
    //   • web / unsupported  → stub (no-op)
    //   • native             → windowManager.ensureInitialized() +
    //                           localNotifier.setup() + listenForNotifications()
    // window_manager's ensureInitialized() call lives inside the native-only
    // file (not here) — importing window_manager directly in main.dart would
    // break the web build compile, same reason local_notifier was moved out.
    await setupDesktopNotifier();
  }

  await AppPackageInfo.init();
  await CacheService().init();
  await VersionService.init();
  await Spdb.loadPanelSettings();
  await Spdb.loadPayrollSettings();

  // Register lifecycle observer only on native (web doesn't need it and
  // AppLifecycle.paused / detached don't fire reliably in browsers).
  if (!kIsWeb) {
    final uid = await Spdb.getUid();
    if (uid != null && uid.isNotEmpty) {
      WidgetsBinding.instance.addObserver(LifecycleHandler(uid));
      try {
        await UserStatusService.setOnline(uid);
      } catch (e) {
        // Silently ignore status update errors during initialization
        debugPrint("Failed to set user online status: $e");
      }
    }
  }

  runApp(const App());
}