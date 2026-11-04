import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Centralizes the "who should see / be notified about this record" rule
/// used by the calendar page and by the creation notifications for
/// tasks, leads, deals, tickets and events:
///
///  • Task / Lead / Deal / Ticket:
///      - created by an employee  -> that employee + every admin
///      - created by an admin     -> every admin only
///  • Event:
///      - always only the person who created it (employee or admin)
class NotificationRecipientService {
  /// Recipients for a task / lead / deal / ticket, based on who created it.
  static Future<List<String>> forRecord({
    required UserDataModel createdBy,
  }) async {
    final admins = await AdminService.getAllAdmins();
    final adminUids = admins
        .map((a) => a.uid ?? '')
        .where((uid) => uid.isNotEmpty)
        .toSet();

    if (createdBy.userType == UserType.admin) {
      return adminUids.toList();
    }

    return {
      ...adminUids,
      if (createdBy.uid.isNotEmpty) createdBy.uid,
    }.toList();
  }

  /// Recipients for an event — only its creator, admin or employee alike.
  static List<String> forEvent({required UserDataModel createdBy}) {
    return createdBy.uid.isNotEmpty ? [createdBy.uid] : [];
  }
}
