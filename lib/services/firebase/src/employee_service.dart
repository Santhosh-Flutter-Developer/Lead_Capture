import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';

class EmployeeService {
  static final FirebaseConfig firebase = FirebaseConfig();

  static Future<String> generateEmployeeId() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .get();

      int maxId = 0;
      final idRegExp = RegExp(r'\d+');

      for (var doc in querySnapshot.docs) {
        var empData = doc.data();
        var empIdStr = empData['employeeId']?.toString() ?? '';
        var match = idRegExp.firstMatch(empIdStr);
        if (match != null) {
          var idVal = int.tryParse(match.group(0) ?? '');
          if (idVal != null && idVal > maxId) {
            maxId = idVal;
          }
        }
      }

      int nextId = maxId + 1;
      return 'EMP${nextId.toString().padLeft(3, '0')}';
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error generating next employee ID: $e");
      return 'EMP001';
    }
  }

  /// Checks a candidate employee record for duplicates.
  ///
  /// employeeId (e.g. "EMP001") is a per-company numbering scheme, so it
  /// is only checked against the current company.
  ///
  /// Email and mobile number, on the other hand, must map to exactly one
  /// user for the whole app: they are checked against every employee AND
  /// every admin, in every company - not just the current one - since
  /// either account type can log in with that email (see
  /// AuthService.checkLogin, which already looks across all companies).
  static Future<String?> checkEmployeeExists({
    required String employeeId,
    required String email,
    required String mobileNumber,
    String? excludeUid,
  }) async {
    try {
      var lowerCaseEmployeeId = employeeId.toLowerCase();
      var cid = await Spdb.getCid();

      var collection = firebase.users
          .doc(cid)
          .collection(Collections.employees.name);

      var idQuery = collection.where(
        'lowercaseEmployeeId',
        isEqualTo: lowerCaseEmployeeId,
      );
      if (excludeUid != null) {
        idQuery = idQuery.where(FieldPath.documentId, isNotEqualTo: excludeUid);
      }
      var idSnapshot = await idQuery.get();
      if (idSnapshot.docs.isNotEmpty) return 'Employee ID already exists';

      return await checkContactExists(
        email: email,
        mobileNumber: mobileNumber,
        excludeUid: excludeUid,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error checking employee: $e';
    }
  }

  /// Standalone email/mobile uniqueness check, for flows that have no
  /// employeeId to check (e.g. creating/editing an Admin from the same
  /// Employees page). Shares the same global, cross-company, cross
  /// employee-and-admin logic as [checkEmployeeExists].
  static Future<String?> checkContactExists({
    required String email,
    required String mobileNumber,
    String? excludeUid,
  }) async {
    try {
      var trimmedEmail = email.trim();
      if (trimmedEmail.isNotEmpty) {
        var emailTaken = await _isEmailTakenGlobally(
          email: trimmedEmail,
          excludeUid: excludeUid,
        );
        if (emailTaken) return 'Email already exists';
      }

      var trimmedMobile = mobileNumber.trim();
      if (trimmedMobile.isNotEmpty) {
        var mobileTaken = await _isMobileNumberTakenGlobally(
          mobileNumber: trimmedMobile,
          excludeUid: excludeUid,
        );
        if (mobileTaken) return 'Mobile number already exists';
      }

      return null;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error checking contact details: $e';
    }
  }

  /// True if [email] already belongs to any employee or admin, in any
  /// company, other than [excludeUid] (the record currently being edited,
  /// if any).
  ///
  /// Employee emails are stored encrypted, and have historically been
  /// encrypted either as typed or lowercased first (see the same fallback
  /// in AuthService.checkLogin), so both forms are checked. Admin emails
  /// are stored as plain lowercase text.
  static Future<bool> _isEmailTakenGlobally({
    required String email,
    String? excludeUid,
  }) async {
    var lowerEmail = email.toLowerCase();
    var encryptedVariants = <String>{email.encrypt, lowerEmail.encrypt}.toList();

    var employeeMatches = await FirebaseFirestore.instance
        .collectionGroup(Collections.employees.name)
        .where('email', whereIn: encryptedVariants)
        .get();
    if (employeeMatches.docs.any((doc) => doc.id != excludeUid)) return true;

    var adminMatches = await FirebaseFirestore.instance
        .collectionGroup(Collections.admins.name)
        .where('email', isEqualTo: lowerEmail)
        .get();
    if (adminMatches.docs.any((doc) => doc.id != excludeUid)) return true;

    return false;
  }

  /// True if [mobileNumber] already belongs to any employee or admin, in
  /// any company, other than [excludeUid].
  static Future<bool> _isMobileNumberTakenGlobally({
    required String mobileNumber,
    String? excludeUid,
  }) async {
    var encryptedMobile = mobileNumber.encrypt;

    var employeeMatches = await FirebaseFirestore.instance
        .collectionGroup(Collections.employees.name)
        .where('mobileNumber', isEqualTo: encryptedMobile)
        .get();
    if (employeeMatches.docs.any((doc) => doc.id != excludeUid)) return true;

    var adminMatches = await FirebaseFirestore.instance
        .collectionGroup(Collections.admins.name)
        .where('mobileNumber', isEqualTo: encryptedMobile)
        .get();
    if (adminMatches.docs.any((doc) => doc.id != excludeUid)) return true;

    return false;
  }

  /// Builds a normalized set of dedupe keys from raw field values:
  /// employeeId, email, and mobile number. This is the single source of
  /// truth for duplicate matching during bulk import, mirroring the
  /// approach used for leads (see LeadService.duplicateKeysFor) so a
  /// whole file can be checked against one in-memory set instead of the
  /// three Firestore round trips per row that checkEmployeeExists does
  /// for the single-employee form.
  static List<String> duplicateKeysFor({
    String? employeeId,
    String? email,
    String? mobileNumber,
  }) {
    final normId = (employeeId ?? '').trim().toLowerCase();
    final normEmail = (email ?? '').trim().toLowerCase();
    final normMobile = (mobileNumber ?? '').trim();

    final keys = <String>[];
    if (normId.isNotEmpty) keys.add('employeeId:$normId');
    if (normEmail.isNotEmpty) keys.add('email:$normEmail');
    if (normMobile.isNotEmpty) keys.add('mobile:$normMobile');
    return keys;
  }

  static List<String> duplicateKeysForEmployee(EmployeeModel employee) =>
      duplicateKeysFor(
        employeeId: employee.employeeId,
        email: employee.email,
        mobileNumber: employee.mobileNumber,
      );

  /// Email/mobile-only dedupe keys (no employeeId) for a record from
  /// ANOTHER company. employeeId numbering is per-company, so it must
  /// never be compared across companies, but email and mobile number
  /// must still map to one user for the whole app.
  static List<String> duplicateContactKeysForEmployee(EmployeeModel employee) =>
      duplicateKeysFor(email: employee.email, mobileNumber: employee.mobileNumber);

  static List<String> duplicateContactKeysForAdmin(AdminModel admin) =>
      duplicateKeysFor(email: admin.email, mobileNumber: admin.mobileNumber);

  /// Fetches every employee (active and inactive) so bulk import can
  /// detect duplicates against the full roster — not just currently
  /// active staff, which is all getAllEmployees() returns.
  static Future<List<EmployeeModel>> getAllEmployeesForDuplicateCheck() async {
    try {
      var cid = await Spdb.getCid();
      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .get();

      return querySnapshot.docs
          .map((doc) => EmployeeModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching employees: $e';
    }
  }

  /// Fetches every employee across EVERY company, for bulk import's
  /// email/mobile dedupe set. Only feed the result through
  /// [duplicateContactKeysForEmployee] - never [duplicateKeysForEmployee] -
  /// since employeeId must stay scoped to a single company.
  static Future<List<EmployeeModel>> getAllEmployeesGlobalForDuplicateCheck() async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collectionGroup(Collections.employees.name)
          .get();

      return querySnapshot.docs
          .map((doc) => EmployeeModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching employees: $e';
    }
  }

  /// Fetches every admin across EVERY company, for bulk import's
  /// email/mobile dedupe set - an employee's email/mobile must not
  /// collide with an admin's either.
  static Future<List<AdminModel>> getAllAdminsGlobalForDuplicateCheck() async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collectionGroup(Collections.admins.name)
          .get();

      return querySnapshot.docs
          .map((doc) => AdminModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching admins: $e';
    }
  }

  static Future<void> createEmployee({required EmployeeModel employee}) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.add(
        '${Collections.users.name}/$cid/${Collections.employees.name}',
        employee.toMap(),
        activity: '${employee.name} has been added as a employee',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error creating employee: $e';
    }
  }

  static Future<void> editEmployee({
    required String uid,
    required EmployeeModel employee,
  }) async {
    try {
      var cid = await Spdb.getCid();

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.employees.name}',
        uid,
        employee.toUpdateMap(),
        activity: '${employee.name} has been updated',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error updating employee: $e';
    }
  }

  static Future<EmployeeModel?> getEmployee({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      if (uid.isEmpty) return null;
      var employeeDoc = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .doc(uid)
          .get();

      if (employeeDoc.exists) {
        var employeeData = employeeDoc.data();
        if (employeeData != null) {
          var employee = EmployeeModel.fromMap(employeeDoc.id, employeeData);
          return employee;
        }
        // else {
        //   throw 'Employee data is empty';
        // }
      }
      // else {
      //   throw 'Employee not found, $uid';
      // }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error getting employee: $e';
    }
    return null;
  }

  static Future<List<EmployeeModel>> getAllEmployees({
    bool? excludeCurrentUser,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var query = firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .where('isActive', isEqualTo: true);

      if (excludeCurrentUser ?? false) {
        var uid = await Spdb.getUid();
        query = query.where(FieldPath.documentId, isNotEqualTo: uid);
      }

      var querySnapshot = await query.get();

      List<EmployeeModel> employees = querySnapshot.docs.map((doc) {
        return EmployeeModel.fromMap(doc.id, doc.data());
      }).toList();

      employees.sort((a, b) => a.name.compareTo(b.name));

      return employees;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching reporting-to employees: $e';
    }
  }

  static Future<void> deleteEmployeeImage({required String uid}) async {
    try {
      var cid = await Spdb.getCid();
      var employee = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .doc(uid)
          .get();
      var profileImageUrl = employee.data()?['profileImageUrl'];
      if (profileImageUrl != null) {
        await StorageService.deleteImage(profileImageUrl);
      }

      await CommonService.update(
        '${Collections.users.name}/$cid/${Collections.employees.name}',
        uid,
        {'profileImageUrl': null},
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error deleting employee: $e';
    }
  }

  static Future<List<String>> getEmployeeWorkflow() async {
    try {
      List<String> workflow = [];
      var currentUid = await Spdb.getUid();
      String? uid = currentUid;

      Set<String> visited = {};

      while (uid != null && uid.isNotEmpty) {
        if (visited.contains(uid)) {
          break;
        }
        visited.add(uid);

        var employee = await getEmployee(uid: uid);

        if (employee != null) {
          if (employee.reportingTo != null &&
              employee.reportingTo!.isNotEmpty) {
            for (var reportUid in employee.reportingTo!) {
              workflow.add(reportUid);
            }

            uid = employee.reportingTo!.first;
          } else {
            uid = null;
          }
        }
      }

      workflow.remove(currentUid);

      return workflow;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error: $e\n$st");
      throw 'Error creating employee workflow: $e';
    }
  }

  static Future<List<String>> getUserWorkflow({String? userId}) async {
    try {
      List<String> workflow = [];
      var currentUid = await Spdb.getUid();
      String? uid = userId ?? currentUid;

      Set<String> visited = {};

      while (uid != null && uid.isNotEmpty) {
        if (visited.contains(uid)) break;
        visited.add(uid);

        dynamic user;

        try {
          user = await getEmployee(uid: uid);
        } catch (_) {
          try {
            user = await AdminService.getAdmin(uid: uid);
          } catch (_) {
            break;
          }
        }

        if (user is EmployeeModel) {
          if (user.reportingTo != null && user.reportingTo!.isNotEmpty) {
            workflow.addAll(user.reportingTo!);
            uid = user.reportingTo!.first;
            continue;
          } else {
            break;
          }
        }

        if (user is AdminModel) {
          break;
        }
      }

      workflow.remove(currentUid);
      return workflow;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error: $e\n$st");
      throw 'Error creating workflow: $e';
    }
  }

  static Future<String?> getEmployeeById({required String employeeId}) async {
    try {
      var cid = await Spdb.getCid();

      var querySnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .where('employeeId', isEqualTo: employeeId)
          .get();
      if (querySnapshot.docs.isEmpty) {
        return null;
      } else {
        return querySnapshot.docs.first.id;
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw e.toString();
    }
  }

  static Future<bool> isEmployeeAssigned(String employeeUid) async {
    try {
      var cid = await Spdb.getCid();

      final taskSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.tasks.name)
          .where('assignees', arrayContains: employeeUid)
          .limit(1)
          .get();
      if (taskSnapshot.docs.isNotEmpty) return true;

      final projectSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.projects.name)
          .where('teamMembers', arrayContains: employeeUid)
          .limit(1)
          .get();
      if (projectSnapshot.docs.isNotEmpty) return true;

      final leadSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.leads.name)
          .where('assignedTo', arrayContains: employeeUid)
          .limit(1)
          .get();
      if (leadSnapshot.docs.isNotEmpty) return true;

      final dealSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.deals.name)
          .where('assignedTo', arrayContains: employeeUid)
          .limit(1)
          .get();
      if (dealSnapshot.docs.isNotEmpty) return true;

      final chatSnapshot = await firebase.users
          .doc(cid)
          .collection(Collections.chats.name)
          .where('participants', arrayContains: employeeUid)
          .limit(1)
          .get();
      if (chatSnapshot.docs.isNotEmpty) return true;

      return false;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("Error checking employee assignment: $e\n$st");
      return false;
    }
  }

  //   static Future<void> deleteEmployee({required String uid}) async {
  //   try {
  //     final firestore = FirebaseFirestore.instance;
  //     final cid = await Spdb.getCid();

  //     final ref = firestore
  //         .collection(Collections.users.name)
  //         .doc(cid)
  //         .collection(Collections.employees.name)
  //         .doc(uid);

  //     final snap = await ref.get();
  //     if (!snap.exists) return;

  //     final data = snap.data()!;

  //     try {
  //       await TrashService.moveToTrash(
  //         docRef: ref,
  //         docData: data,
  //         reason: 'user_deleted',
  //       );
  //     } catch (_) {}

  //     await ref.delete(); // ✅ must succeed

  //     try {
  //       final user = await Spdb.getUser();
  //       final log = ActivityLogModel(
  //         userData: user,
  //         activity: '${data['name']?.toString().decrypt ?? 'User'} deleted',
  //         description:
  //             'User deleted from ${Collections.employees.name}',
  //         collection:
  //             '${Collections.users.name}/$cid/${Collections.employees.name}',
  //         docId: uid,
  //       );

  //       await CommonService.add(
  //         '${Collections.users.name}/$cid/${Collections.activityLogs.name}',
  //         log.toMap(),
  //       );
  //     } catch (_) {}
  //   } catch (e, st) {
  //     await ErrorService.recordError(e, st);
  //     debugPrint('Delete employee failed: $e');
  //     // ❌ DO NOT rethrow
  //   }
  // }

  static Future<void> deleteEmployee({required String uid}) async {
    try {
      var cid = await Spdb.getCid();

      var docRef = await firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .doc(uid)
          .get();
      final data = docRef.data() as Map<String, dynamic>;
      await TrashService.moveToTrash(
        docRef: docRef.reference,
        docData: data,
        reason: 'user_deleted',
      );

      await docRef.reference.delete();
      var user = await Spdb.getUser();
      ActivityLogModel activityLogModel = ActivityLogModel(
        userData: user,
        activity: '${data['name'].toString().decrypt} has been deleted',
        description:
            'User has deleted an entry in ${Collections.employees.name}',
        collection:
            '${Collections.users.name}/$cid/${Collections.employees.name}',
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

  static Future<void> restoreEmployee(EmployeeModel employee) async {
    var cid = await Spdb.getCid();

    final uid = employee.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception("UID missing");
    }

    await firebase.users
        .doc(cid)
        .collection(Collections.employees.name)
        .doc(uid)
        .set(employee.toMap());
  }

  static Future<List<EmployeeModel>> getEmployeesByDepartment({
    required String depId,
  }) async {
    try {
      var cid = await Spdb.getCid();
      var query = firebase.users
          .doc(cid)
          .collection(Collections.employees.name)
          .where('department', arrayContains: depId);

      var querySnapshot = await query.get();

      List<EmployeeModel> employees = querySnapshot.docs.map((doc) {
        return EmployeeModel.fromMap(doc.id, doc.data());
      }).toList();

      employees.sort((a, b) => a.name.compareTo(b.name));

      return employees;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      throw 'Error fetching reporting-to employees: $e';
    }
  }
}