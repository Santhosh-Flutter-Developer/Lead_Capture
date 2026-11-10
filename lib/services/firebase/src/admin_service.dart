import 'package:flutter/material.dart';
import '/models/models.dart';
import '/services/services.dart';

/// Admins – employees.php rows with user_type = admin. No Firestore.
class AdminService {
  static Never _fail(String prefix, Object e, StackTrace st) {
    ErrorService.recordError(e, st);
    debugPrint('$e, $st');
    if (e is ApiException) throw e.message;
    throw '$prefix: $e';
  }

  static Future<List<Map<String, dynamic>>> _rows() async {
    final res = (await EmployeesApiService.list(userType: 'admin')).ensureSuccess();
    return res.dataList.map(Js.m).toList();
  }

  /// employees.php requires an employee_id; AdminModel has none, so one is
  /// generated (ADMIN01, ADMIN02 …).
  static Future<String> _nextAdminCode() async {
    int max = 0;
    for (final r in await _rows()) {
      final m = RegExp(r'(\d+)$').firstMatch(Js.s(r['employee_id']));
      final v = int.tryParse(m?.group(1) ?? '');
      if (v != null && v > max) max = v;
    }
    return 'ADMIN${(max + 1).toString().padLeft(2, '0')}';
  }

  static Future<void> createAdmin({required AdminModel admin}) async {
    try {
      final body = <String, dynamic>{
        'employee_id': await _nextAdminCode(),
        'name': admin.name,
        'email': admin.email.trim().toLowerCase(),
        'password': admin.password,
        'mobile_number': admin.mobileNumber,
        'skills': admin.skills ?? '',
        'about': admin.about ?? '',
        'address': admin.address ?? '',
        'employee_type': admin.employeeType ?? 'Full Time',
        'marital_status': admin.maritalStatus ?? 'Single',
        'make_as_admin': 1,
        'login_allowed': (admin.loginAllowed ?? true) ? 1 : 0,
        'receive_email_notifications': (admin.receiveEmailNotifications ?? true) ? 1 : 0,
        'outside_office': (admin.outsideOffice ?? false) ? 1 : 0,
        if (admin.profileImageUrl != null && admin.profileImageUrl!.isNotEmpty)
          'profile_image_url': ApiConfig.toRelativePath(admin.profileImageUrl),
      };
      (await EmployeesApiService.create(body)).ensureSuccess();
      ApiLive.changed('admin');
    } catch (e, st) {
      _fail('Error creating admin', e, st);
    }
  }

  static Future<void> updateAdmin({
    required String id,
    required AdminModel data,
  }) async {
    try {
      final cur = await EmployeesApiService.get(id);
      if (!cur.status) {
        // Firestore used merge-upsert; the API has no upsert.
        await createAdmin(admin: data);
        return;
      }
      final body = ApiMappers.rowToUpdateBody(cur.dataMap, overrides: {
        'name': data.name,
        'email': data.email.trim().toLowerCase(),
        'mobile_number': data.mobileNumber,
        'skills': data.skills ?? '',
        'about': data.about ?? '',
        'address': data.address ?? '',
        'employee_type': data.employeeType ?? 'Full Time',
        'marital_status': data.maritalStatus ?? 'Single',
        'login_allowed': (data.loginAllowed ?? true) ? 1 : 0,
        'receive_email_notifications': (data.receiveEmailNotifications ?? true) ? 1 : 0,
        'outside_office': (data.outsideOffice ?? false) ? 1 : 0,
        if (data.password.isNotEmpty) 'password': data.password,
        if (data.profileImageUrl != null && data.profileImageUrl!.isNotEmpty)
          'profile_image_url': ApiConfig.toRelativePath(data.profileImageUrl),
      });
      (await EmployeesApiService.update(id, body)).ensureSuccess();
      ApiLive.changed('admin');
    } catch (e, st) {
      _fail('Error updating admin', e, st);
    }
  }

  static Future<AdminModel?> getAdmin({required String uid}) async {
    try {
      if (uid.isEmpty) return null;
      final res = await EmployeesApiService.get(uid);
      if (!res.status || !ApiMappers.isAdminRow(res.dataMap)) return null;
      return ApiMappers.admin(res.dataMap);
    } catch (e, st) {
      _fail('Error fetching admin', e, st);
    }
  }

  static Future<List<AdminModel>> getAllAdmins({bool? excludeCurrentUser}) async {
    try {
      final me = (excludeCurrentUser ?? false) ? await Spdb.getUid() : null;
      return (await _rows())
          .where((r) => me == null || Js.s(r['uid']) != me)
          .map(ApiMappers.admin)
          .toList();
    } catch (e, st) {
      _fail('Error fetching admin list', e, st);
    }
  }

  static Future<void> deleteAdminProfileImage({required String uid}) async {
    try {
      final me = await Spdb.getUid();
      if (uid == me) {
        (await AuthApiService.removeMyAvatar()).ensureSuccess();
      } else {
        final cur = await EmployeesApiService.get(uid);
        if (!cur.status) return;
        (await EmployeesApiService.update(uid, ApiMappers.rowToUpdateBody(cur.dataMap, profileImage: 'assets/images/user.png'))).ensureSuccess();
      }
      ApiLive.changed('admin');
    } catch (e, st) {
      _fail('Error deleting admin profile image', e, st);
    }
  }

  /// Server refuses to delete admin accounts (employees.php rule); the
  /// server message is surfaced unchanged.
  static Future<void> deleteAdmin({required String uid}) async {
    try {
      (await EmployeesApiService.delete(uid)).ensureSuccess();
      ApiLive.changed('admin');
    } catch (e, st) {
      _fail('Error deleting admin', e, st);
    }
  }
}
