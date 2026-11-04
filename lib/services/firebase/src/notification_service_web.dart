import 'dart:html' as html;
// ─────────────────────────────────────────────────────────────────────────────
// notification_service_web.dart  — NEW FILE
// Used on web via conditional import. No local filesystem on web, so all
// avatar/cache helpers return null or do nothing.
// ─────────────────────────────────────────────────────────────────────────────

/// On web: no local filesystem — avatar caching is not possible.
/// Returns null so the notification falls back to a text-only display.
Future<String?> downloadAvatarCircular(
  String? url,
  String name, {
  int size = 192,
  Duration ttl = const Duration(days: 7),
  bool forceRefresh = false,
}) async {
  return null;
}

/// No-op on web.
Future<void> clearAvatarCacheNative() async {}

/// Web: the service worker posts the clicked notification's data on this
/// channel when a tab is already open (BroadcastChannel needs no controller
/// and no message-queue start, unlike ServiceWorker.postMessage).
void listenForNotificationClicks(void Function(Map<String, dynamic>) onClick) {
  try {
    final channel = html.BroadcastChannel('lc_notif_click');
    channel.onMessage.listen((event) {
      final d = event.data;
      // ignore: avoid_print
      print('🔔 [NOTIF] web: click received from service worker: $d');
      if (d is Map) onClick(Map<String, dynamic>.from(d));
    });
  } catch (_) {}
}

/// Prints (in the `flutter run` console) which service worker file is served,
/// which one is registered, and which version is actually running.
Future<void> diagnoseServiceWorker() async {
  try {
    final text = await html.HttpRequest.getString('firebase-messaging-sw.js');
    // ignore: avoid_print
    print(
      '🔔 [NOTIF] served firebase-messaging-sw.js has lc-sw-v5: '
      '${text.contains("lc-sw-v5")}',
    );
  } catch (e) {
    // ignore: avoid_print
    print('🔔 [NOTIF] could not read firebase-messaging-sw.js: $e');
  }

  try {
    final channel = html.BroadcastChannel('lc_sw_info');
    channel.onMessage.listen((event) {
      // ignore: avoid_print
      print('🔔 [NOTIF] running service worker says: ${event.data}');
    });

    final dynamic container = html.window.navigator.serviceWorker;
    final dynamic regs = await container.getRegistrations();
    // ignore: avoid_print
    print('🔔 [NOTIF] service worker registrations: ${regs.length}');
    for (final dynamic reg in regs) {
      final dynamic active = reg.active;
      // ignore: avoid_print
      print(
        '🔔 [NOTIF]   scope=${reg.scope} '
        'active=${active?.scriptUrl} state=${active?.state}',
      );
      try {
        active?.postMessage({'type': 'lc-ping'});
      } catch (_) {}
    }
    Future.delayed(const Duration(seconds: 4), () {
      // ignore: avoid_print
      print(
        '🔔 [NOTIF] (if no "running service worker says" line appeared above, '
        'the running worker is an OLD one without version support)',
      );
    });
  } catch (e) {
    // ignore: avoid_print
    print('🔔 [NOTIF] service worker diagnostics failed: $e');
  }
}