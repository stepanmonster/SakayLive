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

// Manages map state and business logic.
class MapViewModel extends ChangeNotifier {
  bool get hasFakeBuses => _fakeBusState.isNotEmpty;

  void clearUserLocation() {
    _userLocation = null;
    notifyListeners();
  }

  final RouteService _routeService = RouteService();
  final MapDrawingService _mapDrawingService = MapDrawingService();
  VehicleTrackingService? _vehicleTrackingService;
  MapboxMap? _map;

  late final FirebaseDatabase _database;

  late SearchBoxAPI _searchBoxApi;
  String _sessionToken = const Uuid().v4();

  bool _useDemoMode = true;
  static const double mockLatitude = 10.7244;
  static const double mockLongitude = 122.5575;

  bool get useDemoMode => _useDemoMode;
  void setDemoMode(bool value) {
    _useDemoMode = value;
    notifyListeners();
  }

  static const bool useMockBuses = true;

  bool _isInitialized = false;
  bool _isFetchingLocation = false;
  geo.Position? _userLocation;
  Point? _destinationPoint;
  String? _selectedRouteNum;
  String? _currentRouteWithLandmarks;
  int? _selectedDirectionIndex;
  String _searchText = '';
  List<Map<String, dynamic>> _cachedRoutes = [];
  List<Map<String, dynamic>> _displayList = [];

  Map<String, dynamic>? _activeTripStats;

  List<TrackedVehicle> _trackedVehicles = [];
  bool _isTrackingEnabled = false;

  bool _showAllBuses = true;
  String? _highlightedVehicleId;
  bool _showOnlyRealConductors = false;

  TrackedVehicle? _tappedVehicle;

  bool get isInitialized => _isInitialized;
  bool get isRoutesLoaded => _cachedRoutes.isNotEmpty;
  bool get isFetchingLocation => _isFetchingLocation;
  geo.Position? get userLocation => _userLocation;
  Point? get destinationPoint => _destinationPoint;
  String? get selectedRouteNum => _selectedRouteNum;
  String get searchText => _searchText;
  List<Map<String, dynamic>> get displayList => _displayList;
  List<Map<String, dynamic>> get localRoutes => _cachedRoutes;
  SearchBoxAPI get searchBoxApi => _searchBoxApi;
  MapDrawingService get mapDrawingService => _mapDrawingService;
  String get sessionToken => _sessionToken;
  Map<String, dynamic>? get activeTripStats => _activeTripStats;
  bool get hasActiveTrip => _activeTripStats != null;

  List<TrackedVehicle> get trackedVehicles => _trackedVehicles;
  bool get isTrackingEnabled => _isTrackingEnabled;
  bool get showAllBuses => _showAllBuses;
  bool get showOnlyRealConductors => _showOnlyRealConductors;
  TrackedVehicle? get nearestVehicle =>
      _trackedVehicles.isNotEmpty ? _trackedVehicles.first : null;
  int get activeVehicleCount => _trackedVehicles.length;

  int get realConductorCount =>
      _trackedVehicles.where((v) => v.isRealConductor).length;

  int get simulatedBusCount =>
      _trackedVehicles.where((v) => !v.isRealConductor).length;

  TrackedVehicle? get tappedVehicle => _tappedVehicle;
  bool get hasTappedVehicle => _tappedVehicle != null;

  TrackedVehicle? get nearestVehicleForSelectedRoute {
    if (_selectedRouteNum == null) return null;
    return _vehicleTrackingService?.getNearestVehicleForRoute(
      _selectedRouteNum!,
    );
  }

  List<TrackedVehicle> get vehiclesForSelectedRoute {
    if (_selectedRouteNum == null) return [];
    return _vehicleTrackingService?.getVehiclesForRoute(_selectedRouteNum!) ??
        [];
  }

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

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
      debugPrint("Warning: Mapbox Access Token missing");
      _searchBoxApi = SearchBoxAPI(limit: 5);
    }
  }

  Future<void> initializeFirebase() async {
    debugPrint('Initializing Firebase RTDB...');
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://sakaylive-1-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
    await loadRoutesFromFirebase();

    _vehicleTrackingService = VehicleTrackingService(_database);
    _vehicleTrackingService!.onVehiclesUpdated = _onVehiclesUpdated;
  }

  void _onVehiclesUpdated(List<TrackedVehicle> vehicles) {
    _trackedVehicles = vehicles;
    debugPrint('Received ${vehicles.length} vehicles from tracking service');
    notifyListeners();

    if (_isTrackingEnabled && _isInitialized) {
      debugPrint('Redrawing vehicle markers...');
      _drawVehicleMarkers();
    }
  }

  static const double _nearbyBusRadiusMeters = 2000;

  void setShowOnlyRealConductors(bool value) {
    _showOnlyRealConductors = value;
    if (_isTrackingEnabled) {
      _drawVehicleMarkers();
    }
    notifyListeners();
  }

  // Updates vehicle markers on the map based on current route and filtering rules.
  Future<void> _drawVehicleMarkers() async {
    if (_map == null || !_isInitialized) {
      debugPrint('Cannot draw markers: map=$_map, initialized=$_isInitialized');
      return;
    }

    debugPrint(
      '_drawVehicleMarkers: ${_trackedVehicles.length} total vehicles',
    );
    debugPrint(
      'Filter: route=$_selectedRouteNum, directionIndex=$_selectedDirectionIndex',
    );

    await _mapDrawingService.clearBusMarkers();

    List<TrackedVehicle> vehiclesToShow = [];
    final bool showingSpecificRoute = _selectedRouteNum != null;
    final bool allowVisibility = showingSpecificRoute || _showAllBuses;

    if (allowVisibility) {
      for (var vehicle in _trackedVehicles) {
        if (_showOnlyRealConductors && !vehicle.isRealConductor) continue;

        if (showingSpecificRoute) {
          final vehicleRouteId = vehicle.position.routeId.toLowerCase();
          final selectedRoute = _selectedRouteNum!.toLowerCase();

          final bool routeMatches =
              vehicleRouteId == selectedRoute ||
              vehicleRouteId == 'route_$selectedRoute' ||
              vehicleRouteId == 'route $selectedRoute' ||
              vehicleRouteId.contains(selectedRoute);

          if (!routeMatches) continue;

          if (_selectedDirectionIndex != null) {
            final bool directionMatches =
                vehicle.position.directionIndex == _selectedDirectionIndex;
            debugPrint(
              '  Bus ${vehicle.position.id}: dir=${vehicle.position.directionIndex}, selected=$_selectedDirectionIndex, match=$directionMatches',
            );
            if (!directionMatches) {
              continue;
            }
          }
        }
        vehiclesToShow.add(vehicle);
      }
    }

    if (showingSpecificRoute && vehiclesToShow.isNotEmpty) {
      vehiclesToShow.sort(
        (a, b) => a.distanceToUserMeters.compareTo(b.distanceToUserMeters),
      );
      _highlightedVehicleId = vehiclesToShow.first.position.id;
    } else if (!showingSpecificRoute) {
      _highlightedVehicleId = null;
    }

    if (allowVisibility) {
      final realCount = vehiclesToShow.where((v) => v.isRealConductor).length;
      final simCount = vehiclesToShow.where((v) => !v.isRealConductor).length;
      debugPrint(
        'Showing ${vehiclesToShow.length} buses (Real: $realCount, Simulated: $simCount, Route: $_selectedRouteNum)',
      );
    } else {
      debugPrint('Clean Map Mode: Hiding all buses');
    }

    for (var vehicle in vehiclesToShow) {
      final occupancyColor = _getOccupancyColor(vehicle.position.occupancy);
      final isHighlighted = (vehicle.position.id == _highlightedVehicleId);

      final distanceKm = vehicle.distanceToUserMeters / 1000;
      String distanceText = distanceKm < 1
          ? '${vehicle.distanceToUserMeters.round()}m'
          : '${distanceKm.toStringAsFixed(1)}km';

      String displayLabel = isHighlighted
          ? "Next • $distanceText"
          : (vehicle.isRealConductor
                ? "Verified • $distanceText"
                : distanceText);

      _mapDrawingService.queueBusMarker(
        coordinates: [vehicle.position.lng, vehicle.position.lat],
        etaText: displayLabel,
        routeName: vehicle.routeName,
        routeColor: occupancyColor,
        heading: vehicle.position.heading,
        vehicleId: vehicle.position.id,
        occupancyLabel: vehicle.position.occupancyLabel,
      );
    }
    await _mapDrawingService.flushBusMarkers();
  }

  bool handleMapTap(double lat, double lng) {
    final vehicleId = _mapDrawingService.checkBusTap(lat, lng, tolerance: 80.0);

    if (vehicleId != null) {
      final vehicle = _trackedVehicles.firstWhere(
        (v) => v.position.id == vehicleId,
        orElse: () => _trackedVehicles.first,
      );

      _tappedVehicle = vehicle;
      _mapDrawingService.flyTo(
        lat: vehicle.position.lat,
        lng: vehicle.position.lng,
        zoom: 16.0,
        durationMs: 800,
      );

      debugPrint('Bus tapped: ${vehicle.position.id} - ${vehicle.routeName}');

      notifyListeners();
      return true;
    }

    if (_tappedVehicle != null) {
      _tappedVehicle = null;
      notifyListeners();
    }

    return false;
  }

  void selectBus(TrackedVehicle vehicle) {
    _tappedVehicle = vehicle;
    _mapDrawingService.flyTo(
      lat: vehicle.position.lat,
      lng: vehicle.position.lng,
      zoom: 16.0,
      durationMs: 800,
    );
    notifyListeners();
  }

  void clearTappedBus() {
    _tappedVehicle = null;
    notifyListeners();
  }

  Color _getOccupancyColor(String status) {
    switch (status) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'yellow':
        return const Color(0xFFF59E0B);
      case 'green':
      default:
        return const Color(0xFF22C55E);
    }
  }

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

  void startVehicleTracking() {
    if (_vehicleTrackingService == null) return;

    _isTrackingEnabled = true;

    if (_userLocation != null) {
      _vehicleTrackingService!.setUserLocation(
        _userLocation!.latitude,
        _userLocation!.longitude,
      );
    } else {
      fetchUserLocation();
    }

    _vehicleTrackingService!.setRouteData(
      _routeService.cachedRoutes,
      _cachedRoutes,
    );

    _vehicleTrackingService!.startListening();
    notifyListeners();
  }

  void stopVehicleTracking() {
    _vehicleTrackingService?.stopListening();
    _isTrackingEnabled = false;
    _trackedVehicles = [];
    _tappedVehicle = null;
    _mapDrawingService.clearBusMarkers();
    notifyListeners();
  }

  StreamSubscription? _vehicleSubscription;
  Timer? _simulationTimer;
  final List<VehiclePosition> _activeVehicles = [];
  bool _isSimulating = false;

  void listenToLiveVehicles() {
    startVehicleTracking();
  }

  // Simulates a bus moving along a selected route.
  void startGhostBusSimulation() {
    if (_selectedRouteNum == null || _isSimulating) {
      debugPrint("Select a route first to simulate!");
      return;
    }

    final routeData = _displayList.firstWhere(
      (r) => r['num'] == _selectedRouteNum,
    );

    List<dynamic> rawCoords = [];
    if (routeData['legs'] != null && (routeData['legs'] as List).isNotEmpty) {
      rawCoords = routeData['legs'][0]['coords'];
    } else {
      debugPrint("No coordinates found to drive on.");
      return;
    }

    _isSimulating = true;
    int index = 0;
    final String ghostId = "ghost_bus_${_selectedRouteNum}";

    debugPrint("Simulation Started for $ghostId");

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      if (!isInitialized) return;

      if (index >= rawCoords.length) index = 0;

      final point = rawCoords[index];

      final vehicle = VehiclePosition(
        id: ghostId,
        routeId: _selectedRouteNum!,
        lat: point[1],
        lng: point[0],
        heading: 0,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      try {
        await _database.ref('vehicles/$ghostId').set(vehicle.toJson());
      } catch (e) {
        debugPrint("Firebase Write Error: $e");
      }

      index++;
    });
  }

  void stopTracking() {
    _vehicleSubscription?.cancel();
    _simulationTimer?.cancel();
    _isSimulating = false;
    stopVehicleTracking();
  }

  Timer? _fakeBusTimer;
  final Map<String, Map<String, dynamic>> _fakeBusState = {};

  // Creates and moves multiple simulated buses for testing purposes.
  Future<void> addFakeBuses({int count = 5}) async {
    if (!_routeService.isLoaded) {
      debugPrint("Routes not loaded yet!");
      return;
    }

    _fakeBusTimer?.cancel();
    _fakeBusState.clear();

    final random = math.Random();
    final routes = _routeService.cachedRoutes;

    if (routes.isEmpty) {
      debugPrint("No cached routes available!");
      return;
    }

    debugPrint("Adding fake buses - ensuring both directions per route...");

    final Map<String, List<CachedRoute>> routesByNum = {};
    for (final route in routes) {
      routesByNum.putIfAbsent(route.routeNum, () => []).add(route);
    }

    for (final entry in routesByNum.entries) {
      final dirs = entry.value.map((r) => r.directionIndex).toList();
      debugPrint("  Route ${entry.key}: has ${dirs.length} directions $dirs");
    }

    int busIndex = 0;

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
          "  Bus $busIndex: Route ${route.routeNum} - $dirName (dir=${route.directionIndex})",
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

    debugPrint("Created $busIndex buses covering all route directions!");

    _fakeBusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final entries = _fakeBusState.entries.toList();

      for (final entry in entries) {
        final busId = entry.key;
        final state = entry.value;

        final coords = state['coords'] as List<List<double>>;
        var currentIndex = state['currentIndex'] as int;
        final speed = state['speed'] as int;

        currentIndex += speed;
        if (currentIndex >= coords.length) {
          currentIndex = 0;
        }
        state['currentIndex'] = currentIndex;

        final point = coords[currentIndex];

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
          // Ignore write errors during simulation
        }
      }
    });

    notifyListeners();
  }

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

  void stopFakeBuses() {
    _fakeBusTimer?.cancel();
    _fakeBusTimer = null;
    _fakeBusState.clear();
  }

  Future<void> clearFakeBuses() async {
    stopMovingFakeBuses();
    _fakeBusState.clear();

    try {
      await _database.ref('vehicles').remove();
      _trackedVehicles.clear();
      _tappedVehicle = null;
      await _mapDrawingService.clearBusMarkers();
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing vehicles: $e");
    }
  }

  List<Timer> _busTimers = [];

  void startMovingFakeBuses() {
    if (_fakeBusState.isEmpty) {
      debugPrint("No fake buses to move!");
      return;
    }

    stopMovingFakeBuses();
    final random = math.Random();

    for (final entry in _fakeBusState.entries) {
      final busId = entry.key;
      final state = entry.value;
      final coords = state['coords'] as List<List<double>>;
      int currentIndex = (state['currentIndex'] as num).toInt();
      final speed = 800 + random.nextInt(700);

      final timer = Timer.periodic(Duration(milliseconds: speed), (t) async {
        if (coords.isEmpty) return;
        if (currentIndex >= coords.length - 1) {
          currentIndex = 0;
        }

        final point = coords[currentIndex];

        String occupancy = state['occupancy'] ?? "green";
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
          debugPrint("Error updating moving bus: $e");
        }

        int moveSpeed = (state['speed'] ?? 1) is int
            ? state['speed'] as int
            : (state['speed'] as num).toInt();
        currentIndex += moveSpeed;
        state['currentIndex'] = currentIndex;
      });

      _busTimers.add(timer);
    }
  }

  void stopMovingFakeBuses() {
    for (var timer in _busTimers) {
      timer.cancel();
    }
    _busTimers.clear();

    _fakeBusTimer?.cancel();
    _fakeBusTimer = null;
    notifyListeners();
  }

  Future<void> loadRoutesFromFirebase() async {
    try {
      final snapshot = await _database.ref('routes').get();
      if (snapshot.value == null) {
        debugPrint("No routes found in Firebase");
        return;
      }

      List<dynamic> rawData = snapshot.value as List<dynamic>;
      _cachedRoutes = rawData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      _displayList = List.from(_cachedRoutes);
      debugPrint("Loaded ${_cachedRoutes.length} routes from Firebase");
      notifyListeners();
    } catch (e) {
      debugPrint("Firebase routes error: $e");
      // Fallback to local data
      _cachedRoutes = localRoutesData;
      _displayList = List.from(_cachedRoutes);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> loadGeoJson(String path) async {
    try {
      final parentSnap = await _database.ref(path).get();
      if (parentSnap.value == null) return null;

      final Map<String, dynamic> geoJson = {
        'type': parentSnap.child('type').value ?? 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      final featuresSnap = await _database.ref('$path/features').get();
      if (featuresSnap.value != null) {
        List<dynamic> featuresList = featuresSnap.value as List<dynamic>;

        for (var featureRaw in featuresList) {
          if (featureRaw is Map) {
            geoJson['features'].add(Map<String, dynamic>.from(featureRaw));
          }
        }
      }

      debugPrint(
        "GeoJSON loaded: ${geoJson['features'].length} features from $path",
      );
      return geoJson;
    } catch (e) {
      debugPrint("GeoJson error for $path: $e");
      return null;
    }
  }

  Future<void> initialize(MapboxMap map) async {
    _map = map;
    _mapDrawingService.initialize(map);
    await _mapDrawingService.initAnnotationManager();
    await initializeFirebase();
    await _preloadRoutesForFinding();
    startVehicleTracking();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _preloadRoutesForFinding() async {
    try {
      await _routeService.preloadRoutes(localRoutesData);
      debugPrint(
        "Routes preloaded for route finding: ${_routeService.cachedRoutes.length} directions",
      );
    } catch (e) {
      debugPrint("Failed to preload routes: $e");
    }
  }

  Future<void> _safeDraw(Future<void> Function() drawFn) async {
    if (_map == null || !_isInitialized) {
      debugPrint("Map not ready for drawing");
      return;
    }
    try {
      await drawFn();
    } catch (e) {
      debugPrint("Draw failed: $e");
    }
  }

  void updateSearchText(String text) {
    _searchText = text;
    if (text.isEmpty) {
      _displayList = List.from(_cachedRoutes);
      _selectedRouteNum = null;
      _selectedDirectionIndex = null;
    } else {
      _displayList = _cachedRoutes.where((route) {
        final num = route['num'].toString().toLowerCase();
        final dest = route['dest'].toString().toLowerCase();
        return num.contains(text.toLowerCase()) ||
            dest.contains(text.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  Future<void> fetchUserLocation() async {
    _isFetchingLocation = true;
    notifyListeners();

    try {
      if (_useDemoMode) {
        debugPrint("Using DEMO location: $mockLatitude, $mockLongitude");
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
        final pos = await geo.Geolocator.getCurrentPosition();
        _userLocation = pos;
        debugPrint(
          "Using REAL location: ${_userLocation!.latitude}, ${_userLocation!.longitude}",
        );
      }

      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );

      if (_vehicleTrackingService != null && _isTrackingEnabled) {
        _vehicleTrackingService!.setUserLocation(
          _userLocation!.latitude,
          _userLocation!.longitude,
        );
      }

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

  Future<void> flyToCurrentLocation() async {
    if (_userLocation == null) {
      await fetchUserLocation();
      return;
    }

    debugPrint(
      "Flying to current location: ${_userLocation!.latitude}, ${_userLocation!.longitude}",
    );

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

  void flyToLocation(double lat, double lng, {double zoom = 16.0}) {
    debugPrint("Flying to specific location: $lat, $lng");
    _mapDrawingService.flyTo(lat: lat, lng: lng, zoom: zoom, durationMs: 1200);
  }

  // Uses Mapbox Search to find a location and calculates efficient routes to it.
  Future<bool> planTripToPlace(Map<String, dynamic> item) async {
    debugPrint("planTripToPlace called with: ${item['dest']}");

    if (!_routeService.isLoaded) {
      debugPrint("RouteService not loaded!");
      return false;
    }

    if (_userLocation == null) {
      debugPrint("User location is null!");
      return false;
    }

    final String? mapboxId = item['mapbox_id'];
    if (mapboxId == null) {
      debugPrint("No mapbox_id in item");
      return false;
    }

    try {
      final response = await _searchBoxApi.getPlace(mapboxId);
      _sessionToken = const Uuid().v4();

      bool success = false;
      response.fold((result) {
        if (result.features.isNotEmpty) {
          final destPoint = result.features.first.geometry.coordinates;
          debugPrint("Destination: ${destPoint.lat}, ${destPoint.long}");

          _destinationPoint = Point(
            coordinates: Position(destPoint.long, destPoint.lat),
          );

          final options = _routeService.calculateEfficientRoutes(
            userLat: _userLocation!.latitude,
            userLng: _userLocation!.longitude,
            destLat: destPoint.lat,
            destLng: destPoint.long,
          );

          debugPrint("Found ${options.length} route options");

          if (options.isNotEmpty) {
            _displayList = options.map((o) => o.toDisplayMap()).toList();
            _searchText = item['dest'];
            _selectedRouteNum = null;
            _selectedDirectionIndex = null;
            success = true;
            notifyListeners();
          } else {
            debugPrint("No route options found within walking distance");
          }
        }
      }, (failure) => debugPrint("Search Box Error: ${failure.message}"));

      return success;
    } catch (e) {
      debugPrint("Plan Error: $e");
      return false;
    }
  }

  // Draws a multi-leg trip on the map, including walking and bus segments.
  Future<void> drawTripOnMap(Map<String, dynamic> item) async {
    if (_destinationPoint == null || _userLocation == null) {
      debugPrint("Cannot draw trip: missing destination or user location");
      return;
    }

    try {
      final legs = item['legs'] as List;
      final dest = _destinationPoint!.coordinates;

      _selectedRouteNum = item['num'];
      _selectedDirectionIndex = legs.isNotEmpty
          ? (legs[0]['activeDir'] ?? 0)
          : null;

      _highlightedVehicleId = null;
      List<double>? nearestBusCoords;
      try {
        final busLeg = legs.firstWhere(
          (l) =>
              (l['mode'] == 'BUS' || l['route'] != null) &&
              l['route']['num'] == _selectedRouteNum,
          orElse: () => null,
        );

        if (busLeg != null && _isTrackingEnabled) {
          final pickupLat = busLeg['pickup'][1] as double;
          final pickupLng = busLeg['pickup'][0] as double;
          final legDirIndex = busLeg['activeDir'] ?? 0;
          final routeCoords = busLeg['coords'] as List<List<double>>?;
          final pickupIndex = busLeg['pickupIndex'] as int? ?? 0;

          TrackedVehicle? bestBus;
          double minDistance = double.infinity;

          for (var v in _trackedVehicles) {
            final routeMatches =
                v.position.routeId == _selectedRouteNum ||
                v.position.routeId.toLowerCase() ==
                    _selectedRouteNum?.toLowerCase() ||
                v.position.routeId.toLowerCase().contains(
                  _selectedRouteNum?.toLowerCase() ?? '',
                );
            final directionMatches = v.position.directionIndex == legDirIndex;

            if (routeMatches && directionMatches) {
              if (routeCoords != null &&
                  _hasBusPassedBoarding(
                    routeCoords,
                    v.position.lat,
                    v.position.lng,
                    pickupIndex,
                  )) {
                continue;
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
              "Nearest Bus Found: ${bestBus.position.plateNumber} dir=${bestBus.position.directionIndex} (${(minDistance).round()}m away)",
            );
          }
        }
      } catch (e) {
        debugPrint("Error finding nearest bus: $e");
      }

      _activeTripStats = _calculateTripStats(item, legs, dest);

      notifyListeners();

      await _mapDrawingService.clearNavigationLayers();
      await _mapDrawingService.clearMarkers();

      final List<Future<void>> drawOperations = [];
      var firstLeg = legs[0];

      drawOperations.add(
        _mapDrawingService.drawWalkLine(
          startLat: _userLocation!.latitude,
          startLng: _userLocation!.longitude,
          endLat: firstLeg['pickup'][1],
          endLng: firstLeg['pickup'][0],
          layerId: "walk-start",
        ),
      );

      for (int i = 0; i < legs.length; i++) {
        var leg = legs[i];

        drawOperations.add(
          _mapDrawingService.drawPolyline(
            coordinates: leg['coords'] as List<List<double>>,
            startIndex: leg['pickupIndex'],
            endIndex: leg['dropoffIndex'],
            colorName: leg['route']['color'],
            layerId: "bus-leg-$i",
          ),
        );

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

      await Future.wait(drawOperations);

      final walkToPickupMeters = _haversineDistance(
        _userLocation!.latitude,
        _userLocation!.longitude,
        firstLeg['pickup'][1],
        firstLeg['pickup'][0],
      );
      final walkToPickupMin = _estimateWalkTime(walkToPickupMeters);

      _mapDrawingService.queueMarker(
        coordinates: firstLeg['pickup'],
        label:
            "Board Route ${firstLeg['route']['num']} (~$walkToPickupMin min walk)",
        textColor: Colors.blue.shade700,
      );

      for (int i = 0; i < legs.length - 1; i++) {
        var leg = legs[i];
        var next = legs[i + 1];

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
              "Transfer to Route ${next['route']['num']} (~$transferWalkMin min)",
          textColor: Colors.orange.shade700,
        );
      }

      final walkToDestMeters = _haversineDistance(
        (legs.last)['dropoff'][1],
        (legs.last)['dropoff'][0],
        dest.lat.toDouble(),
        dest.lng.toDouble(),
      );
      final walkToDestMin = _estimateWalkTime(walkToDestMeters);

      _mapDrawingService.queueMarker(
        coordinates: [dest.lng.toDouble(), dest.lat.toDouble()],
        label: "Destination (~$walkToDestMin min walk)",
        textColor: Colors.red.shade700,
      );

      await _mapDrawingService.flushMarkers();

      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );

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
      debugPrint("Trip drawing completed successfully");
    } catch (e) {
      debugPrint("Draw Error: $e");
    }
  }

  void toggleBusVisibility() {
    _showAllBuses = !_showAllBuses;

    if (_showAllBuses && !_isTrackingEnabled) {
      startVehicleTracking();
    }

    _drawVehicleMarkers();
    notifyListeners();
  }

  // Selects a route and draws it on the map with landmark markers.
  Future<void> selectRoute(Map<String, dynamic> route) async {
    _selectedRouteNum = route['num'];
    _selectedDirectionIndex = route['activeDir'] ?? 0;
    _destinationPoint = null;
    _activeTripStats = null;
    notifyListeners();

    await _mapDrawingService.clearNavigationLayers();
    await _mapDrawingService.clearMarkers();

    try {
      int dir = route['activeDir'] ?? 0;
      final directionData = route['directions'][dir];

      debugPrint(
        "Selecting Route ${route['num']} direction $dir: ${directionData['name']}",
      );

      Map<String, dynamic>? geoJsonData;

      if (directionData.containsKey('path')) {
        String dbPath = directionData['path'];
        geoJsonData = await loadGeoJson(dbPath);
      }

      if (geoJsonData != null) {
        await _mapDrawingService.drawGeoJsonRoute(
          geoJsonData: geoJsonData,
          colorName: route['color'],
        );

        final landmarks = _extractLandmarks(geoJsonData);
        if (landmarks.isNotEmpty) {
          final routeId = route['num']?.toString() ?? 'unknown';
          await _addLandmarkLettersWithLayers(routeId, landmarks);
        }
      } else if (directionData.containsKey('asset')) {
        String assetPath = directionData['asset'];

        await _mapDrawingService.drawRouteFromAsset(
          assetPath: assetPath,
          colorName: route['color'],
        );

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
      debugPrint("Route ${route['num']} drawn successfully");
    } catch (e) {
      debugPrint("Select route error: $e");
    }
  }

  Future<void> swapRouteDirection(Map<String, dynamic> route) async {
    int currentDir = route['activeDir'] ?? 0;
    route['activeDir'] = (currentDir + 1) % route['directions'].length;

    _selectedDirectionIndex = route['activeDir'];

    final cachedIndex = _cachedRoutes.indexWhere(
      (r) => r['num'] == route['num'],
    );
    if (cachedIndex != -1) {
      _cachedRoutes[cachedIndex]['activeDir'] = route['activeDir'];
    }

    if (_selectedRouteNum == route['num']) {
      await selectRoute(route);
    }

    notifyListeners();
  }

  Future<void> clearSelection() async {
    debugPrint("Clearing map selections...");
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

    if (_userLocation != null) {
      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );
    }

    if (_isTrackingEnabled) {
      _drawVehicleMarkers();
    }

    notifyListeners();
  }

  void handleItemSelection(Map<String, dynamic> item) {
    if (item['type'] == 'trip_option') {
      drawTripOnMap(item);
    } else if (item['type'] == 'route') {
      selectRoute(item);
    } else {
      planTripToPlace(item);
    }
  }

  // Calculates walking distances, estimated times, and finds the nearest bus for a trip.
  Map<String, dynamic> _calculateTripStats(
    Map<String, dynamic> item,
    List legs,
    dynamic dest,
  ) {
    double totalWalkMeters = 0;
    final int rideCount = legs.length;
    final int totalTime = item['totalTime'] ?? 15;
    final bool isTransfer = legs.length > 1;

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

    final walkTimeMin = _estimateWalkTime(totalWalkMeters);

    final routeNames = legs.map((leg) {
      final num = leg['route']['num'];
      final dest = leg['route']['dest'] ?? '';
      return 'Route $num ${dest.isNotEmpty ? '- $dest' : ''}';
    }).toList();

    String? nextBusEta;
    String? nextBusOccupancy;
    String? nextBusPlate;
    double? nextBusDistanceMeters;
    double? nextBusDistanceToBoarding;

    if (legs.isNotEmpty) {
      final firstLeg = legs[0];
      final firstRouteNum = firstLeg['route']['num'].toString();
      final firstLegDirIndex = firstLeg['activeDir'] ?? 0;
      final boardingLat = firstLeg['pickup'][1] as double;
      final boardingLng = firstLeg['pickup'][0] as double;
      final routeCoords = firstLeg['coords'] as List<List<double>>?;
      final pickupIndex = firstLeg['pickupIndex'] as int? ?? 0;

      var busesForRoute = _trackedVehicles.where((v) {
        final vehicleRouteId = v.position.routeId.toLowerCase();
        final routeNum = firstRouteNum.toLowerCase();

        final routeMatches =
            vehicleRouteId == routeNum ||
            vehicleRouteId == 'route_$routeNum' ||
            vehicleRouteId == 'route $routeNum' ||
            vehicleRouteId.contains(routeNum);

        final directionMatches = v.position.directionIndex == firstLegDirIndex;

        return routeMatches && directionMatches;
      }).toList();

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

        final distToBoarding = _haversineDistance(
          nearestBus.position.lat,
          nearestBus.position.lng,
          boardingLat,
          boardingLng,
        );

        final etaMinutes = (distToBoarding / 1000 / 20 * 60).round();
        nextBusEta = etaMinutes < 1 ? 'Arriving' : '~$etaMinutes min';
        nextBusOccupancy = nearestBus.position.occupancyLabel;
        nextBusPlate = nearestBus.position.plateNumber;
        nextBusDistanceMeters = nearestBus.distanceToUserMeters;
        nextBusDistanceToBoarding = distToBoarding;

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
      'nextBusEta': nextBusEta,
      'nextBusOccupancy': nextBusOccupancy,
      'nextBusPlate': nextBusPlate,
      'nextBusDistanceMeters': nextBusDistanceMeters,
      'nextBusDistanceToBoarding': nextBusDistanceToBoarding,
      'hasNextBus': nextBusEta != null,
    };
  }

  int _estimateWalkTime(double meters) {
    final minutes = (meters / 80).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  int _findClosestPointIndex(
    List<List<double>> coords,
    double lat,
    double lng, {
    double maxDistance = 500,
  }) {
    int closestIdx = -1;
    double minDist = maxDistance;

    for (int i = 0; i < coords.length; i++) {
      final point = coords[i];
      final dist = _haversineDistance(lat, lng, point[1], point[0]);
      if (dist < minDist) {
        minDist = dist;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  bool _hasBusPassedBoarding(
    List<List<double>> routeCoords,
    double busLat,
    double busLng,
    int pickupIndex,
  ) {
    final busIndex = _findClosestPointIndex(routeCoords, busLat, busLng);
    if (busIndex < 0) return false;
    return busIndex > pickupIndex;
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000;
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

  Future<void> _addLandmarkLettersWithLayers(
    String routeId,
    List<Map<String, dynamic>> landmarks,
  ) async {
    if (_map == null || landmarks.isEmpty) return;

    try {
      await _clearLandmarkLayers();

      final startLandmark = landmarks.first;
      final endLandmark = landmarks.last;

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
      debugPrint('Added Start and End markers for route $routeId');
    } catch (e) {
      debugPrint('Error adding landmark layers: $e');
    }
  }

  Future<void> _clearLandmarkLayers() async {
    if (_map == null || _currentRouteWithLandmarks == null) return;

    try {
      await _map!.style.removeStyleLayer('start-text');
      await _map!.style.removeStyleLayer('start-circle');
      await _map!.style.removeStyleSource('start-source');

      await _map!.style.removeStyleLayer('end-text');
      await _map!.style.removeStyleLayer('end-circle');
      await _map!.style.removeStyleSource('end-source');

      _currentRouteWithLandmarks = null;
      debugPrint('Cleared landmark layers');
    } catch (e) {
      debugPrint('Note: Landmark layers may not exist yet');
    }
  }
}
