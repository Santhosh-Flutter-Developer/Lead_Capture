import 'package:shared_preferences/shared_preferences.dart';

/// Holds the Bearer token for the PHP API.
///
/// Stored in SharedPreferences (already used by the app for the session).
/// Passwords are never stored. See MISSING_API_REQUIREMENTS.md / limitations
/// for the note about moving the token to flutter_secure_storage.
class SessionManager {
  SessionManager._();
  static const _tokenKey = 'api_token';
  static String? _cached;

  /// Called by ApiClient when any request returns 401 / invalid-token.
  /// The app shell can assign this to force navigation to the login screen.
  static void Function()? onUnauthorized;

  static Future<String?> getToken() async {
    if (_cached != null) return _cached;
    final sp = await SharedPreferences.getInstance();
    _cached = sp.getString(_tokenKey);
    return _cached;
  }

  static Future<void> saveToken(String token) async {
    _cached = token;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, token);
  }

  static Future<void> clear() async {
    _cached = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
  }

  static Future<bool> hasToken() async => (await getToken())?.isNotEmpty ?? false;
}
