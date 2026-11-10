import 'dart:async';
import '/models/models.dart';
import '/services/api/api.dart';

/// Presence. The API has no endpoint to set online/offline (the server keeps
/// `is_online` / `last_active` itself), so set* are no-ops. Status is read from
/// chats.php `user_profile`, polled every 60 s.
class UserStatusService {
  static Future<void> setOnline(String uid) async {}
  static Future<void> setOffline(String uid) async {}

  static Stream<UserStatusModel?> streamStatus(String uid) {
    if (uid.isEmpty) return const Stream.empty();
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
    );
  }
}
