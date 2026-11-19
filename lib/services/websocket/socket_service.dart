// ==============================================================================
// LeadCapture CRM - Real-time WebSocket Service (Flutter Mobile & Desktop)
// ==============================================================================
//
// Prerequisites:
// Add to your `pubspec.yaml`:
// dependencies:
//   socket_io_client: ^3.0.0
//
// Usage:
// 1. In your app startup (or right after user logs in):
//    CrmSocketService.instance.init(
//      serverUrl: 'http://YOUR_SERVER_IP_OR_DOMAIN:8085',
//      userUid: currentUser.uid,
//      companyId: currentUser.companyId,
//      userName: currentUser.name,
//    );
//
// 2. Listen to incoming events:
//    CrmSocketService.instance.onNotification.listen((data) {
//       // Show in-app banner or update notification count
//    });
//
//    CrmSocketService.instance.onChatMessage.listen((data) {
//       // Append new message to chat screen
//    });
// ==============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class CrmSocketService {
  CrmSocketService._internal();
  static final CrmSocketService instance = CrmSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Gateway unreachable (not deployed / blocked): do not hammer it every few
  // seconds. After [_maxFailures] errors stop, then try again every
  // [_retryAfter]. The app keeps working through its polling fallback.
  static const _maxFailures = 3;
  static const _retryAfter = Duration(minutes: 2);
  int _failures = 0;
  Timer? _retryTimer;
  Map<String, dynamic>? _lastArgs;

  bool get isConnected => _isConnected;

  // Stream controllers for app-wide reactive state management
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _moduleUpdateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotification => _notificationController.stream;
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onModuleUpdate => _moduleUpdateController.stream;

  /// Initialize and connect to the Node.js WebSocket Gateway
  void init({
    required String serverUrl,
    required String userUid,
    int companyId = 1,
    String userName = 'User',
  }) {
    _lastArgs = {
      'serverUrl': serverUrl,
      'userUid': userUid,
      'companyId': companyId,
      'userName': userName,
    };
    _retryTimer?.cancel();
    if (_socket != null && _isConnected) {
      debugPrint('[CrmSocketService] Already connected.');
      return;
    }

    try {
      debugPrint('[CrmSocketService] Connecting to $serverUrl for user $userUid ($userName)...');

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setQuery({
              'user_uid': userUid,
              'company_id': companyId.toString(),
              'name': userName,
            })
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .build(),
      );

      _socket?.onConnect((_) {
        _isConnected = true;
        _failures = 0;
        debugPrint('[CrmSocketService] Connected successfully to WebSocket Server!');
      });

      _socket?.onDisconnect((reason) {
        _isConnected = false;
        debugPrint('[CrmSocketService] Disconnected from WebSocket: $reason');
      });

      _socket?.onConnectError((err) {
        _isConnected = false;
        _failures++;
        if (_failures == 1) {
          debugPrint('[CrmSocketService] Connection error: $err');
        }
        if (_failures >= _maxFailures) {
          debugPrint('[CrmSocketService] Gateway unreachable, pausing '
              '${_retryAfter.inMinutes} min (polling fallback is active).');
          try {
            _socket?.dispose();
          } catch (_) {}
          _socket = null;
          final a = _lastArgs;
          _failures = 0;
          _retryTimer?.cancel();
          if (a != null) {
            _retryTimer = Timer(_retryAfter, () => init(
                  serverUrl: a['serverUrl'] as String,
                  userUid: a['userUid'] as String,
                  companyId: a['companyId'] as int,
                  userName: a['userName'] as String,
                ));
          }
        }
      });

      // 1. Notification Event
      _socket?.on('notification', (data) {
        debugPrint('[CrmSocketService] Incoming Notification: $data');
        if (data is Map) {
          _notificationController.add(Map<String, dynamic>.from(data));
        }
      });

      // 2. Chat Message Event
      _socket?.on('chat_message', (data) {
        debugPrint('[CrmSocketService] Incoming Chat Message: $data');
        if (data is Map) {
          _chatMessageController.add(Map<String, dynamic>.from(data));
        }
      });

      // 3. Module Update Events
      for (final event in ['lead_updated', 'deal_updated', 'task_updated', 'ticket_updated']) {
        _socket?.on(event, (data) {
          debugPrint('[CrmSocketService] Module Update ($event): $data');
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            map['_module_event'] = event;
            _moduleUpdateController.add(map);
          }
        });
      }
    } catch (e, st) {
      debugPrint('[CrmSocketService] Exception initializing socket: $e\n$st');
    }
  }

  /// Disconnect socket (e.g. on user logout)
  void disconnect() {
    _retryTimer?.cancel();
    _lastArgs = null;
    _failures = 0;
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;
      debugPrint('[CrmSocketService] Disconnected and disposed.');
    } catch (e) {
      debugPrint('[CrmSocketService] Error disconnecting: $e');
    }
  }
}