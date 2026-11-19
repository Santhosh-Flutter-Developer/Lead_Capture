import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import '/services/services.dart';
import '/app/app.dart';
import '/constants/constants.dart';
import '/views/views.dart';

final AudioPlayer _player = AudioPlayer();

/// Desktop notifier. The PHP API has no push channel, so new notifications
/// are polled from notifications.php every 20 s (class name kept for callers).
class FirestoreNotificationListener {
  static final Set<String> _shownIds = {};
  static Timer? _timer;
  static bool _primed = false;

  /// true the first time [id] is seen (shared by the poller and WebSocket so a
  /// notification is never shown twice).
  static bool claim(String id) => id.isNotEmpty && _shownIds.add(id);

  /// Shows a notification that arrived over the WebSocket instantly.
  static Future<void> showFromSocket(Map<String, dynamic> data) async {
    final me = (await Spdb.getUid())?.trim() ?? '';
    final n = CrmMappers.notification(data, myUid: me);
    if (!claim(n.uid ?? '')) return;
    final notification = LocalNotification(
      title: n.title.isEmpty ? 'New Notification' : n.title,
      body: n.body.isEmpty ? 'You have a new message' : n.body,
    );
    notification.onClick = () async {
      await windowManager.focus();
      await windowManager.show();
      final t = n.type?.name ?? '';
      if (t == 'chat' || t == 'task' || t == 'ticket') {
        NotificationService.instance.openFromPayload({...n.payload, 'type': t});
        return;
      }
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      final isAdmin = await Spdb.isAdminLoggedIn();
      navigator.pushAndRemoveUntil(
        CupertinoPageRoute(builder: (_) => MainScreen(isAdmin: isAdmin)),
        (route) => false,
      );
    };
    notification.show();
    _playSound();
  }

  /// Stops polling (call on logout).
  static Future<void> stopListening() async {
    _timer?.cancel();
    _timer = null;
    _shownIds.clear();
    _primed = false;
  }

  static Future<void> listenForNotifications() async {
    await stopListening();
    final uid = (await Spdb.getUid())?.trim();
    if (uid == null || uid.isEmpty) return;

    Future<void> poll() async {
      try {
        // WebSocket delivers instantly (RealtimeService); poll only as a
        // fallback while it is down (or for the very first priming call).
        if (_primed && CrmSocketService.instance.isConnected) return;
        final current = (await Spdb.getUid())?.trim();
        if (current != uid) {
          await stopListening();
          return;
        }
        final res = (await NotificationsApiService.call('list')).ensureSuccess();
        final list = Js.mapList(res.dataMap['notifications'])
            .map((m) => CrmMappers.notification(m, myUid: uid))
            .toList();
        for (final n in list) {
          final id = n.uid ?? '';
          if (id.isEmpty || _shownIds.contains(id)) continue;
          _shownIds.add(id);
          if (!_primed) continue; // first poll only records what exists
          if (n.readBy.contains(uid)) continue;
          final created = n.createdAt;
          if (created != null && DateTime.now().difference(created).inSeconds > 120) continue;

          final notification = LocalNotification(
            title: n.title.isEmpty ? 'New Notification' : n.title,
            body: n.body.isEmpty ? 'You have a new message' : n.body,
          );
          notification.onClick = () async {
            await windowManager.focus();
            await windowManager.show();
            // The PHP payload has no `type` key (it is a column of the
            // notification), so take it from the model.
            final t = n.type?.name ?? '';
            if (t == 'chat' || t == 'task' || t == 'ticket') {
              NotificationService.instance.openFromPayload({
                ...n.payload,
                'type': t,
              });
              return;
            }
            final navigator = navigatorKey.currentState;
            if (navigator == null) return;
            final isAdmin = await Spdb.isAdminLoggedIn();
            navigator.pushAndRemoveUntil(
              CupertinoPageRoute(builder: (_) => MainScreen(isAdmin: isAdmin)),
              (route) => false,
            );
          };
          notification.show();
          _playSound();
        }
        _primed = true;
      } catch (_) {}
    }

    await poll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => poll());
  }

  static void _playSound() async {
    await _player.play(AssetSource('audio/notify.mp3'), volume: 1.0);
  }

  static Future<void> sendTestNotification() async {
    try {
      LocalNotification notification = LocalNotification(
        title: "Test Notification",
        body: "This is a test notification.",
      );

      notification.onClick = () async {
        await windowManager.focus();
        await windowManager.show();

        var navigator = navigatorKey.currentState;
        if (navigator == null) return;
        bool isAdmin = await Spdb.isAdminLoggedIn();

        navigator.pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => MainScreen(isAdmin: isAdmin)),
          (route) => false,
        );
      };

      notification.show();
    } catch (e) {
      throw 'Error sending test notification: $e';
    }
  }
}