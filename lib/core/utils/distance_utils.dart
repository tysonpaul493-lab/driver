import 'dart:math';

/// Utility methods for calculating geographic distances and ETAs
class DistanceUtils {
  /// Calculate Haversine distance in meters between two lat/lng coordinates
  static double calculateDistanceInMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double earthRadius = 6371000; // in meters
    final double dLat = _degreesToRadians(endLatitude - startLatitude);
    final double dLon = _degreesToRadians(endLongitude - startLongitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLatitude)) *
            cos(_degreesToRadians(endLatitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Format distance string (e.g. "850 m" or "4.2 km")
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Estimate time of arrival assuming urban ambulance speed ~35 km/h with siren
  static String estimateEta(double meters) {
    if (meters <= 0) return 'Arrived';
    const double averageSpeedKmh = 35.0; // Emergency speed
    final double hours = (meters / 1000) / averageSpeedKmh;
    final int minutes = (hours * 60).ceil();
    if (minutes < 1) return '< 1 min';
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    return '$minutes mins';
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
