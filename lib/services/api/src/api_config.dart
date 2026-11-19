import 'package:flutter/foundation.dart';

/// Centralised PHP REST API configuration.
///
/// Environment selection:
///   * release builds  -> production
///   * debug/profile   -> local
///   * override anytime with:  --dart-define=API_ENV=production|local
///   * override base URL with: --dart-define=API_BASE_URL=https://host/path/api
///
/// NOTE: `localhost` only works for web/desktop. Android emulators reach the
/// host machine at 10.0.2.2, so pass API_BASE_URL for emulator/device testing.
class ApiConfig {
  ApiConfig._();

  static const String productionBaseUrl =
      'https://sriseosolutions.com/mahendran/crm_php/api';
  // Local testing now also uses the hosted server (no localhost / CORS issues).
  static const String localBaseUrl = productionBaseUrl;

  static const String _envOverride = String.fromEnvironment('API_ENV');
  static const String _urlOverride = String.fromEnvironment('API_BASE_URL');

  static bool get isProduction {
    if (_envOverride == 'production') return true;
    if (_envOverride == 'local') return false;
    return kReleaseMode;
  }

  static String get baseUrl {
    if (_urlOverride.isNotEmpty) return _urlOverride.replaceAll(RegExp(r'/+$'), '');
    return isProduction ? productionBaseUrl : localBaseUrl;
  }

  /// Real-time (socket.io) gateway used for instant notifications.
  /// Pass the PUBLIC address of the Node gateway with
  /// `--dart-define=WS_URL=https://host:port` (the server config only knows
  /// the internal 127.0.0.1:8085). Empty => derived from the API host on
  /// port 8085; set `--dart-define=WS_URL=off` to disable.
  static const String _wsOverride = String.fromEnvironment('WS_URL');
  static bool get wsEnabled => _wsOverride != 'off';
  static String get wsUrl {
    if (_wsOverride.isNotEmpty && _wsOverride != 'off') return _wsOverride;
    final u = Uri.parse(baseUrl);
    // Web: the site's CSP only allows wss://<host> (port 443), so use the
    // proxied origin (server must proxy /socket.io/ to the gateway).
    if (kIsWeb) return '${u.scheme}://${u.host}';
    return '${u.scheme}://${u.host}:8085';
  }

  /// Origin used to turn relative file paths (e.g. `uploads/profile/a.png`)
  /// returned by the API into absolute URLs. The API folder is `<root>/api`,
  /// uploads are served from `<root>`.
  static String get siteRoot => baseUrl.replaceFirst(RegExp(r'/(api|admin)$'), '');

  /// Server limit for every uploaded file (upload.php / chats.php): 30 MB.
  static const int maxUploadBytes = 30 * 1024 * 1024;
  static const String maxUploadLabel = '30 MB';
  static bool exceedsUploadLimit(int bytes) => bytes > maxUploadBytes;
  static String uploadTooLargeMessage(String fileName) =>
      '"$fileName" is larger than $maxUploadLabel. Please choose a smaller file.';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 45);
  static const Duration uploadTimeout = Duration(minutes: 3);

  /// Resolve a path returned by the API into a displayable absolute URL.
  /// Handles: full URLs, bundled assets, `uploads/x.png` (relative to the
  /// site root) and `/mahendran/crm_php/uploads/x.png` (BASE_URL-prefixed).
  static String resolveFileUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('assets/images/')) return path; // bundled asset
    final root = Uri.parse(siteRoot);
    if (path.startsWith('/')) {
      // Already contains the site's base path -> only add scheme+host.
      if (root.path.isNotEmpty && path.startsWith(root.path)) {
        return '${root.scheme}://${root.authority}$path';
      }
      return '$siteRoot$path';
    }
    return '$siteRoot/$path';
  }

  /// Inverse of [resolveFileUrl]: strips the site root so the DB keeps a
  /// relative path. Unknown / external URLs are returned unchanged.
  static String toRelativePath(String? url) {
    if (url == null || url.isEmpty) return '';
    final prefix = '$siteRoot/';
    if (url.startsWith(prefix)) return url.substring(prefix.length);
    return url;
  }
}