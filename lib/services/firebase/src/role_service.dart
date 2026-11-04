import 'package:flutter/material.dart';
import '/utils/utils.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';

class RoleService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<String?> checkRoleNameExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .get();

      if (name.toLowerCase().trim() ==
          RoleModel.superAdminRoleName.toLowerCase()) {
        return '${RoleModel.superAdminRoleName} is a reserved role name';
      }

      for (var doc in querySnapshot.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;
        final role = RoleModel.fromMap(doc.id, doc.data());
        if (role.name.toLowerCase().trim() == name.toLowerCase().trim()) {
          return 'Role name already exists';
        }
      }
      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint('${e.toString()}, ${st.toString()}');
      throw 'Error checking role name: $e';
    }
  }

  static Future<void> createRole({required RoleModel role}) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.roles.name}',
        role.toMap(),
        activity: '${role.name} has been added as a role',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating role: $e';
    }
  }


  static Future<void> editRole({
    required String uid,
    required RoleModel role,
  }) async {
    try {
      final existing = await getRole(uid: uid);
      if (existing.isSuperAdmin) {
        throw 'Cannot edit the ${RoleModel.superAdminRoleName} role';
      }

      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.roles.name}',
        uid,
        role.toUpdateMap(),
        activity: '${role.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating role: $e';
    }
  }

  static Future<RoleModel> getRole({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var roleDoc = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .doc(uid)
          .get();

      if (roleDoc.exists) {
        var roleData = roleDoc.data();
        if (roleData != null) {
          var role = RoleModel.fromMap(roleDoc.id, roleData);
          return role;
        } else {
          throw 'Role data is empty';
        }
      } else {
        throw 'Role not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error getting role: $e';
    }
  }

  static Future<List<RoleModel>> getAllRoles() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .get();

      List<RoleModel> roles = querySnapshot.docs.map((doc) {
        return RoleModel.fromMap(doc.id, doc.data());
      }).toList();

      return roles;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching roles: $e';
    }
  }

  /// Returns a user-facing message if this role cannot be deleted
  /// (reserved role, or currently mapped to one or more employees),
  /// or null if it is safe to delete. Call this before showing a
  /// delete confirmation so the user only sees "are you sure?" when
  /// the delete can actually succeed.
  static Future<String?> getRoleDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;

      final role = await getRole(uid: uid);
      if (role.isSuperAdmin) {
        return 'Cannot delete the ${RoleModel.superAdminRoleName} role';
      }

      var cid = await Spdb.getCid();
      var employeeAssignedDocs = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .where('role', isEqualTo: uid)
          .limit(1)
          .get();

      if (employeeAssignedDocs.docs.isNotEmpty) {
        return 'This role is already mapped to an employee. Please reassign or update that employee before deleting this role.';
      }

      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return null;
    }
  }

  static Future<void> deleteRole({required String uid}) async {
    try {
      final blocker = await getRoleDeletionBlocker(uid);
      if (blocker != null) {
        throw blocker;
      }

      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .doc(uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );
      docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['name'].toString().decrypt} has been deleted',
        description: 'User has deleted an entry in ${Collections.roles.name}',
        collection: '${Collections.users.name}/$cid/${Collections.roles.name}',
        docId: docRef.id,
      );
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
        activityLogModel.toMap(),
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<void> restoreRole(RoleModel role) async {
  var cid = await Spdb.getCid();

  final uid = role.uid;
  if (uid == null || uid.isEmpty) {
    throw Exception("UID missing");
  }

  await firebase.users
      .doc(cid)
      .collection(Collections.roles.name)
      .doc(uid)
      .set(role.toMap());
}

  static Future<String> getRoleByNameOrCreateRole({
    required String name,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .get();

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data['name'].toString().decrypt.toLowerCase() ==
            name.toLowerCase()) {
          return doc.id;
        }
      }

      var role = RoleModel(
        name: name,
        description: '',
        createdBy: await Spdb.getUser(),
      );
      var newDoc = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .add(role.toMap());

      return newDoc.id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<List<String>> getUsersWithPermission({
    required String page,
    required bool Function(PermissionModel) permissionCheck,
  }) async {
    try {
      var cid = await Spdb.getCid();
      Set<String> userIds = {};

      // Get all roles
      var rolesSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.roles.name)
          .get();

      // Filter roles that have the required permission
      List<String> eligibleRoleIds = [];
      for (var roleDoc in rolesSnapshot.docs) {
        var role = RoleModel.fromMap(roleDoc.id, roleDoc.data());
        var permission = role.permissions.firstWhere(
          (p) => p.page.toLowerCase() == page.toLowerCase(),
          orElse: () => PermissionModel(page: page),
        );
        if (permissionCheck(permission)) {
          eligibleRoleIds.add(roleDoc.id);
        }
      }

      // Get all employees with eligible roles
      if (eligibleRoleIds.isNotEmpty) {
        var employeesSnapshot = await firebase.users
            .doc(cid)
            .collection(Collections.employees.name)
            .where('isActive', isEqualTo: true)
            .get();

        for (var empDoc in employeesSnapshot.docs) {
          var empData = empDoc.data();
          var empRole = empData['role'] as String?;
          if (empRole != null && eligibleRoleIds.contains(empRole)) {
            userIds.add(empDoc.id);
          }
        }
      }

      // Also include all admins (they typically have all permissions)
      var adminsSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.admins.name)
          .get();

      for (var adminDoc in adminsSnapshot.docs) {
        userIds.add(adminDoc.id);
      }

      return userIds.toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error getting users with permission: $e\n$st");
      return [];
    }
  }
}
