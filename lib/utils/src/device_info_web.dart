// ─────────────────────────────────────────────────────────────────────────────
// device_info_web.dart  — NEW FILE
// Web stub — getPlatformDeviceInfo() is never called on web because
// device_info.dart handles kIsWeb inline with webBrowserInfo.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:device_info_plus/device_info_plus.dart';

Future<Map<String, String?>> getPlatformDeviceInfo(
    DeviceInfoPlugin plugin) async {
  // Should never be reached on web — the kIsWeb branch in DeviceInfo handles it.
  return {
    'deviceId': 'web',
    'deviceName': 'web',
    'brand': 'web',
    'model': 'web',
    'platform': 'Web',
    'fcmId': null,
  };
}
