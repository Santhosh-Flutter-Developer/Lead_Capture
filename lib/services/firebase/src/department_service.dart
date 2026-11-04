import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class DepartmentService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<void> createDepartment({
    required DepartmentModel department,
  }) async {
    try {
      var cid = await Spdb.getCid();
      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.departments.name}',
        department.toMap(),
        activity: '${department.name} has been added as a department',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating department: $e';
    }
  }

  static Future<void> editDepartment({
    required String uid,
    required DepartmentModel department,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.departments.name}',
        uid,
        department.toUpdateMap(),
        activity: '${department.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating department: $e';
    }
  }

  static Future<DepartmentModel> getDepartment({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var departmentDoc = await firebase.users
          .doc(cid)
          .collection(Collections.departments.name)
          .doc(uid)
          .get();

      if (departmentDoc.exists) {
        var departmentData = departmentDoc.data();
        if (departmentData != null) {
          var department = DepartmentModel.fromMap(
            departmentDoc.id,
            departmentData,
          );
          return department;
        } else {
          throw 'Department data is empty';
        }
      } else {
        throw 'Department not found';
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating department: $e';
    }
  }

  static Future<List<DepartmentModel>> getAllDepartments() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.departments.name)
          .get();

      List<DepartmentModel> departments = querySnapshot.docs.map((doc) {
        return DepartmentModel.fromMap(doc.id, doc.data());
      }).toList();

      return departments;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching departments: $e';
    }
  }

  /// Returns a user-facing message if this department cannot be
  /// deleted (currently mapped to one or more sub departments or
  /// employees), or null if it is safe to delete. Call this before
  /// showing a delete confirmation so the user only sees
  /// "are you sure?" when the delete can actually succeed.
  static Future<String?> getDepartmentDeletionBlocker(String uid) async {
    try {
      if (uid.isEmpty) return null;

      var cid = await Spdb.getCid();

      var subDepartmentAssignedDocs = await firebase.users
          .doc(cid)
          .collection(Collections.subDepartments.name)
          .where('department', isEqualTo: uid)
          .limit(1)
          .get();

      if (subDepartmentAssignedDocs.docs.isNotEmpty) {
        return 'This department has a sub department mapped to it. Please reassign or delete the sub department before deleting this department.';
      }

      // employee.department is stored as a list of department ids,
      // so this must use arrayContains rather than isEqualTo.
      var employeeAssignedDocs = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .where('department', arrayContains: uid)
          .limit(1)
          .get();

      if (employeeAssignedDocs.docs.isNotEmpty) {
        return 'This department is already mapped to an employee. Please reassign or update that employee before deleting this department.';
      }

      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return null;
    }
  }

  static Future<void> deleteDepartment({required String uid}) async {
    try {
      final blocker = await getDepartmentDeletionBlocker(uid);
      if (blocker != null) {
        throw blocker;
      }

      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.departments.name)
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
        description:
            'User has deleted an entry in ${Collections.departments.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.departments.name}',
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

  static Future<void> restoreDepartment(DepartmentModel department) async {
    var cid = await Spdb.getCid();

    final uid = department.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.departments.name)
        .doc(uid)
        .set(department.toMap());
  }

  static Future<String> getDepartmentByNameOrCreateDepartment({
    required String name,
  }) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.departments.name)
          .get();

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data['name'].toString().decrypt.toLowerCase() ==
            name.toLowerCase()) {
          return doc.id;
        }
      }

      var department = DepartmentModel(
        name: name,
        description: '',
        createdBy: await Spdb.getUser(),
      );
      var newDoc = await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.departments.name}',
        department.toMap(),
        activity: '${department.name} has been added as a department',
      );
      return newDoc.id;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<String?> checkDepartmentExists({
    required String name,
    String? excludeUid,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.departments.name)
          .get();

      for (var doc in querySnapshot.docs) {
        if (excludeUid != null && doc.id == excludeUid) continue;
        
        var data = doc.data();
        if (data['name'] != null && 
            data['name'].toString().decrypt.trim().toLowerCase() ==
                name.trim().toLowerCase()) {
          return 'Department name already exists';
        }
      }
      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      return 'Error checking department existence: $e';
    }
  }
}
