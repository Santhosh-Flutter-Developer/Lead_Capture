// ─────────────────────────────────────────────────────────────────────────────
// app.dart
// CHANGED:
//   • Removed `import 'dart:io'`  (crashes on web)
//   • Removed `import 'package:flutter_window_close/flutter_window_close.dart'`
//   • Added conditional import for setupWindowClose() via stub / native files
//   • Replaced `Platform.isWindows` with `kIsWindows` (from platform.dart)
//   • Web now also gets PopScope (back-button guard), just like mobile
// ─────────────────────────────────────────────────────────────────────────────
// import 'dart:io' show exit; // `exit()` is still needed on Windows — safe
// because it is only called inside !kIsWeb branch.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leadcapture/views/components/src/show_dialog.dart';
import 'package:provider/provider.dart';
// import '../../utils/src/tray_stub.dart';
import '/services/services.dart';
import '/views/views.dart';
import '/utils/utils.dart';
import '/theme/theme.dart';
import '/app/app.dart';

// Conditional import: on web the stub is used (does nothing).
// On native the real flutter_window_close wrapper is used.
import '/utils/src/window_close_stub.dart'
    if (dart.library.io) '/utils/src/window_close_native.dart';

import '/utils/src/tray_stub.dart'
    if (dart.library.io) '/utils/src/tray_native.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final ShowDialogs showDialogs = ShowDialogs();

  @override
  void initState() {
    super.initState();

    // Register Windows close handler only on native Windows.
    // The setupWindowClose() call is a no-op on web / other platforms.
    if (!kIsWeb && kIsWindows) {
      setupTray();
      setupWindowClose(() async {
        final ctx = navigatorKey.currentContext;
        if (ctx == null) return true;

        bool? shouldExit = await showDialogs.showExitConfirmationDialog(ctx);

        if (shouldExit == true) {
          // exit(0);
          minimizeToTrayOnClose();
        }
        
        return false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider()..checkLoginStatus(),
        ),
        ChangeNotifierProvider(create: (context) => MessageProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, child) {
          Widget home = authProvider.homeWidget ?? const Splash();

          // Once the logged-in main screen is showing, let the notification
          // service open any chat the user tapped on (cold start from a
          // notification).
          final ready = authProvider.homeWidget;
          if (ready is MainScreen || ready is RouteScreen) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              NotificationService.instance.markAppReady();
            });
          }

          // On Windows native: no PopScope (window_close handles it).
          // On web AND mobile: wrap with PopScope for back-button / browser
          // back navigation guard.
          if (!kIsWindows) {
            home = PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                final ctx = navigatorKey.currentContext;
                if (ctx == null) return;
                await showDialogs.showExitConfirmationDialog(ctx);
              },
              child: home,
            );
          }

          return MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: messengerKey,
            debugShowCheckedModeBanner: false,
            title: "Lead Capture",
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            // App-wide text selection (web, Windows, Android, iOS):
            //   • mouse drag / double-click / Ctrl+A / Ctrl+C on web+desktop
            //   • long-press + handles + Copy toolbar on touch devices
            // Placed in `builder` so it also covers dialogs, bottom sheets
            // and every pushed route. TextFields keep their own editing
            // selection; navigation chrome opts out with
            // SelectionContainer.disabled.
            builder: (context, child) =>
                AppSelectionShell(child: child ?? const SizedBox.shrink()),
            home: authProvider.isLoggedIn ? home : const Splash(),
          );
        },
      ),
    );
  }
}

/// Makes all text in the app selectable.
///
/// `SelectionArea` needs an [Overlay] ABOVE it (for the selection handles
/// and the Copy toolbar). `MaterialApp.builder` sits above the Navigator's
/// own Overlay, so putting SelectionArea there directly crashes with
/// "No Overlay widget found". This shell supplies a root Overlay and puts
/// SelectionArea + the app (Navigator) inside its single entry.
class AppSelectionShell extends StatefulWidget {
  final Widget child;
  const AppSelectionShell({super.key, required this.child});

  @override
  State<AppSelectionShell> createState() => _AppSelectionShellState();
}

class _AppSelectionShellState extends State<AppSelectionShell> {
  // Created once, so the app below is never rebuilt from scratch (that
  // would lose navigation and screen state). It always shows the LATEST
  // `widget.child`; see didUpdateWidget.
  late final OverlayEntry _entry = OverlayEntry(
    // SelectionArea must be INSIDE the Overlay (it looks the Overlay up as an
    // ancestor), so it lives in the entry, around the app.
    builder: (context) => SelectionArea(child: widget.child),
  );

  @override
  void didUpdateWidget(covariant AppSelectionShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild(); // pick up the new child (theme/auth changes)
  }

  @override
  void dispose() {
    try {
      _entry.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}