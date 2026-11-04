import 'package:flutter_window_close/flutter_window_close.dart';

/// Registers the Windows "should close?" handler.
void setupWindowClose(Future<bool?> Function() handler) {
  FlutterWindowClose.setWindowShouldCloseHandler(() async {
    return await handler() ?? false;
  });
}
