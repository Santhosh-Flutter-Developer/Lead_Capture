// ─────────────────────────────────────────────────────────────────────────────
// tray_stub.dart — NEW FILE
// Used on web (and any unsupported platform) via conditional import.
// tray_manager is desktop-only; importing it directly in web-reachable code
// breaks the web build compile, same reason local_notifier/window_manager
// are kept out of main.dart/app.dart directly.
// ─────────────────────────────────────────────────────────────────────────────

/// No-op on web.
Future<void> setupTray() async {}

/// No-op on web — window_close_stub.dart already handles the close
/// confirmation flow there; this is never called on web.
Future<bool> minimizeToTrayOnClose() async => true;