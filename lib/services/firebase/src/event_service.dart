import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class EventService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Creates the event document. The server-side "Event Started" broadcast
  /// to ALL users is intentionally NOT scheduled from here — it is picked
  /// up by the `onEventWritten` Cloud Function trigger the moment this
  /// document lands in Firestore. That keeps the exact-time notification
  /// reliable even if the app is closed/crashes right after this call
  /// returns (see functions/index.js).
  static Future<EventModel> createEvent({
    required EventModel event,
    String? docId,
  }) async {
    try {
      var cid = await Spdb.getCid();

      final ref = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.events.name}',
        event.toMap(),
        docId: docId,
        activity: '${event.eventName} has been added as a event',
      );
      final createdEvent = event.copyWith(uid: ref.id);

      // Events are private: only the person who created it (employee or
      // admin) can see it or be notified about it — never other attendees
      // or the rest of the admin team.
      final users = NotificationRecipientService.forEvent(
        createdBy: event.createdBy,
      );

      final fcmIds = <String>[];
      for (var i in users) {
        final userFcmIds = await AuthService.getUserFcmIds(uid: i);
        if (userFcmIds.isNotEmpty) {
          fcmIds.addAll(userFcmIds);
        }
      }

      final user = await Spdb.getUser();
      await PostNotificationService.sendNotification(
        model: NotificationModel(
          collectionId: cid ?? '',
          title: 'Event : ${event.eventName}',
          body: 'New event created by ${user.name}',
          toFcms: fcmIds,
          toUids: users,
          senderId: await Spdb.getUid(),
          type: NotificationType.info,
          payload: {'eventId': ref.id},
        ),
      );

      // Personal "15 minutes before" reminder for attendees only. This is
      // separate from the "Event Started, for everyone" broadcast, which
      // the Cloud Function handles from the event document itself.
      for (var attendeeId in users) {
        var attendeeFcmIds = await AuthService.getUserFcmIds(uid: attendeeId);

        final reminderTime = event.eventDateTime.subtract(
          const Duration(minutes: 15),
        );
        if (reminderTime.isBefore(DateTime.now())) continue;

        ReminderService.createReminder(
          scheduledAt: reminderTime,
          docId: '${ref.id}_$attendeeId',
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Event Reminder',
            body: 'You have an upcoming event: ${event.eventName} at ${_formatDateTime(event.eventDateTime)}',
            toFcms: attendeeFcmIds,
            toUids: [attendeeId],
            payload: {'eventId': ref.id},
            type: NotificationType.eventReminder,
          ),
        );
      }

      return createdEvent;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating event: $e';
    }
  }

  static Future<void> editEvent({
    required String uid,
    required EventModel event,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.events.name}',
        uid,
        event.toUpdateMap(),
        activity: '${event.eventName} has been updated',
      );

      // Update reminders for all attendees. Using a deterministic doc id
      // (eventId_attendeeId) means re-saving the event overwrites the
      // existing reminder in place instead of creating a duplicate that
      // would fire twice (requirement: no duplicate notifications, and
      // edited/rescheduled events must reschedule their reminder).
      // Events are private: only the creator gets reminders for it.
      final users = NotificationRecipientService.forEvent(
        createdBy: event.createdBy,
      );

      final reminderTime = event.eventDateTime.subtract(
        const Duration(minutes: 15),
      );

      for (var attendeeId in users) {
        final reminderDocId = '${uid}_$attendeeId';

        if (reminderTime.isBefore(DateTime.now())) {
          // New time is already past the 15-min-before mark — cancel any
          // previously scheduled reminder instead of leaving a stale one.
          await ReminderService.cancelReminder(docId: reminderDocId);
          continue;
        }

        var attendeeFcmIds = await AuthService.getUserFcmIds(uid: attendeeId);

        ReminderService.createReminder(
          scheduledAt: reminderTime,
          docId: reminderDocId,
          notification: NotificationModel(
            collectionId: cid ?? '',
            title: 'Event Reminder',
            body: 'You have an upcoming event: ${event.eventName} at ${_formatDateTime(event.eventDateTime)}',
            toFcms: attendeeFcmIds,
            toUids: [attendeeId],
            payload: {'eventId': uid},
            type: NotificationType.eventReminder,
          ),
        );
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating event: $e';
    }
  }

  static Future<EventModel> getEvent({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var eventDoc = await firebase.users
          .doc(cid)
          .collection(Collections.events.name)
          .doc(uid)
          .get();

      if (eventDoc.exists) {
        var eventData = eventDoc.data();
        if (eventData != null) {
          var event = EventModel.fromMap(eventDoc.id, eventData);
          return event;
        } else {
          throw 'Event data is empty';
        }
      } else {
        throw 'Event not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating event: $e';
    }
  }

  static Future<List<EventModel>> getAllEvents() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.events.name)
          .get();

      List<EventModel> events = querySnapshot.docs.map((doc) {
        return EventModel.fromMap(doc.id, doc.data());
      }).toList();

      events.sort((a, b) => a.eventName.compareTo(b.eventName));

      return events;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching events: $e';
    }
  }

  static Future<bool> isEventAssigned(String uid) async {
    try {
      var cid = await Spdb.getCid();

      final snapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .where('event', isEqualTo: uid)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking event assignment: $e\n$st");
      return false;
    }
  }

  /// Deletes the event. The server-side `onEventWritten` Cloud Function
  /// trigger fires on this delete and marks the matching
  /// `eventStartNotifications` document `cancelled` so the "Event Started"
  /// broadcast to all users is never sent. Here we only need to clean up
  /// the per-attendee 15-minutes-before reminders, since those live in a
  /// client-writable collection.
  static Future<void> deleteEvent({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      final docRef = await firebase.users
          .doc(cid)
          .collection(Collections.events.name)
          .doc(uid)
          .get();

      final data = docRef.data() as Map<String, dynamic>;

      final attendees = <String>{
        ...(data['eventAttendes'] != null
            ? List<String>.from(data['eventAttendes'] as List)
            : <String>[]),
        if (data['createdBy'] != null &&
            (data['createdBy'] as Map)['uid'] != null)
          (data['createdBy'] as Map)['uid'] as String,
      }.where((e) => e.isNotEmpty);

      for (var attendeeId in attendees) {
        await ReminderService.cancelReminder(docId: '${uid}_$attendeeId');
      }

      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['eventName'] ?? 'N/A'} has been deleted',
        description: 'User has deleted an entry in ${Collections.events.name}',
        collection: '${Collections.users.name}/$cid/${Collections.events.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error deleting event: $e\n$st");
      throw 'Error deleting event: $e';
    }
  }
}
