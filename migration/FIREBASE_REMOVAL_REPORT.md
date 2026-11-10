# Firebase removal report

* `grep` for `FirebaseFirestore`, `FirebaseConfig`, `cloud_firestore`, `firebase_storage`, `FirebaseStorage`, `FieldValue`, `Collections.`(usage), `.snapshots()` over `lib/` → **no matches**.
* `pubspec.yaml`: removed `cloud_firestore`, `firebase_storage`. **Kept** `firebase_core`, `firebase_messaging` for FCM only (`main.dart`, `notification_service.dart`, `auth_service.dart`, `device_info.dart`, notification test page).
* Deleted: `firebase_config.dart`, `encrypt_service.dart` (Firestore re-encryption tool), `trash_service.dart`, diff/noise files.
* Models use a local `Timestamp` compat class (`models/src/timestamp.dart`); no Firebase type is used for data.
* Hardcoded SMTP password and FCM service-account key removed from client code (rotate them!).
* `lib/firebase_options.dart` is still present because FCM needs `Firebase.initializeApp`.
* Removed from the app (not in PHP): attendance, work time, WFH, leave, salary, bank details, employee status.
