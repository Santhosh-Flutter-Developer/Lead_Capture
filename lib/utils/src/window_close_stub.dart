// ─────────────────────────────────────────────────────────────────────────────
// window_close_stub.dart  — NEW FILE (used on web & non-Windows platforms)
// Provides a no-op setupWindowClose() so that app.dart can use a conditional
// import without crashing on web.
// ─────────────────────────────────────────────────────────────────────────────

/// No-op on web / non-Windows. Does nothing.
void setupWindowClose(Future<bool?> Function() handler) {}
