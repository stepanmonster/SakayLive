import 'package:flutter/material.dart'
    show ChangeNotifier, Color, Colors, debugPrint;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_search/mapbox_search.dart' hide Color;
import 'package:uuid/uuid.dart';
import 'package:sakaylive/data/jeepney_routes.dart';
import 'package:sakaylive/models/trip_option.dart';
import 'package:sakaylive/models/cached_route.dart';
import 'package:sakaylive/services/route_service.dart';
import 'package:sakaylive/services/map_drawing_service.dart';
import 'package:sakaylive/services/vehicle_tracking_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:sakaylive/services/auth_service.dart';
import 'package:flutter/services.dart'; // for rootBundle
import 'dart:async';
import 'package:sakaylive/models/vehicle_position.dart';

/// ViewModel for the Map Screen following MVVM pattern.
/// Contains all business logic and state management.
class MapViewModel extends ChangeNotifier {
  /// Clear the cached user location (for mode switching)
  void clearUserLocation() {
    _userLocation = null;
    notifyListeners();
  }

  // --- SERVICES ---
  final RouteService _routeService = RouteService();
  final MapDrawingService _mapDrawingService = MapDrawingService();
  VehicleTrackingService? _vehicleTrackingService;
  MapboxMap? _map;

  // --- FIREBASE ---
  late final FirebaseDatabase _database;

  // --- API ---
  late SearchBoxAPI _searchBoxApi;
  String _sessionToken = const Uuid().v4();

  // --- MOCK LOCATION FOR TESTING ---
  // Set to true to use fake location instead of real GPS
  // In production, set this to false to use real GPS
  bool _useDemoMode = true; // Mutable - can be toggled at runtime
  // PHV6+497, Quintin Salas St, Jaro, Iloilo City, 5000 Iloilo
  static const double mockLatitude = 10.7244;
  static const double mockLongitude = 122.5575;

  // Getter and setter for demo mode
  bool get useDemoMode => _useDemoMode;
  void setDemoMode(bool value) {
    _useDemoMode = value;
    notifyListeners();
  }

  // --- BUS DATA MODE ---
  // Set to true to use mock/simulated buses, false for real conductor data only
  static const bool useMockBuses = true;

  // --- STATE ---
  bool _isInitialized = false;
  bool _isFetchingLocation = false;
  geo.Position? _userLocation;
  Point? _destinationPoint;
  String? _selectedRouteNum;
  String?
  _currentRouteWithLandmarks; // Track which route has landmarks displayed
  int?
  _selectedDirectionIndex; // 0 or 1 - which direction the trip is traveling
  String _searchText = '';
  List<Map<String, dynamic>> _cachedRoutes = []; // 🔥 FIREBASE ROUTES
  List<Map<String, dynamic>> _displayList = [];

  // --- TRIP STATISTICS ---
  Map<String, dynamic>? _activeTripStats;

  // --- LIVE VEHICLE TRACKING ---
  List<TrackedVehicle> _trackedVehicles = [];
  bool _isTrackingEnabled = false;

  // --- BUS VISIBILITY CONTROL ---
  bool _showAllBuses =
      true; // Show all buses by default (set to false for cleaner map in production)
  String? _highlightedVehicleId; // ID of the "nearest bus" to highlight
  bool _showOnlyRealConductors =
      false; // Filter to show only verified conductor buses

  // --- TAPPED BUS STATE (for showing bus info card) ---
  TrackedVehicle? _tappedVehicle;

  // --- GETTERS ---
  bool get isInitialized => _isInitialized;
  bool get isRoutesLoaded => _cachedRoutes.isNotEmpty; // 🔥 CHANGED
  bool get isFetchingLocation => _isFetchingLocation;
  geo.Position? get userLocation => _userLocation;
  Point? get destinationPoint => _destinationPoint;
  String? get selectedRouteNum => _selectedRouteNum;
  String get searchText => _searchText;
  List<Map<String, dynamic>> get displayList => _displayList;
  List<Map<String, dynamic>> get localRoutes => _cachedRoutes; // 🔥 CHANGED
  SearchBoxAPI get searchBoxApi => _searchBoxApi;
  MapDrawingService get mapDrawingService => _mapDrawingService;
  String get sessionToken => _sessionToken;
  Map<String, dynamic>? get activeTripStats => _activeTripStats;
  bool get hasActiveTrip => _activeTripStats != null;

  // --- VEHICLE TRACKING GETTERS ---
  List<TrackedVehicle> get trackedVehicles => _trackedVehicles;
  bool get isTrackingEnabled => _isTrackingEnabled;
  bool get showAllBuses => _showAllBuses;
  bool get showOnlyRealConductors => _showOnlyRealConductors;
  TrackedVehicle? get nearestVehicle =>
      _trackedVehicles.isNotEmpty ? _trackedVehicles.first : null;
  int get activeVehicleCount => _trackedVehicles.length;

  /// Count of real conductor buses (not simulated)
  int get realConductorCount =>
      _trackedVehicles.where((v) => v.isRealConductor).length;

  /// Count of simulated buses
  int get simulatedBusCount =>
      _trackedVehicles.where((v) => !v.isRealConductor).length;

  /// Currently tapped/selected bus (for showing info card)
  TrackedVehicle? get tappedVehicle => _tappedVehicle;
  bool get hasTappedVehicle => _tappedVehicle != null;

  /// Get nearest vehicle for the currently selected route
  TrackedVehicle? get nearestVehicleForSelectedRoute {
    if (_selectedRouteNum == null) return null;
    return _vehicleTrackingService?.getNearestVehicleForRoute(
      _selectedRouteNum!,
    );
  }

  /// Get all vehicles for the currently selected route
  List<TrackedVehicle> get vehiclesForSelectedRoute {
    if (_selectedRouteNum == null) return [];
    return _vehicleTrackingService?.getVehiclesForRoute(_selectedRouteNum!) ??
        [];
  }

  MapViewModel() {
    _initializeApi();
    _displayList = List.from(_cachedRoutes);
  }

  void _initializeApi() {
    final String token = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');
    if (token.isNotEmpty) {
      MapBoxSearch.init(token);
      _searchBoxApi = SearchBoxAPI(limit: 5, country: 'PH');
    } else {
      debugPrint("⚠️ WARNING: Mapbox Access Token missing");
      _searchBoxApi = SearchBoxAPI(limit: 5);
    }
  }

  /// 🔥 NEW: Initialize Firebase + Load Routes
  Future<void> initializeFirebase() async {
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://sakaylive-1-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
    await loadRoutesFromFirebase();

    // Initialize vehicle tracking service
    _vehicleTrackingService = VehicleTrackingService(_database);
    _vehicleTrackingService!.onVehiclesUpdated = _onVehiclesUpdated;
  }

  /// Handle vehicle updates from tracking service
  void _onVehiclesUpdated(List<TrackedVehicle> vehicles) {
    _trackedVehicles = vehicles;
    debugPrint('📍 Received ${vehicles.length} vehicles from tracking service');
    notifyListeners();

    // Also update markers on map if tracking is enabled
    if (_isTrackingEnabled && _isInitialized) {
      debugPrint('🎨 Redrawing vehicle markers...');
      _drawVehicleMarkers();
    } else {
      debugPrint(
        '⚠️ Skipping marker draw: tracking=$_isTrackingEnabled, initialized=$_isInitialized',
      );
    }
  }

  /// Maximum distance (in meters) to show buses when no route is selected
  static const double _nearbyBusRadiusMeters = 2000; // 2km

  /// Toggle to show only real conductor buses (not simulated)
  void setShowOnlyRealConductors(bool value) {
    _showOnlyRealConductors = value;
    if (_isTrackingEnabled) {
      _drawVehicleMarkers();
    }
    notifyListeners();
  }

  /// Draw vehicle markers on the map using CONTEXT-BASED FILTERING:
  /// - Idle Mode (no route selected): Show all tracked buses
  /// - Route Selected: Show ONLY buses serving that specific route
  /// - Real Conductor Mode: Only show verified conductor buses
  Future<void> _drawVehicleMarkers() async {
    if (_map == null || !_isInitialized) {
      debugPrint(
        '❌ Cannot draw markers: map=$_map, initialized=$_isInitialized',
      );
      return;
    }

    debugPrint(
      '🎨 _drawVehicleMarkers: ${_trackedVehicles.length} total vehicles',
    );
    debugPrint(
      '🎨 Filter: route=$_selectedRouteNum, directionIndex=$_selectedDirectionIndex',
    );

    // Clear previous bus markers
    await _mapDrawingService.clearBusMarkers();

    // CONTEXT FILTER: Determine what buses to show based on user state
    List<TrackedVehicle> vehiclesToShow = [];

    // VISIBILITY LOGIC:
    // 1. If a route is selected → ONLY show buses for that route (always filter)
    // 2. If NO route selected AND _showAllBuses is ON → Show all buses
    // 3. If NO route selected AND _showAllBuses is OFF → Hide all buses
    // 4. If _showOnlyRealConductors is ON → Filter out simulated buses

    final bool showingSpecificRoute = _selectedRouteNum != null;
    final bool allowVisibility = showingSpecificRoute || _showAllBuses;

    if (!allowVisibility) {
      // Hide all buses
    } else {
      for (var vehicle in _trackedVehicles) {
        // FILTER 0: If showing only real conductors, skip simulated buses
        if (_showOnlyRealConductors && !vehicle.isRealConductor) {
          continue;
        }

        // FILTER 1: If a route is selected, ALWAYS filter to that route only
        if (showingSpecificRoute) {
          // Flexible route matching - handle different formats:
          // routeId could be "10", "route_10", "Route 10", etc.
          final vehicleRouteId = vehicle.position.routeId.toLowerCase();
          final selectedRoute = _selectedRouteNum!.toLowerCase();

          final bool routeMatches =
              vehicleRouteId == selectedRoute ||
              vehicleRouteId == 'route_$selectedRoute' ||
              vehicleRouteId == 'route $selectedRoute' ||
              vehicleRouteId.contains(selectedRoute);

          if (!routeMatches) {
            continue; // Skip buses not on selected route
          }

          // FILTER 2: If direction is selected (trip mode), only show buses going that direction
          if (_selectedDirectionIndex != null) {
            final bool directionMatches =
                vehicle.position.directionIndex == _selectedDirectionIndex;
            debugPrint(
              '  🔍 Bus ${vehicle.position.id}: dir=${vehicle.position.directionIndex}, selected=$_selectedDirectionIndex, match=$directionMatches',
            );
            if (!directionMatches) {
              continue; // Skip buses going the opposite direction
            }
          }
        }
        // If no route selected and _showAllBuses is true, show all buses

        // NOTE: Stale filter is already handled in VehicleTrackingService
        vehiclesToShow.add(vehicle);
      }
    }

    // Auto-highlight the nearest bus for the selected route
    if (showingSpecificRoute && vehiclesToShow.isNotEmpty) {
      // Sort by distance to user and highlight the nearest
      vehiclesToShow.sort(
        (a, b) => a.distanceToUserMeters.compareTo(b.distanceToUserMeters),
      );
      _highlightedVehicleId = vehiclesToShow.first.position.id;
    } else if (!showingSpecificRoute) {
      _highlightedVehicleId = null; // Clear highlight when no route selected
    }

    if (allowVisibility) {
      final realCount = vehiclesToShow.where((v) => v.isRealConductor).length;
      final simCount = vehiclesToShow.where((v) => !v.isRealConductor).length;
      debugPrint(
        '🚌 Showing ${vehiclesToShow.length} buses '
        '(Real: $realCount, Simulated: $simCount, Route: $_selectedRouteNum)',
      );
    } else {
      debugPrint('🧹 Clean Map Mode: Hiding all buses');
    }

    // Draw bus markers with OCCUPANCY-BASED coloring
    // Color indicates capacity status set by conductor:
    // Green = seats available, Yellow = standing only, Red = full
    for (var vehicle in vehiclesToShow) {
      // Use occupancy status color instead of route color
      final occupancyColor = _getOccupancyColor(vehicle.position.occupancy);

      final isHighlighted = (vehicle.position.id == _highlightedVehicleId);

      // Show distance from user instead of ETA
      final distanceKm = vehicle.distanceToUserMeters / 1000;
      String distanceText;
      if (distanceKm < 1) {
        distanceText = '${vehicle.distanceToUserMeters.round()}m';
      } else {
        distanceText = '${distanceKm.toStringAsFixed(1)}km';
      }

      // Build label: highlight next bus, show verified badge, and distance
      String displayLabel;
      if (isHighlighted) {
        displayLabel = "★ NEXT • $distanceText";
      } else if (vehicle.isRealConductor) {
        displayLabel = "✓ $distanceText";
      } else {
        displayLabel = distanceText;
      }

      _mapDrawingService.queueBusMarker(
        coordinates: [vehicle.position.lng, vehicle.position.lat],
        etaText: displayLabel,
        routeName: vehicle.routeName,
        routeColor: occupancyColor, // Now based on occupancy!
        heading: vehicle.position.heading,
        vehicleId: vehicle.position.id,
        occupancyLabel: vehicle.position.occupancyLabel, // Accessibility symbol
      );
    }
    await _mapDrawingService.flushBusMarkers();
  }

  // =========================================================
  // BUS TAP INTERACTION
  // =========================================================

  /// Handle a tap on the map at the given coordinates
  /// Returns true if a bus was tapped, false otherwise
  bool handleMapTap(double lat, double lng) {
    // Check if tap is on a bus marker
    final vehicleId = _mapDrawingService.checkBusTap(lat, lng, tolerance: 80.0);

    if (vehicleId != null) {
      // Find the tapped vehicle
      final vehicle = _trackedVehicles.firstWhere(
        (v) => v.position.id == vehicleId,
        orElse: () => _trackedVehicles.first,
      );

      _tappedVehicle = vehicle;

      // Fly camera to the bus location
      _mapDrawingService.flyTo(
        lat: vehicle.position.lat,
        lng: vehicle.position.lng,
        zoom: 16.0,
        durationMs: 800,
      );

      debugPrint(
        '🚌 Bus tapped: ${vehicle.position.id} - ${vehicle.routeName}',
      );

      notifyListeners();
      return true;
    }

    // Tap was not on a bus - clear any selected bus
    if (_tappedVehicle != null) {
      _tappedVehicle = null;
      notifyListeners();
    }

    return false;
  }

  /// Select a specific bus by its ID (from UI list)
  void selectBus(TrackedVehicle vehicle) {
    _tappedVehicle = vehicle;

    // Fly camera to the bus location
    _mapDrawingService.flyTo(
      lat: vehicle.position.lat,
      lng: vehicle.position.lng,
      zoom: 16.0,
      durationMs: 800,
    );

    notifyListeners();
  }

  /// Clear the tapped/selected bus
  void clearTappedBus() {
    _tappedVehicle = null;
    notifyListeners();
  }

  /// Get color based on bus occupancy status (conductor-set)
  /// - Green: Seats available
  /// - Yellow/Amber: Standing room only
  /// - Red: Full capacity
  Color _getOccupancyColor(String status) {
    switch (status) {
      case 'red':
        return const Color(0xFFEF4444); // Full
      case 'yellow':
        return const Color(0xFFF59E0B); // Standing only (amber)
      case 'green':
      default:
        return const Color(0xFF22C55E); // Seats available
    }
  }

  /// Convert color name to Color (for route colors)
  Color _getColorFromName(String colorName) {
    switch (colorName) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'orange':
        return const Color(0xFFF97316);
      case 'green':
        return const Color(0xFF22C55E);
      case 'red':
        return const Color(0xFFEF4444);
      case 'purple':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Start live vehicle tracking
  void startVehicleTracking() {
    if (_vehicleTrackingService == null) return;

    _isTrackingEnabled = true;

    // Set user location for ETA calculations
    if (_userLocation != null) {
      _vehicleTrackingService!.setUserLocation(
        _userLocation!.latitude,
        _userLocation!.longitude,
      );
    } else {
      // If no location yet, try to get it
      fetchUserLocation();
    }

    // Set route data for matching
    _vehicleTrackingService!.setRouteData(
      _routeService.cachedRoutes,
      _cachedRoutes,
    );

    _vehicleTrackingService!.startListening();
    notifyListeners();
  }

  /// Stop live vehicle tracking
  void stopVehicleTracking() {
    _vehicleTrackingService?.stopListening();
    _isTrackingEnabled = false;
    _trackedVehicles = [];
    _tappedVehicle = null; // Clear tapped bus when stopping

    // Clear bus markers from the map
    _mapDrawingService.clearBusMarkers();

    notifyListeners();
  }

  // --- LIVE TRACKING STATE ---
  StreamSubscription? _vehicleSubscription;
  Timer? _simulationTimer;
  final List<VehiclePosition> _activeVehicles = [];
  bool _isSimulating = false;

  /// 🎧 START LISTENING (Passenger View) - Uses VehicleTrackingService
  void listenToLiveVehicles() {
    startVehicleTracking();
  }

  /// 👻 START SIMULATION (Conductor View)
  /// Drives a ghost bus along the currently selected route
  void startGhostBusSimulation() {
    if (_selectedRouteNum == null || _isSimulating) {
      debugPrint("❌ Select a route first to simulate!");
      return;
    }

    // Get the coordinates of the selected route
    // Assumes the first leg is the bus ride
    final routeData = _displayList.firstWhere(
      (r) => r['num'] == _selectedRouteNum,
    );

    // Safety check: Are there coordinates?
    // Note: You might need to adjust this path based on your exact data structure
    List<dynamic> rawCoords = [];
    if (routeData['legs'] != null && (routeData['legs'] as List).isNotEmpty) {
      rawCoords = routeData['legs'][0]['coords'];
    } else {
      // Fallback for direct route objects
      // You might need to fetch the GeoJSON coordinates here if they aren't loaded
      debugPrint("⚠️ No coordinates found to drive on.");
      return;
    }

    _isSimulating = true;
    int index = 0;
    final String ghostId = "ghost_bus_${_selectedRouteNum}";

    debugPrint("👻 Simulation Started for $ghostId");

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      if (!isInitialized) return;

      if (index >= rawCoords.length) index = 0; // Loop forever

      final point = rawCoords[index]; // [lng, lat]

      final vehicle = VehiclePosition(
        id: ghostId,
        routeId: _selectedRouteNum!,
        lat: point[1],
        lng: point[0],
        heading: 0, // We can calculate bearing later
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Upload to Firebase
      try {
        await _database.ref('vehicles/$ghostId').set(vehicle.toJson());
      } catch (e) {
        debugPrint("🔥 Firebase Write Error: $e");
      }

      index++;
    });
  }

  /// 🛑 STOP EVERYTHING
  void stopTracking() {
    _vehicleSubscription?.cancel();
    _simulationTimer?.cancel();
    _isSimulating = false;
    stopVehicleTracking();
  }

  /// 🚌 ADD FAKE BUSES FOR TESTING
  /// Creates multiple simulated buses at random positions along routes
  /// These buses will MOVE along their routes to simulate real traffic
  Timer? _fakeBusTimer;
  final Map<String, Map<String, dynamic>> _fakeBusState = {};

  Future<void> addFakeBuses({int count = 5}) async {
    if (!_routeService.isLoaded) {
      debugPrint("❌ Routes not loaded yet!");
      return;
    }

    // Stop any existing fake bus simulation
    _fakeBusTimer?.cancel();
    _fakeBusState.clear();

    final random = math.Random();
    final routes = _routeService.cachedRoutes;

    if (routes.isEmpty) {
      debugPrint("❌ No cached routes available!");
      return;
    }

    debugPrint("🚌 Adding fake buses - ensuring both directions per route...");

    // Group routes by route number to ensure we get both directions
    final Map<String, List<CachedRoute>> routesByNum = {};
    for (final route in routes) {
      routesByNum.putIfAbsent(route.routeNum, () => []).add(route);
    }

    // Debug: Print what directions we have for each route
    for (final entry in routesByNum.entries) {
      final dirs = entry.value.map((r) => r.directionIndex).toList();
      debugPrint("  Route ${entry.key}: has ${dirs.length} directions $dirs");
    }

    int busIndex = 0;

    // FIRST: Create one bus for EACH direction of EACH route (ensures coverage)
    for (final routeNum in routesByNum.keys) {
      final directionsForRoute = routesByNum[routeNum]!;

      for (final route in directionsForRoute) {
        final coords = route.coordinates;
        if (coords.length < 10) continue;

        final startIndex = random.nextInt(coords.length ~/ 2);
        final busId =
            "fake_bus_${route.routeNum}_dir${route.directionIndex}_$busIndex";

        String occupancy = "green";
        int roll = random.nextInt(100);
        if (roll > 85) {
          occupancy = "red";
        } else if (roll > 60) {
          occupancy = "yellow";
        }

        final dirName =
            route.directions.isNotEmpty &&
                route.directionIndex < route.directions.length
            ? route.directions[route.directionIndex]['name'] ?? 'Unknown'
            : 'Dir ${route.directionIndex}';

        debugPrint(
          "  🚐 Bus $busIndex: Route ${route.routeNum} - $dirName (dir=${route.directionIndex})",
        );

        _fakeBusState[busId] = {
          'routeNum': route.routeNum,
          'coords': coords,
          'currentIndex': startIndex,
          'occupancy': occupancy,
          'plateNumber': "ABC ${1000 + random.nextInt(9000)}",
          'speed': 1 + random.nextInt(3),
          'directionIndex': route.directionIndex,
        };

        busIndex++;
      }
    }

    debugPrint("🚌 Created $busIndex buses covering all route directions!");

    // Start periodic updates to move the buses
    _fakeBusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      // Create a copy of entries to avoid concurrent modification
      final entries = _fakeBusState.entries.toList();

      for (final entry in entries) {
        final busId = entry.key;
        final state = entry.value;

        final coords = state['coords'] as List<List<double>>;
        var currentIndex = state['currentIndex'] as int;
        final speed = state['speed'] as int;

        // Move along route
        currentIndex += speed;
        if (currentIndex >= coords.length) {
          currentIndex = 0; // Loop back to start
        }
        state['currentIndex'] = currentIndex;

        final point = coords[currentIndex];

        // Calculate heading based on next point
        double heading = 0;
        if (currentIndex < coords.length - 1) {
          final nextPoint = coords[currentIndex + 1];
          heading = _calculateBearing(
            point[1],
            point[0],
            nextPoint[1],
            nextPoint[0],
          );
        }

        final vehicle = VehiclePosition(
          id: busId,
          routeId: state['routeNum'],
          lat: point[1],
          lng: point[0],
          heading: heading,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          passengerCount: (state['occupancy'] == 'red')
              ? 30
              : (state['occupancy'] == 'yellow')
              ? 20
              : 10,
          plateNumber: state['plateNumber'],
          occupancy: state['occupancy'],
          directionIndex: state['directionIndex'] ?? 0,
        );

        try {
          await _database.ref('vehicles/$busId').set(vehicle.toJson());
        } catch (e) {
          // Silently ignore permission errors during simulation
        }
      }
    });

    debugPrint("🚌 Started ${_fakeBusState.length} moving fake buses!");
  }

  /// Calculate bearing between two points
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final x = math.sin(dLng) * math.cos(lat2Rad);
    final y =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    var bearing = math.atan2(x, y) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Stop fake bus simulation
  void stopFakeBuses() {
    _fakeBusTimer?.cancel();
    _fakeBusTimer = null;
    _fakeBusState.clear();
    debugPrint("🛑 Stopped fake bus simulation");
  }

  /// 🧹 CLEAR ALL FAKE BUSES
  Future<void> clearFakeBuses() async {
    // First stop all timers
    stopMovingFakeBuses();

    try {
      // Remove from Firebase
      await _database.ref('vehicles').remove();
      debugPrint("🧹 Cleared all vehicles from Firebase");

      // Clear local tracked vehicles list
      _trackedVehicles.clear();
      _tappedVehicle = null;

      // Clear bus markers from the map
      await _mapDrawingService.clearBusMarkers();

      notifyListeners();
    } catch (e) {
      debugPrint("🔥 Error clearing vehicles: $e");
    }
  }

  /// 🔄 SIMULATE MOVING BUSES
  /// Makes all fake buses move along their routes
  List<Timer> _busTimers = [];

  void startMovingFakeBuses() {
    if (_fakeBusState.isEmpty) {
      debugPrint("❌ No fake buses to move! Add fake buses first.");
      return;
    }

    // Stop any existing timers
    stopMovingFakeBuses();

    final random = math.Random();

    for (final entry in _fakeBusState.entries) {
      final busId = entry.key;
      final state = entry.value;
      final coords = state['coords'] as List<List<double>>;
      int currentIndex = (state['currentIndex'] as num).toInt();
      final speed = 800 + random.nextInt(700); // 800-1500ms per update

      final timer = Timer.periodic(Duration(milliseconds: speed), (t) async {
        if (coords.isEmpty) return;
        if (currentIndex >= coords.length - 1) {
          currentIndex = 0; // Loop back
        }

        final point = coords[currentIndex];

        // Randomize occupancy for testing moving buses too
        String occupancy = state['occupancy'] ?? "green";
        int roll = random.nextInt(100);
        int seed = busId.hashCode + currentIndex;
        if (seed % 100 > 85) {
          occupancy = "red";
        } else if (seed % 100 > 60) {
          occupancy = "yellow";
        }

        final vehicle = VehiclePosition(
          id: busId,
          routeId: state['routeNum'],
          lat: point[1],
          lng: point[0],
          heading: 0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          passengerCount: (occupancy == 'red')
              ? 30
              : (occupancy == 'yellow')
              ? 20
              : 10,
          plateNumber: state['plateNumber'],
          occupancy: occupancy,
          directionIndex: state['directionIndex'] ?? 0,
        );

        try {
          await _database.ref('vehicles/$busId').set(vehicle.toJson());
        } catch (e) {
          debugPrint("🔥 Error updating moving bus: $e");
        }

        int moveSpeed = (state['speed'] ?? 1) is int
            ? state['speed'] as int
            : (state['speed'] as num).toInt();
        currentIndex += moveSpeed;
        state['currentIndex'] = currentIndex;
      });

      _busTimers.add(timer);
    }

    debugPrint("🚌 Started ${_busTimers.length} moving fake buses!");
  }

  void stopMovingFakeBuses() {
    // Stop the moving bus timers
    for (var timer in _busTimers) {
      timer.cancel();
    }
    _busTimers.clear();

    // Also stop the fake bus timer from addFakeBuses
    _fakeBusTimer?.cancel();
    _fakeBusTimer = null;
    _fakeBusState.clear();

    debugPrint("🛑 Stopped all moving buses and fake bus simulations");
  }

  /// 🔥 NEW: Load routes from Firebase
  Future<void> loadRoutesFromFirebase() async {
    try {
      final snapshot = await _database.ref('routes').get();
      if (snapshot.value == null) return;

      List<dynamic> rawData = snapshot.value as List<dynamic>;
      _cachedRoutes = rawData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      _displayList = List.from(_cachedRoutes);
      notifyListeners();
    } catch (e) {
      debugPrint("Firebase routes error: $e");
      // Fallback to local data
      _cachedRoutes = localRoutesData;
      _displayList = List.from(_cachedRoutes);
      notifyListeners();
    }
  }

  /// 🔥 FIXED: Handle both Map and String from Firebase
  Future<Map<String, dynamic>?> loadGeoJson(String path) async {
    try {
      final parentSnap = await _database.ref(path).get();
      if (parentSnap.value == null) return null;

      final Map<String, dynamic> geoJson = {
        'type': parentSnap.child('type').value ?? 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      // 🔥 FIX: Handle List<Object?> from features
      final featuresSnap = await _database.ref('$path/features').get();
      if (featuresSnap.value != null) {
        List<dynamic> featuresList = featuresSnap.value as List<dynamic>;

        for (var featureRaw in featuresList) {
          if (featureRaw is Map) {
            geoJson['features'].add(Map<String, dynamic>.from(featureRaw));
          }
        }
      }

      debugPrint("✅ GeoJSON loaded: ${geoJson['features'].length} features");
      return geoJson;
    } catch (e) {
      debugPrint("GeoJSON error: $e");
      return null;
    }
  }

  /// Initialize the map and preload routes.
  Future<void> initialize(MapboxMap map) async {
    _map = map;
    _mapDrawingService.initialize(map);
    await _mapDrawingService.initAnnotationManager();
    await initializeFirebase(); // 🔥 FIREBASE FIRST

    // 🔥 PRELOAD ROUTES FOR ROUTE FINDING
    await _preloadRoutesForFinding();

    // 🚌 AUTO-START VEHICLE TRACKING
    startVehicleTracking();

    _isInitialized = true;
    notifyListeners();
  }

  /// Preload route coordinates for route finding algorithm
  Future<void> _preloadRoutesForFinding() async {
    try {
      // Use local routes data which has asset paths
      await _routeService.preloadRoutes(localRoutesData);
      debugPrint(
        "✅ Routes preloaded for route finding: ${_routeService.cachedRoutes.length} directions",
      );
    } catch (e) {
      debugPrint("❌ Failed to preload routes: $e");
    }
  }

  Future<void> _safeDraw(Future<void> Function() drawFn) async {
    if (_map == null || !_isInitialized) {
      debugPrint("❌ Map not ready for drawing");
      return;
    }
    try {
      await drawFn();
    } catch (e) {
      debugPrint("Draw failed: $e");
    }
  }

  /// Update the search text and reset display if empty.
  void updateSearchText(String text) {
    _searchText = text;
    if (text.isEmpty) {
      _displayList = List.from(_cachedRoutes); // 🔥 CHANGED
      _selectedRouteNum = null;
      _selectedDirectionIndex = null;
    } else {
      // Filter cached routes
      _displayList = _cachedRoutes.where((route) {
        final num = route['num'].toString().toLowerCase();
        final dest = route['dest'].toString().toLowerCase();
        return num.contains(text.toLowerCase()) ||
            dest.contains(text.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  /// Handle user location fetch.
  Future<void> fetchUserLocation() async {
    _isFetchingLocation = true;
    notifyListeners();

    try {
      if (_useDemoMode) {
        // 🧪 MOCK LOCATION: PHV6+497, Quintin Salas St, Jaro, Iloilo City
        debugPrint("🧪 Using DEMO location: $mockLatitude, $mockLongitude");
        _userLocation = geo.Position(
          latitude: mockLatitude,
          longitude: mockLongitude,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      } else {
        // Real GPS location
        final pos = await geo.Geolocator.getCurrentPosition();
        _userLocation = pos;
      }

      // Draw blue marker at user location
      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );

      // Update vehicle tracking service with new location for ETA calculations
      if (_vehicleTrackingService != null && _isTrackingEnabled) {
        _vehicleTrackingService!.setUserLocation(
          _userLocation!.latitude,
          _userLocation!.longitude,
        );
      }

      // Fly to user location
      _mapDrawingService.flyTo(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
        zoom: 15.0,
        durationMs: 1500,
      );
    } catch (e) {
      debugPrint("Location Error: $e");
    }

    _isFetchingLocation = false;
    notifyListeners();
  }

  /// Fly to the current user location (can be called anytime)
  Future<void> flyToCurrentLocation() async {
    if (_userLocation == null) {
      // Try to fetch location first if we don't have it
      await fetchUserLocation();
      return;
    }

    // Ensure user location marker is visible
    await _mapDrawingService.drawUserLocationMarker(
      lat: _userLocation!.latitude,
      lng: _userLocation!.longitude,
    );

    _mapDrawingService.flyTo(
      lat: _userLocation!.latitude,
      lng: _userLocation!.longitude,
      zoom: 15.0,
      durationMs: 1500,
    );
  }

  /// Fly to any specific location
  void flyToLocation(double lat, double lng, {double zoom = 16.0}) {
    _mapDrawingService.flyTo(lat: lat, lng: lng, zoom: zoom, durationMs: 1200);
  }

  /// Plan a trip to a place from search results.
  Future<bool> planTripToPlace(Map<String, dynamic> item) async {
    debugPrint("🔍 planTripToPlace called with: ${item['dest']}");
    debugPrint("   RouteService loaded: ${_routeService.isLoaded}");
    debugPrint(
      "   User location: ${_userLocation?.latitude}, ${_userLocation?.longitude}",
    );
    debugPrint("   Cached routes count: ${_routeService.cachedRoutes.length}");

    if (!_routeService.isLoaded) {
      debugPrint("❌ RouteService not loaded!");
      return false;
    }

    if (_userLocation == null) {
      debugPrint("❌ User location is null!");
      return false;
    }

    final String? mapboxId = item['mapbox_id'];
    if (mapboxId == null) {
      debugPrint("❌ No mapbox_id in item");
      return false;
    }

    try {
      final response = await _searchBoxApi.getPlace(mapboxId);
      _sessionToken = const Uuid().v4();

      bool success = false;
      response.fold((result) {
        if (result.features.isNotEmpty) {
          final destPoint = result.features.first.geometry.coordinates;
          debugPrint("📍 Destination: ${destPoint.lat}, ${destPoint.long}");

          _destinationPoint = Point(
            coordinates: Position(destPoint.long, destPoint.lat),
          );

          final options = _routeService.calculateEfficientRoutes(
            userLat: _userLocation!.latitude,
            userLng: _userLocation!.longitude,
            destLat: destPoint.lat,
            destLng: destPoint.long,
          );

          debugPrint("📊 Found ${options.length} route options");

          if (options.isNotEmpty) {
            _displayList = options.map((o) => o.toDisplayMap()).toList();
            _searchText = item['dest'];
            _selectedRouteNum = null;
            _selectedDirectionIndex = null;
            success = true;
            notifyListeners();
          } else {
            debugPrint("❌ No route options found within walking distance");
          }
        }
      }, (failure) => debugPrint("Error: ${failure.message}"));

      return success;
    } catch (e) {
      debugPrint("Plan Error: $e");
      return false;
    }
  }

  /// Draw a trip option on the map.
  Future<void> drawTripOnMap(Map<String, dynamic> item) async {
    if (_destinationPoint == null || _userLocation == null) return;

    try {
      final legs = item['legs'] as List;
      final dest = _destinationPoint!.coordinates;

      _selectedRouteNum = item['num'];
      // Set direction index for filtering (use first leg's direction)
      _selectedDirectionIndex = legs.isNotEmpty
          ? (legs[0]['activeDir'] ?? 0)
          : null;

      // 🔥 NEW: Find nearest bus for the selected route relative to pickup
      _highlightedVehicleId = null;
      List<double>? nearestBusCoords; // [lng, lat]
      try {
        // Find the bus leg that matches the selected route
        final busLeg = legs.firstWhere(
          (l) =>
              (l['mode'] == 'BUS' || l['route'] != null) &&
              l['route']['num'] == _selectedRouteNum,
          orElse: () => null,
        );

        if (busLeg != null && _isTrackingEnabled) {
          final pickupLat = busLeg['pickup'][1] as double;
          final pickupLng = busLeg['pickup'][0] as double;
          final legDirIndex =
              busLeg['activeDir'] ?? 0; // Get direction from leg
          final routeCoords = busLeg['coords'] as List<List<double>>?;
          final pickupIndex = busLeg['pickupIndex'] as int? ?? 0;

          TrackedVehicle? bestBus;
          double minDistance = double.infinity;

          for (var v in _trackedVehicles) {
            // Must match BOTH route AND direction
            final routeMatches =
                v.position.routeId == _selectedRouteNum ||
                v.position.routeId.toLowerCase() ==
                    _selectedRouteNum?.toLowerCase() ||
                v.position.routeId.toLowerCase().contains(
                  _selectedRouteNum?.toLowerCase() ?? '',
                );
            final directionMatches = v.position.directionIndex == legDirIndex;

            if (routeMatches && directionMatches) {
              // Skip buses that have already passed the boarding point
              if (routeCoords != null &&
                  _hasBusPassedBoarding(
                    routeCoords,
                    v.position.lat,
                    v.position.lng,
                    pickupIndex,
                  )) {
                continue; // Bus has passed, skip it
              }

              final dist = _haversineDistance(
                v.position.lat,
                v.position.lng,
                pickupLat,
                pickupLng,
              );
              if (dist < minDistance) {
                minDistance = dist;
                bestBus = v;
              }
            }
          }

          if (bestBus != null) {
            _highlightedVehicleId = bestBus.position.id;
            nearestBusCoords = [bestBus.position.lng, bestBus.position.lat];
            debugPrint(
              "🎯 Nearest Bus Found: ${bestBus.position.plateNumber} dir=${bestBus.position.directionIndex} (${(minDistance).round()}m away)",
            );
          }
        }
      } catch (e) {
        debugPrint("Error finding nearest bus: $e");
      }

      // Calculate trip statistics
      _activeTripStats = _calculateTripStats(item, legs, dest);

      notifyListeners();

      await _mapDrawingService.clearNavigationLayers();
      await _mapDrawingService.clearMarkers();

      // === STEP 1: Draw all lines first (so markers appear on top) ===

      // Collect all draw operations
      final List<Future<void>> drawOperations = [];
      var firstLeg = legs[0];

      // Walk from User to First Boarding
      drawOperations.add(
        _mapDrawingService.drawWalkLine(
          startLat: _userLocation!.latitude,
          startLng: _userLocation!.longitude,
          endLat: firstLeg['pickup'][1],
          endLng: firstLeg['pickup'][0],
          layerId: "walk-start",
        ),
      );

      // Draw all bus paths and transfer walks
      for (int i = 0; i < legs.length; i++) {
        var leg = legs[i];

        // Draw Bus Path
        drawOperations.add(
          _mapDrawingService.drawPolyline(
            coordinates: leg['coords'] as List<List<double>>,
            startIndex: leg['pickupIndex'],
            endIndex: leg['dropoffIndex'],
            colorName: leg['route']['color'],
            layerId: "bus-leg-$i",
          ),
        );

        // Transfer walk lines
        if (i < legs.length - 1) {
          var next = legs[i + 1];
          drawOperations.add(
            _mapDrawingService.drawWalkLine(
              startLat: leg['dropoff'][1],
              startLng: leg['dropoff'][0],
              endLat: next['pickup'][1],
              endLng: next['pickup'][0],
              layerId: "walk-transfer-$i",
            ),
          );
        }
      }

      // Walk to Destination
      var lastLeg = legs.last;
      drawOperations.add(
        _mapDrawingService.drawWalkLine(
          startLat: lastLeg['dropoff'][1],
          startLng: lastLeg['dropoff'][0],
          endLat: dest.lat.toDouble(),
          endLng: dest.lng.toDouble(),
          layerId: "walk-end",
        ),
      );

      // Execute all draw operations in parallel for faster rendering
      await Future.wait(drawOperations);

      // === STEP 2: Draw all markers AFTER lines (so they appear on top) ===
      // Queue markers for batch creation (more efficient than individual creates)

      // Calculate walk distance to first pickup for label
      final walkToPickupMeters = _haversineDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        firstLeg['pickup'][1],
        firstLeg['pickup'][0],
      );
      final walkToPickupMin = _estimateWalkTime(walkToPickupMeters);

      // Board marker with walking time
      _mapDrawingService.queueMarker(
        coordinates: firstLeg['pickup'],
        label:
            "● Board Route ${firstLeg['route']['num']} (~$walkToPickupMin min walk)",
        textColor: Colors.blue.shade700,
      );

      // Transfer markers with walking info
      for (int i = 0; i < legs.length - 1; i++) {
        var leg = legs[i];
        var next = legs[i + 1];

        // Calculate transfer walk distance
        final transferWalkMeters = _haversineDistance(
          leg['dropoff'][1],
          leg['dropoff'][0],
          next['pickup'][1],
          next['pickup'][0],
        );
        final transferWalkMin = _estimateWalkTime(transferWalkMeters);

        _mapDrawingService.queueMarker(
          coordinates: leg['dropoff'],
          label:
              "↔ Transfer to Route ${next['route']['num']} (~$transferWalkMin min)",
          textColor: Colors.orange.shade700,
        );
      }

      // Calculate walk to destination
      final walkToDestMeters = _haversineDistance(
        (legs.last)['dropoff'][1],
        (legs.last)['dropoff'][0],
        dest.lat.toDouble(),
        dest.lng.toDouble(),
      );
      final walkToDestMin = _estimateWalkTime(walkToDestMeters);

      // Destination marker with walking time
      _mapDrawingService.queueMarker(
        coordinates: [dest.lng.toDouble(), dest.lat.toDouble()],
        label: "◉ Destination (~$walkToDestMin min walk)",
        textColor: Colors.red.shade700,
      );

      // Flush all markers in one batch
      await _mapDrawingService.flushMarkers();

      // Redraw user location marker (it uses a separate layer so it's preserved)
      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );

      // Redraw vehicle markers for the selected route
      if (_isTrackingEnabled) {
        _drawVehicleMarkers();
      }

      _mapDrawingService.fitCameraToTrip(
        userLat: _userLocation!.latitude,
        userLng: _userLocation!.longitude,
        destLat: dest.lat.toDouble(),
        destLng: dest.lng.toDouble(),
        extraPoint: nearestBusCoords,
      );
    } catch (e) {
      debugPrint("Draw Error: $e");
    }
  }

  /// Toggle "Show All Buses" visibility
  void toggleBusVisibility() {
    _showAllBuses = !_showAllBuses;

    // Ensure tracking is ON if we are showing all buses
    if (_showAllBuses && !_isTrackingEnabled) {
      startVehicleTracking();
    }

    _drawVehicleMarkers(); // Redraw with new visibility rule
    notifyListeners();
  }

  /// 🔥 UPDATED: Select route with Firebase GeoJSON or local assets + landmarks
  Future<void> selectRoute(Map<String, dynamic> route) async {
    _selectedRouteNum = route['num'];
    // Set direction index based on activeDir so buses are filtered correctly
    _selectedDirectionIndex = route['activeDir'] ?? 0;
    _destinationPoint = null;
    _activeTripStats = null; // Clear trip stats when selecting a route
    notifyListeners();

    await _mapDrawingService.clearNavigationLayers();
    await _mapDrawingService.clearMarkers();

    try {
      int dir = route['activeDir'] ?? 0;
      final directionData = route['directions'][dir];

      debugPrint(
        "📍 Selecting Route ${route['num']} direction $dir: ${directionData['name']}",
      );

      // Check if it's a Firebase path or local asset
      Map<String, dynamic>? geoJsonData;

      if (directionData.containsKey('path')) {
        // Try Firebase path first
        String dbPath = directionData['path'];
        geoJsonData = await loadGeoJson(dbPath);
      }

      if (geoJsonData != null) {
        // Successfully loaded from Firebase
        await _mapDrawingService.drawGeoJsonRoute(
          geoJsonData: geoJsonData,
          colorName: route['color'],
        );

        // ✅ ADD LANDMARK LETTERS from Firebase GeoJSON
        final landmarks = _extractLandmarks(geoJsonData);
        if (landmarks.isNotEmpty) {
          final routeId = route['num']?.toString() ?? 'unknown';
          await _addLandmarkLettersWithLayers(routeId, landmarks);
        }
      } else if (directionData.containsKey('asset')) {
        // Fallback to local asset if Firebase failed or missing
        String assetPath = directionData['asset'];

        // First draw the route
        await _mapDrawingService.drawRouteFromAsset(
          assetPath: assetPath,
          colorName: route['color'],
        );

        // ✅ Load GeoJSON from asset to get landmarks
        try {
          final String geoJsonString = await rootBundle.loadString(assetPath);
          geoJsonData = jsonDecode(geoJsonString) as Map<String, dynamic>;

          final landmarks = _extractLandmarks(geoJsonData);
          if (landmarks.isNotEmpty) {
            final routeId = route['num']?.toString() ?? 'unknown';
            await _addLandmarkLettersWithLayers(routeId, landmarks);
          }
        } catch (e) {
          debugPrint('Could not load landmarks from asset: $e');
        }
      }

      debugPrint("✅ Route ${route['num']} drawn successfully");
    } catch (e) {
      debugPrint("Select route error: $e");
    }

    // Redraw user location marker (it uses a separate layer so it's preserved)
    if (_userLocation != null) {
      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );
    }

    // Redraw vehicle markers based on new route AND direction selection
    if (_isTrackingEnabled) {
      _drawVehicleMarkers();
    }

    _mapDrawingService.flyTo(lat: 10.7202, lng: 122.5644, zoom: 13.0);
  }

  /// Swap route direction.
  Future<void> swapRouteDirection(Map<String, dynamic> route) async {
    int currentDir = route['activeDir'] ?? 0;
    route['activeDir'] = (currentDir + 1) % route['directions'].length;

    // Update the selected direction index for bus filtering
    _selectedDirectionIndex = route['activeDir'];

    // Update cached route too
    final cachedIndex = _cachedRoutes.indexWhere(
      (r) => r['num'] == route['num'],
    );
    if (cachedIndex != -1) {
      _cachedRoutes[cachedIndex]['activeDir'] = route['activeDir'];
    }

    // ✅ If this route is currently selected, redraw it with new direction
    if (_selectedRouteNum == route['num']) {
      await selectRoute(route);
    }

    notifyListeners();
  }

  /// Clear all selections and reset to default state.
  /// Clear all selections and reset to default state.
  Future<void> clearSelection() async {
    // ✅ CLEAR LANDMARKS FIRST
    await _clearLandmarkLayers();

    _searchText = '';
    _selectedRouteNum = null;
    _selectedDirectionIndex = null;
    _destinationPoint = null;
    _activeTripStats = null;
    _displayList = List.from(_cachedRoutes);

    await _mapDrawingService.clearNavigationLayers();
    await _mapDrawingService.clearMarkers();
    await _mapDrawingService.clearBusMarkers();

    // Redraw user location marker
    if (_userLocation != null) {
      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );
    }

    // Redraw vehicle markers (Clean Map: will hide all buses)
    if (_isTrackingEnabled) {
      _drawVehicleMarkers();
    }

    notifyListeners();
  }

  /// Handle item selection from the list.
  void handleItemSelection(Map<String, dynamic> item) {
    if (item['type'] == 'trip_option') {
      drawTripOnMap(item);
    } else if (item['type'] == 'route') {
      selectRoute(item);
    } else {
      planTripToPlace(item);
    }
  }

  /// Calculate trip statistics from trip data
  Map<String, dynamic> _calculateTripStats(
    Map<String, dynamic> item,
    List legs,
    dynamic dest,
  ) {
    double totalWalkMeters = 0;
    final int rideCount = legs.length;
    final int totalTime = item['totalTime'] ?? 15;
    final bool isTransfer = legs.length > 1;

    // Calculate walk to first pickup
    if (_userLocation != null && legs.isNotEmpty) {
      final firstLeg = legs[0];
      final pickupLat = firstLeg['pickup'][1] as double;
      final pickupLng = firstLeg['pickup'][0] as double;
      totalWalkMeters += _haversineDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        pickupLat,
        pickupLng,
      );
    }

    // Calculate transfer walks
    for (int i = 0; i < legs.length - 1; i++) {
      final currentLeg = legs[i];
      final nextLeg = legs[i + 1];
      final dropoffLat = currentLeg['dropoff'][1] as double;
      final dropoffLng = currentLeg['dropoff'][0] as double;
      final pickupLat = nextLeg['pickup'][1] as double;
      final pickupLng = nextLeg['pickup'][0] as double;
      totalWalkMeters += _haversineDistance(
        dropoffLat,
        dropoffLng,
        pickupLat,
        pickupLng,
      );
    }

    // Calculate walk from last dropoff to destination
    if (legs.isNotEmpty) {
      final lastLeg = legs.last;
      final dropoffLat = lastLeg['dropoff'][1] as double;
      final dropoffLng = lastLeg['dropoff'][0] as double;
      totalWalkMeters += _haversineDistance(
        dropoffLat,
        dropoffLng,
        dest.lat.toDouble(),
        dest.lng.toDouble(),
      );
    }

    // Estimate walking time using helper
    final walkTimeMin = _estimateWalkTime(totalWalkMeters);

    // Get route names for display
    final routeNames = legs
        .map((leg) => 'Route ${leg['route']['num']}')
        .toList();

    // Find next bus for first leg's route - nearest to BOARDING POINT
    String? nextBusEta;
    String? nextBusOccupancy;
    String? nextBusPlate;
    double? nextBusDistanceMeters;
    double? nextBusDistanceToBoarding;

    if (legs.isNotEmpty) {
      final firstLeg = legs[0];
      final firstRouteNum = firstLeg['route']['num'].toString();
      final firstLegDirIndex =
          firstLeg['activeDir'] ?? 0; // Get direction from leg
      final boardingLat = firstLeg['pickup'][1] as double;
      final boardingLng = firstLeg['pickup'][0] as double;
      final routeCoords = firstLeg['coords'] as List<List<double>>?;
      final pickupIndex = firstLeg['pickupIndex'] as int? ?? 0;

      var busesForRoute = _trackedVehicles.where((v) {
        final vehicleRouteId = v.position.routeId.toLowerCase();
        final routeNum = firstRouteNum.toLowerCase();

        // Match route number
        final routeMatches =
            vehicleRouteId == routeNum ||
            vehicleRouteId == 'route_$routeNum' ||
            vehicleRouteId == 'route $routeNum' ||
            vehicleRouteId.contains(routeNum);

        // Match direction (only consider buses going the same direction)
        final directionMatches = v.position.directionIndex == firstLegDirIndex;

        return routeMatches && directionMatches;
      }).toList();

      // Filter out buses that have already passed the boarding point
      if (routeCoords != null) {
        busesForRoute = busesForRoute.where((v) {
          return !_hasBusPassedBoarding(
            routeCoords,
            v.position.lat,
            v.position.lng,
            pickupIndex,
          );
        }).toList();
      }

      if (busesForRoute.isNotEmpty) {
        // Sort by distance to BOARDING POINT (not user)
        busesForRoute.sort((a, b) {
          final distA = _haversineDistance(
            a.position.lat,
            a.position.lng,
            boardingLat,
            boardingLng,
          );
          final distB = _haversineDistance(
            b.position.lat,
            b.position.lng,
            boardingLat,
            boardingLng,
          );
          return distA.compareTo(distB);
        });
        final nearestBus = busesForRoute.first;

        // Calculate distance to boarding point for display
        final distToBoarding = _haversineDistance(
          nearestBus.position.lat,
          nearestBus.position.lng,
          boardingLat,
          boardingLng,
        );

        // Estimate ETA based on distance to boarding (assume 20km/h average speed)
        final etaMinutes = (distToBoarding / 1000 / 20 * 60).round();
        nextBusEta = etaMinutes < 1 ? 'Arriving' : '~$etaMinutes min';
        nextBusOccupancy = nearestBus.position.occupancyLabel;
        nextBusPlate = nearestBus.position.plateNumber;
        nextBusDistanceMeters = nearestBus.distanceToUserMeters;
        nextBusDistanceToBoarding = distToBoarding;

        // Update highlighted bus
        _highlightedVehicleId = nearestBus.position.id;
      }
    }

    return {
      'walkKm': totalWalkMeters / 1000,
      'walkTimeMin': walkTimeMin,
      'rideCount': rideCount,
      'totalTime': totalTime,
      'isTransfer': isTransfer,
      'routeNames': routeNames,
      // Next bus info
      'nextBusEta': nextBusEta,
      'nextBusOccupancy': nextBusOccupancy,
      'nextBusPlate': nextBusPlate,
      'nextBusDistanceMeters': nextBusDistanceMeters,
      'nextBusDistanceToBoarding': nextBusDistanceToBoarding,
      'hasNextBus': nextBusEta != null,
    };
  }

  /// Estimate walking time in minutes from distance in meters
  /// Average walking speed: ~80 meters per minute (4.8 km/h)
  int _estimateWalkTime(double meters) {
    // 80 meters per minute is a comfortable walking pace
    final minutes = (meters / 80).ceil();
    return minutes < 1 ? 1 : minutes; // Minimum 1 minute
  }

  /// Find the closest point index on a route for a given lat/lng.
  /// Returns -1 if no point is within maxDistance meters.
  int _findClosestPointIndex(
    List<List<double>> coords,
    double lat,
    double lng, {
    double maxDistance = 500, // meters
  }) {
    int closestIdx = -1;
    double minDist = maxDistance;

    for (int i = 0; i < coords.length; i++) {
      final point = coords[i]; // [lng, lat]
      final dist = _haversineDistance(lat, lng, point[1], point[0]);
      if (dist < minDist) {
        minDist = dist;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  /// Check if a bus has passed the boarding point.
  /// Returns true if the bus is AHEAD of (past) the pickup on the route.
  bool _hasBusPassedBoarding(
    List<List<double>> routeCoords,
    double busLat,
    double busLng,
    int pickupIndex,
  ) {
    final busIndex = _findClosestPointIndex(routeCoords, busLat, busLng);
    if (busIndex < 0) return false; // Bus not on route, don't filter
    // If bus's position along the route is past the pickup, it has passed
    return busIndex > pickupIndex;
  }

  /// Haversine formula to calculate distance between two coordinates in meters
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * math.pi / 180;

  List<Map<String, dynamic>> _extractLandmarks(
    Map<String, dynamic> geoJsonData,
  ) {
    if (geoJsonData['features'] == null) return [];

    final features = geoJsonData['features'] as List;
    List<Map<String, dynamic>> landmarks = [];

    for (var feature in features) {
      if (feature['geometry']['type'] == 'Point') {
        final coords = feature['geometry']['coordinates'];
        landmarks.add({
          'name': feature['properties']['name'] ?? 'Unnamed',
          'coordinates': [coords[0], coords[1]],
        });
      }
    }

    return landmarks;
  }

  /// Add letter markers to landmarks
  /// Add start and end markers to landmarks
  /// Add start and end markers to landmarks
  /// Add start and end markers to landmarks
  Future<void> _addLandmarkLettersWithLayers(
    String routeId,
    List<Map<String, dynamic>> landmarks,
  ) async {
    if (_map == null || landmarks.isEmpty) return;

    try {
      // Clear previous layers if they exist
      await _clearLandmarkLayers();

      // Create separate sources for start and end
      final startLandmark = landmarks.first;
      final endLandmark = landmarks.last;

      // Start marker GeoJSON
      final startGeoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': startLandmark['coordinates'],
            },
            'properties': {'label': 'Start', 'name': startLandmark['name']},
          },
        ],
      };

      // End marker GeoJSON
      final endGeoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': endLandmark['coordinates'],
            },
            'properties': {'label': 'End', 'name': endLandmark['name']},
          },
        ],
      };

      // Add start source and layers
      await _map!.style.addSource(
        GeoJsonSource(id: 'start-source', data: jsonEncode(startGeoJson)),
      );

      await _map!.style.addLayer(
        CircleLayer(id: 'start-circle', sourceId: 'start-source')
          ..circleRadius = 18.0
          ..circleColor = Colors.green.value
          ..circleStrokeWidth = 3.0
          ..circleStrokeColor = Colors.white.value,
      );

      await _map!.style.addLayer(
        SymbolLayer(id: 'start-text', sourceId: 'start-source')
          ..textField = "{label}"
          ..textSize = 12.0
          ..textColor = Colors.white.value
          ..textHaloColor = Colors.black.value
          ..textHaloWidth = 1.0
          ..textAllowOverlap = true
          ..textIgnorePlacement = true,
      );

      // Add end source and layers
      await _map!.style.addSource(
        GeoJsonSource(id: 'end-source', data: jsonEncode(endGeoJson)),
      );

      await _map!.style.addLayer(
        CircleLayer(id: 'end-circle', sourceId: 'end-source')
          ..circleRadius = 18.0
          ..circleColor = Colors.red.value
          ..circleStrokeWidth = 3.0
          ..circleStrokeColor = Colors.white.value,
      );

      await _map!.style.addLayer(
        SymbolLayer(id: 'end-text', sourceId: 'end-source')
          ..textField = "{label}"
          ..textSize = 12.0
          ..textColor = Colors.white.value
          ..textHaloColor = Colors.black.value
          ..textHaloWidth = 1.0
          ..textAllowOverlap = true
          ..textIgnorePlacement = true,
      );

      _currentRouteWithLandmarks = routeId;
      debugPrint('✅ Added Start and End markers for route $routeId');
    } catch (e) {
      debugPrint('❌ Error adding landmark layers: $e');
    }
  }

  /// Clear landmark layers
  /// Clear landmark layers
  /// Clear landmark layers
  Future<void> _clearLandmarkLayers() async {
    if (_map == null || _currentRouteWithLandmarks == null) return;

    try {
      // Remove start layers and source
      await _map!.style.removeStyleLayer('start-text');
      await _map!.style.removeStyleLayer('start-circle');
      await _map!.style.removeStyleSource('start-source');

      // Remove end layers and source
      await _map!.style.removeStyleLayer('end-text');
      await _map!.style.removeStyleLayer('end-circle');
      await _map!.style.removeStyleSource('end-source');

      _currentRouteWithLandmarks = null;
      debugPrint('✅ Cleared landmark layers');
    } catch (e) {
      // Layers might not exist yet, that's okay
      debugPrint('Note: Landmark layers may not exist yet');
    }
  }
}
