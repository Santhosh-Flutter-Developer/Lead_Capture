import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/services.dart';
import '/utils/utils.dart' show DeviceInfo;

/// Error log. Errors used to be written to a Firestore `errors` collection;
/// the PHP API has no such endpoint, so they are printed and kept in a small
/// on-device ring buffer (last [_max]) that the Developer > App errors screen
/// reads.
class ErrorService {
  static const _key = 'app_error_log';
  static const _max = 100;
  static bool _busy = false;

  static Future<void> recordError(Object? e, StackTrace st) async {
    debugPrint('ERROR: $e\n$st');
    if (_busy) return; // never loop on our own failures
    _busy = true;
    try {
      final cid = await Spdb.getCid();
      if (cid == null || cid.isEmpty) return;
      Map<String, dynamic> device = {};
      try {
        device = (await DeviceInfo.getDeviceInfo(forDebug: true)).toMatchMap();
      } catch (_) {}
      final sp = await SharedPreferences.getInstance();
      final list = _decode(sp.getString(_key));
      list.insert(0, {
        'cid': cid,
        'uid': await Spdb.getUid(),
        'error': e.toString(),
        'stackTrace': st.toString(),
        'device': device.map((k, v) => MapEntry(k.toString(), v?.toString())),
        'time': DateTime.now().millisecondsSinceEpoch,
      });
      await sp.setString(_key, jsonEncode(list.take(_max).toList()));
    } catch (error) {
      debugPrint('Failed to store error: $error');
    } finally {
      _busy = false;
    }
  }

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Newest first.
  static Future<List<Map<String, dynamic>>> recent() async {
    final sp = await SharedPreferences.getInstance();
    return _decode(sp.getString(_key));
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
