import 'package:flutter/cupertino.dart';

class Navigate {
  static void route(BuildContext context, Widget widget) {
    Navigator.push(context, CupertinoPageRoute(builder: (context) {
      return widget;
    }));
  }

  /// Same as [route] but returns the value the pushed page pops with, so the
  /// caller can refresh itself when the page closes.
  static Future<T?> routeForResult<T>(BuildContext context, Widget widget) {
    return Navigator.push<T>(
      context,
      CupertinoPageRoute<T>(builder: (context) => widget),
    );
  }

  static void routeReplace(BuildContext context, Widget widget) {
    Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) {
      return widget;
    }));
  }
}