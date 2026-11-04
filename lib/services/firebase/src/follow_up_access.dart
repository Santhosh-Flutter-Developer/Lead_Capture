import '/models/models.dart';
import '/services/services.dart';

/// Follow-up assignment for Leads, Deals and Project Updations.
///
/// A record may be assigned to ONE employee ("Follow Up"). Visibility rule:
///   • no follow-up set      -> visible exactly as before (nothing changes)
///   • follow-up set         -> visible ONLY to that employee and to admins
class FollowUpAccess {
  FollowUpAccess._();

  /// Keeps only the records the logged-in user is allowed to see.
  static Future<List<T>> filterVisible<T>(
    List<T> items,
    String? Function(T item) followUpOf,
  ) async {
    if (await Spdb.isAdminLoggedIn()) return items;
    final uid = (await Spdb.getUid())?.trim() ?? '';
    return items.where((e) => _allowed(followUpOf(e), uid)).toList();
  }

  /// Same rule for a single record (e.g. a direct link / notification).
  static Future<bool> canView(String? followUp) async {
    if (await Spdb.isAdminLoggedIn()) return true;
    final uid = (await Spdb.getUid())?.trim() ?? '';
    return _allowed(followUp, uid);
  }

  static bool _allowed(String? followUp, String uid) {
    final f = followUp?.trim() ?? '';
    return f.isEmpty || f == uid;
  }

  // ── dropdown helpers ────────────────────────────────────────────────────

  /// Active employees that can be picked as follow-up.
  static Future<List<EmployeeModel>> employees() =>
      EmployeeService.getAllEmployees();

  /// uid -> label. Normally just the name; when two employees share a name
  /// the e-mail is appended so every dropdown entry stays unique.
  static Map<String, String> labelsByUid(List<EmployeeModel> employees) {
    final counts = <String, int>{};
    for (final e in employees) {
      final k = e.name.trim().toLowerCase();
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return {
      for (final e in employees)
        if ((e.uid ?? '').isNotEmpty)
          e.uid!: (counts[e.name.trim().toLowerCase()] ?? 0) > 1
              ? '${e.name} (${e.email})'
              : e.name,
    };
  }

  /// Finds an employee by name or e-mail (case-insensitive). Used by the
  /// bulk upload, where the sheet holds a name or an e-mail address.
  static EmployeeModel? findEmployee(
    List<EmployeeModel> employees,
    String text,
  ) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final e in employees) {
      if (e.email.trim().toLowerCase() == t) return e;
    }
    for (final e in employees) {
      if (e.name.trim().toLowerCase() == t) return e;
    }
    return null;
  }
}