import '/models/models.dart';

/// Notifications are created and pushed by the PHP server as a side effect of
/// each action (leads.php, tasks.php, …), so the app no longer sends them.
/// (The old implementation signed FCM requests with a service-account key
/// embedded in the app; that has been removed – rotate that key.)
class PostNotificationService {
  static Future<void> sendNotification({required NotificationModel model}) async {}
}
