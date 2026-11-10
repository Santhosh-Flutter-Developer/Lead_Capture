import 'package:flutter/material.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Calendar events – backed by calendar.php (no Firestore). The server has no
/// per-event "completed" flag and does not mirror lead/deal activities.
class EventService {
  static Never _fail(Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e\n$st');
    if (e is ApiException) throw e.message;
    throw e.toString();
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _body(EventModel e) => {
    'title': e.eventName,
    'description': e.eventDescription,
    'start_date_time': _fmt(e.eventDateTime),
    'end_date_time': _fmt(e.eventEndDateTime),
    'repeat_type': e.eventRepeatType.name,
    'assignees': e.eventAttendes,
  };

  static Future<EventModel> createEvent({required EventModel event, String? docId}) async {
    try {
      final res = (await CalendarApiService.call('create', _body(event))).ensureSuccess();
      ApiLive.changed('calendar');
      return event.copyWith(uid: Js.s(res.dataMap['uid']));
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<void> editEvent({required String uid, required EventModel event}) async {
    try {
      (await CalendarApiService.call('update', {'uid': uid, ..._body(event)})).ensureSuccess();
      ApiLive.changed('calendar');
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<EventModel> getEvent({required String uid}) async {
    try {
      final res = (await CalendarApiService.call('get', {'uid': uid})).ensureSuccess();
      return CrmMappers.event(res.dataMap);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<EventModel>> getAllEvents() async {
    try {
      final res = (await CalendarApiService.call('list')).ensureSuccess();
      return Js.mapList(res.dataMap['events']).map(CrmMappers.event).toList();
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<bool> isEventAssigned(String uid) async => false;

  static Future<void> deleteEvent({required String uid}) async {
    try {
      (await CalendarApiService.call('delete', {'uid': uid})).ensureSuccess();
      ApiLive.changed('calendar');
    } catch (e, st) {
      _fail(e, st);
    }
  }
}
