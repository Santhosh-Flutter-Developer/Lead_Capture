import '/services/services.dart';
import '/services/api/api.dart';
import '/models/models.dart';

/// Settings via settings.php (`get`, `update_preference`).
class SettingsService {
  Future<SettingsModel> fetchSettings() async {
    final res = (await SettingsApiService.call('get')).ensureSuccess();
    final d = res.dataMap;
    final p = Js.m(d['preferences']);
    final c = Js.m(d['company']);
    return SettingsModel(
      uid: await Spdb.getUid(),
      emailNotification: Js.b(p['emailNotification'], true),
      pushNotification: Js.b(p['pushNotification'], true),
      inAppNotification: Js.b(p['inAppNotification'], true),
      showChats: !Js.b(p['hideChatPanel'], false),
      companyName: Js.s(c['company_name']),
      appName: Js.s(p['appName']),
      timezone: Js.s(p['timezone'], 'Asia/Kolkata'),
      language: Js.s(p['language'], 'English (US)'),
      dashboardLayout: Js.s(p['dashboardLayout'], 'Default Overview'),
      autoBackup: Js.b(p['autoBackup'], true),
      payrollEnabled: false,
    );
  }

  /// Saves one preference (the app's `showChats` is stored as `hideChatPanel`).
  Future<void> updateField(String key, dynamic value) async {
    var k = key;
    var v = value;
    if (key == 'showChats') {
      k = 'hideChatPanel';
      v = !(value == true);
    }
    (await SettingsApiService.call('update_preference', {'key': k, 'value': v}))
        .ensureSuccess();
  }
}
