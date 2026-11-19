// ─────────────────────────────────────────────────────────────────────────────
// notification_service.dart
// CHANGED:
//   • Added `initializeForWeb()` method — requests browser notification
//     permission and obtains the FCM web token (VAPID key required).
//   • Wrapped `dart:io` File usage inside `!kIsWeb` guard.
//   • `getToken()` now guards the APNS call with `!kIsWeb`.
//   • `_requestPermission()` iOS-specific code guarded with `!kIsWeb`.
//   • `_downloadAndMakeCircular()` uses `getTemporaryDirectory()` only on
//     non-web; on web returns null immediately (no local filesystem).
//   • Everything else (Firestore streams, chat handler, etc.) unchanged.
//
// HOW TO GET YOUR VAPID KEY:
//   Firebase Console → Project Settings → Cloud Messaging → Web Push certs
//   → Generate Key Pair → copy the key string into kVapidKey below.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:iconsax/iconsax.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:leadcapture/firebase_options.dart';
import 'package:leadcapture/views/screens/calendar/form/event_view.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart' hide timeago;
import '/views/views.dart';
import '/app/app.dart';

// Only import dart:io + path_provider on non-web platforms.
// On web these packages either don't exist or have no filesystem access.
import 'notification_service_io.dart'
    if (dart.library.html) 'notification_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VAPID key — replace with your actual key from Firebase Console.
// ─────────────────────────────────────────────────────────────────────────────
const String kVapidKey =
    'BElo9iyDmRacZr_hHvqLsXhMjCdn4mE8t6XZve1RD6DlU8g5NUTV1Xl8UiiMXkRmBDklec0WQ8KxPfTAFNSBw5o';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.setupFlutterNotifications();
    await NotificationService.instance.showNotification(message);
  } catch (e, st) {
    await ErrorService.recordError(e, st);
  }
}

/// `true` only if the push is meant for the user who is logged in on this
/// device RIGHT NOW. Drops pushes when nobody is logged in (after logout) or
/// when the logged-in user is not one of the intended recipients (leftover
/// token of a previous account).
Future<bool> _isForCurrentUser(Map<String, dynamic> data) async {
  try {
    final uid = (await Spdb.getUidFresh())?.trim();
    if (uid == null || uid.isEmpty) return false; // logged out
    final raw = (data['toUids'] ?? '').toString();
    if (raw.isEmpty) return true; // older payload without recipients
    return raw.split(',').map((e) => e.trim()).contains(uid);
  } catch (_) {
    return true; // never lose a notification because of a check failure
  }
}

/// One notification can reach the app three ways: FCM, WebSocket and the
/// fallback poll. All share FirestoreNotificationListener.claim(uid), so it is
/// shown once. Messages built by showFromApi carry `lc_local` (already claimed).
bool _alreadyShown(Map<String, dynamic> data) {
  if ((data['lc_local'] ?? '').toString() == '1') return false;
  final id = (data['notification_uid'] ?? data['uid'] ?? '').toString();
  if (id.isEmpty) return false;
  return !FirestoreNotificationListener.claim(id);
}

/// Returns the FCM token for the current device/browser.
Future<String> getToken() async {
  try {
    if (!kIsWeb) {
      // APNS token required on iOS before FCM token is available
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
    }
    // On web, pass the VAPID key to identify the push subscription.
    String? fcm = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? kVapidKey : null,
    );
    return fcm ?? '';
  } catch (e, st) {
    debugPrint('❌ FCM getToken error: $e');
    await ErrorService.recordError(e, st);
    return '';
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  // ── Push token -> PHP API ─────────────────────────────────────────────────
  StreamSubscription<String>? _tokenRefreshSub;

  /// Token last registered on the server. Logout removes THIS one (FCM may
  /// hand out a different token later, which would leave the registered row
  /// behind and keep pushing to a logged-out device).
  final Set<String> registeredTokens = {};

  String get _deviceType {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'desktop';
    }
  }

  /// Sends this device's FCM token to notifications.php (register_fcm_token)
  /// so the server can push task / ticket / chat notifications to it. Safe to
  /// call repeatedly (server upserts); does nothing when logged out or on
  /// platforms without FCM. Never throws.
  Future<void> syncTokenToServer() async {
    try {
      final supportsFcm = kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      if (!supportsFcm) return;
      if (!await SessionManager.hasToken()) return; // logged out
      final token = await getToken();
      if (token.isEmpty) return;
      (await NotificationsApiService.registerFcmToken(
        token: token,
        deviceType: _deviceType,
      )).ensureSuccess();
      registeredTokens.add(token);
      debugPrint('🔔 [NOTIF] FCM token registered with server ($_deviceType)');
      // Keep the server copy fresh when FCM rotates the token.
      _tokenRefreshSub ??= _messaging.onTokenRefresh.listen(
        (_) => syncTokenToServer(),
      );
    } catch (e, st) {
      debugPrint('❌ [NOTIF] token sync failed: $e');
      await ErrorService.recordError(e, st);
    }
  }

  /// Step-by-step push check (shown from the Notifications page). Tells which
  /// link is broken: permission -> FCM token -> registered on server ->
  /// server FCM config -> FCM send (test_push).
  Future<String> pushDiagnostics() async {
    final out = StringBuffer();
    final supports = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    out.writeln('Platform: $_deviceType');
    if (!supports) {
      out.writeln('This platform has no FCM push (uses WebSocket / local '
          'notifications only).');
      return out.toString();
    }
    try {
      final s = await _messaging.getNotificationSettings();
      out.writeln('1. Permission: ${s.authorizationStatus.name}');
    } catch (e) {
      out.writeln('1. Permission: error $e');
    }
    String token = '';
    try {
      token = await getToken();
    } catch (_) {}
    out.writeln(token.isEmpty
        ? '2. FCM token: NONE (browser/app could not get a token - check '
            'permission, VAPID key, service worker)'
        : '2. FCM token: OK (${token.substring(0, 12)}...)');
    if (token.isEmpty) return out.toString();
    try {
      final r = await NotificationsApiService.registerFcmToken(
          token: token, deviceType: _deviceType);
      out.writeln('3. Register on server: ${r.status ? 'OK' : 'FAILED - ${r.message}'}');
    } catch (e) {
      out.writeln('3. Register on server: ERROR $e');
    }
    try {
      final r = await NotificationsApiService.call('config');
      final d = r.dataMap;
      out.writeln('4. Server config: fcm_enabled=${d['fcm_enabled']}, '
          'service_account=${d['fcm_service_account']}, '
          'project=${d['fcm_project_id']}');
    } catch (e) {
      out.writeln('4. Server config: ERROR $e');
    }
    try {
      final r = await NotificationsApiService.call('test_push');
      final d = r.dataMap;
      out.writeln('5. test_push: sent=${d['sent']}, failed=${d['failed']}, '
          'tokens_found=${d['tokens_found']}, error=${d['error'] ?? d['skipped'] ?? '-'}');
      if ((Js.i(d['sent']) ?? 0) > 0) {
        out.writeln('=> Server sent it. Switch to another tab/app now: the '
            'system notification should appear. If it does not, the problem is '
            'the browser/OS (site notification permission, Focus Assist, '
            'service worker).');
      } else if ((Js.i(d['tokens_found']) ?? 1) == 0) {
        out.writeln('=> Server has NO token for you (register failed).');
      } else {
        out.writeln('=> FCM rejected it. API team: check PHP error_log for '
            '"[FCM REJECTED]" / "[FCM WARNING]".');
      }
    } catch (e) {
      out.writeln('5. test_push: ERROR $e');
    }
    return out.toString();
  }

  // ── Web initialisation ────────────────────────────────────────────────────
  /// Call this on web instead of initalize().
  /// Requests browser notification permission and sets up message handlers.
  Future<void> initializeForWeb() async {
    // Set up notification-click handling FIRST, independent of permission /
    // token requests below (they can fail or stall, e.g. blocked permission).
    try {
      // Tab already open: the service worker tells it which chat was clicked.
      listenForNotificationClicks((data) => _handleBackgroundMessage(data));
      diagnoseServiceWorker(); // prints SW status to the console (no await)

      // Notification click on web opens the app as /?notifType=chat&chatId=..
      final q = Uri.base.queryParameters;
      debugPrint('🔔 [NOTIF] web init, url params=$q');
      if (q['notifType'] == 'chat' && (q['chatId'] ?? '').isNotEmpty) {
        _handleBackgroundMessage({'type': 'chat', 'chatId': q['chatId']});
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }

    try {
      // Request permission — shows browser permission prompt
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Get web push token (requires VAPID key)
      final token = await _messaging.getToken(vapidKey: kVapidKey);
      debugPrint('🌐 Web FCM token: $token');
      syncTokenToServer(); // register with the PHP API (no-op if logged out)

      // Listen for foreground messages on web
      FirebaseMessaging.onMessage.listen(_handleWebForegroundMessage);

      // Handle notification tap when app was in background / closed
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleBackgroundMessage(message.data);
      });

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage.data);
      }
    } catch (e, st) {
      debugPrint('❌ FCM initializeForWeb error: $e');
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _handleWebForegroundMessage(RemoteMessage message) async {
    // Not for the user logged in here -> ignore.
    if (!await _isForCurrentUser(message.data)) return;
    if (_alreadyShown(message.data)) return; // WebSocket / poll showed it

    // On web, flutter_local_notifications is not available.
    // Show an in-app snackbar/dialog instead.
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'You have a new message';

    // Small top-edge toast (auto hides) instead of the old bottom SnackBar.
    final type = message.data['type'];
    final bool openable = const [
      'chat',
      'eventStarted',
      'eventReminder',
      'task',
      'ticket',
    ].contains(type);

    InAppToast.show(
      ctx,
      overlay: navigatorKey.currentState?.overlay,
      title: title.toString(),
      body: body.toString(),
      icon: type == 'chat'
          ? Iconsax.message
          : (type == 'eventStarted' || type == 'eventReminder')
              ? Iconsax.calendar_1
              : type == 'task'
                  ? Iconsax.task_square
                  : type == 'ticket'
                      ? Iconsax.ticket
                      : Iconsax.notification_bing,
      // Tapping the toast goes to the exact chat / event.
      onTap: openable ? () => _handleBackgroundMessage(message.data) : null,
    );
  }

  // ── Mobile initialisation (unchanged) ────────────────────────────────────
  Future<void> initalize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await _requestPermission();
      await setupFlutterNotifications();
      await _setupMessageHandlers();
      await _checkLaunchedFromNotification();
      syncTokenToServer(); // register with the PHP API (no-op if logged out)
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // iOS-specific — not needed on web
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> setupFlutterNotifications() async {
    // flutter_local_notifications does not support web
    if (kIsWeb) return;

    try {
      if (_isFlutterLocalNotificationsInitialized) return;

      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important notifications',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);

      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      final darwinNotificationCategories = [
        DarwinNotificationCategory(
          'REPLY_CATEGORY',
          actions: [
            DarwinNotificationAction.text(
              'REPLY_ACTION_KEY',
              'Reply',
              buttonTitle: 'Send',
              placeholder: 'Type your reply...',
            ),
          ],
        ),
      ];

      final initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: darwinNotificationCategories,
      );

      final initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) async {
          if (details.actionId == 'REPLY_ACTION_KEY') {
            final reply = details.input;
            final payload = convertPayload(details.payload ?? '{}');
            await _replyMessage(payload, reply ?? '');
          } else {
            _handleBackgroundMessage(convertPayload(details.payload ?? '{}'));
          }
        },
      );

      _isFlutterLocalNotificationsInitialized = true;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  final Map<String, List<Message>> _messageHistory = {};

  /// Shows a notification that came from the PHP API (WebSocket event or the
  /// notifications.php poll) with the SAME display path the FCM push used:
  /// web -> in-app toast, Android / iOS -> local notification.
  /// Desktop is handled by FirestoreNotificationListener.
  Future<void> showFromApi(NotificationModel n) async {
    final data = <String, dynamic>{
      for (final e in n.payload.entries) e.key: '${e.value}',
      'type': n.type?.name ?? 'info',
      'title': n.title,
      'body': n.body,
      'notification_uid': n.uid ?? '',
      'lc_local': '1', // already claimed by RealtimeService
    };
    final message = RemoteMessage(
      messageId: n.uid,
      data: data,
      notification: RemoteNotification(title: n.title, body: n.body),
    );
    if (kIsWeb) {
      await _handleWebForegroundMessage(message);
    } else {
      await showNotification(message);
    }
  }

  Future<void> showNotification(RemoteMessage message) async {
    // On web, showNotification is handled by the service worker (SW).
    // Foreground messages are handled by _handleWebForegroundMessage().
    if (kIsWeb) return;

    // Covers foreground + background (Android/iOS): only show the push if it
    // is for the user who is logged in on this device.
    if (!await _isForCurrentUser(message.data)) {
      debugPrint('🔕 [NOTIF] dropped: not for the logged-in user');
      return;
    }
    if (_alreadyShown(message.data)) return; // WebSocket / poll showed it

    try {
      final notification = message.notification;
      final data = _normalizePushData(message.data);
      debugPrint('🔔 [NOTIF] showNotification called, data=$data');
      final type = data['type'];
      final chatId = data['chatId'];
      final bool isGroupChat = data['isGroupChat'] == 'true';
      final String chatTitle = (data['chatTitle'] ?? '').toString().trim();
      String rawBody =
          (notification?.body ?? data['body'] ?? 'New message').toString();

      // Pushes are data-only, so `notification` is null and the old
      // `notification?.title ?? 'Unknown'` always fell through to 'Unknown'.
      // Resolve the real sender name from the payload instead.
      String senderName = (data['senderName'] ?? '').toString().trim();
      if (senderName.isEmpty && isGroupChat) {
        // Older payloads: group body is "<sender>: <message>".
        final idx = rawBody.indexOf(': ');
        if (idx > 0) senderName = rawBody.substring(0, idx).trim();
      }
      if (senderName.isEmpty && !isGroupChat) {
        senderName =
            (notification?.title ?? data['title'] ?? '').toString().trim();
      }
      if (senderName.isEmpty) senderName = chatTitle;
      if (senderName.isEmpty) senderName = 'New message';

      // Sender name is shown separately by MessagingStyle, so drop the
      // "<sender>: " prefix that group bodies carry.
      String messageText = rawBody;
      final prefix = '$senderName: ';
      if (isGroupChat && messageText.startsWith(prefix)) {
        messageText = messageText.substring(prefix.length);
      }

      if (type == 'chat' && chatId != null) {
        try {
          await _showChatNotification(
            data: data,
            chatId: chatId.toString(),
            senderName: senderName,
            messageText: messageText,
            chatTitle: chatTitle,
            isGroupChat: isGroupChat,
          );
        } catch (e, st) {
          // Never lose the notification: fall back to a plain one.
          debugPrint('❌ [NOTIF] chat style failed: $e\n$st');
          await ErrorService.recordError(e, st);
          await _localNotifications.show(
            chatId.hashCode,
            chatTitle.isNotEmpty ? chatTitle : senderName,
            isGroupChat ? '$senderName: $messageText' : messageText,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'chat_channel',
                'Chat Messages',
                channelDescription: 'All chat messages',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                categoryIdentifier: 'REPLY_CATEGORY',
              ),
            ),
            payload: json.encode({...data, 'isReply': 'true'}),
          );
        }
        return;
      }

      await _localNotifications.show(
        message.hashCode,
        notification?.title ?? data['title'] ?? 'Notification',
        notification?.body ?? data['body'] ?? 'You have a new message',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'General Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: json.encode(data),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _showChatNotification({
    required Map<String, dynamic> data,
    required String chatId,
    required String senderName,
    required String messageText,
    required String chatTitle,
    required bool isGroupChat,
  }) async {
    String? avatarPath = await downloadAvatarCircular(
      data['senderImageUrl'],
      'sender_$chatId',
    );

    final groupKey = 'chat_$chatId';
    final bool isUserReply = data['isReply'] == 'true';

    final me = Person(name: 'You');
    final senderPerson = Person(
      name: isUserReply ? 'You' : senderName,
      icon: avatarPath != null
          ? BitmapFilePathAndroidIcon(avatarPath)
          : null,
    );

    final newMessage = Message(messageText, DateTime.now(), senderPerson);
    _messageHistory.putIfAbsent(groupKey, () => []);
    _messageHistory[groupKey]!.add(newMessage);

    final style = MessagingStyleInformation(
      me,
      messages: _messageHistory[groupKey] ?? [],
      conversationTitle: chatTitle.isNotEmpty ? chatTitle : null,
      groupConversation: isGroupChat,
    );

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_channel',
        'Chat Messages',
        channelDescription: 'All chat messages',
        styleInformation: style,
        importance: Importance.max,
        priority: Priority.high,
        groupKey: groupKey,
        onlyAlertOnce: true,
        actions: [
          const AndroidNotificationAction(
            'REPLY_ACTION_KEY',
            'Quick Reply',
            showsUserInterface: true,
            allowGeneratedReplies: true,
            inputs: [
              AndroidNotificationActionInput(label: 'Type reply...'),
            ],
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'REPLY_CATEGORY',
      ),
    );

    await _localNotifications.show(
      groupKey.hashCode,
      null,
      null,
      notificationDetails,
      payload: json.encode({...data, 'isReply': 'true'}),
    );
    debugPrint('🔔 [NOTIF] chat notification shown for $groupKey');
  }

  Future<void> _replyMessage(
    Map<String, dynamic> message,
    String typedDataFromInput,
  ) async {
    try {
      ChatService.sendChatMessage(
        chatId: message["chatId"],
        message: typedDataFromInput,
      );
      showNotification(
        RemoteMessage(
          data: {
            "type": "chat",
            "chatId": message["chatId"],
            "chatTitle": message["chatTitle"],
            "isGroupChat": message["isGroupChat"] ?? "false",
            "isReply": "true",
          },
          notification: RemoteNotification(
            title: "You",
            body: typedDataFromInput,
          ),
        ),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _setupMessageHandlers() async {
    try {
      FirebaseMessaging.onMessage.listen(showNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleBackgroundMessage(message.data);
      });
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage.data);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // ── Notification tap routing ──────────────────────────────────────────────
  // A tap can arrive before the UI exists (app was killed / in recents), so
  // the payload is parked here and opened once the app reports it is ready.
  Map<String, dynamic>? _pendingPayload;
  bool _appReady = false;

  /// Android/iOS: if the app was cold-started by tapping a local notification,
  /// onDidReceiveNotificationResponse is NOT called, so read the launch payload.
  Future<void> _checkLaunchedFromNotification() async {
    try {
      final details = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final response = details!.notificationResponse;
        if (response?.actionId == 'REPLY_ACTION_KEY') return;
        final payload = convertPayload(response?.payload ?? '{}');
        if (payload.isNotEmpty) _pendingPayload = payload;
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// Called by the app once the main screen is on screen.
  void markAppReady() {
    _appReady = true;
    final pending = _pendingPayload;
    if (pending == null) return;
    _pendingPayload = null;
    _openFromPayload(pending, resetStack: false);
  }

  /// Public entry for platforms with their own click handlers (Windows).
  /// Opens immediately (no ready-gate): the app is already running.
  void openFromPayload(Map<String, dynamic> payload) {
    debugPrint('🔔 [NOTIF] openFromPayload $payload');
    if (navigatorKey.currentState == null) {
      _pendingPayload = payload;
      return;
    }
    _openFromPayload(payload);
  }

  void _handleBackgroundMessage(Map<String, dynamic> rawMessage) {
    final message = _normalizePushData(rawMessage);
    debugPrint('🔔 [NOTIF] open requested: $message');
    // The app is already running for every runtime tap (banner "Open",
    // notification click, onMessageOpenedApp), so open straight away. Only
    // park the payload when there is no navigator yet (cold start). It used
    // to also wait for _appReady, which stays false after a fresh login
    // (login navigates itself), so those taps were silently dropped.
    if (navigatorKey.currentState == null) {
      _pendingPayload = message;
      return;
    }
    _openFromPayload(message);
  }

  Future<void> _openFromPayload(
    Map<String, dynamic> message, {
    bool resetStack = true,
  }) async {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      final uid = await Spdb.getUid();
      debugPrint(
        '🔔 [NOTIF] _openFromPayload type=${message['type']} '
        'chatId=${message['chatId']} uid=$uid',
      );
      if (uid == null || uid.isEmpty) return; // not logged in

      // Wide layouts (Windows / web / tablets) show chats inside the sidebar
      // shell, not as a pushed screen, so open MainScreen on the Chats menu
      // with this chat pre-selected. Mirrors MainScreen's own breakpoint.
      final ctx = navigatorKey.currentContext;
      final double width = ctx != null ? MediaQuery.of(ctx).size.width : 0;
      final bool wideLayout = !kIsMobile && width >= 1000;
      debugPrint('🔔 [NOTIF] width=$width wideLayout=$wideLayout');
      if (message['type'] == 'chat' && wideLayout) {
        final chatId = (message['chatId'] ?? '').toString();
        if (chatId.isEmpty) return;
        final isAdmin = await Spdb.isAdminLoggedIn();
        navigator.pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (_) => MainScreen(
              isAdmin: isAdmin,
              selectedMenu: 'Chats',
              selectedChatUid: chatId,
            ),
          ),
          (route) => false,
        );
        return;
      }

      if (resetStack) {
        bool isAdmin = await Spdb.isAdminLoggedIn();
        navigator.pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => MainScreen(isAdmin: isAdmin)),
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (message['type'] == 'chat') {
        final chatId = (message['chatId'] ?? '').toString();
        ChatModel? chatModel;

        try {
          final raw = message['chat'];
          if (raw is String && raw.isNotEmpty) {
            final map = json.decode(raw) as Map<String, dynamic>;
            chatModel = ChatModel.fromMap(
              chatId.isNotEmpty ? chatId : (map['uid'] ?? '').toString(),
              map,
            );
          }
        } catch (_) {
          chatModel = null;
        }
        if (chatModel == null && chatId.isNotEmpty) {
          chatModel = await ChatService.getChat(uid: chatId);
        }
        if (chatModel == null) return;

        // The OTHER participant (this was '' before, which opened the
        // "Saved messages" style header instead of the sender's chat).
        final opponentUid = chatModel.participants.firstWhere(
          (id) => id != uid,
          orElse: () => '',
        );

        navigator.push(
          CupertinoPageRoute(
            builder: (context) => ChatMessages(
              chat: chatModel!,
              currentUser: uid,
              opponentUid: opponentUid,
              onOpenChat: null,
            ),
          ),
        );
        return;
      }

      await _openOtherNotification(message, navigator);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> _openOtherNotification(
    Map<String, dynamic> message,
    NavigatorState navigator,
  ) async {
    // Task push (create / update / status change): open that task.
    if (message['type'] == 'task') {
      final taskId = _payloadValue(message, 'taskId');
      if (taskId.isNotEmpty) {
        navigator.push(
          CupertinoPageRoute(builder: (context) => TaskView(uid: taskId)),
        );
      }
      return;
    }

    // Ticket push (create / update / status change): open that ticket.
    if (message['type'] == 'ticket') {
      final ticketId = _payloadValue(message, 'ticketId');
      if (ticketId.isNotEmpty) {
        navigator.push(
          CupertinoPageRoute(builder: (context) => TicketView(uid: ticketId)),
        );
      }
      return;
    }

    if (message['type'] == 'eventStarted' ||
        message['type'] == 'eventReminder') {
      final eventId = message['eventId'];
      if (eventId != null && eventId.toString().isNotEmpty) {
        try {
          final event = await EventService.getEvent(uid: eventId.toString());
          navigator.push(
            CupertinoPageRoute(
              builder: (context) => EventViewPage(event: event),
            ),
          );
        } catch (e, st) {
          await ErrorService.recordError(e, st);
        }
      }
      return;
    }

    await showDialog(
      context: navigator.context,
      builder: (context) =>
          ConfirmDialog(content: message.toString(), title: "Notification"),
    );
  }

  /// The PHP server's push `data` differs a little from the old Cloud
  /// Function payload (chat: `chat_uid` / `is_group` / `group_name` /
  /// `sender_name`, and fields may sit inside a JSON `payload`). Flattens it
  /// into the keys the handlers below expect (`chatId`, `isGroupChat`,
  /// `chatTitle`, `senderName`).
  Map<String, dynamic> _normalizePushData(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    try {
      var p = raw['payload'];
      if (p is String && p.isNotEmpty) p = json.decode(p);
      if (p is Map) {
        p.forEach((k, v) => out.putIfAbsent(k.toString(), () => v));
      }
    } catch (_) {}
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = out[k];
        if (v != null && v.toString().isNotEmpty && v.toString() != 'null') {
          return v.toString();
        }
      }
      return '';
    }

    if (pick(['chatId']).isEmpty) {
      final c = pick(['chatUid', 'chat_uid']);
      if (c.isNotEmpty) out['chatId'] = c;
    }
    if (out['isGroupChat'] == null) {
      final g = out['is_group'];
      out['isGroupChat'] =
          (g == 1 || g == true || g == '1' || g == 'true') ? 'true' : 'false';
    }
    if (pick(['chatTitle']).isEmpty) {
      final t = pick(['group_name']);
      if (t.isNotEmpty) out['chatTitle'] = t;
    }
    if (pick(['senderName']).isEmpty) {
      final n = pick(['sender_name']);
      if (n.isNotEmpty) out['senderName'] = n;
    }
    return out;
  }

  /// Reads [key] from a push `data` map. The PHP server may send it flat
  /// (`taskId`) or inside a JSON `payload` field, so both are checked.
  String _payloadValue(Map<String, dynamic> data, String key) {
    final direct = data[key];
    if (direct != null && direct.toString().isNotEmpty) return direct.toString();
    try {
      var p = data['payload'];
      if (p is String && p.isNotEmpty) p = json.decode(p);
      if (p is Map && p[key] != null) return p[key].toString();
    } catch (_) {}
    return '';
  }

  Map<String, dynamic> convertPayload(String payload) {
    try {
      return json.decode(payload);
    } catch (_) {
      return {};
    }
  }

  Future<void> clearAvatarCache() async {
    if (kIsWeb) return; // No local cache on web
    await clearAvatarCacheNative();
  }
}

// ─── notifications.php helpers (platform-agnostic) ───────────────────────────

Future<void> deleteNotification(String uid) async {
  try {
    (await NotificationsApiService.call('delete', {'uid': uid})).ensureSuccess();
    ApiLive.changed('notifications');
  } catch (e, st) {
    await ErrorService.recordError(e, st);
    throw e.toString();
  }
}

Future<void> restoreNotification(NotificationModel item) async {
  try {
    (await NotificationsApiService.call('restore', {'uid': item.uid})).ensureSuccess();
    ApiLive.changed('notifications');
  } catch (e, st) {
    await ErrorService.recordError(e, st);
  }
}

/// Unread count for the logged-in user (notifications.php `unread_count`),
/// refreshed after every change and polled every 30 s.
Stream<int> getNotificationCount() {
  return ApiLive.watch<int>({'notifications'}, () async {
    final res = (await NotificationsApiService.call('list')).ensureSuccess();
    return Js.i(res.dataMap['unread_count']) ?? 0;
  });
}

/// Marks notifications as read (notifications.php mark_read, per id).
Future<void> markNotificationsAsRead(List<String> notificationIds) async {
  if (notificationIds.isEmpty) return;
  try {
    for (final id in notificationIds) {
      await NotificationsApiService.call('mark_read', {'uid': id});
    }
    ApiLive.changed('notifications');
  } catch (e, st) {
    await ErrorService.recordError(e, st);
  }
}