// ─────────────────────────────────────────────────────────────────────────────
// desktop_notifier_stub.dart  — NEW FILE
// Used on web (and any unsupported platform) via conditional import in main.dart.
// All functions are no-ops so the web build compiles without local_notifier.
// ─────────────────────────────────────────────────────────────────────────────

/// No-op on web.
Future<void> setupDesktopNotifier() async {}
