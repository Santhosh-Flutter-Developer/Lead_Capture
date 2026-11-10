import '/models/models.dart';

/// Reminders were scheduled by a Firebase Cloud Function. The PHP API has no
/// reminder endpoint (server creates its own notifications), so these are
/// no-ops kept for existing callers.
class ReminderService {
  static Future<void> createReminder({
    required DateTime scheduledAt,
    required NotificationModel notification,
    String? docId,
  }) async {}

  static Future<void> cancelReminder({required String docId}) async {}
}
