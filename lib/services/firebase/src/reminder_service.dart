import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';
import '/services/services.dart';

class ReminderService {
  /// Creates (or, when [docId] is given, overwrites) a reminder document in
  /// the top-level `reminders` collection that `reminderScheduler` (Cloud
  /// Function, functions/index.js) polls every minute.
  ///
  /// Pass a deterministic [docId] (e.g. `'${eventId}_$attendeeId'`) for
  /// reminders tied to an editable entity like an event, so that re-saving
  /// the entity updates the existing reminder instead of creating a
  /// duplicate that would fire twice.
  static Future<void> createReminder({
    required DateTime scheduledAt,
    required NotificationModel notification,
    String? docId,
  }) async {
    ReminderModel reminderModel = ReminderModel(
      notification: notification,
      scheduledAt: scheduledAt,
      isSent: false,
      createdAt: DateTime.now(),
      createdBy: await Spdb.getUser(),
    );
    var firestore = FirebaseFirestore.instance;
    if (docId != null && docId.isNotEmpty) {
      await firestore.collection('reminders').doc(docId).set(
        reminderModel.toMap(),
      );
    } else {
      await firestore.collection('reminders').add(reminderModel.toMap());
    }
  }

  /// Cancels a previously-scheduled reminder so it will not fire. Safe to
  /// call even if the reminder was already sent or never existed.
  static Future<void> cancelReminder({required String docId}) async {
    var firestore = FirebaseFirestore.instance;
    await firestore.collection('reminders').doc(docId).delete();
  }
}
