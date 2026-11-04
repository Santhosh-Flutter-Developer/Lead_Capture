import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class HolidayService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<String?> createHoliday({required HolidayModel holiday}) async {
    try {
      var cid = await Spdb.getCid();
      var docRef = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.holidays.name}',
        holiday.toMap(),
        activity: '${holiday.reason} has been added as a holiday',
      );

      return docRef.id;
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error creating holiday: $e';
    }
  }

  static Future<void> updateHoliday({
    required String uid,
    required HolidayModel holiday,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.holidays.name}',
        uid,
        holiday.toUpdateMap(),
        activity: '${holiday.reason} has been updated',
      );
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      throw 'Error updating holiday: $e';
    }
  }

  static Future<HolidayModel> getHoliday({required String uid}) async {
    try {
      final cid = await Spdb.getCid();

      if (cid == null || cid.isEmpty) {
        throw 'Invalid company id';
      }

      if (uid.isEmpty) {
        throw 'Invalid holiday id';
      }

      final docRef = firebase.users
          .doc(cid)
          .collection(Collections.holidays.name)
          .doc(uid);

      final holidayDoc = await docRef.get();

      if (!holidayDoc.exists) {
        throw 'Holiday not found';
      }

      final data = holidayDoc.data();
      if (data == null) {
        throw 'Holiday data is empty';
      }

      return HolidayModel.fromMap(holidayDoc.id, data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("getHoliday error: $e\n$st");
      throw 'Error loading holiday: $e';
    }
  }

  static Future<List<HolidayModel>> getAllHolidays() async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.holidays.name)
          .get();

      debugPrint("Total Holiday Docs: ${querySnapshot.docs.length}");

      List<HolidayModel> holidays = querySnapshot.docs.map((doc) {
        return HolidayModel.fromMap(doc.id, doc.data());
      }).toList();

      // Sort by date
      holidays.sort((a, b) => a.date.compareTo(b.date));

      return holidays;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching holidays: $e';
    }
  }

  static Future<List<HolidayModel>> getHolidaysByYear(int year) async {
    try {
      var cid = await Spdb.getCid();

      var startOfYear = DateTime(year, 1, 1);
      var endOfYear = DateTime(year, 12, 31, 23, 59, 59);

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.holidays.name)
          .where('date', isGreaterThanOrEqualTo: startOfYear.millisecondsSinceEpoch)
          .where('date', isLessThanOrEqualTo: endOfYear.millisecondsSinceEpoch)
          .get();

      debugPrint("Total Holiday Docs for $year: ${querySnapshot.docs.length}");

      List<HolidayModel> holidays = querySnapshot.docs.map((doc) {
        return HolidayModel.fromMap(doc.id, doc.data());
      }).toList();

      // Sort by date
      holidays.sort((a, b) => a.date.compareTo(b.date));

      return holidays;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching holidays: $e';
    }
  }

  static Future<void> deleteHoliday({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.holidays.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();

      var reason = data['reason'] != null ? data['reason'] as String : 'Holiday';

      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '$reason has been deleted',
        description: 'User has deleted an entry in ${Collections.holidays.name}',
        collection: '${Collections.users.name}/$cid/${Collections.holidays.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting holiday: $e\n$st");
      throw 'Error deleting holiday: $e';
    }
  }

  static Future<bool> isDateTaken(DateTime date, {String? excludeId}) async {
    try {
      var cid = await Spdb.getCid();
      final dateMs = date.millisecondsSinceEpoch;

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.holidays.name)
          .where('date', isEqualTo: dateMs)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      // If excludeId is provided, check if the existing holiday is the same one
      if (excludeId != null) {
        return querySnapshot.docs.any((doc) => doc.id != excludeId);
      }

      return true;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking date: $e\n$st");
      return false;
    }
  }
}
