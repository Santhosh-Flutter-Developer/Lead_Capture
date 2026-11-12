import 'dart:async';

/// The old app relied on Firestore `.snapshots()` so lists refreshed by
/// themselves after any write. The PHP API is request/response only, so:
///  * every successful write calls [ApiLive.changed] with the data keys it
///    touched, and every watcher of those keys re-fetches immediately;
///  * a slow timer (default 30s) picks up changes made by OTHER users.
/// This is polling, not realtime – the backend has no push channel.
class ApiLive {
  ApiLive._();
  static final StreamController<String> _bus = StreamController<String>.broadcast();

  /// Notify watchers that data under [keys] changed (e.g. 'designation').
  static void changed(Object keys) {
    final list = keys is Iterable ? keys.map((e) => e.toString()) : [keys.toString()];
    for (final k in list) {
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
  static Stream<T> watch<T>(
    Set<String> keys,
    Future<T> Function() fetch, {
    Duration interval = const Duration(seconds: 30),
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
      running = true;
      try {
        do {
          again = false;
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
        if (interval > Duration.zero) timer = Timer.periodic(interval, (_) => run());
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