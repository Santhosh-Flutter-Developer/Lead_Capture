import 'api_client.dart';
import 'api_constants.dart';
import 'api_response.dart';
import 'session_manager.dart';

/// auth.php + the profile endpoints of employees.php.
class AuthApiService {
  AuthApiService._();
  static final _c = ApiClient.instance;

  /// Login with email OR employee id. Stores the token on success.
  static Future<ApiResponse> login({String? email, String? employeeId, required String password}) async {
    final res = await _c.post(
      ApiEndpoints.auth,
      action: 'login',
      auth: false,
      body: {
        'check_login': '1',
        if (email != null && email.isNotEmpty) 'email': email.trim(),
        if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId.trim(),
        'password': password,
      },
    );
    if (res.status) {
      final token = res.dataMap['token']?.toString();
      if (token != null && token.isNotEmpty) await SessionManager.saveToken(token);
    }
    return res;
  }

  static Future<ApiResponse> registerCompany({
    required String companyName,
    required String fullName,
    required String email,
    required String password,
    String? mobileNumber,
  }) =>
      _c.post(ApiEndpoints.auth, action: 'register_company', auth: false, body: {
        'company_name': companyName,
        'full_name': fullName,
        'email': email.trim(),
        'password': password,
        if (mobileNumber != null && mobileNumber.isNotEmpty) 'mobile_number': mobileNumber,
        'terms': 1,
      });

  static Future<ApiResponse> checkEmail(String email) =>
      _c.post(ApiEndpoints.auth, action: 'check_email', auth: false, body: {'email': email.trim()});

  static Future<ApiResponse> forgotPassword(String email) =>
      _c.post(ApiEndpoints.auth, action: 'forgot_password', auth: false, body: {'email': email.trim()});

  static Future<ApiResponse> validateResetToken(String token) =>
      _c.post(ApiEndpoints.auth, action: 'validate_reset_token', auth: false, body: {'token': token});

  static Future<ApiResponse> resetPassword({
    required String token,
    required String password,
    String? confirmPassword,
  }) =>
      _c.post(ApiEndpoints.auth, action: 'reset_password', auth: false, body: {
        'token': token,
        'password': password,
        'confirm_password': confirmPassword ?? password,
      });

  static Future<ApiResponse> changePassword({required String currentPassword, required String newPassword}) =>
      _c.post(ApiEndpoints.auth,
          action: 'change_password', body: {'current_password': currentPassword, 'new_password': newPassword});

  static Future<ApiResponse> checkSession() => _c.post(ApiEndpoints.auth, action: 'check_session', body: {});

  static Future<ApiResponse> getMyProfile() => _c.post(ApiEndpoints.employees, action: 'get_my_profile', body: {});

  static Future<ApiResponse> updateMyProfile(Map<String, dynamic> fields) =>
      _c.post(ApiEndpoints.employees, action: 'update_my_profile', body: fields);

  static Future<ApiResponse> removeMyAvatar() => _c.post(ApiEndpoints.employees, action: 'remove_my_avatar', body: {});

  /// Logs out on the server and ALWAYS clears the local token.
  static Future<void> logout() async {
    try {
      await _c.post(ApiEndpoints.auth, action: 'logout', body: {});
    } catch (_) {
      // Server unreachable / token already invalid: still clear locally.
    } finally {
      await SessionManager.clear();
    }
  }
}
