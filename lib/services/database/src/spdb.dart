import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/constants/constants.dart';
import '/services/services.dart';
import '/models/models.dart';

class Spdb {
  static Future<SharedPreferences> _connect() async {
    return await SharedPreferences.getInstance();
  }

  static Future<String?> getLastRunAppVersion() async {
    final cn = await _connect();
    return cn.getString('last_run_app_version');
  }

  static Future<void> setLastRunAppVersion(String version) async {
    final cn = await _connect();
    await cn.setString('last_run_app_version', version);
  }

  /// Clears only the login/session data, leaving unrelated local
  /// preferences (panel/payroll settings, etc.) untouched.
  static Future<void> clearLoginSession() async {
    try {
      final cn = await _connect();
      await cn.remove('cid');
      await cn.remove('employee');
      await cn.remove('admin');
      await cn.setBool('employee_login', false);
      await cn.setBool('admin_login', false);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<void> forceLogout() async {
    try {
      final cn = await _connect();
      await cn.clear();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  // Save the Company Logo URL
  static Future<void> saveCompanyLogo(String? url) async {
    try {
      final cn = await _connect();
      if (url != null) {
        await cn.setString("company_logo", url);
      }
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<String?> getCompanyLogo() async {
    try {
      final cn = await _connect();
      return cn.getString("company_logo");
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> setEmployeeLogin({
    required EmployeeModel model,
    required String cid,
    String? logoUrl,
  }) async {
    try {
      final cn = await _connect();
      cn.setString("cid", cid);
      cn.setBool("employee_login", true);
      cn.setBool("admin_login", false);
      if (logoUrl != null) cn.setString("company_logo", logoUrl);

      var map = model.toMap();
      map["uid"] = model.uid;
      cn.setString("employee", json.encode(map));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<bool> isEmployeeLoggedIn() async {
    final cn = await _connect();
    return cn.getBool("employee_login") ?? false;
  }

  static Future<EmployeeModel?> getEmployee() async {
    try {
      final cn = await _connect();
      final raw = cn.getString("employee");

      if (raw == null) return null;

      final data = jsonDecode(raw);

      return EmployeeModel.fromMap(data["uid"], data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<bool> checkLogin() async {
    final cn = await _connect();
    return (cn.getBool("employee_login") ?? false) ||
        (cn.getBool("admin_login") ?? false);
  }

  static Future<UserDataModel> getUser() async {
    try {
      final cn = await _connect();
      final raw = cn.getString('employee') ?? cn.getString('admin');
      if (raw == null) return UserDataModel.fromEmptyMap();

      final data = jsonDecode(raw);
      EmployeeModel? employeeModel;
      AdminModel? adminModel;
      if (cn.getBool("admin_login") == true) {
        adminModel = AdminModel.fromMap(data["uid"], data);
      } else {
        employeeModel = EmployeeModel.fromMap(data["uid"], data);
      }

      UserDataModel userDataModel = UserDataModel(
        uid: employeeModel?.uid ?? adminModel?.uid ?? '',
        name: employeeModel?.name ?? adminModel?.name ?? '',
        profilePic:
            employeeModel?.profileImageUrl ?? adminModel?.profileImageUrl ?? '',
        desc:
            employeeModel?.designation != null &&
                (employeeModel?.designation.isNotEmpty ?? false)
            ? CacheService.designationByUid(
                employeeModel?.designation ?? '',
              )?.name
            : adminModel?.email ?? '',
        userType: employeeModel != null
            ? UserType.employee
            : adminModel != null
            ? UserType.admin
            : UserType.employee,
      );

      return userDataModel;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return UserDataModel.fromEmptyMap();
    }
  }

  static Future<String?> getCid() async {
    final cn = await _connect();
    return cn.getString('cid');
  }

  /// Same as [getUid] but re-reads the preferences from disk first. Needed
  /// in the push background isolate, whose cached copy can be stale after
  /// the user logs in/out in the main isolate.
  static Future<String?> getUidFresh() async {
    final cn = await _connect();
    try {
      await cn.reload();
    } catch (_) {}
    return getUid();
  }

  static Future<String?> getUid() async {
    final cn = await _connect();

    if (cn.getBool("admin_login") == true) {
      final raw = cn.getString("admin");
      if (raw != null) {
        Map<String, dynamic> data = json.decode(raw);
        return data['uid'];
      }
    }

    if (cn.getBool("employee_login") == true) {
      final raw = cn.getString("employee");
      if (raw != null) {
        Map<String, dynamic> data = json.decode(raw);
        return data['uid'];
      }
    }

    return null;
  }

  static Future<void> saveLastLoginLocation({
    required double latitude,
    required double longitude,
    DateTime? at,
  }) async {
    try {
      final cn = await _connect();
      await cn.setDouble('last_login_lat', latitude);
      await cn.setDouble('last_login_lng', longitude);
      await cn.setInt(
        'last_login_at',
        (at ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<Map<String, dynamic>?> getLastLoginLocation() async {
    try {
      final cn = await _connect();
      final lat = cn.getDouble('last_login_lat');
      final lng = cn.getDouble('last_login_lng');
      final atMs = cn.getInt('last_login_at');
      if (lat == null || lng == null || atMs == null) return null;

      return {
        'latitude': lat,
        'longitude': lng,
        'at': DateTime.fromMillisecondsSinceEpoch(atMs),
      };
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> setAdminLogin({
    required AdminModel model,
    required String cid,
    String? logoUrl,
  }) async {
    try {
      final cn = await _connect();
      cn.setString("cid", cid);
      cn.setBool("admin_login", true);
      cn.setBool("employee_login", false);
      if (logoUrl != null) cn.setString("company_logo", logoUrl);

      var map = model.toMap();
      map["uid"] = model.uid;
      cn.setString("admin", json.encode(map));
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<bool> isAdminLoggedIn() async {
    final cn = await _connect();
    return cn.getBool("admin_login") ?? false;
  }

  static Future<AdminModel?> getAdmin() async {
    try {
      final cn = await _connect();
      final raw = cn.getString("admin");

      final data = jsonDecode(raw ?? '{}');
      return AdminModel.fromMap(data["uid"], data);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static Future<void> logoutAdmin() async {
    try {
      final cn = await _connect();
      await cn.remove("admin");
      await cn.setBool("admin_login", false);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  Future<void> logoutEmployee() async {
    try {
      final cn = await _connect();
      await cn.remove("employee");
      await cn.setBool("employee_login", false);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<void> clearDb() async {
    try {
      final cn = await _connect();
      await cn.clear();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<void> saveSettings(String id) async {
    final prefs = await _connect();
    await prefs.setString('settingsDocId', id);
  }

  static Future<String?> getSettings() async {
    final prefs = await _connect();
    return prefs.getString('settingsDocId');
  }

  static Future<void> savePanelSettings(bool value) async {
    final prefs = await _connect();
    await prefs.setBool('panelSettings', value);
    PanelSettingsNotifier.hidePanel.value = value;
  }

  static Future<bool?> getPanelSettings() async {
    final prefs = await _connect();
    return prefs.getBool('panelSettings');
  }

  static Future<void> loadPanelSettings() async {
    final prefs = await _connect();
    final value = prefs.getBool('panelSettings') ?? false;
    PanelSettingsNotifier.hidePanel.value = value;
  }

  static Future<void> savePayrollSettings(bool value) async {
    final prefs = await _connect();
    await prefs.setBool('payrollEnabled', value);

    AppSettingsNotifier.payrollEnabled.value = value;
  }

  static Future<bool> getPayrollSettings() async {
    final prefs = await _connect();
    return prefs.getBool('payrollEnabled') ?? false;
  }

  static Future<void> loadPayrollSettings() async {
    final prefs = await _connect();
    final value = prefs.getBool('payrollEnabled') ?? false;

    AppSettingsNotifier.payrollEnabled.value = value;
  }
}

class PanelSettingsNotifier {
  static final ValueNotifier<bool> hidePanel = ValueNotifier<bool>(false);
}

class AppSettingsNotifier {
  static final ValueNotifier<bool> payrollEnabled = ValueNotifier(false);
}