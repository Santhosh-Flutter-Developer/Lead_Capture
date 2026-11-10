import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/models/src/download_model.dart';
import 'spdb.dart';

/// Download history is a purely local log (the PHP API has none). Kept per
/// user in SharedPreferences, newest first, max 200 entries.
class DownloadHistoryStore {
  static const _max = 200;
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String _key(String uid) => 'download_history_$uid';

  static Future<void> add(DownloadHistoryModel m) async {
    final sp = await SharedPreferences.getInstance();
    final key = _key(m.userId);
    final raw = sp.getString(key);
    final list = raw == null
        ? <dynamic>[]
        : (jsonDecode(raw) as List);
    list.insert(0, m.toMap());
    await sp.setString(key, jsonEncode(list.take(_max).toList()));
    changes.value++;
  }

  static Future<List<DownloadHistoryModel>> load() async {
    final uid = await Spdb.getUid() ?? '';
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uid));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => DownloadHistoryModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
