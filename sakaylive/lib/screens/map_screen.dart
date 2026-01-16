import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_search/mapbox_search.dart' hide Color;
import 'package:uuid/uuid.dart';
import 'package:sakaylive/data/jeepney_routes.dart';
import 'package:sakaylive/screens/login_page.dart';
import 'package:sakaylive/screens/routes_list_page.dart';
import 'package:sakaylive/screens/search_page.dart';
import 'package:sakaylive/screens/theme.dart';
import 'package:sakaylive/widgets/sakay_bottom_sheet.dart';

// --- HELPER CLASS FOR CACHED ROUTES ---
class CachedRoute {
  final Map<String, dynamic> rawData;
  final int dirIdx;
  final List<List<double>> coords; // Cached coordinates [lng, lat]

  CachedRoute({
    required this.rawData,
    required this.dirIdx,
    required this.coords,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- CONTROLLERS ---
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();

  // --- DATA ---
  late SearchBoxAPI _searchBoxApi;
  String _sessionToken = const Uuid().v4();

  // CACHE: Stores parsed coordinates to avoid lagging the UI during search
  List<CachedRoute> _cachedRoutes = [];
  bool _isRoutesLoaded = false;

  bool _isFetchingLocation = false;
  List<Map<String, dynamic>> _displayList = [];
  String? _selectedRouteNum;

  // --- TRIP POINTS ---
  geo.Position? _userLocation;
  Point? _destinationPoint;
  Point? _pickupPoint;
  Point? _dropoffPoint;

  final List<Map<String, dynamic>> _localRoutes = localRoutesData;

  @override
  void initState() {
    super.initState();
    _displayList = List.from(_localRoutes);
    _initMapboxApi();
    _preloadRoutes(); // Load routes into memory once
  }

  void _initMapboxApi() {
    final String token = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');
    if (token.isNotEmpty) {
      MapBoxSearch.init(token);
      _searchBoxApi = SearchBoxAPI(limit: 5, country: 'PH');
    } else {
      debugPrint("⚠️ WARNING: Mapbox Access Token missing");
      _searchBoxApi = SearchBoxAPI(limit: 5);
    }
  }

  // --- OPTIMIZATION: PRELOAD ROUTES ---
  Future<void> _preloadRoutes() async {
    for (var route in _localRoutes) {
      List directions = route['directions'];
      for (int dirIdx = 0; dirIdx < directions.length; dirIdx++) {
        try {
          String assetPath = directions[dirIdx]['asset'];
          final String geojson = await rootBundle.loadString(assetPath);
          final Map<String, dynamic> data = json.decode(geojson);

          // robust coordinate extraction
          List<dynamic> rawCoords = [];
          if (data['type'] == 'FeatureCollection') {
            rawCoords = data['features'][0]['geometry']['coordinates'];
          } else {
            rawCoords = data['geometry']['coordinates'];
          }

          // Convert to List<List<double>> for speed
          List<List<double>> parsedCoords = rawCoords.map((c) {
            return [(c[0] as num).toDouble(), (c[1] as num).toDouble()];
          }).toList();

          _cachedRoutes.add(
            CachedRoute(rawData: route, dirIdx: dirIdx, coords: parsedCoords),
          );
        } catch (e) {
          debugPrint("Error loading route ${route['num']}: $e");
        }
      }
    }
    setState(() => _isRoutesLoaded = true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // --- UI & NAVIGATION METHODS (Unchanged logic, compacted) ---
  void _openSearchPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(searchBoxApi: _searchBoxApi),
      ),
    );
    if (result != null && result is Map<String, dynamic>)
      _handleItemSelection(result);
  }

  void _openRoutesPage() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutesListPage()),
    );
    if (selected != null) {
      final route = _localRoutes.firstWhere(
        (r) => r['num'] == selected['num'],
        orElse: () => selected,
      );
      if (selected['activeDir'] != null)
        route['activeDir'] = selected['activeDir'];
      _selectRoute(route);
    }
  }

  void _handleItemSelection(Map<String, dynamic> item) {
    if (item['type'] == 'trip_option')
      _drawTripOnMap(item);
    else if (item['type'] == 'route')
      _selectRoute(item);
    else
      _planTripToPlace(item);
  }

  // --- 1. TRIP PLANNING LOGIC ---
  void _planTripToPlace(Map<String, dynamic> item) async {
    FocusScope.of(context).unfocus();
    if (!_isRoutesLoaded) return;

    final String? mapboxId = item['mapbox_id'];
    if (mapboxId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Finding best routes..."),
        duration: Duration(milliseconds: 800),
      ),
    );

    try {
      final response = await _searchBoxApi.getPlace(mapboxId);
      _sessionToken = const Uuid().v4(); // Reset session

      response.fold((success) async {
        if (success.features.isNotEmpty) {
          final destPoint = success.features.first.geometry.coordinates;
          _destinationPoint = Point(
            coordinates: Position(destPoint.long, destPoint.lat),
          );

          if (_userLocation != null) {
            final options = _calculateEfficientRoutes(
              _userLocation!.latitude,
              _userLocation!.longitude,
              destPoint.lat,
              destPoint.long,
            );

            if (options.isNotEmpty) {
              setState(() {
                _displayList = options;
                _searchController.text = item['dest'];
                _selectedRouteNum = null;
                _pickupPoint = null;
                _dropoffPoint = null;
              });
              _sheetController.animateTo(
                0.4,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
              _clearNavigationLayers();
              _updateMapAnnotations();
              _fitCameraToTrip(destPoint.lat, destPoint.long);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("No routes found within walking distance."),
                ),
              );
            }
          }
        }
      }, (failure) => debugPrint("Error: ${failure.message}"));
    } catch (e) {
      debugPrint("Plan Error: $e");
    }
  }

  // --- 2. OPTIMIZED ALGORITHM ---
  List<Map<String, dynamic>> _calculateEfficientRoutes(
    double uLat,
    double uLng,
    double dLat,
    double dLng,
  ) {
    List<Map<String, dynamic>> results = [];

    // Step A: Filter routes near Start and End (Spatial Indexing Lite)
    // We use the cached coordinates for speed.
    List<Map<String, dynamic>> startCandidates = [];
    List<Map<String, dynamic>> endCandidates = [];

    for (var cached in _cachedRoutes) {
      // Find closest node to User
      int pIdx = -1;
      double minP = 1000.0; // 1km max walk start
      for (int i = 0; i < cached.coords.length; i++) {
        double d = _fastDist(
          uLat,
          uLng,
          cached.coords[i][1],
          cached.coords[i][0],
        );
        if (d < minP) {
          minP = d;
          pIdx = i;
        }
      }

      // Find closest node to Dest
      int dIdx = -1;
      double minD = 1000.0; // 1km max walk end
      for (int i = 0; i < cached.coords.length; i++) {
        double d = _fastDist(
          dLat,
          dLng,
          cached.coords[i][1],
          cached.coords[i][0],
        );
        if (d < minD) {
          minD = d;
          dIdx = i;
        }
      }

      var meta = {
        'cached': cached,
        'pIdx': pIdx, // Index where user gets ON
        'dIdx': dIdx, // Index where user gets OFF
      };

      if (pIdx != -1) startCandidates.add(meta);
      if (dIdx != -1) endCandidates.add(meta);
    }

    // Step B: Direct Trips
    for (var leg in startCandidates) {
      if (leg['dIdx'] != -1 && leg['pIdx'] < leg['dIdx']) {
        results.add(_buildTripResult([leg]));
      }
    }

    // Step C: Transfer Trips (Only if needed)
    if (results.length < 3) {
      for (var leg1 in startCandidates) {
        for (var leg2 in endCandidates) {
          var r1 = leg1['cached'] as CachedRoute;
          var r2 = leg2['cached'] as CachedRoute;
          if (r1.rawData['num'] == r2.rawData['num']) continue; // Same route

          // Find Intersection
          // We look for a point where Route A (after user boarding)
          // comes close to Route B (before user alighting).
          var transfer = _findIntersection(
            r1.coords,
            leg1['pIdx'],
            r2.coords,
            leg2['dIdx'],
          );

          if (transfer != null) {
            // Clone and modify indices for the transfer logic
            var l1 = Map<String, dynamic>.from(leg1);
            l1['dIdx'] = transfer['idx1']; // Drop off at transfer

            var l2 = Map<String, dynamic>.from(leg2);
            l2['pIdx'] = transfer['idx2']; // Pick up at transfer

            // Validate directionality
            if (l1['pIdx'] < l1['dIdx'] && l2['pIdx'] < l2['dIdx']) {
              results.add(_buildTripResult([l1, l2]));
            }
          }
        }
      }
    }

    // Sort by total estimated time
    results.sort(
      (a, b) => (a['totalTime'] as int).compareTo(b['totalTime'] as int),
    );
    return results.take(3).toList();
  }

  // Optimized Intersection Finder
  Map<String, int>? _findIntersection(
    List<List<double>> c1,
    int start1,
    List<List<double>> c2,
    int end2,
  ) {
    // Iterate Route A forward from boarding point
    for (int i = start1; i < c1.length; i += 2) {
      // Skip 1 point for speed
      double lat1 = c1[i][1];
      double lng1 = c1[i][0];

      // Iterate Route B forward from start until dropoff point
      for (int j = 0; j < end2; j += 2) {
        double lat2 = c2[j][1];
        double lng2 = c2[j][0];

        // 150m transfer tolerance
        if (_fastDist(lat1, lng1, lat2, lng2) < 150.0) {
          return {'idx1': i, 'idx2': j}; // Valid transfer found
        }
      }
    }
    return null;
  }

  // --- 3. DRAWING & UI CONSTRUCTION ---
  Map<String, dynamic> _buildTripResult(List<Map<String, dynamic>> legs) {
    int totalTime = 0;
    List<Map<String, dynamic>> uiLegs = [];

    for (var leg in legs) {
      CachedRoute cr = leg['cached'];
      int p = leg['pIdx'];
      int d = leg['dIdx'];

      // Calculate distance nodes
      int nodes = (d - p).abs();
      totalTime += (nodes * 0.15).ceil() + 5; // Rough estimate + wait time

      uiLegs.add({
        'route': cr.rawData,
        'activeDir': cr.dirIdx,
        'coords': cr.coords, // Pass full coords for drawing slicing
        'pickup': cr.coords[p],
        'dropoff': cr.coords[d],
        'pickupIndex': p,
        'dropoffIndex': d,
      });
    }

    String desc = legs.length == 1
        ? "Ride ${uiLegs[0]['route']['num']}"
        : "${uiLegs[0]['route']['num']} ➔ ${uiLegs[1]['route']['num']}";

    // Ensure safe default for the UI list
    var primaryRoute = uiLegs[0]['route'];
    int primaryDir = uiLegs[0]['activeDir'];

    return {
      "type": "trip_option",
      "num": primaryRoute['num'],
      "dest": desc,
      "status": legs.length > 1 ? "Transfer" : "Direct",
      "color": primaryRoute['color'],
      "time": "$totalTime min",
      "totalTime": totalTime,
      "walk_dist_text": "View Map",

      // Critical fields for the UI List to prevent crashes
      "activeDir": primaryDir,
      "route_data": primaryRoute,
      "directions":
          primaryRoute['directions'], // Pass directions list for the tile

      "legs": uiLegs,
    };
  }

  void _drawTripOnMap(Map<String, dynamic> item) async {
    try {
      final legs = item['legs'] as List;
      final dest = _destinationPoint!.coordinates;

      setState(() {
        _selectedRouteNum = item['num'];
        _pickupPoint = null;
        _dropoffPoint = null;
      });

      await _clearNavigationLayers();
      await _pointAnnotationManager?.deleteAll();

      // 1. Walk from User to First Boarding
      var l1 = legs[0];
      await _drawWalkLine(
        _userLocation!.latitude,
        _userLocation!.longitude,
        l1['pickup'][1],
        l1['pickup'][0],
        "walk-start",
      );

      for (int i = 0; i < legs.length; i++) {
        var leg = legs[i];

        // 2. Draw Bus Path
        await _drawPolyline(
          leg['coords'] as List<List<double>>,
          leg['pickupIndex'],
          leg['dropoffIndex'],
          leg['route']['color'],
          "bus-leg-$i",
        );

        // 3. Markers
        await _addMarker(
          leg['pickup'],
          i == 0 ? "Board" : "Transfer",
          Colors.blue,
        );
        if (i == legs.length - 1) {
          await _addMarker(leg['dropoff'], "Alight", Colors.green);
        }

        // 4. Transfer Walk (if needed)
        if (i < legs.length - 1) {
          var next = legs[i + 1];
          await _drawWalkLine(
            leg['dropoff'][1],
            leg['dropoff'][0],
            next['pickup'][1],
            next['pickup'][0],
            "walk-transfer-$i",
          );
        }
      }

      // 5. Walk to Destination
      var last = legs.last;
      await _drawWalkLine(
        last['dropoff'][1],
        last['dropoff'][0],
        dest.lat.toDouble(),
        dest.lng.toDouble(),
        "walk-end",
      );
      await _addMarker(
        [dest.lng.toDouble(), dest.lat.toDouble()],
        "Dest",
        Colors.red,
      );

      _fitCameraToTrip(dest.lat.toDouble(), dest.lng.toDouble());
      _sheetController.animateTo(
        0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint("Draw Error: $e");
    }
  }

  // --- DRAWING UTILS ---
  Future<void> _drawPolyline(
    List<List<double>> fullCoords,
    int start,
    int end,
    String colorName,
    String layerId,
  ) async {
    if (_mapboxMap == null) return;
    int s = min(start, end);
    int e = max(start, end);
    if (s >= e) return;

    List<List<double>> segment = fullCoords.sublist(s, e + 1);

    final geoJson = {
      "type": "Feature",
      "properties": {},
      "geometry": {"type": "LineString", "coordinates": segment},
    };
    final style = _mapboxMap!.style;

    if (await style.styleSourceExists("$layerId-source")) {
      await style.removeStyleLayer("$layerId-layer");
      await style.removeStyleSource("$layerId-source");
    }
    await style.addSource(
      GeoJsonSource(id: "$layerId-source", data: json.encode(geoJson)),
    );
    await style.addLayer(
      LineLayer(
        id: "$layerId-layer",
        sourceId: "$layerId-source",
        lineColor: _getRouteColor(colorName).value,
        lineWidth: 6.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Future<void> _drawWalkLine(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    String id,
  ) async {
    // Just draw a dotted straight line for performance (API calls are expensive/slow)
    // Or use the API if you prefer accuracy over speed/cost.
    // Here using simple straight line GeoJSON for instant feedback.
    final geoJson = {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [lng1, lat1],
          [lng2, lat2],
        ],
      },
    };
    final style = _mapboxMap!.style;
    if (await style.styleSourceExists("$id-source")) {
      await style.removeStyleLayer("$id-layer");
      await style.removeStyleSource("$id-source");
    }
    await style.addSource(
      GeoJsonSource(id: "$id-source", data: json.encode(geoJson)),
    );
    await style.addLayer(
      LineLayer(
        id: "$id-layer",
        sourceId: "$id-source",
        lineColor: Colors.grey.shade600.value,
        lineWidth: 4.0,
        lineDasharray: [1.0, 1.5],
      ),
    );
  }

  Future<void> _addMarker(
    List<double> coords,
    String label,
    MaterialColor color,
  ) async {
    await _pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(coords[0], coords[1])),
        textField: label,
        textSize: 12.0,
        textOffset: [0, -1.5],
        textColor: color.shade800.value,
        iconImage: "marker-15",
        iconColor: color.value,
      ),
    );
  }

  // --- UTILS ---
  // Haversine optimized for pure math (no platform channel overhead)
  double _fastDist(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  // --- BOILERPLATE (Map Setup, Location, etc) ---
  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    map.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    map.logo.updateSettings(LogoSettings(marginBottom: 150, marginLeft: 16));
    map.attribution.updateSettings(
      AttributionSettings(marginBottom: 150, marginLeft: 100),
    );
    _handleLocationPermission();
  }

  void _onStyleLoaded(StyleLoadedEventData d) async {
    _pointAnnotationManager = await _mapboxMap!.annotations
        .createPointAnnotationManager();
  }

  Future<void> _handleLocationPermission() async {
    setState(() => _isFetchingLocation = true);
    try {
      final pos = await geo.Geolocator.getCurrentPosition();
      setState(() => _userLocation = pos);
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 2000),
      );
    } catch (_) {}
    if (mounted) setState(() => _isFetchingLocation = false);
  }

  void _fitCameraToTrip(double lat, double lng) {
    if (_userLocation == null) return;
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            (_userLocation!.longitude + lng) / 2,
            (_userLocation!.latitude + lat) / 2,
          ),
        ),
        zoom: 12.0,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  Future<void> _clearNavigationLayers() async {
    final style = _mapboxMap?.style;
    if (style == null) return;
    List<String> ids = ["walk-start", "walk-end", "route"];
    for (int i = 0; i < 5; i++) {
      ids.add("bus-leg-$i");
      ids.add("walk-transfer-$i");
    }
    for (String id in ids) {
      if (await style.styleSourceExists("$id-source")) {
        await style.removeStyleLayer("$id-layer");
        await style.removeStyleSource("$id-source");
      }
    }
  }

  // Manual Route Select (from List Page)
  void _selectRoute(Map<String, dynamic> route) async {
    setState(() {
      _pickupPoint = null;
      _dropoffPoint = null;
      _destinationPoint = null;
      _selectedRouteNum = route['num'];
    });
    await _clearNavigationLayers();
    await _updateMapAnnotations();

    // Draw full route using cached data if available, else load it
    // Simplified for now: just load it
    int dir = route['activeDir'] ?? 0;
    String asset = route['directions'][dir]['asset'];
    String? jsonStr = await rootBundle.loadString(asset);
    final style = _mapboxMap!.style;
    if (await style.styleSourceExists("route-source")) {
      await style.removeStyleLayer("route-layer");
      await style.removeStyleSource("route-source");
    }
    await style.addSource(GeoJsonSource(id: "route-source", data: jsonStr));
    await style.addLayer(
      LineLayer(
        id: "route-layer",
        sourceId: "route-source",
        lineColor: _getRouteColor(route['color']).value,
        lineWidth: 5.0,
      ),
    );

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(122.5644, 10.7202)),
        zoom: 13.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
    _sheetController.animateTo(
      0.18,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _updateMapAnnotations() async {
    _pointAnnotationManager?.deleteAll();
    // Re-add dest pin if route was cleared
    if (_destinationPoint != null && _selectedRouteNum == null) {
      await _addMarker(
        [
          _destinationPoint!.coordinates.lng.toDouble(),
          _destinationPoint!.coordinates.lat.toDouble(),
        ],
        "📍",
        Colors.red,
      );
    }
  }

  Color _getRouteColor(String c) {
    switch (c) {
      case 'blue':
        return Colors.blue.shade700;
      case 'orange':
        return Colors.orange.shade700;
      case 'green':
        return Colors.green.shade700;
      case 'red':
        return Colors.red.shade700;
      case 'grey':
        return Colors.grey.shade700;
      default:
        return Colors.purple.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Exact Pixel Heights for Snapping
    const double headerH = 32.0;
    const double searchH = 66.0;
    const double buttonsH = 101.0;
    final double minSize =
        (headerH + searchH + bottomPadding) / screenHeight + 0.01;
    final double midSize =
        (headerH + searchH + buttonsH + bottomPadding) / screenHeight;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey("mapbox_main"),
              textureView: false,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(122.5644, 10.7202)),
                zoom: 13.5,
              ),
              styleUri: 'mapbox://styles/cjhernia/cmkcq0g9d002h01sudbwmfeho',
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _circularIconButton(
                  Icons.menu,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: (screenHeight * midSize) + 20,
            child: _circularIconButton(
              _isFetchingLocation
                  ? Icons.hourglass_top
                  : Icons.near_me_outlined,
              onPressed: _handleLocationPermission,
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: minSize,
            minChildSize: minSize,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: [minSize, midSize, 0.85],
            builder: (context, scrollController) {
              return SakayBottomSheet(
                scrollController: scrollController,
                searchController: _searchController,
                routes: _displayList,
                selectedRouteNum: _selectedRouteNum,
                bottomPadding: bottomPadding,
                onRouteSelected: (item) => _handleItemSelection(item),
                onRouteSwap: (item) {
                  if (item['type'] == 'route') {
                    setState(
                      () => item['activeDir'] = (item['activeDir'] + 1) % 2,
                    );
                    if (_selectedRouteNum == item['num']) _selectRoute(item);
                  }
                },
                onSearchTap: _openSearchPage,
                onSearchClear: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _selectedRouteNum = null;
                    _destinationPoint = null;
                    _pickupPoint = null;
                    _dropoffPoint = null;
                    _displayList = List.from(_localRoutes);
                  });
                  _clearNavigationLayers();
                  _updateMapAnnotations();
                  _sheetController.animateTo(
                    midSize,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                onRoutesTap: _openRoutesPage,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() => Drawer(
    backgroundColor: beige,
    child: SafeArea(
      child: Column(
        children: [
          Container(
            height: 120,
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/images/sakaylive_logo.png'),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text("Transit Passes"),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Login"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _circularIconButton(IconData i, {VoidCallback? onPressed}) =>
      Container(
        height: 44,
        width: 44,
        decoration: const BoxDecoration(
          color: beige,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: IconButton(
          icon: Icon(i, color: Colors.black87, size: 20),
          onPressed: onPressed,
        ),
      );
}
