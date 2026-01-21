import 'package:sakaylive/utils/geo_utils.dart';

class VehiclePosition {
  final String id;
  final String routeId;
  final double lat;
  final double lng;
  final double heading;
  final int timestamp;
  final int? passengerCount;
  final String? driverName;
  final String? plateNumber;

  VehiclePosition({
    required this.id,
    required this.routeId,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.timestamp,
    this.passengerCount,
    this.driverName,
    this.plateNumber,
  });

  // Convert to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'timestamp': timestamp,
      'passenger_count': passengerCount,
      'driver_name': driverName,
      'plate_number': plateNumber,
    };
  }

  // Create from Firebase Data
  factory VehiclePosition.fromMap(String id, Map<dynamic, dynamic> map) {
    return VehiclePosition(
      id: id,
      routeId: map['route_id'] ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] ?? 0,
      passengerCount: map['passenger_count'],
      driverName: map['driver_name'],
      plateNumber: map['plate_number'],
    );
  }

  /// Calculate distance to a point in meters
  double distanceTo(double targetLat, double targetLng) {
    return GeoUtils.fastDistance(lat, lng, targetLat, targetLng);
  }

  /// Check if this position is stale (older than threshold)
  bool isStale({int thresholdSeconds = 60}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) > (thresholdSeconds * 1000);
  }

  /// Get age of this position in seconds
  int get ageSeconds {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ((now - timestamp) / 1000).round();
  }

  /// Get human-readable last seen text
  String get lastSeenText {
    final age = ageSeconds;
    if (age < 10) return 'Just now';
    if (age < 60) return '${age}s ago';
    if (age < 3600) return '${(age / 60).round()}m ago';
    return 'Over 1h ago';
  }
}

/// Extended vehicle info with ETA calculations for UI display
class TrackedVehicle {
  final VehiclePosition position;
  final double distanceToUserMeters;
  final int? etaMinutes;
  final int? stopsAway;
  final String routeName;
  final String routeColor;
  final String direction;

  TrackedVehicle({
    required this.position,
    required this.distanceToUserMeters,
    this.etaMinutes,
    this.stopsAway,
    required this.routeName,
    required this.routeColor,
    required this.direction,
  });

  /// Format distance for display
  String get distanceText {
    if (distanceToUserMeters < 1000) {
      return '${distanceToUserMeters.round()}m away';
    }
    return '${(distanceToUserMeters / 1000).toStringAsFixed(1)}km away';
  }

  /// Format ETA for display
  String get etaText {
    if (etaMinutes == null) return 'Calculating...';
    if (etaMinutes! < 1) return 'Arriving now';
    if (etaMinutes! == 1) return '1 min';
    return '$etaMinutes mins';
  }

  /// Determine urgency level for UI styling
  String get urgencyLevel {
    if (etaMinutes == null) return 'unknown';
    if (etaMinutes! <= 2) return 'arriving';
    if (etaMinutes! <= 5) return 'soon';
    return 'normal';
  }
}
