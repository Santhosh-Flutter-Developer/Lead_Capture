import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/models.dart';

class UserStatusService {
  static final _statusRef = FirebaseFirestore.instance.collection(
    "user_status",
  );

  static Future<void> setOnline(String uid) async {
    await _statusRef.doc(uid).set({
      "isOnline": true,
      "lastSeen": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setOffline(String uid) async {
    await _statusRef.doc(uid).set({
      "isOnline": false,
      "lastSeen": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<UserStatusModel?> streamStatus(String uid) {
    if (uid.isEmpty) return const Stream.empty();
    return _statusRef
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserStatusModel.fromMap(doc.data()!) : null);
  }
}
