import 'dart:async';

import 'session_manager.dart';

/// The old app relied on Firestore `.snapshots()` so lists refreshed by
/// themselves after any write. The PHP API is request/response only, so:
///  * every successful write calls [ApiLive.changed] with the data keys it
///    touched, and every watcher of those keys re-fetches immediately;
///  * a slow timer (default 30s) picks up changes made by OTHER users.
/// This is polling, not realtime – the backend has no push channel.
class ApiLive {
  ApiLive._();
  static final StreamController<String> _bus = StreamController<String>.broadcast();

  static final Map<String, int> _stamps = {};
  static final Map<String, _CacheEntry> _cache = {};

  /// Short-lived cache for rarely-changing lookups (lead / deal status ...)
  /// that several watchers read in the same polling cycle. Concurrent calls
  /// share one request (the Future itself is cached), and any
  /// [changed] of [key] (a write) drops it. Keyed per session token so a
  /// different login never sees another user's data.
  static Future<T> cached<T>(
    String key,
    Future<T> Function() fetch, {
    Duration ttl = const Duration(minutes: 2),
  }) async {
    final ck = '$key|${await SessionManager.getToken() ?? ''}';
    final stamp = _stamps[key] ?? 0;
    final e = _cache[ck];
    if (e != null &&
        e.stamp == stamp &&
        DateTime.now().difference(e.at) < ttl) {
      return e.future as Future<T>;
    }
    final f = fetch();
    _cache[ck] = _CacheEntry(f, DateTime.now(), stamp);
    f.catchError((_) {
      if (identical(_cache[ck]?.future, f)) _cache.remove(ck);
      return f;
    });
    return f;
  }

  /// Notify watchers that data under [keys] changed (e.g. 'designation').
  static void changed(Object keys) {
    final list = keys is Iterable ? keys.map((e) => e.toString()) : [keys.toString()];
    for (final k in list) {
      _stamps[k] = (_stamps[k] ?? 0) + 1;
      _bus.add(k);
    }
  }

  /// A constant stream that can be listened to any number of times (plain
  /// `Stream.value` is single-subscription and throws "Bad state: Stream has
  /// already been listened to" when a screen rebuilds and listens again).
  static Stream<T> value<T>(T v) => Stream<T>.multi((c) {
        c.add(v);
        c.close();
      }, isBroadcast: true);

  /// Emits [fetch]() now, again on every [changed] of one of [keys], and
  /// every [interval]. Errors are forwarded to the stream (so BLoC onError
  /// still works); polling continues after an error.
  /// Set by RealtimeService: true while the WebSocket is connected. The
  /// server then pushes changes (-> [changed]), so the timer only runs as a
  /// slow safety net instead of every [interval].
  static bool Function() socketConnected = () => false;
  static const _socketSlowFactor = 6; // 30 s -> every 3 min

  static Stream<T> watch<T>(
    Set<String> keys,
    Future<T> Function() fetch, {
    Duration interval = const Duration(seconds: 30),
    bool slowWithSocket = true,
  }) {
    late StreamController<T> ctrl;
    T? last;
    var hasLast = false;
    StreamSubscription<String>? sub;
    Timer? timer;
    var running = false;
    var again = false;

    Future<void> run() async {
      if (ctrl.isClosed) return;
      if (running) {
        again = true;
        return;
      }
      // Logged out (token cleared): stop polling instead of hammering the API
      // with 401s.
      running = true;
      try {
        do {
          again = false;
          if (!await SessionManager.hasToken()) break;
          try {
            final v = await fetch();
            if (!ctrl.isClosed) {
              last = v;
              hasLast = true;
              ctrl.add(v);
            }
          } catch (e, st) {
            if (!ctrl.isClosed) ctrl.addError(e, st);
          }
        } while (again && !ctrl.isClosed);
      } finally {
        running = false;
      }
    }

    // Broadcast + replay of the latest value: a screen can rebuild and listen
    // to the same stream again (a plain stream throws "Bad state: Stream has
    // already been listened to") and must still get the current data at once.
    ctrl = StreamController<T>.broadcast(
      onListen: () {
        run();
        sub = _bus.stream.where(keys.contains).listen((_) => run());
        if (interval > Duration.zero) {
          var tick = 0;
          timer = Timer.periodic(interval, (_) {
            tick++;
            if (slowWithSocket && socketConnected() && tick % _socketSlowFactor != 0) return;
            run();
          });
        }
      },
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return Stream<T>.multi((c) {
      if (hasLast) c.add(last as T);
      final s = ctrl.stream.listen(c.add, onError: c.addError, onDone: c.close);
      c.onCancel = s.cancel;
    }, isBroadcast: true);
  }
}

class _CacheEntry {
  _CacheEntry(this.future, this.at, this.stamp);
  final Future<dynamic> future;
  final DateTime at;
  final int stamp;
}