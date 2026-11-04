import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/services.dart';
import '/models/models.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String users = "users";
  static const String settings = "settings";

  Future<DocumentReference<Map<String, dynamic>>> _docRef() async {
    final cid = await Spdb.getCid();
    final uid = await Spdb.getUid();

    if (cid == null || uid == null) {
      throw StateError("User not logged in");
    }

    return _firestore.collection(users).doc(cid).collection(settings).doc(uid);
  }

  Future<SettingsModel> fetchSettings() async {
    final ref = await _docRef();
    final snap = await ref.get();

    if (!snap.exists) {
      final uid = await Spdb.getUid();

      final defaults = SettingsModel(
        uid: uid,
        emailNotification: true,
        pushNotification: true,
        inAppNotification: true,
        showChats: true,
        companyName: "",
        appName: "",
        timezone: "UTC",
        language: "English",
        dashboardLayout: "Default",
        autoBackup: false,
        payrollEnabled: true,
      );

      await ref.set(defaults.toMap());
      return defaults;
    }

    return SettingsModel.fromMap(snap.data()!);
  }

  Future<void> updateField(String key, dynamic value) async {
    final ref = await _docRef();
    await ref.update({key: value});
  }
}
