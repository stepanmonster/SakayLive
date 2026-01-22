// lib/services/conductor_tracking_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sakaylive/models/vehicle_position.dart';

/// Configuration for conductor tracking behavior
class ConductorTrackingConfig {
  /// How often to send location updates (in seconds)
  final int updateIntervalSeconds;

  /// Minimum distance (meters) to move before sending an update
  final double minDistanceMeters;

  /// Accuracy requirement for GPS
  final geo.LocationAccuracy accuracy;

  /// Whether to keep tracking in background
  final bool enableBackground;

  const ConductorTrackingConfig({
    this.updateIntervalSeconds = 5,
    this.minDistanceMeters = 10,
    this.accuracy = geo.LocationAccuracy.high,
    this.enableBackground = true,
  });

  /// Production config - frequent updates, high accuracy
  static const production = ConductorTrackingConfig(
    updateIntervalSeconds: 3,
    minDistanceMeters: 5,
    accuracy: geo.LocationAccuracy.high,
    enableBackground: true,
  );

  /// Battery saver config - less frequent updates
  static const batterySaver = ConductorTrackingConfig(
    updateIntervalSeconds: 10,
    minDistanceMeters: 20,
    accuracy: geo.LocationAccuracy.medium,
    enableBackground: true,
  );

  /// Testing config - very frequent updates
  static const testing = ConductorTrackingConfig(
    updateIntervalSeconds: 2,
    minDistanceMeters: 3,
    accuracy: geo.LocationAccuracy.best,
    enableBackground: false,
  );
}

/// Tracks the conductor's current trip state
class ConductorTripState {
  final String tripId;
  final String busId;
  final String routeId;
  final String conductorId;
  final String conductorName;
  final String occupancyStatus; // 'green', 'yellow', 'red'
  final DateTime startTime;
  final int passengerCount;
  final double? lastLat;
  final double? lastLng;
  final double? lastHeading;
  final DateTime? lastUpdateTime;
  final double totalDistanceMeters;
  final int updateCount;

  ConductorTripState({
    required this.tripId,
    required this.busId,
    required this.routeId,
    required this.conductorId,
    required this.conductorName,
    this.occupancyStatus = 'green',
    required this.startTime,
    this.passengerCount = 0,
    this.lastLat,
    this.lastLng,
    this.lastHeading,
    this.lastUpdateTime,
    this.totalDistanceMeters = 0,
    this.updateCount = 0,
  });

  ConductorTripState copyWith({
    String? occupancyStatus,
    int? passengerCount,
    double? lastLat,
    double? lastLng,
    double? lastHeading,
    DateTime? lastUpdateTime,
    double? totalDistanceMeters,
    int? updateCount,
  }) {
    return ConductorTripState(
      tripId: tripId,
      busId: busId,
      routeId: routeId,
      conductorId: conductorId,
      conductorName: conductorName,
      occupancyStatus: occupancyStatus ?? this.occupancyStatus,
      startTime: startTime,
      passengerCount: passengerCount ?? this.passengerCount,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastHeading: lastHeading ?? this.lastHeading,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      updateCount: updateCount ?? this.updateCount,
    );
  }

  Duration get tripDuration => DateTime.now().difference(startTime);

  String get tripDurationText {
    final d = tripDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${h}h ${m}m";
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'bus_id': busId,
      'route_id': routeId,
      'conductor_id': conductorId,
      'conductor_name': conductorName,
      'occupancy': occupancyStatus,
      'start_time': startTime.millisecondsSinceEpoch,
      'passenger_count': passengerCount,
      'last_lat': lastLat,
      'last_lng': lastLng,
      'last_heading': lastHeading,
      'last_update': lastUpdateTime?.millisecondsSinceEpoch,
      'total_distance_m': totalDistanceMeters,
      'update_count': updateCount,
    };
  }
}

/// Service for broadcasting conductor's GPS location to Firebase.
///
/// This service handles:
/// - GPS location tracking with configurable intervals
/// - Broadcasting position updates to Firebase Realtime Database
/// - Managing trip lifecycle (start/end)
/// - Occupancy status updates
/// - Trip statistics and history
///
/// Usage:
/// ```dart
/// final service = ConductorTrackingService(database);
/// await service.startTrip(busId: 'E-Bus 01', routeId: '3', conductorId: 'abc123');
/// service.updateOccupancy('yellow');
/// await service.endTrip();
/// ```
class ConductorTrackingService {
  final FirebaseDatabase _database;
  final ConductorTrackingConfig _config;

  // Location tracking
  StreamSubscription<geo.Position>? _locationSubscription;
  geo.Position? _lastPosition;

  // Trip state
  ConductorTripState? _currentTrip;
  bool _isBroadcasting = false;

  // Callbacks
  Function(ConductorTripState)? onTripUpdated;
  Function(String)? onError;
  Function(geo.Position)? onLocationUpdated;

  ConductorTrackingService(this._database, {ConductorTrackingConfig? config})
    : _config = config ?? ConductorTrackingConfig.production;

  // --- GETTERS ---
  bool get isActive => _isBroadcasting && _currentTrip != null;
  ConductorTripState? get currentTrip => _currentTrip;
  geo.Position? get lastPosition => _lastPosition;
  ConductorTrackingConfig get config => _config;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError?.call('Location services are disabled. Please enable GPS.');
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        onError?.call('Location permissions are denied.');
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      onError?.call(
        'Location permissions are permanently denied. Please enable in settings.',
      );
      return false;
    }

    return true;
  }

  /// Start a new trip and begin GPS broadcasting
  ///
  /// [busId] - The bus identifier (e.g., "E-Bus 01")
  /// [routeId] - The route number (e.g., "3")
  /// [conductorId] - The conductor's user ID from Firebase Auth
  /// [conductorName] - Display name of the conductor
  Future<bool> startTrip({
    required String busId,
    required String routeId,
    required String conductorId,
    required String conductorName,
  }) async {
    if (_isBroadcasting) {
      debugPrint('⚠️ Trip already in progress');
      return false;
    }

    // Check permissions first
    final hasPermission = await checkPermissions();
    if (!hasPermission) return false;

    // Generate unique trip ID
    final tripId = '${conductorId}_${DateTime.now().millisecondsSinceEpoch}';

    // Create trip state
    _currentTrip = ConductorTripState(
      tripId: tripId,
      busId: busId,
      routeId: routeId,
      conductorId: conductorId,
      conductorName: conductorName,
      startTime: DateTime.now(),
    );

    // Start location tracking
    await _startLocationTracking();

    _isBroadcasting = true;
    debugPrint('🚌 Trip started: $busId on Route $routeId');

    // Notify UI
    onTripUpdated?.call(_currentTrip!);

    return true;
  }

  /// Start listening to GPS location updates
  Future<void> _startLocationTracking() async {
    final locationSettings = geo.LocationSettings(
      accuracy: _config.accuracy,
      distanceFilter: _config.minDistanceMeters.round(),
    );

    // Get initial position
    try {
      _lastPosition = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(accuracy: _config.accuracy),
      );

      // Send initial position
      await _broadcastPosition(_lastPosition!);
    } catch (e) {
      debugPrint('⚠️ Failed to get initial position: $e');
    }

    // Start continuous tracking
    _locationSubscription =
        geo.Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          _handleLocationUpdate,
          onError: (error) {
            debugPrint('🔴 Location error: $error');
            onError?.call('GPS error: $error');
          },
        );
  }

  /// Handle incoming location updates
  void _handleLocationUpdate(geo.Position position) async {
    if (!_isBroadcasting || _currentTrip == null) return;

    // Calculate distance traveled (if we have previous position)
    double distanceTraveled = 0;
    if (_lastPosition != null) {
      distanceTraveled = geo.Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }

    _lastPosition = position;
    onLocationUpdated?.call(position);

    // Broadcast to Firebase
    await _broadcastPosition(position, distanceDelta: distanceTraveled);
  }

  /// Send position update to Firebase
  Future<void> _broadcastPosition(
    geo.Position position, {
    double distanceDelta = 0,
  }) async {
    if (_currentTrip == null) return;

    final now = DateTime.now();

    // Update trip state
    _currentTrip = _currentTrip!.copyWith(
      lastLat: position.latitude,
      lastLng: position.longitude,
      lastHeading: position.heading,
      lastUpdateTime: now,
      totalDistanceMeters: _currentTrip!.totalDistanceMeters + distanceDelta,
      updateCount: _currentTrip!.updateCount + 1,
    );

    // Create vehicle position for passengers to see
    final vehicleData = VehiclePosition(
      id: _currentTrip!.busId,
      routeId: _currentTrip!.routeId,
      lat: position.latitude,
      lng: position.longitude,
      heading: position.heading,
      timestamp: now.millisecondsSinceEpoch,
      passengerCount: _currentTrip!.passengerCount,
      driverName: _currentTrip!.conductorName,
      plateNumber: _currentTrip!.busId, // Use busId as plate for now
      occupancy: _currentTrip!.occupancyStatus,
    ).toJson();

    // Add conductor-specific metadata
    vehicleData['conductor_id'] = _currentTrip!.conductorId;
    vehicleData['trip_id'] = _currentTrip!.tripId;
    vehicleData['speed'] = position.speed;
    vehicleData['accuracy'] = position.accuracy;

    try {
      // Update vehicle position (what passengers see)
      await _database.ref('vehicles/${_currentTrip!.busId}').set(vehicleData);

      // Also update active trip record (for analytics)
      await _database
          .ref('activeTrips/${_currentTrip!.tripId}')
          .set(_currentTrip!.toJson());

      debugPrint(
        '📍 Position sent: ${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)} '
        '(Update #${_currentTrip!.updateCount})',
      );
    } catch (e) {
      debugPrint('🔴 Firebase error: $e');
      onError?.call('Failed to send location: $e');
    }

    // Notify UI
    onTripUpdated?.call(_currentTrip!);
  }

  /// Update the occupancy status
  void updateOccupancy(String status) {
    if (_currentTrip == null) return;

    _currentTrip = _currentTrip!.copyWith(occupancyStatus: status);

    // Immediately broadcast the change
    if (_lastPosition != null) {
      _broadcastPosition(_lastPosition!);
    }

    debugPrint('🚌 Occupancy updated: $status');
    onTripUpdated?.call(_currentTrip!);
  }

  /// Update passenger count (optional feature)
  void updatePassengerCount(int count) {
    if (_currentTrip == null) return;

    _currentTrip = _currentTrip!.copyWith(passengerCount: count);
    onTripUpdated?.call(_currentTrip!);
  }

  /// End the current trip
  Future<void> endTrip() async {
    if (_currentTrip == null) return;

    // Stop location tracking
    _locationSubscription?.cancel();
    _locationSubscription = null;

    // Save trip to history
    await _saveTripToHistory();

    // Remove from active vehicles
    try {
      await _database.ref('vehicles/${_currentTrip!.busId}').remove();
      await _database.ref('activeTrips/${_currentTrip!.tripId}').remove();
    } catch (e) {
      debugPrint('⚠️ Error cleaning up trip: $e');
    }

    final tripDuration = _currentTrip!.tripDurationText;
    final totalDistance = (_currentTrip!.totalDistanceMeters / 1000)
        .toStringAsFixed(2);

    debugPrint(
      '🏁 Trip ended: Duration $tripDuration, Distance ${totalDistance}km',
    );

    _isBroadcasting = false;
    _currentTrip = null;
    _lastPosition = null;
  }

  /// Save completed trip to history for analytics
  Future<void> _saveTripToHistory() async {
    if (_currentTrip == null) return;

    final historyData = {
      ..._currentTrip!.toJson(),
      'end_time': DateTime.now().millisecondsSinceEpoch,
      'duration_seconds': _currentTrip!.tripDuration.inSeconds,
    };

    try {
      await _database
          .ref(
            'tripHistory/${_currentTrip!.conductorId}/${_currentTrip!.tripId}',
          )
          .set(historyData);

      debugPrint('📊 Trip saved to history');
    } catch (e) {
      debugPrint('⚠️ Failed to save trip history: $e');
    }
  }

  /// Force send current location (for manual refresh)
  Future<void> forceUpdate() async {
    if (!_isBroadcasting) return;

    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(accuracy: _config.accuracy),
      );
      await _broadcastPosition(position);
    } catch (e) {
      debugPrint('⚠️ Force update failed: $e');
    }
  }

  /// Get trip history for a conductor
  Future<List<Map<String, dynamic>>> getTripHistory(String conductorId) async {
    try {
      final snapshot = await _database
          .ref('tripHistory/$conductorId')
          .orderByChild('end_time')
          .limitToLast(50)
          .get();

      if (snapshot.value == null) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      return data.values
          .map((trip) => Map<String, dynamic>.from(trip as Map))
          .toList()
        ..sort((a, b) => (b['end_time'] ?? 0).compareTo(a['end_time'] ?? 0));
    } catch (e) {
      debugPrint('⚠️ Failed to load trip history: $e');
      return [];
    }
  }

  /// Clean up resources
  void dispose() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isBroadcasting = false;
  }
}
