// ─────────────────────────────────────────────────────────────────────────────
// version_service.dart
// CHANGED:
//   • Removed `import 'dart:io'`
//   • Replaced `Platform.isAndroid` etc. with `kIsWeb` + `defaultTargetPlatform`
//     from flutter/foundation.dart (web-safe)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import '/models/models.dart';
import '/utils/utils.dart';
import '/services/api/api.dart';
import '/services/services.dart';

class VersionService {
  static VersionModel? _versionModel;

  static Future<void> init() async {
    try {
      _versionModel = await _checkForUpdates();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  /// settings.php `get` returns the server's APP_VERSION (one version for all
  /// platforms, no download url / notes).
  static Future<VersionModel?> _checkForUpdates() async {
    try {
      if (!await Spdb.checkLogin()) return null;
      final res = (await SettingsApiService.call('get')).ensureSuccess();
      final latest = res.dataMap['version']?.toString() ?? '';
      if (latest.isEmpty) return null;

      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else {
        platform = defaultTargetPlatform.name;
      }

      final model = VersionModel(
        version: latest,
        platform: platform,
        timestamp: DateTime.now(),
      );
      if (_isNewer(AppPackageInfo.version, latest)) model.isUpdateNeed = true;
      return model;
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      return null;
    }
  }

  static bool _isNewer(String current, String latest) {
    List<int> c = _normalizeVersion(current);
    List<int> l = _normalizeVersion(latest);
    for (int i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _normalizeVersion(String v) {
    List<String> parts = v.split('.');
    while (parts.length < 3) {
      parts.add('0');
    }
    if (parts.length > 3) parts = parts.sublist(0, 3);
    return parts.map((e) => int.tryParse(e) ?? 0).toList();
  }

  static VersionModel? get version => _versionModel;
}
