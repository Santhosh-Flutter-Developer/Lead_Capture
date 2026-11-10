import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Roles & permissions – backed by roles.php (no Firestore).
class RoleService {
  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e, $st');
    if (e is ApiException) throw e.message;
    throw '$prefix: $e';
  }

  static Future<String?> checkRoleNameExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      if (name.toLowerCase().trim() == RoleModel.superAdminRoleName.toLowerCase()) {
        return '${RoleModel.superAdminRoleName} is a reserved role name';
      }
      for (final role in await getAllRoles()) {
        if (excludeUid != null && role.uid == excludeUid) continue;
        if (role.name.toLowerCase().trim() == name.toLowerCase().trim()) {
          return 'Role name already exists';
        }
      }
      return null;
    } catch (e, st) {
      _fail('Error checking role name', e, st);
    }
  }

  static Future<void> createRole({required RoleModel role}) async {
    try {
      (await RolesApiService.create(
        name: role.name,
        description: role.description,
        permissions: ApiMappers.permissionsBody(role.permissions),
      )).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed('role');
    } catch (e, st) {
      _fail('Error creating role', e, st);
    }
  }

  static Future<void> editRole({
    required String uid,
    required RoleModel role,
  }) async {
    try {
      (await RolesApiService.update(
        uid: uid,
        name: role.name,
        description: role.description,
        permissions: ApiMappers.permissionsBody(role.permissions),
      )).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed('role');
    } catch (e, st) {
      _fail('Error updating role', e, st);
    }
  }

  /// Full role including its page permissions.
  static Future<RoleModel> getRole({required String uid}) async {
    try {
      final res = (await RolesApiService.get(uid)).ensureSuccess();
      return ApiMappers.role(res.dataMap);
    } catch (e, st) {
      _fail('Error getting role', e, st);
    }
  }

  /// List view (roles.php list does not include permissions; use [getRole]).
  static Future<List<RoleModel>> getAllRoles() async {
    try {
      final res = (await RolesApiService.list()).ensureSuccess();
      return res.dataList.map((e) => ApiMappers.role(Js.m(e))).toList();
    } catch (e, st) {
      _fail('Error fetching roles', e, st);
    }
  }

  static Future<String?> getRoleDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;
      final roles = (await RolesApiService.list()).ensureSuccess().dataList.map(Js.m);
      final row = roles.where((r) => Js.s(r['uid']) == uid);
      if (row.isEmpty) return null;
      final r = row.first;
      final isSuper = Js.b(r['is_super_admin']) ||
          Js.s(r['name']).toLowerCase().trim() == RoleModel.superAdminRoleName.toLowerCase();
      if (isSuper) return 'Cannot delete the ${RoleModel.superAdminRoleName} role';
      if ((Js.i(r['employee_count']) ?? 0) > 0) {
        return 'This role is already mapped to an employee. Please reassign or update that employee before deleting this role.';
      }
      return null;
    } catch (e, st) {
      ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> deleteRole({required String uid}) async {
    try {
      final blocker = await getRoleDeletionBlocker(uid);
      if (blocker != null) throw blocker;
      (await RolesApiService.delete(uid)).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed('role');
    } catch (e, st) {
      ErrorService.recordError(e, st);
      if (e is ApiException) throw e.message;
      throw e.toString();
    }
  }

  static Future<void> restoreRole(RoleModel role) async {
    final uid = role.uid;
    if (uid == null || uid.isEmpty) throw Exception('UID missing');
    try {
      (await RolesApiService.restore(uid)).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed('role');
    } catch (e, st) {
      _fail('Error restoring role', e, st);
    }
  }

  static Future<String> getRoleByNameOrCreateRole({required String name}) async {
    try {
      for (final r in await getAllRoles()) {
        if (r.name.toLowerCase() == name.toLowerCase()) return r.uid ?? '';
      }
      final res = (await RolesApiService.create(
        name: name,
        description: '',
        permissions: const [],
      )).ensureSuccess();
      ApiLookup.invalidate();
      ApiLive.changed('role');
      return Js.s(res.dataMap['uid']);
    } catch (e, st) {
      _fail('Error creating role', e, st);
    }
  }

  /// UIDs of active users whose role grants [permissionCheck] on [page];
  /// admins are always included (as before).
  static Future<List<String>> getUsersWithPermission({
    required String page,
    required bool Function(PermissionModel) permissionCheck,
  }) async {
    try {
      final roleRows = (await RolesApiService.list()).ensureSuccess().dataList.map(Js.m).toList();
      final eligibleRoleIds = <int>{};
      for (final r in roleRows) {
        final full = (await RolesApiService.get(Js.s(r['uid']))).ensureSuccess();
        final role = ApiMappers.role(full.dataMap);
        final p = role.permissions.firstWhere(
          (p) => p.page.toLowerCase() == page.toLowerCase(),
          orElse: () => PermissionModel(page: page),
        );
        if (permissionCheck(p)) {
          final id = Js.i(r['id']);
          if (id != null) eligibleRoleIds.add(id);
        }
      }
      final users = (await EmployeesApiService.list()).ensureSuccess().dataList.map(Js.m);
      final ids = <String>{};
      for (final u in users) {
        final isAdmin = ApiMappers.isAdminRow(u);
        final active = Js.b(u['is_active'], true);
        if (isAdmin || (active && eligibleRoleIds.contains(Js.i(u['role_id'])))) {
          ids.add(Js.s(u['uid']));
        }
      }
      return ids.toList();
    } catch (e, st) {
      ErrorService.recordError(e, st);
      debugPrint('Error getting users with permission: $e\n$st');
      return [];
    }
  }
}
