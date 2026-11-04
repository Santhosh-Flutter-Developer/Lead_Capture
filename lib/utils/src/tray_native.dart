// ─────────────────────────────────────────────────────────────────────────────
// tray_native.dart — NEW FILE
// Used on native desktop platforms (Windows / macOS / Linux) via conditional
// import in app.dart. Puts Mini CRM in the system tray and turns the window's
// close (X) button into "hide to tray" instead of "exit the process" — the
// Firestore notification listener (windows_notification_service.dart) only
// keeps working while the process is alive, so this is what lets reminder /
// "Event Started" notifications keep arriving after the user clicks X.
// Actually quitting the app is only done from the tray icon's "Exit" item.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class _AppTrayListener with TrayListener {
  @override
  void onTrayIconMouseDown() {
    // Left-click the tray icon → bring the window back.
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'open':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'exit':
        await trayManager.destroy();
        exit(0);
    }
  }
}

final _trayListener = _AppTrayListener();
bool _trayInitialized = false;

Future<void> setupTray() async {
  if (_trayInitialized) return;
  _trayInitialized = true;

  trayManager.addListener(_trayListener);

  // tray_manager needs a real filesystem path on Windows/Linux (unlike
  // normal Flutter assets, which are only reachable through rootBundle at
  // runtime) — desktop builds put the asset bundle under
  // <executable dir>/data/flutter_assets/.
  final iconPath = p.join(
    p.dirname(Platform.resolvedExecutable),
    'data',
    'flutter_assets',
    'assets',
    'icons',
    'tray_icon.ico',
  );

  await trayManager.setIcon(iconPath);
  await trayManager.setToolTip('LeadcaptureCRM');
  await trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'open', label: 'Open LeadcaptureCRM'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit'),
      ],
    ),
  );
}

/// Called from the flutter_window_close "should close?" handler. Hides the
/// window to the tray and tells flutter_window_close to cancel the actual
/// close, so the process (and its Firestore notification listener) keeps
/// running in the background.
Future<bool> minimizeToTrayOnClose() async {
  await windowManager.hide();
  return false;
}
