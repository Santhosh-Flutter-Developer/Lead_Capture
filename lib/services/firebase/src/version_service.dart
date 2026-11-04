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
import '/constants/constants.dart';
import '/services/services.dart';

class VersionService {
  static final FirebaseConfig firebase = FirebaseConfig();
  static VersionModel? _versionModel;

  static Future<void> init() async {
    try {
      _versionModel = await _checkForUpdates();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static Future<VersionModel?> _checkForUpdates() async {
    try {
      String? cid = await Spdb.getCid();
      if (cid == null) return null;

      // ── Web-safe platform string ──────────────────────────────────────────
      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            platform = 'android';
            break;
          case TargetPlatform.iOS:
            platform = 'ios';
            break;
          case TargetPlatform.windows:
            platform = 'windows';
            break;
          case TargetPlatform.macOS:
            platform = 'macos';
            break;
          case TargetPlatform.linux:
            platform = 'linux';
            break;
          default:
            platform = 'unknown';
        }
      }

      var versionDoc = await firebase.users
          .doc(cid)
          .collection(Collections.version.name)
          .where('platform', isEqualTo: platform)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (versionDoc.docs.isEmpty) return null;

      var versionData = versionDoc.docs.first.data();
      var versionModel = VersionModel.fromMap(versionData);
      var currentVersion = AppPackageInfo.version;
      var latestVersion = versionData['version'].toString();

      if (_isNewer(currentVersion, latestVersion)) {
        versionModel.isUpdateNeed = true;
      }

      return versionModel;
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
