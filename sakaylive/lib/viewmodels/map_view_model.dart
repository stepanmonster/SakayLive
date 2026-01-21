import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:uuid/uuid.dart';
import 'package:sakaylive/data/jeepney_routes.dart';
import 'package:sakaylive/models/trip_option.dart';
import 'package:sakaylive/services/route_service.dart';
import 'package:sakaylive/services/map_drawing_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:sakaylive/services/auth_service.dart';
import 'package:flutter/services.dart'; // for rootBundle

/// ViewModel for the Map Screen following MVVM pattern.
/// Contains all business logic and state management.
class MapViewModel extends ChangeNotifier {
  // --- SERVICES ---
  final RouteService _routeService = RouteService();
  final MapDrawingService _mapDrawingService = MapDrawingService();
  MapboxMap? _map;

  // --- FIREBASE ---
  late final FirebaseDatabase _database;

  // --- API ---
  late SearchBoxAPI _searchBoxApi;
  String _sessionToken = const Uuid().v4();

  // --- MOCK LOCATION FOR TESTING ---
  // Set to true to use fake location instead of real GPS
  static const bool useMockLocation = true;
  // PHV6+497, Quintin Salas St, Jaro, Iloilo City, 5000 Iloilo
  static const double mockLatitude = 10.7244;
  static const double mockLongitude = 122.5575;

  // --- STATE ---
  bool _isInitialized = false;
  bool _isFetchingLocation = false;
  geo.Position? _userLocation;
  Point? _destinationPoint;
  String? _selectedRouteNum;
  String? _currentRouteWithLandmarks; // Track which route has landmarks displayed
  String _searchText = '';
  List<Map<String, dynamic>> _cachedRoutes = []; // 🔥 FIREBASE ROUTES
  List<Map<String, dynamic>> _displayList = [];

  // --- TRIP STATISTICS ---
  Map<String, dynamic>? _activeTripStats;

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
      if (useMockLocation) {
        // 🧪 MOCK LOCATION: PHV6+497, Quintin Salas St, Jaro, Iloilo City
        debugPrint("🧪 Using MOCK location: $mockLatitude, $mockLongitude");
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

      _mapDrawingService.fitCameraToTrip(
        userLat: _userLocation!.latitude,
        userLng: _userLocation!.longitude,
        destLat: dest.lat.toDouble(),
        destLng: dest.lng.toDouble(),
      );
    } catch (e) {
      debugPrint("Draw Error: $e");
    }
  }

  /// 🔥 UPDATED: Select route with Firebase GeoJSON or local assets
  /// 🔥 UPDATED: Select route with Firebase GeoJSON or local assets + landmarks
Future<void> selectRoute(Map<String, dynamic> route) async {
  _selectedRouteNum = route['num'];
  _destinationPoint = null;
  _activeTripStats = null; // Clear trip stats when selecting a route
  notifyListeners();

  await _mapDrawingService.clearNavigationLayers();
  await _mapDrawingService.clearMarkers();

  try {
    int dir = route['activeDir'] ?? 0;
    final directionData = route['directions'][dir];
    Map<String, dynamic>? geoJsonData;

    // Check if it's a Firebase path or local asset
    if (directionData.containsKey('path')) {
      // Firebase path
      String dbPath = directionData['path'];
      geoJsonData = await loadGeoJson(dbPath);
      if (geoJsonData != null) {
        await _mapDrawingService.drawGeoJsonRoute(
          geoJsonData: geoJsonData,
          colorName: route['color'],
        );
        
        // ✅ ADD LANDMARK LETTERS
        final landmarks = _extractLandmarks(geoJsonData);
        if (landmarks.isNotEmpty) {
          final routeId = route['num']?.toString() ?? 'unknown';
          await _addLandmarkLettersWithLayers(routeId, landmarks);
        }
      }
    } else if (directionData.containsKey('asset')) {
      // Local asset path
      String assetPath = directionData['asset'];
      
      // First draw the route
      await _mapDrawingService.drawRouteFromAsset(
        assetPath: assetPath,
        colorName: route['color'],
      );
      
      // ✅ Load GeoJSON from asset to get landmarks
      try {
        // Import flutter/services.dart for rootBundle
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

  _mapDrawingService.flyTo(lat: 10.7202, lng: 122.5644, zoom: 13.0);
}

  /// Swap route direction.
  /// Swap route direction.
Future<void> swapRouteDirection(Map<String, dynamic> route) async {
  int currentDir = route['activeDir'] ?? 0;
  route['activeDir'] = (currentDir + 1) % route['directions'].length;

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
    _destinationPoint = null;
    _activeTripStats = null;
    _displayList = List.from(_cachedRoutes);

    await _mapDrawingService.clearNavigationLayers();
    await _mapDrawingService.clearMarkers();

    // Redraw user location marker
    if (_userLocation != null) {
      await _mapDrawingService.drawUserLocationMarker(
        lat: _userLocation!.latitude,
        lng: _userLocation!.longitude,
      );
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

    return {
      'walkKm': totalWalkMeters / 1000,
      'walkTimeMin': walkTimeMin,
      'rideCount': rideCount,
      'totalTime': totalTime,
      'isTransfer': isTransfer,
      'routeNames': routeNames,
    };
  }

  /// Estimate walking time in minutes from distance in meters
  /// Average walking speed: ~80 meters per minute (4.8 km/h)
  int _estimateWalkTime(double meters) {
    // 80 meters per minute is a comfortable walking pace
    final minutes = (meters / 80).ceil();
    return minutes < 1 ? 1 : minutes; // Minimum 1 minute
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

  List<Map<String, dynamic>> _extractLandmarks(Map<String, dynamic> geoJsonData) {
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
  List<Map<String, dynamic>> landmarks
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
      'features': [{
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': startLandmark['coordinates'],
        },
        'properties': {
          'label': 'Start',
          'name': startLandmark['name'],
        }
      }]
    };
    
    // End marker GeoJSON
    final endGeoJson = {
      'type': 'FeatureCollection',
      'features': [{
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': endLandmark['coordinates'],
        },
        'properties': {
          'label': 'End',
          'name': endLandmark['name'],
        }
      }]
    };
    
    // Add start source and layers
    await _map!.style.addSource(
      GeoJsonSource(
        id: 'start-source',
        data: jsonEncode(startGeoJson),
      ),
    );
    
    await _map!.style.addLayer(
      CircleLayer(
        id: 'start-circle',
        sourceId: 'start-source',
      )..circleRadius = 18.0
       ..circleColor = Colors.green.value
       ..circleStrokeWidth = 3.0
       ..circleStrokeColor = Colors.white.value,
    );
    
    await _map!.style.addLayer(
      SymbolLayer(
        id: 'start-text',
        sourceId: 'start-source',
      )..textField = "{label}"
       ..textSize = 12.0
       ..textColor = Colors.white.value
       ..textHaloColor = Colors.black.value
       ..textHaloWidth = 1.0
       ..textAllowOverlap = true
       ..textIgnorePlacement = true,
    );
    
    // Add end source and layers
    await _map!.style.addSource(
      GeoJsonSource(
        id: 'end-source',
        data: jsonEncode(endGeoJson),
      ),
    );
    
    await _map!.style.addLayer(
      CircleLayer(
        id: 'end-circle',
        sourceId: 'end-source',
      )..circleRadius = 18.0
       ..circleColor = Colors.red.value
       ..circleStrokeWidth = 3.0
       ..circleStrokeColor = Colors.white.value,
    );
    
    await _map!.style.addLayer(
      SymbolLayer(
        id: 'end-text',
        sourceId: 'end-source',
      )..textField = "{label}"
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
