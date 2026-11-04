import 'package:package_info_plus/package_info_plus.dart';
import '/services/services.dart';

class AppPackageInfo {
  static late PackageInfo _packageInfo;

  static Future<void> init() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (e, st) {
      await ErrorService.recordError(e, st);
    }
  }

  static String get appName => _packageInfo.appName;
  static String get packageName => _packageInfo.packageName;
  static String get version => _packageInfo.version;
  static String get buildNumber => _packageInfo.buildNumber;
}
