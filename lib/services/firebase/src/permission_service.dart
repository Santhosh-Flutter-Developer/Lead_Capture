import 'package:shared_preferences/shared_preferences.dart';
import '/models/models.dart';
import '/services/services.dart';

class PermissionService {
  static const _createKey = 'perm_create';
  static const _editKey = 'perm_edit';
  static const _deleteKey = 'perm_delete';
  static const _viewKey = 'perm_view';
  static const _exportKey = 'perm_export';
  static const _importKey = 'perm_import';

  /// Save Permissions
  static Future<void> savePermissions(List<PermissionModel> permissions) async {
    final prefs = await SharedPreferences.getInstance();

    for (var i in permissions) {
      await prefs.setBool('${_createKey}_${i.page}', i.canCreate);
      await prefs.setBool('${_editKey}_${i.page}', i.canEdit);
      await prefs.setBool('${_deleteKey}_${i.page}', i.canDelete);
      await prefs.setBool('${_viewKey}_${i.page}', i.canView);
      await prefs.setBool('${_exportKey}_${i.page}', i.canExport);
      await prefs.setBool('${_importKey}_${i.page}', i.canImport);
    }
  }

  /// Returns permissions for [page], always pulled fresh from the
  /// employee's current role in Firestore so that changes an admin makes
  /// to a role show up immediately (next time this page is opened) instead
  /// of waiting for the user to log out and back in, or hit manual sync.
  ///
  /// Falls back to the last synced values cached in SharedPreferences if
  /// the live fetch fails (e.g. offline).
  static Future<PermissionModel?> getPermissions(String page) async {
    var isAdmin = await Spdb.isAdminLoggedIn();
    if (isAdmin) {
      return PermissionModel(
        page: page,
        canCreate: true,
        canDelete: true,
        canEdit: true,
        canView: true,
        canExport: true,
        canImport: true,
      );
    }

    try {
      final employee = await Spdb.getEmployee();
      if (employee != null && employee.role.isNotEmpty) {
        final role = await RoleService.getRole(uid: employee.role);

        // Keep the local cache in sync so the offline fallback below
        // (and anything else still reading the cache) stays fresh too.
        await savePermissions(role.permissions);

        final match = role.permissions.where((p) => p.page == page);
        if (match.isEmpty) return null;

        // Return the role's permission entry for this page exactly as
        // configured — including one where every flag is false, which
        // means the admin explicitly revoked all access. Collapsing
        // that case to null would make it indistinguishable from "this
        // role doesn't mention this page at all", and callers that
        // default-allow on null (e.g. Dashboard widgets) would then
        // wrongly show content the admin just turned off.
        return match.first;
      }
    } catch (_) {
      // Live fetch failed (e.g. offline) — fall back to cached values below.
    }

    return _getCachedPermissions(page);
  }

  static Future<PermissionModel?> _getCachedPermissions(String page) async {
    final prefs = await SharedPreferences.getInstance();

    // If the page was never synced to this device at all, there's truly
    // nothing cached for it — return null so callers can apply their own
    // fallback. Once it *has* been synced, trust the cached flags as-is,
    // even if every one of them is false (an explicit "no access").
    if (!prefs.containsKey('${_viewKey}_$page')) {
      return null;
    }

    final canCreate = prefs.getBool('${_createKey}_$page') ?? false;
    final canEdit = prefs.getBool('${_editKey}_$page') ?? false;
    final canDelete = prefs.getBool('${_deleteKey}_$page') ?? false;
    final canView = prefs.getBool('${_viewKey}_$page') ?? false;
    final canExport = prefs.getBool('${_exportKey}_$page') ?? false;
    final canImport = prefs.getBool('${_importKey}_$page') ?? false;

    return PermissionModel(
      page: page,
      canCreate: canCreate,
      canDelete: canDelete,
      canEdit: canEdit,
      canView: canView,
      canExport: canExport,
      canImport: canImport,
    );
  }
}
