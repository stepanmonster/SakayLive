import 'package:sakaylive/utils/geo_utils.dart';

/// Represents a vehicle's current position and status.
///
/// This model is used for:
/// - Real conductor GPS data (production)
/// - Mock/simulated bus data (testing)
///
/// Data flows:
/// 1. Conductor broadcasts position via ConductorTrackingService
/// 2. Position is stored in Firebase at 'vehicles/{busId}'
/// 3. Passengers receive updates via VehicleTrackingService
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
  final String occupancy; // 'green' (seats), 'yellow' (standing), 'red' (full)

  // Direction index (0 or 1) - which direction the bus is traveling
  final int directionIndex;

  // Extended conductor data (for real trips)
  final String? conductorId;
  final String? tripId;
  final double? speed;
  final double? accuracy;
  final bool isRealConductor;

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
    this.occupancy = 'green',
    this.directionIndex = 0,
    this.conductorId,
    this.tripId,
    this.speed,
    this.accuracy,
    this.isRealConductor = false,
  });

  /// Convert to JSON for Firebase
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
      'occupancy': occupancy,
      'direction_index': directionIndex,
      if (conductorId != null) 'conductor_id': conductorId,
      if (tripId != null) 'trip_id': tripId,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
      'is_real_conductor': isRealConductor,
    };
  }

  /// Create from Firebase Data
  factory VehiclePosition.fromMap(String id, Map<dynamic, dynamic> map) {
    return VehiclePosition(
      id: id,
      routeId: map['route_id']?.toString() ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] ?? 0,
      passengerCount: map['passenger_count'],
      driverName: map['driver_name'],
      plateNumber: map['plate_number'],
      occupancy: map['occupancy'] ?? 'green',
      directionIndex: map['direction_index'] ?? 0,
      conductorId: map['conductor_id'],
      tripId: map['trip_id'],
      speed: (map['speed'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      isRealConductor:
          map['is_real_conductor'] == true || map['conductor_id'] != null,
    );
  }

  /// Create a copy with updated fields
  VehiclePosition copyWith({
    String? id,
    String? routeId,
    double? lat,
    double? lng,
    double? heading,
    int? timestamp,
    int? passengerCount,
    String? driverName,
    String? plateNumber,
    String? occupancy,
    int? directionIndex,
    String? conductorId,
    String? tripId,
    double? speed,
    double? accuracy,
    bool? isRealConductor,
  }) {
    return VehiclePosition(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      passengerCount: passengerCount ?? this.passengerCount,
      driverName: driverName ?? this.driverName,
      plateNumber: plateNumber ?? this.plateNumber,
      occupancy: occupancy ?? this.occupancy,
      directionIndex: directionIndex ?? this.directionIndex,
      conductorId: conductorId ?? this.conductorId,
      tripId: tripId ?? this.tripId,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      isRealConductor: isRealConductor ?? this.isRealConductor,
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

  /// Get occupancy status text for display
  String get occupancyText {
    switch (occupancy) {
      case 'red':
        return 'Full';
      case 'yellow':
        return 'Standing Only';
      case 'green':
      default:
        return 'Seats Available';
    }
  }

  /// Get accessibility-friendly label with symbol
  String get occupancyLabel {
    switch (occupancy) {
      case 'red':
        return 'Full';
      case 'yellow':
        return 'Standing';
      case 'green':
      default:
        return 'Available';
    }
  }

  /// Get speed in km/h
  String get speedText {
    if (speed == null) return 'N/A';
    final kmh = speed! * 3.6; // m/s to km/h
    return '${kmh.toStringAsFixed(0)} km/h';
  }

  /// Get GPS accuracy text
  String get accuracyText {
    if (accuracy == null) return 'N/A';
    if (accuracy! < 10) return 'Excellent';
    if (accuracy! < 30) return 'Good';
    if (accuracy! < 100) return 'Fair';
    return 'Poor';
  }

  /// Check if this is verified conductor data
  bool get isVerified => isRealConductor && conductorId != null;

  /// Get source label for UI
  String get sourceLabel {
    if (isVerified) return 'Live Conductor';
    if (id.startsWith('fake_') ||
        id.startsWith('moving_') ||
        id.startsWith('ghost_')) {
      return 'Simulated';
    }
    return 'Unknown';
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

  /// Check if this is a real conductor (not simulated)
  bool get isRealConductor => position.isRealConductor;

  /// Get a short label for the bus
  String get shortLabel {
    final eta = etaMinutes != null ? '~$etaMinutes min' : '';
    return '${position.id} $eta'.trim();
  }
}
