import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/utils/utils.dart';

/// Connects the socket.io gateway after login and turns its events into UI
/// refreshes / desktop notifications. Mobile and web already get the system
/// notification from FCM, so there the socket only refreshes the badge and
/// lists (no duplicate banner). Desktop shows the notification instantly
/// (the 20 s poller stays as a fallback and shares the dedupe set).
class RealtimeService {
  RealtimeService._();

  static StreamSubscription? _nSub;
  static StreamSubscription? _mSub;
  static StreamSubscription? _cSub;
  static Timer? _debounce;
  static final Set<String> _pending = {};

  static Future<void> start() async {
    if (!ApiConfig.wsEnabled) return;
    try {
      await stop();
      final uid = (await Spdb.getUid())?.trim() ?? '';
      if (uid.isEmpty) return;
      final cid = int.tryParse((await Spdb.getCid()) ?? '') ?? 1;
      final user = await Spdb.getUser();

      final s = CrmSocketService.instance;
      ApiLive.socketConnected = () => s.isConnected;
      s.init(
        serverUrl: ApiConfig.wsUrl,
        userUid: uid,
        companyId: cid,
        userName: user.name.isEmpty ? 'User' : user.name,
      );

      // Chat messages pushed by the server: refresh the open chat and the
      // chat list AT ONCE. Without this the socket being connected slowed the
      // chat polling down (30 s / 90 s), so group messages looked "missing".
      _cSub = s.onChatMessage.listen((data) {
        final chatUid = Js.s(data['chat_uid']);
        ChatService.addSocketMessage(data);
        ApiLive.changed({'chats', if (chatUid.isNotEmpty) 'chat:$chatUid'});
      });

      _nSub = s.onNotification.listen((data) async {
        // Only notifications addressed to THIS user in THIS company.
        final rec = Js.s(data['recipient_uid']).trim();
        if (rec.isNotEmpty && rec != 'all' && rec != uid) return;
        final dc = Js.s(data['company_id']).trim();
        if (dc.isNotEmpty && dc != cid.toString()) return;
        _touch({'notifications'});
        if (Js.s(data['type']).toLowerCase() == 'chat') {
          var raw = data['payload'];
          if (raw is String && raw.trim().startsWith('{')) {
            try {
              raw = jsonDecode(raw);
            } catch (_) {}
          }
          final p = Js.m(raw);
          final chatUid = Js.s(p['chatId'] ?? p['chat_uid'] ?? p['chatUid']);
          ApiLive.changed({'chats', if (chatUid.isNotEmpty) 'chat:$chatUid'});
        }
        final type = Js.s(data['type']).toLowerCase();
        final ref = Js.s(Js.m(data['payload'])['uid'] ?? data['task_uid'] ?? data['ticket_uid']);
        if (type == 'task' && ref.isNotEmpty) _touch({'tasks', 'task_$ref'});
        if (type == 'ticket' && ref.isNotEmpty) _touch({'tickets', 'ticket_$ref'});
        try {
          if (kIsDesktop) {
            await FirestoreNotificationListener.showFromSocket(data);
          } else {
            await _showOnDevice(data);
          }
        } catch (e) {
          debugPrint('[Realtime] show failed: $e');
        }
      });
      if (!kIsDesktop) _startFallbackPoll(uid);

      _mSub = s.onModuleUpdate.listen((data) {
        final uid = Js.s(data['uid']);
        switch (Js.s(data['_module_event'])) {
          case 'lead_updated':
            _touch({'leads', if (uid.isNotEmpty) 'lead_$uid'});
          case 'deal_updated':
            _touch({'deals', if (uid.isNotEmpty) 'deal_$uid'});
          case 'task_updated':
            _touch({'tasks', if (uid.isNotEmpty) 'task_$uid'});
          case 'ticket_updated':
            _touch({'tickets', if (uid.isNotEmpty) 'ticket_$uid'});
        }
      });
    } catch (e, st) {
      ErrorService.recordError(e, st);
    }
  }

  // ── Android / iOS / web display ─────────────────────────────────────────
  // The PHP API never sends FCM by itself, so while the app is open the
  // notification is shown from the WebSocket event, or (if the socket is not
  // connected) from a 20 s poll of notifications.php. Both share the dedupe
  // set with the desktop listener, so one notification is never shown twice.
  static Timer? _poll;
  static bool _primed = false;

  /// Android / iOS / web: while the app is NOT in the foreground the server's
  /// FCM push (it carries a `notification` block) is shown by the system. A
  /// second local notification from the socket / poll would be a duplicate.
  static bool get _inForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<void> _showOnDevice(Map<String, dynamic> data) async {
    if (!_inForeground) return; // FCM system notification covers it
    final me = (await Spdb.getUid())?.trim() ?? '';
    final n = CrmMappers.notification(data, myUid: me);
    if (!FirestoreNotificationListener.claim(n.uid ?? '')) return;
    await NotificationService.instance.showFromApi(n);
  }

  static void _startFallbackPoll(String uid) {
    _poll?.cancel();
    _primed = false;
    Future<void> poll() async {
      try {
        if (CrmSocketService.instance.isConnected && _primed) return;
        if (((await Spdb.getUid())?.trim() ?? '') != uid) return;
        final res = (await NotificationsApiService.call('list')).ensureSuccess();
        final list = Js.mapList(res.dataMap['notifications'])
            .map((m) => CrmMappers.notification(m, myUid: uid))
            .toList();
        for (final n in list) {
          final id = n.uid ?? '';
          if (id.isEmpty) continue;
          if (!FirestoreNotificationListener.claim(id)) continue;
          if (!_primed) continue; // first poll only records what exists
          if (!_inForeground) continue; // FCM system notification covers it
          if (n.readBy.contains(uid)) continue;
          final c = n.createdAt;
          if (c != null && DateTime.now().difference(c).inSeconds > 120) continue;
          await NotificationService.instance.showFromApi(n);
        }
        _primed = true;
        _touch({'notifications'});
      } catch (_) {}
    }

    poll();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => poll());
  }

  /// Coalesces bursts of events into one refresh.
  static void _touch(Set<String> keys) {
    _pending.addAll(keys);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final k = Set<String>.from(_pending);
      _pending.clear();
      ApiLive.changed(k);
    });
  }

  static Future<void> stop() async {
    ApiLive.socketConnected = () => false;
    await _nSub?.cancel();
    await _mSub?.cancel();
    await _cSub?.cancel();
    _nSub = _mSub = _cSub = null;
    _debounce?.cancel();
    _poll?.cancel();
    _poll = null;
    _primed = false;
    _pending.clear();
    CrmSocketService.instance.disconnect();
  }
}