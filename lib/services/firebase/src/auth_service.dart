import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

/// Authentication – backed by auth.php / employees.php (JWT-less bearer
/// token issued by the PHP API). No Firebase Auth / Firestore.
///
/// FCM (push) is the only Firebase piece still touched here: the device
/// token is deleted locally on logout. The PHP API has no endpoint to store
/// device tokens (see MISSING_API_REQUIREMENTS.md), so [getUserFcmIds]
/// returns an empty list.
class AuthService {
  /// Password typed at login, kept only in memory so the forced
  /// "change initial password" screen can call change_password (which needs
  /// the current password). Never persisted.
  static String? _pendingPassword;

  static Future<Map<String, dynamic>> checkLogin({
    String? employeeId,
    String? email,
    required String password,
  }) async {
    try {
      final ident = ((email != null && email.trim().isNotEmpty) ? email : (employeeId ?? '')).trim();
      if (ident.isEmpty) return {'status': false, 'error': 'No user found'};

      final isEmail = ident.contains('@');
      final res = await AuthApiService.login(
        email: isEmail ? ident : null,
        employeeId: isEmail ? null : ident,
        password: password,
      );
      if (!res.status) {
        return {'status': false, 'error': res.message.isEmpty ? 'Invalid credentials' : res.message};
      }

      final session = Js.m(res.dataMap['user']);
      ApiLookup.invalidate();
      await ApiLookup.ensure();

      // Full profile (login response only carries the session subset).
      final profileRes = await AuthApiService.getMyProfile();
      final row = profileRes.status ? {...session, ...profileRes.dataMap} : session;

      final isAdmin = ApiMappers.isAdminRow(row);
      _pendingPassword = password;

      final out = <String, dynamic>{
        'status': true,
        'collectionId': Js.s(session['company_id'] ?? row['company_id']),
        'uid': Js.s(row['uid']),
        'isAdmin': isAdmin,
        'companyLogo': ApiMappers.photo(session['company_logo']),
        'companyName': Js.s(session['company_name'] ?? row['company_name']),
      };
      if (isAdmin) {
        out['admin'] = ApiMappers.admin(row);
        out['permissions'] = AppStrings.permissionsTrueMap;
      } else {
        out['employee'] = ApiMappers.employee(row);
        out['permissions'] = ApiMappers.permissions(session['permissions']);
      }
      return out;
    } catch (e, st) {
      debugPrint('Login Error: $e');
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  /// True when the e-mail already belongs to a user (registration check).
  static Future<bool> isRegistrationEmailTaken(String email) async {
    final res = await AuthApiService.checkEmail(email);
    final d = res.dataMap;
    if (d.containsKey('exists')) return Js.b(d['exists']);
    if (d.containsKey('available')) return !Js.b(d['available']);
    return !res.status;
  }

  static String _logoDataUri(Uint8List bytes, String? fileName) {
    var ext = (fileName ?? '').contains('.') ? fileName!.split('.').last.toLowerCase() : 'png';
    if (ext == 'jpg') ext = 'jpeg';
    if (!['jpeg', 'png', 'gif', 'webp'].contains(ext)) ext = 'png';
    return 'data:image/$ext;base64,${base64Encode(bytes)}';
  }

  static Future<Map<String, dynamic>> registerCompany({
    required String name,
    required String adminEmail,
    required String adminName,
    required String password,
    File? logo,
    Uint8List? logoBytes,
    double? companyLat,
    double? companyLng,
    double? companyRadius,
  }) async {
    try {
      String? logoUri;
      if (kIsWeb && logoBytes != null) {
        logoUri = _logoDataUri(logoBytes, null);
      } else if (logo != null) {
        logoUri = _logoDataUri(await logo.readAsBytes(), logo.path);
      }
      final email = adminEmail.trim().toLowerCase();
      final res = await ApiClient.instance.post(
        ApiEndpoints.auth,
        action: 'register_company',
        auth: false,
        body: {
          // Both key sets: the API document and the deployed auth.php differ.
          'company_name': name,
          'company_email': email,
          'admin_name': adminName,
          'full_name': adminName,
          'admin_email': email,
          'email': email,
          'password': password,
          'terms': 1,
          if (logoUri != null) 'logo': logoUri,
        },
      );
      if (!res.status) {
        return {'status': false, 'error': res.message};
      }
      return {'status': true, 'message': 'Company registered successfully'};
    } catch (e, st) {
      debugPrint('$e, $st');
      await ErrorService.recordError(e, st);
      return {'status': false, 'error': e.toString()};
    }
  }

  // ── Forgot password (OTP flow: check_user_email → send_otp → verify_otp → reset_password)

  /// Returns {uid,name,email} when the e-mail belongs to a user, else null.
  static Future<Map<String, dynamic>?> checkEmailExists({required String email}) async {
    try {
      final res = await ApiClient.instance.post(
        ApiEndpoints.auth,
        action: 'check_user_email',
        auth: false,
        body: {'email': email.trim()},
      );
      if (!res.status) return null;
      final d = res.dataMap;
      return {'uid': Js.s(d['uid']), 'name': Js.s(d['name']), 'email': Js.s(d['email'], email)};
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  /// Asks the server to e-mail a 6-digit OTP. Returns true when mail was sent.
  static Future<bool> sendResetOtp(String email) async {
    final res = await ApiClient.instance.post(
      ApiEndpoints.auth,
      action: 'send_otp',
      auth: false,
      body: {'email': email.trim()},
    );
    if (!res.status) throw res.message;
    final d = res.dataMap;
    final sent = Js.b(d['mail_sent']);
    if (!sent && !ApiConfig.isProduction && d['dev_otp'] != null) {
      debugPrint('DEV OTP (SMTP not configured): ${d['dev_otp']}');
    }
    return sent;
  }

  /// Verifies the OTP; returns the one-time reset token.
  static Future<String> verifyResetOtp({required String email, required String otp}) async {
    final res = await ApiClient.instance.post(
      ApiEndpoints.auth,
      action: 'verify_otp',
      auth: false,
      body: {'email': email.trim(), 'otp': otp.trim()},
    );
    if (!res.status) throw res.message;
    return Js.s(res.dataMap['reset_token']);
  }

  /// Two modes:
  ///  * forgot-password: `emailData['reset_token']` is present → reset_password
  ///  * first login (initial password): logged-in user → change_password
  static Future<void> resetPassword({
    required Map<String, dynamic> emailData,
    required String newPassword,
  }) async {
    try {
      final token = Js.s(emailData['reset_token']);
      if (token.isNotEmpty) {
        (await AuthApiService.resetPassword(token: token, password: newPassword)).ensureSuccess();
        return;
      }
      final current = _pendingPassword;
      if (current == null || current.isEmpty) {
        throw 'Session expired. Please log in again.';
      }
      (await AuthApiService.changePassword(currentPassword: current, newPassword: newPassword)).ensureSuccess();
      _pendingPassword = null;
      await SessionManager.clear(); // screen asks the user to log in again
    } catch (e, st) {
      debugPrint('Error resetting password: $e, $st');
      await ErrorService.recordError(e, st);
      rethrow;
    }
  }

  // ── Push-token helpers (FCM stays; PHP has no token store yet) ──────────

  static Future<void> removeFcmTokenEverywhere(String token) async {}

  /// Logout cleanup: ends the PHP session (marks offline, clears token) and
  /// deletes the FCM token on the device. Never throws.
  static Future<void> removeCurrentDeviceFcm() async {
    try {
      await AuthApiService.logout();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
    try {
      final supportsFcm = kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      if (supportsFcm) await FirebaseMessaging.instance.deleteToken();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<bool> checkUserEmailExists({required String email, String? uid}) async {
    final m = await checkEmailExists(email: email);
    if (m == null) return false;
    return uid == null || m['uid'] != uid;
  }

  /// No device-token endpoint exists in the PHP API yet.
  static Future<List<String>> getUserFcmIds({required String uid}) async => <String>[];

  /// Re-reads the logged-in user's profile (used by the manual "Sync" action).
  static Future<Map<String, dynamic>> refreshLogin() async {
    try {
      final res = await AuthApiService.getMyProfile();
      if (!res.status) return {'status': false, 'error': res.message};
      ApiLookup.invalidate();
      await ApiLookup.ensure();
      final row = res.dataMap;
      final cid = await Spdb.getCid();
      final out = <String, dynamic>{'status': true, 'collectionId': cid, 'uid': Js.s(row['uid'])};
      if (ApiMappers.isAdminRow(row)) {
        out['admin'] = ApiMappers.admin(row);
      } else {
        out['employee'] = ApiMappers.employee(row);
      }
      return out;
    } catch (e, st) {
      debugPrint('$e, $st');
      await ErrorService.recordError(e, st);
      throw e.toString();
    }
  }

  /// The PHP server records login logs itself during `login`.
  static Future<void> saveLoginLogs({required LoginLogsModel log}) async {}

  /// The PHP server records activity itself for every write.
  static Future<void> saveActivityLogs({required ActivityLogModel log}) async {}
}
