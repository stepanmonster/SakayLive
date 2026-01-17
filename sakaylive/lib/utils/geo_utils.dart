import 'dart:math';

/// Utility class for geographic calculations.
class GeoUtils {
  /// Maximum walking distance in meters for pickup/dropoff points.
  static const double maxWalkDistanceMeters = 1000.0;

  /// Transfer tolerance in meters (how close routes must be for transfer).
  static const double transferToleranceMeters = 150.0;

  /// Haversine formula optimized for speed (no platform channel overhead).
  /// Returns distance in meters between two lat/lng points.
  static double fastDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // PI / 180
    final c = cos;
    final a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R * asin(sqrt(a)) in meters
  }

  /// Estimate travel time based on number of route nodes.
  /// Rough estimate: ~0.15 min per node + 5 min wait time.
  static int estimateTravelTime(int nodeCount) {
    return (nodeCount * 0.15).ceil() + 5;
  }

  /// Calculate midpoint between two coordinates.
  static ({double lat, double lng}) midpoint(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return (lat: (lat1 + lat2) / 2, lng: (lng1 + lng2) / 2);
  }
}
