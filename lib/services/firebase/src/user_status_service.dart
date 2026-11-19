import 'dart:async';
import '/models/models.dart';
import '/services/api/api.dart';

/// Presence. The API has no endpoint to set online/offline (the server keeps
/// `is_online` / `last_active` itself), so set* are no-ops. Status is read from
/// chats.php `user_profile`, polled every 60 s.
class UserStatusService {
  static Future<void> setOnline(String uid) async {}
  static Future<void> setOffline(String uid) async {}

  // ONE shared stream per user. The screens call streamStatus() inside a
  // StreamBuilder's build(); returning a new stream on every rebuild made each
  // rebuild re-subscribe and fire a fresh user_profile request (dozens per
  // second -> HTTP 429 from the server's rate limit).
  static final Map<String, Stream<UserStatusModel?>> _streams = {};

  static Stream<UserStatusModel?> streamStatus(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _streams.putIfAbsent(uid, () => _create(uid));
  }

  /// Forget cached streams (call on logout).
  static void reset() => _streams.clear();

  static Stream<UserStatusModel?> _create(String uid) {
    return ApiLive.watch<UserStatusModel?>(
      {'status:$uid'},
      () async {
        final res = (await ChatsApiService.call('user_profile', {'uid': uid})).ensureSuccess();
        final d = res.dataMap;
        return UserStatusModel(
          isOnline: Js.b(d['is_online']),
          lastSeen: Js.dt(d['last_active']),
        );
      },
      interval: const Duration(seconds: 60),
      slowWithSocket: false, // presence is not pushed over the socket
    );
  }
}