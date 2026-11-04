import 'package:cloud_firestore/cloud_firestore.dart';

/// A singleton class that provides typed access to Firestore collections.
///
/// Usage:
/// ```dart
/// final usersRef = FirebaseConfig.instance.users;
/// final versionRef = FirebaseConfig.instance.version;
/// final regionsRef = FirebaseConfig.instance.regionsRef;
/// final systemRef = FirebaseConfig.instance.systemRef;
/// ```
class FirebaseConfig {
  /// Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firestore Collections
  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get admins =>
      _firestore.collection('admins');

  CollectionReference<Map<String, dynamic>> get version =>
      _firestore.collection('version');

  CollectionReference<Map<String, dynamic>> get regions =>
      _firestore.collection('regions');

  CollectionReference<Map<String, dynamic>> get system =>
      _firestore.collection('system');

  CollectionReference<Map<String, dynamic>> get errors =>
      _firestore.collection('errors');

  collection(String name) {}
}
