import 'dart:math' as math;

class GeofenceUtils {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculates the distance in meters between two coordinates using the Haversine formula.
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Checks if coordinates are within the specified radius (default 200m).
  static bool isWithinGeofence(
    double currentLat,
    double currentLon,
    double officeLat,
    double officeLon, {
    double radiusMeters = 200.0,
  }) {
    final distance = calculateDistanceMeters(
      currentLat,
      currentLon,
      officeLat,
      officeLon,
    );
    return distance <= radiusMeters;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}
