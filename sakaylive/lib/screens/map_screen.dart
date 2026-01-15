import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sakaylive/screens/login_page.dart';
import 'package:sakaylive/screens/theme.dart';
import 'package:sakaylive/widgets/sakay_bottom_sheet.dart'; // Import your new widget

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

  // --- STATE ---
  bool _isFetchingLocation = false;
  List<Map<String, dynamic>> _currentRoutes = [];
  String? _selectedRouteNum;

  // --- DATA ---
  final List<Map<String, dynamic>> _routeTemplates = [
    {
      "num": "3",
      "dest": "Ungka via CPU",
      "color": "blue",
      "directions": [
        {"name": "To City Proper", "asset": "assets/routes/route_3.geojson"},
        {"name": "To Ungka Terminal", "asset": "assets/routes/route_3.geojson"},
      ],
      "activeDir": 0,
      "status": "Every 5 mins",
      "time": "5 min",
    },
    {
      "num": "4",
      "dest": "Ungka via Diversion",
      "color": "orange",
      "directions": [
        {"name": "To City Proper", "asset": "assets/routes/route_4.geojson"},
        {"name": "To Ungka Terminal", "asset": "assets/routes/route_4.geojson"},
      ],
      "activeDir": 0,
      "status": "Arriving",
      "time": "2 min",
    },
    {
      "num": "10",
      "dest": "Tagbak Terminal",
      "color": "green",
      "directions": [
        {"name": "To City Proper", "asset": "assets/routes/route_10.geojson"},
        {"name": "To Tagbak", "asset": "assets/routes/route_10.geojson"},
      ],
      "activeDir": 0,
      "status": "Loading",
      "time": "12 min",
    },
    {
      "num": "5",
      "dest": "Festive Walk via SM",
      "color": "red",
      "directions": [
        {"name": "To City Proper", "asset": "assets/routes/route_5.geojson"},
        {"name": "To Festive Walk", "asset": "assets/routes/route_5.geojson"},
      ],
      "activeDir": 0,
      "status": "Departing",
      "time": "8 min",
    },
    {
      "num": "9",
      "dest": "Mohon Terminal",
      "color": "purple",
      "directions": [
        {"name": "To City Proper", "asset": "assets/routes/route_9.geojson"},
        {"name": "To Mohon", "asset": "assets/routes/route_9.geojson"},
      ],
      "activeDir": 0,
      "status": "Delayed",
      "time": "15 min",
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentRoutes = List.from(_routeTemplates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // --- MAP METHODS ---
  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    mapboxMap.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginBottom: 150.0,
        marginLeft: 16.0,
      ),
    );
    mapboxMap.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginBottom: 150.0,
        marginLeft: 100.0,
      ),
    );
    mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    _handleLocationPermission();
  }

  void _onStyleLoaded(StyleLoadedEventData data) async {
    if (_mapboxMap == null) return;
    try {
      _pointAnnotationManager = await _mapboxMap!.annotations
          .createPointAnnotationManager();
      _pointAnnotationManager?.addOnPointAnnotationClickListener(
        _PointTapHandler(onTap: (annotation) => _onBusClicked(annotation)),
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- LOGIC ---
  Future<void> _drawRouteLine(Map<String, dynamic> route) async {
    if (_mapboxMap == null) return;
    try {
      int activeIdx = route['activeDir'];
      String assetPath = route['directions'][activeIdx]['asset'];
      final String? geojsonString = await _safeLoadAsset(assetPath);
      if (geojsonString == null) return;

      final style = _mapboxMap!.style;
      if (await style.styleSourceExists("route-source")) {
        await style.removeStyleLayer("route-layer");
        await style.removeStyleSource("route-source");
      }
      await style.addSource(
        GeoJsonSource(id: "route-source", data: geojsonString),
      );
      await style.addLayer(
        LineLayer(
          id: "route-layer",
          sourceId: "route-source",
          lineColor: _getRouteColor(route['color']).value,
          lineWidth: 5.0,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.8,
        ),
      );
    } catch (e) {
      debugPrint("Draw Error: $e");
    }
  }

  Future<void> _updateBusMarkers() async {
    if (_pointAnnotationManager == null) return;
    await _pointAnnotationManager?.deleteAll();
    final random = Random();

    for (var route in _currentRoutes) {
      if (_selectedRouteNum != null && route['num'] != _selectedRouteNum)
        continue;

      try {
        String assetPath = route['directions'][route['activeDir']]['asset'];
        final String? geojsonString = await _safeLoadAsset(assetPath);
        if (geojsonString == null) continue;

        final Map<String, dynamic> geojsonData = json.decode(geojsonString);
        List coords = _extractCoordinates(geojsonData);

        if (coords.isNotEmpty) {
          final randomIndex = random.nextInt(coords.length);
          route['lat'] = coords[randomIndex][1].toDouble();
          route['lng'] = coords[randomIndex][0].toDouble();

          await _pointAnnotationManager?.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(route['lng'], route['lat']),
              ),
              textField: "🚌",
              textSize: 24.0,
              textOffset: [0, -0.5],
              textColor: Colors.black.value,
              iconImage: "marker-15",
              iconOpacity: 0,
            ),
          );
        }
      } catch (e) {
        debugPrint("Spawn Error: $e");
      }
    }
  }

  void _selectRoute(Map<String, dynamic> route) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedRouteNum = route['num']);
    _drawRouteLine(route);
    _updateBusMarkers();
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(route['lng'], route['lat'])),
        zoom: 15.0,
        pitch: 30.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  void _onBusClicked(PointAnnotation a) {
    final p = a.geometry;
    if (p == null) return;
    final match = _currentRoutes.firstWhere(
      (r) => (r['lng'] - p.coordinates.lng).abs() < 0.0001,
      orElse: () => {},
    );
    if (match.isNotEmpty) _selectRoute(match);
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // --- COMPACT SIZING LOGIC (Adjusted for Wrapper) ---
    const double floatMargin = 16.0;
    const double handleHeight = 24.0;
    const double searchSectionHeight = 66.0;
    const double buttonsSectionHeight = 80.0;

    // Height for Mode 1 (Just Search) = 90px
    final double mode1Pixels = handleHeight + searchSectionHeight;

    // Height for Mode 2 (Search + Buttons) = 170px
    final double mode2Pixels = mode1Pixels + buttonsSectionHeight;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      drawer: _buildDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double totalScreenHeight = constraints.maxHeight;

          // Mode 1: Min Size
          final double minSheetSize =
              (mode1Pixels + floatMargin + bottomPadding) / totalScreenHeight +
              0.01;

          // Mode 2: Mid Size
          final double midSheetSize =
              (mode2Pixels + floatMargin + bottomPadding) / totalScreenHeight +
              0.01;

          // Mode 3: Max Size (Fixed to 85%)
          const double maxSheetSize = 0.85;

          return Stack(
            children: [
              Positioned.fill(
                child: MapWidget(
                  key: const ValueKey("mapbox_main"),
                  textureView: false,
                  cameraOptions: CameraOptions(
                    center: Point(coordinates: Position(122.5644, 10.7202)),
                    zoom: 13.5,
                  ),
                  styleUri:
                      'mapbox://styles/cjhernia/cmkcq0g9d002h01sudbwmfeho',
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
                // Location button tracks the top of the sheet
                bottom: (totalScreenHeight * minSheetSize + 10),
                child: _circularIconButton(
                  _isFetchingLocation
                      ? Icons.hourglass_top
                      : Icons.near_me_outlined,
                  onPressed: _handleLocationPermission,
                ),
              ),

              // NEW: Using the Refactored Widget
              DraggableScrollableSheet(
                controller: _sheetController,
                initialChildSize: minSheetSize, // Starts collapsed
                minChildSize: minSheetSize,
                maxChildSize: maxSheetSize,
                snap: true,
                snapSizes: [minSheetSize, midSheetSize, maxSheetSize],
                builder: (context, scrollController) {
                  return SakayBottomSheet(
                    scrollController: scrollController,
                    searchController: _searchController,
                    routes: _currentRoutes,
                    selectedRouteNum: _selectedRouteNum,
                    bottomPadding: bottomPadding,
                    onRouteSelected: (route) => _selectRoute(route),
                    onRouteSwap: (route) {
                      setState(
                        () => route['activeDir'] = (route['activeDir'] + 1) % 2,
                      );
                      if (_selectedRouteNum == route['num']) {
                        _drawRouteLine(route);
                        _updateBusMarkers();
                      }
                    },
                    onSearchTap: () {
                      _sheetController.animateTo(
                        0.85,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    onSearchClear: () {
                      _searchController.clear();
                      setState(() => _selectedRouteNum = null);
                      _updateBusMarkers();
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- HELPERS (Drawer & Buttons remain local to screen) ---
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: beige,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              child: Image.asset(
                'assets/images/sakaylive_logo.png',
                height: 80,
                errorBuilder: (c, o, s) => const Center(
                  child: Text(
                    "SakayLive",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.payment),
                    title: const Text("Transit Passes"),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Login"),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  // --- UTILS ---
  Future<String?> _safeLoadAsset(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      return null;
    }
  }

  List _extractCoordinates(Map<String, dynamic> d) =>
      d['type'] == 'FeatureCollection'
      ? d['features'][0]['geometry']['coordinates']
      : d['geometry']['coordinates'];
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
      default:
        return Colors.purple.shade700;
    }
  }

  Future<void> _handleLocationPermission() async {
    setState(() => _isFetchingLocation = true);
    try {
      final pos = await geo.Geolocator.getCurrentPosition();
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 2000),
      );
      await _updateBusMarkers();
    } catch (e) {
      debugPrint("Loc: $e");
    }
    if (mounted) setState(() => _isFetchingLocation = false);
  }
}

class _PointTapHandler extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) onTap;
  _PointTapHandler({required this.onTap});
  @override
  void onPointAnnotationClick(PointAnnotation annotation) => onTap(annotation);
}
