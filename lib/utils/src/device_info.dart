// ─────────────────────────────────────────────────────────────────────────────
// device_info.dart
// CHANGED:
//   • Removed top-level `import 'dart:io'`
//   • Added conditional import so Platform.is* is only used on non-web
//   • The kIsWeb branch was already present — just needed the import fixed
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '/models/models.dart';
import '/services/services.dart';
import 'package:http/http.dart' as http;

// Conditionally import dart:io Platform — never loaded on web
import 'device_info_io.dart'
    if (dart.library.html) 'device_info_web.dart' show getPlatformDeviceInfo;

class DeviceInfo {
  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  static Future<DeviceModel> getDeviceInfo({bool forDebug = false}) async {
    String? deviceId;
    String? deviceName;
    String? brand;
    String? model;
    String? platform;
    String? fcmId;

    try {
      if (kIsWeb) {
        // Web platform — no dart:io needed
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        deviceId = webInfo.vendor ?? 'unknown';
        deviceName = webInfo.userAgent ?? 'unknown';
        brand = webInfo.browserName.name;
        model = 'Web Browser';
        platform = 'Web';
        try {
          fcmId = await FirebaseMessaging.instance.getToken(
            vapidKey: 'BElo9iyDmRacZr_hHvqLsXhMjCdn4mE8t6XZve1RD6DlU8g5NUTV1Xl8UiiMXkRmBDklec0WQ8KxPfTAFNSBw5o',
          );
        } catch (e) {
          debugPrint('❌ FCM Token retrieval failed: $e');
        }
      } else {
        // Native — delegates to platform-specific function in device_info_io.dart
        final info = await getPlatformDeviceInfo(deviceInfoPlugin);
        deviceId = info['deviceId'];
        deviceName = info['deviceName'];
        brand = info['brand'];
        model = info['model'];
        platform = info['platform'];
        fcmId = info['fcmId'];
      }
    } catch (e, st) {
      debugPrint("${e.toString()}, ${st.toString()}");
      await ErrorService.recordError(e, st);
      deviceId = 'error';
      deviceName = 'error';
      brand = 'error';
      model = e.toString();
    }

    if (forDebug) {
      return DeviceModel(
        deviceId: deviceId,
        deviceName: deviceName,
        brand: brand,
        model: model,
        platform: platform,
      );
    }

    return DeviceModel(
      deviceId: deviceId,
      deviceName: deviceName,
      brand: brand,
      model: model,
      platform: platform,
      lastLoginAt: DateTime.now(),
      fcmId: fcmId,
    );
  }
}

class LoginAlertDeviceInfo {
  static Future<Map<String, dynamic>> _getLocationAndIPAddress() async {
    try {
      final response = await http.get(Uri.parse("https://ipinfo.io/json"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          "location": "${data['city']}, ${data['region']}, ${data['country']}",
          "ip_address": data['ip'],
        };
      } else {
        return {"location": "Unknown Location", "ip_address": "Unknown IP"};
      }
    } catch (e) {
      return {"location": "Unknown Location", "ip_address": "Unknown IP"};
    }
  }

  static Future<LoginAlertModel> getLoginAlertInfo() async {
    DeviceModel deviceInfo = await DeviceInfo.getDeviceInfo();
    String deviceString =
        "Device Name: ${deviceInfo.deviceName}, Brand: ${deviceInfo.brand}, Model: ${deviceInfo.model}, Platform: ${deviceInfo.platform}";

    Map<String, dynamic> locationData = await _getLocationAndIPAddress();

    return LoginAlertModel(
      ipAddress: locationData['ip_address'] ?? 'Unknown IP',
      location: locationData['location'] ?? 'Unknown Location',
      dateTime: DateTime.now(),
      device: deviceString,
    );
  }
}
