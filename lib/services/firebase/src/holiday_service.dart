import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/api/api.dart';
import '/services/services.dart';

/// Holidays via masters.php (type `holiday`: name + date). The server has no
/// "days" field, so every holiday is a single day.
class HolidayService {
  static const _type = 'holiday';
  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static HolidayModel _map(Map<String, dynamic> m) {
    final date = Js.dt(m['date']) ?? DateTime.now();
    return HolidayModel(
      uid: Js.s(m['uid']),
      date: DateTime(date.year, date.month, date.day),
      reason: Js.s(m['name']),
      days: 1,
      createdAt: Js.dt(m['created_at']),
      updatedAt: Js.dt(m['updated_at'] ?? m['created_at']),
      createdBy: UserDataModel(
        uid: Js.s(m['created_by']),
        name: Js.s(m['created_by_name']),
        profilePic: ApiConfig.resolveFileUrl(Js.opt(m['created_by_photo'])),
        userType: UserType.employee,
      ),
    );
  }

  static Future<String?> createHoliday({required HolidayModel holiday}) async {
    try {
      final res = (await MastersApiService.create(_type, {
        'name': holiday.reason,
        'date': _ymd(holiday.date),
      }))
          .ensureSuccess();
      ApiLive.changed({'holiday'});
      return Js.opt(res.dataMap['uid']);
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      throw 'Error creating holiday: ${_msg(e)}';
    }
  }

  static Future<void> updateHoliday({
    required String uid,
    required HolidayModel holiday,
  }) async {
    try {
      (await MastersApiService.update(_type, uid, {
        'name': holiday.reason,
        'date': _ymd(holiday.date),
      }))
          .ensureSuccess();
      ApiLive.changed({'holiday'});
    } catch (e, st) {
      debugPrint("$e, $st");
      await ErrorService.recordError(e, st);
      throw 'Error updating holiday: ${_msg(e)}';
    }
  }

  static Future<HolidayModel> getHoliday({required String uid}) async {
    final all = await getAllHolidays();
    for (final h in all) {
      if (h.uid == uid) return h;
    }
    throw 'Error loading holiday: Holiday not found';
  }

  static Future<List<HolidayModel>> getAllHolidays() async {
    try {
      final res = (await MastersApiService.list(_type)).ensureSuccess();
      final list = Js.mapList(res.data).map(_map).toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error fetching holidays: ${_msg(e)}';
    }
  }

  static Future<List<HolidayModel>> getHolidaysByYear(int year) async {
    final all = await getAllHolidays();
    return all.where((h) => h.date.year == year).toList();
  }

  static Future<void> deleteHoliday({required String uid}) async {
    try {
      (await MastersApiService.delete(_type, uid)).ensureSuccess();
      ApiLive.changed({'holiday'});
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      throw 'Error deleting holiday: ${_msg(e)}';
    }
  }

  static Future<bool> isDateTaken(DateTime date, {String? excludeId}) async {
    final all = await getAllHolidays();
    return all.any((h) =>
        h.uid != excludeId &&
        h.date.year == date.year &&
        h.date.month == date.month &&
        h.date.day == date.day);
  }
}
