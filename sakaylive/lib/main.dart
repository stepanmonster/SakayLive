import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;

// --- REFINED CUSTOM GESTURE DETECTOR ---
class CustomGestureDetector extends StatelessWidget {
  static const int axisY = 1;
  final int axis;
  final Widget child;
  final double velocityThreshold;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  const CustomGestureDetector({
    super.key,
    required this.child,
    required this.axis,
    this.velocityThreshold = 100.0,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        if (axis == axisY) {
          if (velocity.dy > velocityThreshold) {
            onSwipeDown?.call();
          } else if (velocity.dy < -velocityThreshold) {
            onSwipeUp?.call();
          }
        }
      },
      child: child,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: ''));

  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: MapScreen()),
  );
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Using ValueNotifier for high-performance UI updates without full build calls
  late final ValueNotifier<double> _drawerHeightNotifier;
  late double _closedHeight;
  late double _openHeight;

  final List<Map<String, String>> _routes = [
    {
      "num": "16",
      "dest": "Main",
      "status": "10 buses in next hour",
      "time": "5 min",
    },
    {
      "num": "1",
      "dest": "St-Laurent",
      "status": "Every 15 minutes",
      "time": "10 min",
    },
    {
      "num": "88",
      "dest": "Hurdman",
      "status": "Delayed 4 mins",
      "time": "12 min",
    },
    {"num": "95", "dest": "Orléans", "status": "On time", "time": "15 min"},
  ];

  @override
  void initState() {
    super.initState();
    _closedHeight = 130.0;
    _drawerHeightNotifier = ValueNotifier(_closedHeight);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _openHeight = MediaQuery.of(context).size.height * 0.65; // Slightly taller
  }

  Future<void> _handleLocationPermission() async {
    geo.Position position = await geo.Geolocator.getCurrentPosition();
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigoAccent),
              child: Text(
                "SakayLive",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text("Transit Passes"),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: CustomGestureDetector(
        axis: CustomGestureDetector.axisY,
        onSwipeUp: () => _drawerHeightNotifier.value = _openHeight,
        onSwipeDown: () => _drawerHeightNotifier.value = _closedHeight,
        child: Stack(
          children: [
            // 1. PERFORMANCE OPTIMIZED MAP LAYER
            Positioned.fill(
              child: RepaintBoundary(
                // Creates a separate display list to stop lag during drawer movement
                child: MapWidget(
                  key: const ValueKey("mapbox_main"),
                  textureView: true,
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  onMapCreated: _onMapCreated,
                ),
              ),
            ),

            // 2. BURGER MENU ICON
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

            // 3. UI LAYER BUILDER (Listens to drawer height without rebuilding map)
            ValueListenableBuilder<double>(
              valueListenable: _drawerHeightNotifier,
              builder: (context, height, child) {
                return Stack(
                  children: [
                    // STICKY GPS BUTTON
                    AnimatedPositioned(
                      duration: const Duration(
                        milliseconds: 200,
                      ), // Shorter duration = less lag perception
                      curve: Curves.fastOutSlowIn,
                      right: 16,
                      bottom: height + 20, // Increased spacing from drawer
                      child: _circularIconButton(
                        Icons.near_me_outlined,
                        onPressed: _handleLocationPermission,
                      ),
                    ),

                    // ANIMATED BOTTOM DRAWER
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.fastOutSlowIn,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: height,
                      child: _buildDrawerContent(height > _closedHeight + 50),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // COMBINED LOGO & ATTRIBUTION IN TOP RIGHT, SIDE BY SIDE
    mapboxMap.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.TOP_RIGHT,
        marginTop: 60,
        marginRight: 350,
      ),
    );
    mapboxMap.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.TOP_RIGHT,
        marginTop: 60, // Same marginTop to align them in a row
        marginRight:
            10, // Increase marginRight so attribution appears left of logo
      ),
    );

    mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  Widget _buildDrawerContent(bool isOpen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.indigoAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text(
                    "Where to?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.mic, color: Colors.white, size: 20),
                  SizedBox(width: 16),
                ],
              ),
            ),
          ),
          if (isOpen)
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: 60,
                ), // Increased bottom padding for drawer content
                children: _routes.map((route) => _routeTile(route)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _routeTile(Map<String, String> data) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bus, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  data["num"]!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            data["dest"]!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            data["status"]!,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          trailing: Text(
            data["time"]!,
            style: const TextStyle(
              color: Colors.indigoAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const Divider(indent: 70, endIndent: 16, height: 1),
      ],
    );
  }

  Widget _circularIconButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      height: 44,
      width: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
