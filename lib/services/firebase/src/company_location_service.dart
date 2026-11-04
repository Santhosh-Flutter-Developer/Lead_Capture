import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/services.dart';

class CompanyGeofence {
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const CompanyGeofence({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

class CompanyLocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> saveGeofence({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final cid = await Spdb.getCid();
    if (cid == null) return;
    await _firestore.collection('users').doc(cid).update({
      'companyLat': latitude,
      'companyLng': longitude,
      'companyRadius': radiusMeters,
    });
  }

  static Future<CompanyGeofence?> getGeofence() async {
    final cid = await Spdb.getCid();
    if (cid == null) return null;
    final snap = await _firestore.collection('users').doc(cid).get();
    final data = snap.data();
    if (data == null) return null;
    final lat = (data['companyLat'] as num?)?.toDouble();
    final lng = (data['companyLng'] as num?)?.toDouble();
    final radius = (data['companyRadius'] as num?)?.toDouble();
    if (lat == null || lng == null || radius == null) return null;
    return CompanyGeofence(latitude: lat, longitude: lng, radiusMeters: radius);
  }
}
