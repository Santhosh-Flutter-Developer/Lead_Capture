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
    'event_type': e.eventType.name,
    'color': _hex(e.accentColor),
    'all_day': e.allDay ? 1 : 0,
  };

  static String _hex(int c) =>
      '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int _parseColor(dynamic v) {
    final s = Js.s(v).trim().replaceAll('#', '');
    if (s.isEmpty) return EventModel.defaultAccent;
    final n = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
    return n ?? EventModel.defaultAccent;
  }

  /// calendar.php row -> [EventModel] including event type / colour / all-day.
  static EventModel _fromApi(Map<String, dynamic> m) {
    return CrmMappers.event(m).copyWith(
      eventType: EventTypeX.fromName(Js.s(m['event_type'])),
      accentColor: _parseColor(m['color']),
      allDay: Js.b(m['all_day']),
    );
  }

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
      return _fromApi(res.dataMap);
    } catch (e, st) {
      _fail(e, st);
    }
  }

  static Future<List<EventModel>> getAllEvents() async {
    try {
      final res = (await CalendarApiService.call('list')).ensureSuccess();
      return Js.mapList(res.dataMap['events']).map(_fromApi).toList();
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