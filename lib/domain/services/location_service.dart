import 'package:geolocator/geolocator.dart';
import '../../core/utils/geofence_utils.dart';

enum LocationSimulationMode {
  disabled,
  atOffice, // 0m
  withinGeofence, // ~120m
  outsideGeofence, // ~450m
  custom,
}

class LocationCheckResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final bool isWithinGeofence;
  final String? errorMessage;
  final bool isPermanentlyDenied;
  final bool isServiceDisabled;
  final bool isSimulated;

  const LocationCheckResult({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.isWithinGeofence = false,
    this.errorMessage,
    this.isPermanentlyDenied = false,
    this.isServiceDisabled = false,
    this.isSimulated = false,
  });
}

class LocationService {
  LocationSimulationMode simulationMode = LocationSimulationMode.disabled;
  double customLat = 10.0159;
  double customLng = 76.3419;

  void setSimulationMode(LocationSimulationMode mode, {double? lat, double? lng}) {
    simulationMode = mode;
    if (lat != null) customLat = lat;
    if (lng != null) customLng = lng;
  }

  /// Evaluates device location or simulation against the office coordinates and geofence.
  Future<LocationCheckResult> checkGeofence({
    required double officeLat,
    required double officeLng,
    double radiusMeters = 200.0,
  }) async {
    // 1. Reviewer Simulation Mode
    if (simulationMode != LocationSimulationMode.disabled) {
      double simulatedLat = officeLat;
      double simulatedLng = officeLng;

      switch (simulationMode) {
        case LocationSimulationMode.atOffice:
          simulatedLat = officeLat;
          simulatedLng = officeLng;
          break;
        case LocationSimulationMode.withinGeofence:
          // ~120m north (1 degree latitude is approx 111,000 meters; 120m is ~0.00108 deg)
          simulatedLat = officeLat + 0.00108;
          simulatedLng = officeLng;
          break;
        case LocationSimulationMode.outsideGeofence:
          // ~450m north (~0.00405 deg)
          simulatedLat = officeLat + 0.00405;
          simulatedLng = officeLng;
          break;
        case LocationSimulationMode.custom:
          simulatedLat = customLat;
          simulatedLng = customLng;
          break;
        case LocationSimulationMode.disabled:
          break;
      }

      final distance = GeofenceUtils.calculateDistanceMeters(
        simulatedLat,
        simulatedLng,
        officeLat,
        officeLng,
      );

      final inside = distance <= radiusMeters;
      return LocationCheckResult(
        isSuccess: true,
        latitude: simulatedLat,
        longitude: simulatedLng,
        distanceMeters: distance,
        isWithinGeofence: inside,
        isSimulated: true,
        errorMessage: inside
            ? null
            : 'You are ${distance.toStringAsFixed(1)}m from the office. Permitted radius is ${radiusMeters.toInt()}m.',
      );
    }

    // 2. Hardware GPS via Geolocator
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      return LocationCheckResult(
        isSuccess: false,
        isServiceDisabled: true,
        errorMessage: 'Location services are disabled on this device. Please turn on GPS.',
      );
    }

    if (!serviceEnabled) {
      return const LocationCheckResult(
        isSuccess: false,
        isServiceDisabled: true,
        errorMessage: 'Location services are disabled. Please enable GPS in device settings.',
      );
    }

    // Check permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationCheckResult(
          isSuccess: false,
          errorMessage: 'Location permission was denied. Location is required to verify office proximity.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationCheckResult(
        isSuccess: false,
        isPermanentlyDenied: true,
        errorMessage: 'Location permission is permanently denied. Please grant location access in App Settings.',
      );
    }

    // Acquire current GPS position
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = GeofenceUtils.calculateDistanceMeters(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      final inside = distance <= radiusMeters;
      return LocationCheckResult(
        isSuccess: true,
        latitude: position.latitude,
        longitude: position.longitude,
        distanceMeters: distance,
        isWithinGeofence: inside,
        isSimulated: false,
        errorMessage: inside
            ? null
            : 'You are ${distance.toStringAsFixed(1)}m away from the office. Permitted radius is ${radiusMeters.toInt()}m.',
      );
    } catch (e) {
      return LocationCheckResult(
        isSuccess: false,
        errorMessage: 'Failed to acquire GPS fix: ${e.toString()}',
      );
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
