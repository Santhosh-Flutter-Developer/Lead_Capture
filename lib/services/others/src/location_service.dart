// import 'dart:developer';
// import 'package:geolocator/geolocator.dart';
// import '/models/models.dart';

// enum LocationPermissionStatus {
//   granted,
//   denied,
//   deniedForever,
//   serviceDisabled,
//   unableToDetermine,
// }

// class LocationPermissionResult {
//   final LocationPermissionStatus status;
//   final String message;
//   final bool canProceed;
//   final bool needsSettings;

//   LocationPermissionResult({
//     required this.status,
//     required this.message,
//     required this.canProceed,
//     this.needsSettings = false,
//   });
// }

// class GeofencingResult {
//   final bool isWithinGeofence;
//   final double distanceInMeters;
//   final double distanceInKm;
//   final String message;
//   final Position? currentPosition;

//   GeofencingResult({
//     required this.isWithinGeofence,
//     required this.distanceInMeters,
//     required this.distanceInKm,
//     required this.message,
//     this.currentPosition,
//   });
// }

// class LocationService {
//   static Future<bool> requestPermission() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return false;

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }
//     return permission == LocationPermission.whileInUse ||
//         permission == LocationPermission.always;
//   }

//   /// Get detailed permission status
//   static Future<LocationPermissionStatus> getPermissionStatus() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       return LocationPermissionStatus.serviceDisabled;
//     }

//     LocationPermission permission = await Geolocator.checkPermission();
//     switch (permission) {
//       case LocationPermission.denied:
//         return LocationPermissionStatus.denied;
//       case LocationPermission.deniedForever:
//         return LocationPermissionStatus.deniedForever;
//       case LocationPermission.whileInUse:
//       case LocationPermission.always:
//         return LocationPermissionStatus.granted;
//       case LocationPermission.unableToDetermine:
//         return LocationPermissionStatus.unableToDetermine;
//     }
//   }

//   /// Request permission with detailed status
//   static Future<LocationPermissionResult> requestPermissionWithStatus() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       return LocationPermissionResult(
//         status: LocationPermissionStatus.serviceDisabled,
//         message: 'Location services are disabled. Please enable them in settings.',
//         canProceed: false,
//       );
//     }

//     LocationPermission permission = await Geolocator.checkPermission();
    
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         return LocationPermissionResult(
//           status: LocationPermissionStatus.denied,
//           message: 'Location permission was denied. Please enable it to use geofencing features.',
//           canProceed: false,
//         );
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       return LocationPermissionResult(
//         status: LocationPermissionStatus.deniedForever,
//         message: 'Location permission is permanently denied. Please enable it in app settings.',
//         canProceed: false,
//         needsSettings: true,
//       );
//     }

//     if (permission == LocationPermission.whileInUse || 
//         permission == LocationPermission.always) {
//       return LocationPermissionResult(
//         status: LocationPermissionStatus.granted,
//         message: 'Location permission granted.',
//         canProceed: true,
//       );
//     }

//     return LocationPermissionResult(
//       status: LocationPermissionStatus.unableToDetermine,
//       message: 'Unable to determine location permission status.',
//       canProceed: false,
//     );
//   }

//   static Future<Position?> getCurrentPosition() async {
//     final granted = await requestPermission();
//     if (!granted) return null;
//     try {
//       return await Geolocator.getCurrentPosition(
//         locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
//       );
//     } catch (e) {
//       log('Error getting current position: $e');
//       return null;
//     }
//   }

//   /// Returns distance in metres between two lat/lng points.
//   static double distanceBetween(
//     double lat1,
//     double lng1,
//     double lat2,
//     double lng2,
//   ) {
//     return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
//   }

//   static bool isWithinRadius({
//     required double currentLat,
//     required double currentLng,
//     required double centerLat,
//     required double centerLng,
//     required double radiusMeters,
//   }) {
//     final distance = distanceBetween(
//       currentLat,
//       currentLng,
//       centerLat,
//       centerLng,
//     );
//     return distance <= radiusMeters;
//   }

//   /// Validate if current position is within company geofence
//   static Future<GeofencingResult> validateGeofence(
//     CompanyModel company,
//   ) async {
//     // Check if company has GPS coordinates configured
//     if (company.latitude == null ||
//         company.longitude == null ||
//         company.radius == 0) {
//       return GeofencingResult(
//         isWithinGeofence: true, // Allow if geofencing not configured
//         distanceInMeters: 0,
//         distanceInKm: 0,
//         message: 'Geofencing not configured for this company',
//       );
//     }

//     // Get current position
//     final position = await getCurrentPosition();
//     if (position == null) {
//       return GeofencingResult(
//         isWithinGeofence: false,
//         distanceInMeters: -1,
//         distanceInKm: -1,
//         message: 'Unable to get current location. Please enable location services.',
//         currentPosition: null,
//       );
//     }

//     // Calculate distance
//     final distanceInMeters = distanceBetween(
//       position.latitude,
//       position.longitude,
//       company.latitude!,
//       company.longitude!,
//     );

//     final distanceInKm = distanceInMeters / 1000;
//     final isWithin = distanceInMeters <= company.radius;

//     String message;
//     if (isWithin) {
//       message = 'You are within office premises (${distanceInKm.toStringAsFixed(2)} km from office)';
//     } else {
//       message = 'You are outside office premises (${distanceInKm.toStringAsFixed(2)} km from office). Punch-in may require admin approval.';
//     }

//     return GeofencingResult(
//       isWithinGeofence: isWithin,
//       distanceInMeters: distanceInMeters,
//       distanceInKm: distanceInKm,
//       message: message,
//       currentPosition: position,
//     );
//   }

//   /// Get distance from company location
//   static Future<double?> getDistanceFromCompany(
//     CompanyModel company,
//   ) async {
//     if (company.latitude == null || company.longitude == null) {
//       return null;
//     }

//     final position = await getCurrentPosition();
//     if (position == null) return null;

//     return distanceBetween(
//       position.latitude,
//       position.longitude,
//       company.latitude!,
//       company.longitude!,
//     );
//   }

//   /// Format distance for display
//   static String formatDistance(double distanceInMeters) {
//     if (distanceInMeters < 1000) {
//       return '${distanceInMeters.toStringAsFixed(0)} m';
//     } else {
//       return '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
//     }
//   }

//   /// Check if location services are enabled
//   static Future<bool> isLocationServiceEnabled() async {
//     return await Geolocator.isLocationServiceEnabled();
//   }

//   /// Open location settings
//   static Future<bool> openLocationSettings() async {
//     return await Geolocator.openLocationSettings();
//   }

//   /// Open app settings for location permission
//   static Future<bool> openAppSettings() async {
//     return await Geolocator.openAppSettings();
//   }
// }
