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
import 'package:sakaylive/services/auth_service.dart';

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

  // --- STATE ---
  bool _isInitialized = false;
  bool _isFetchingLocation = false;
  geo.Position? _userLocation;
  Point? _destinationPoint;
  String? _selectedRouteNum;
  String _searchText = '';
  List<Map<String, dynamic>> _cachedRoutes = [];  // 🔥 FIREBASE ROUTES
  List<Map<String, dynamic>> _displayList = [];

  // --- GETTERS ---
  bool get isInitialized => _isInitialized;
  bool get isRoutesLoaded => _cachedRoutes.isNotEmpty;  // 🔥 CHANGED
  bool get isFetchingLocation => _isFetchingLocation;
  geo.Position? get userLocation => _userLocation;
  Point? get destinationPoint => _destinationPoint;
  String? get selectedRouteNum => _selectedRouteNum;
  String get searchText => _searchText;
  List<Map<String, dynamic>> get displayList => _displayList;
  List<Map<String, dynamic>> get localRoutes => _cachedRoutes;  // 🔥 CHANGED
  SearchBoxAPI get searchBoxApi => _searchBoxApi;
  MapDrawingService get mapDrawingService => _mapDrawingService;
  String get sessionToken => _sessionToken;

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
      databaseURL: 'https://sakaylive-1-default-rtdb.asia-southeast1.firebasedatabase.app'
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
    await initializeFirebase();  // 🔥 FIREBASE FIRST
    _isInitialized = true;
    notifyListeners();
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
      _displayList = List.from(_cachedRoutes);  // 🔥 CHANGED
      _selectedRouteNum = null;
    } else {
      // Filter cached routes
      _displayList = _cachedRoutes.where((route) {
        final num = route['num'].toString().toLowerCase();
        final dest = route['dest'].toString().toLowerCase();
        return num.contains(text.toLowerCase()) || dest.contains(text.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }

  /// Handle user location fetch.
  Future<void> fetchUserLocation() async {
    _isFetchingLocation = true;
    notifyListeners();

    try {
      final pos = await geo.Geolocator.getCurrentPosition();
      _userLocation = pos;
      _mapDrawingService.flyTo(
        lat: pos.latitude,
        lng: pos.longitude,
        zoom: 14.5,
        durationMs: 2000,
      );
    } catch (e) {
      debugPrint("Location Error: $e");
    }

    _isFetchingLocation = false;
    notifyListeners();
  }

  /// Plan a trip to a place from search results.
  Future<bool> planTripToPlace(Map<String, dynamic> item) async {
    if (!_routeService.isLoaded || _userLocation == null) return false;

    final String? mapboxId = item['mapbox_id'];
    if (mapboxId == null) return false;

    try {
      final response = await _searchBoxApi.getPlace(mapboxId);
      _sessionToken = const Uuid().v4();

      bool success = false;
      response.fold((result) {
        if (result.features.isNotEmpty) {
          final destPoint = result.features.first.geometry.coordinates;
          _destinationPoint = Point(
            coordinates: Position(destPoint.long, destPoint.lat),
          );

          final options = _routeService.calculateEfficientRoutes(
            userLat: _userLocation!.latitude,
            userLng: _userLocation!.longitude,
            destLat: destPoint.lat,
            destLng: destPoint.long,
          );

          if (options.isNotEmpty) {
            _displayList = options.map((o) => o.toDisplayMap()).toList();
            _searchText = item['dest'];
            _selectedRouteNum = null;
            success = true;
            notifyListeners();
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

      // Board marker
      _mapDrawingService.queueMarker(
        coordinates: firstLeg['pickup'],
        label: "● Board here",
        textColor: Colors.blue.shade700,
      );

      // Transfer markers
      for (int i = 0; i < legs.length - 1; i++) {
        var leg = legs[i];
        var next = legs[i + 1];
        _mapDrawingService.queueMarker(
          coordinates: leg['dropoff'],
          label: "↔ Transfer to ${next['route']['num']}",
          textColor: Colors.orange.shade700,
        );
      }

      // Destination marker
      _mapDrawingService.queueMarker(
        coordinates: [dest.lng.toDouble(), dest.lat.toDouble()],
        label: "◉ Destination",
        textColor: Colors.red.shade700,
      );

      // Flush all markers in one batch
      await _mapDrawingService.flushMarkers();

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

  /// 🔥 UPDATED: Select route with Firebase GeoJSON
  Future<void> selectRoute(Map<String, dynamic> route) async {
    _selectedRouteNum = route['num'];
    _destinationPoint = null;
    notifyListeners();

    await _mapDrawingService.clearNavigationLayers();
    await _mapDrawingService.clearMarkers();

    try {
      int dir = route['activeDir'] ?? 0;
      String dbPath = route['directions'][dir]['path'];  // 🔥 PATH not asset
      
      final geoJsonData = await loadGeoJson(dbPath);
      if (geoJsonData != null) {
        await _mapDrawingService.drawGeoJsonRoute(
          geoJsonData: geoJsonData,
          colorName: route['color'],
        );
      }
    } catch (e) {
      debugPrint("Select route error: $e");
    }

    _mapDrawingService.flyTo(lat: 10.7202, lng: 122.5644, zoom: 13.0);
  }

    /// Swap route direction.
    void swapRouteDirection(Map<String, dynamic> route) {
      int currentDir = route['activeDir'] ?? 0;
      route['activeDir'] = (currentDir + 1) % route['directions'].length;
      
      // Update cached route too
      final cachedIndex = _cachedRoutes.indexWhere((r) => r['num'] == route['num']);
      if (cachedIndex != -1) {
        _cachedRoutes[cachedIndex]['activeDir'] = route['activeDir'];
      }
      
      notifyListeners();
    }

  /// Clear all selections and reset to default state.
  Future<void> clearSelection() async {
    _searchText = '';
    _selectedRouteNum = null;
    _destinationPoint = null;
    _displayList = List.from(_cachedRoutes);  // 🔥 CHANGED

    await _mapDrawingService.clearNavigationLayers();
    await _mapDrawingService.clearMarkers();

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
}
