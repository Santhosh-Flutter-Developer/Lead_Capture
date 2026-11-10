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

/// Company geofence – settings.php (save_geofence / get preferences).
class CompanyLocationService {
  static Future<void> saveGeofence({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    (await SettingsApiService.call('save_geofence', {
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
    })).ensureSuccess();
  }

  static Future<CompanyGeofence?> getGeofence() async {
    final res = (await SettingsApiService.call('get')).ensureSuccess();
    final p = Js.m(res.dataMap['preferences']);
    final lat = double.tryParse('${p['companyLat'] ?? ''}');
    final lng = double.tryParse('${p['companyLng'] ?? ''}');
    final radius = double.tryParse('${p['companyRadius'] ?? ''}');
    if (lat == null || lng == null || radius == null) return null;
    return CompanyGeofence(latitude: lat, longitude: lng, radiusMeters: radius);
  }
}
