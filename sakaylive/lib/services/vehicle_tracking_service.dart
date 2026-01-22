import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sakaylive/models/vehicle_position.dart';
import 'package:sakaylive/models/cached_route.dart';
import 'package:sakaylive/utils/geo_utils.dart';

/// Service for tracking live vehicle positions and calculating ETAs.
class VehicleTrackingService {
  final FirebaseDatabase _database;
  StreamSubscription? _vehicleSubscription;

  // Callback for when vehicles are updated
  Function(List<TrackedVehicle>)? onVehiclesUpdated;

  // Current tracked vehicles
  final List<VehiclePosition> _rawVehicles = [];
  List<TrackedVehicle> _trackedVehicles = [];

  // User's current position (for ETA calculations)
  double? _userLat;
  double? _userLng;

  // Route data for matching vehicles to routes
  List<CachedRoute> _cachedRoutes = [];
  List<Map<String, dynamic>> _routeMetadata = [];

  VehicleTrackingService(this._database);

  /// Set user location for distance/ETA calculations
  void setUserLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _recalculateTrackedVehicles();
  }

  /// Set route data for route matching
  void setRouteData(
    List<CachedRoute> cachedRoutes,
    List<Map<String, dynamic>> routeMetadata,
  ) {
    _cachedRoutes = cachedRoutes;
    _routeMetadata = routeMetadata;
  }

  /// Start listening to live vehicle updates
  void startListening() {
    _vehicleSubscription?.cancel();

    final ref = _database.ref('vehicles');

    _vehicleSubscription = ref.onValue.listen((event) {
      if (event.snapshot.value == null) {
        _rawVehicles.clear();
        _trackedVehicles.clear();
        onVehiclesUpdated?.call([]);
        return;
      }

      final rawData = event.snapshot.value as Map<dynamic, dynamic>;
      _rawVehicles.clear();

      rawData.forEach((key, value) {
        final vehicle = VehiclePosition.fromMap(key.toString(), value);
        // FILTER: Skip stale/ghost buses (older than 30 minutes for testing, 5 min for production)
        // This prevents "ghost buses" from appearing on the map
        // TODO: Change to 300 (5 min) for production
        const staleThreshold = 1800; // 30 minutes for testing
        if (vehicle.isStale(thresholdSeconds: staleThreshold)) {
          debugPrint(
            '👻 Skipping stale bus ${vehicle.id} (last seen: ${vehicle.lastSeenText})',
          );
          return; // Skip this vehicle
        }
        _rawVehicles.add(vehicle);
      });

      _recalculateTrackedVehicles();
    });
  }

  /// Stop listening to vehicle updates
  void stopListening() {
    _vehicleSubscription?.cancel();
    _vehicleSubscription = null;
  }

  /// Recalculate all tracked vehicles with distances and ETAs
  void _recalculateTrackedVehicles() {
    if (_userLat == null || _userLng == null) {
      _trackedVehicles = _rawVehicles
          .map((v) => _createTrackedVehicle(v))
          .toList();
    } else {
      _trackedVehicles = _rawVehicles
          .map((v) => _createTrackedVehicle(v))
          .toList();
      // Sort by distance (nearest first)
      _trackedVehicles.sort(
        (a, b) => a.distanceToUserMeters.compareTo(b.distanceToUserMeters),
      );
    }

    onVehiclesUpdated?.call(_trackedVehicles);
  }

  /// Create a TrackedVehicle with all calculated fields
  TrackedVehicle _createTrackedVehicle(VehiclePosition vehicle) {
    // Calculate distance to user
    double distance = 0;
    if (_userLat != null && _userLng != null) {
      distance = vehicle.distanceTo(_userLat!, _userLng!);
    }

    // Find route metadata
    final routeData = _findRouteData(vehicle.routeId);
    final routeName = routeData?['dest'] ?? 'Route ${vehicle.routeId}';
    final routeColor = routeData?['color'] ?? 'blue';
    final direction = _getDirectionName(routeData, vehicle);

    // Calculate ETA (simple estimation based on distance)
    // Assume average jeepney speed of 20 km/h in city traffic
    int? eta;
    int? stopsAway;

    if (_userLat != null && _userLng != null) {
      // Find the route and calculate ETA along the route
      final routeEta = _calculateRouteBasedETA(vehicle, _userLat!, _userLng!);
      eta = routeEta.eta;
      stopsAway = routeEta.stops;
    }

    return TrackedVehicle(
      position: vehicle,
      distanceToUserMeters: distance,
      etaMinutes: eta,
      stopsAway: stopsAway,
      routeName: routeName,
      routeColor: routeColor,
      direction: direction,
    );
  }

  /// Find route metadata by route ID
  Map<String, dynamic>? _findRouteData(String routeId) {
    try {
      return _routeMetadata.firstWhere((r) => r['num'].toString() == routeId);
    } catch (_) {
      return null;
    }
  }

  /// Get direction name from route data
  String _getDirectionName(
    Map<String, dynamic>? routeData,
    VehiclePosition vehicle,
  ) {
    if (routeData == null) return 'Unknown';

    final directions = routeData['directions'] as List?;
    if (directions == null || directions.isEmpty) return 'Unknown';

    // Try to determine direction based on heading or default to first direction
    // In a real app, you'd track which direction the vehicle is going
    final activeDir = routeData['activeDir'] ?? 0;
    if (activeDir < directions.length) {
      return directions[activeDir]['name'] ?? 'Unknown';
    }
    return directions[0]['name'] ?? 'Unknown';
  }

  /// Calculate ETA based on route path (more accurate than straight-line distance)
  ({int? eta, int? stops}) _calculateRouteBasedETA(
    VehiclePosition vehicle,
    double userLat,
    double userLng,
  ) {
    // Find the cached route that matches this vehicle
    CachedRoute? matchedRoute;
    int vehiclePointIndex = -1;
    int userPointIndex = -1;
    double minVehicleDist = double.infinity;
    double minUserDist = double.infinity;

    for (var route in _cachedRoutes) {
      if (route.routeNum != vehicle.routeId) continue;

      // Find closest point on route to vehicle
      for (int i = 0; i < route.coordinates.length; i++) {
        final coord = route.coordinates[i];
        final distToVehicle = GeoUtils.fastDistance(
          vehicle.lat,
          vehicle.lng,
          coord[1],
          coord[0],
        );

        if (distToVehicle < minVehicleDist) {
          minVehicleDist = distToVehicle;
          vehiclePointIndex = i;
          matchedRoute = route;
        }
      }
    }

    if (matchedRoute == null || vehiclePointIndex == -1) {
      // Fallback: simple distance-based ETA
      final distance = vehicle.distanceTo(userLat, userLng);
      // Average speed 20 km/h = 333 m/min
      return (eta: (distance / 333).ceil(), stops: null);
    }

    // Find closest point on route to user
    for (int i = 0; i < matchedRoute.coordinates.length; i++) {
      final coord = matchedRoute.coordinates[i];
      final distToUser = GeoUtils.fastDistance(
        userLat,
        userLng,
        coord[1],
        coord[0],
      );

      if (distToUser < minUserDist) {
        minUserDist = distToUser;
        userPointIndex = i;
      }
    }

    // Check if vehicle is approaching user (vehicle index < user index)
    if (vehiclePointIndex >= userPointIndex) {
      // Vehicle has passed or is at user location
      return (eta: 0, stops: 0);
    }

    // Calculate distance along route from vehicle to user
    double routeDistance = 0;
    int stopCount = 0;

    for (int i = vehiclePointIndex; i < userPointIndex; i++) {
      final from = matchedRoute.coordinates[i];
      final to = matchedRoute.coordinates[i + 1];
      routeDistance += GeoUtils.fastDistance(from[1], from[0], to[1], to[0]);

      // Count stops (roughly every 10 points = 1 stop)
      if ((i - vehiclePointIndex) % 10 == 0) {
        stopCount++;
      }
    }

    // Calculate ETA: average speed 20 km/h = 333 m/min
    // Add 30 seconds per stop for loading/unloading
    final baseEta = (routeDistance / 333).ceil();
    final stopDelay = (stopCount * 0.5).ceil();

    return (eta: baseEta + stopDelay, stops: stopCount);
  }

  /// Get all tracked vehicles
  List<TrackedVehicle> get trackedVehicles => _trackedVehicles;

  /// Get vehicles for a specific route
  List<TrackedVehicle> getVehiclesForRoute(String routeId) {
    return _trackedVehicles
        .where((v) => v.position.routeId == routeId)
        .toList();
  }

  /// Get the nearest vehicle overall
  TrackedVehicle? get nearestVehicle {
    if (_trackedVehicles.isEmpty) return null;
    return _trackedVehicles.first;
  }

  /// Get the nearest vehicle for a specific route
  TrackedVehicle? getNearestVehicleForRoute(String routeId) {
    final routeVehicles = getVehiclesForRoute(routeId);
    if (routeVehicles.isEmpty) return null;
    return routeVehicles.first;
  }

  /// Get count of active vehicles
  int get activeVehicleCount => _trackedVehicles.length;

  /// Get count of vehicles for a specific route
  int getVehicleCountForRoute(String routeId) {
    return _trackedVehicles.where((v) => v.position.routeId == routeId).length;
  }

  /// Cleanup
  void dispose() {
    stopListening();
  }
}
