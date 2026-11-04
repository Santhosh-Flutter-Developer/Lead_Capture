import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatusModel {
  final bool isOnline;
  final DateTime? lastSeen;

  UserStatusModel({required this.isOnline, this.lastSeen});

  factory UserStatusModel.fromMap(Map<String, dynamic> map) {
    DateTime? lastSeenDate;
    if (map["lastSeen"] != null) {
      if (map["lastSeen"] is Timestamp) {
        lastSeenDate = (map["lastSeen"] as Timestamp).toDate();
      } else if (map["lastSeen"] is int) {
        lastSeenDate = DateTime.fromMillisecondsSinceEpoch(
          map["lastSeen"] as int,
        );
      }
    }
    return UserStatusModel(
      isOnline: map["isOnline"] ?? false,
      lastSeen: lastSeenDate,
    );
  }
}
