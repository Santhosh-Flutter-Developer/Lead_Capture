// ─────────────────────────────────────────────────────────────────────────────
// device_info_io.dart  — NEW FILE
// Native platform device info — uses dart:io Platform and device_info_plus.
// Only compiled on native via conditional import in device_info.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:leadcapture/services/firebase/src/notification_service.dart';
// import 'notification_service.dart' show getToken;

/// Returns a map of device info fields for the current native platform.
Future<Map<String, String?>> getPlatformDeviceInfo(
    DeviceInfoPlugin plugin) async {
  String? deviceId;
  String? deviceName;
  String? brand;
  String? model;
  String? platform;
  String? fcmId;

  if (Platform.isAndroid) {
    final android = await plugin.androidInfo;
    deviceId = android.id;
    deviceName = android.device;
    brand = android.brand;
    model = android.model;
    platform = 'Android';
    fcmId = await getToken();
  } else if (Platform.isIOS) {
    final ios = await plugin.iosInfo;
    deviceId = ios.identifierForVendor ?? 'unknown';
    deviceName = ios.name;
    brand = ios.systemName;
    model = ios.model;
    platform = 'iOS';
    fcmId = await getToken();
  } else if (Platform.isWindows) {
    final windows = await plugin.windowsInfo;
    deviceId = windows.deviceId;
    deviceName = windows.computerName;
    brand = 'Microsoft';
    model = windows.productName;
    platform = 'Microsoft';
  } else if (Platform.isLinux) {
    final linux = await plugin.linuxInfo;
    deviceId = linux.machineId ?? 'unknown';
    deviceName = linux.name;
    brand = linux.prettyName;
    model = linux.version;
    platform = 'Linux';
  } else if (Platform.isMacOS) {
    final mac = await plugin.macOsInfo;
    deviceId = mac.systemGUID ?? 'unknown';
    deviceName = mac.computerName;
    brand = 'Apple';
    model = mac.model;
    platform = 'macOS';
  } else {
    deviceId = 'unknown';
    deviceName = 'unknown';
    brand = 'unknown';
    model = 'unknown';
    platform = 'unknown';
  }

  return {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'brand': brand,
    'model': model,
    'platform': platform,
    'fcmId': fcmId,
  };
}
