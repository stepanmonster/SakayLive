// lib/features/map/map_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sakaylive/screens/login_page.dart';
import 'package:sakaylive/screens/theme.dart';
import '../widgets/custom_gesture_detector.dart';
import 'auth_gate.dart';
import 'login_page.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  late final ValueNotifier<double> _drawerHeightNotifier;
  late double _closedHeight;
  late double _openHeight;

  final List<Map<String, String>> _routes = [
    {"num": "16", "dest": "Main", "status": "10 buses in next hour", "time": "5 min"},
    {"num": "1", "dest": "St-Laurent", "status": "Every 15 minutes", "time": "10 min"},
    {"num": "88", "dest": "Hurdman", "status": "Delayed 4 mins", "time": "12 min"},
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
    _openHeight = MediaQuery.of(context).size.height * 0.65;
  }

  Future<void> _handleLocationPermission() async {
    geo.Position position = await geo.Geolocator.getCurrentPosition();
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(position.longitude, position.latitude)),
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
        backgroundColor: beige,
        child: SafeArea( 
          child: Column(
            children: [
              Container(
                height: 120,
                width: double.infinity, 
                /* decoration: const BoxDecoration(
                  color: kLightBrown,
                ),
                */
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Image.asset(
                    'assets/images/sakaylive_logo.png',
                    height: 80,
                    width: 200,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: Icon(Icons.payment), 
                      title: Text("Transit Passes"), 
                      onTap: () {},
                    ),
                    // Add more tiles here
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.person), 
                title: Text("Login"), 
                onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                },
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: Stack(children: [ 
        // Map layer (gets touches first)
        Positioned.fill(
          child: RepaintBoundary(
            child: MapWidget(
              key: const ValueKey("mapbox_main"),
              textureView: true,
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
            ),
          ),
        ),
        
        // Burger menu
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
        
        // UI overlay (drawer + GPS)
        ValueListenableBuilder<double>(
          valueListenable: _drawerHeightNotifier,
          builder: (context, height, child) {
            return Stack(children: [
              // GPS button
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                right: 16,
                bottom: height + 20,
                child: _circularIconButton(
                  Icons.near_me_outlined, 
                  onPressed: _handleLocationPermission,
                ),
              ),
              // Drawer content
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                left: 0, right: 0, bottom: 0, height: height,
                child: _buildDrawerContent(height > _closedHeight + 50),
              ),
              // SWIPE ZONE - TOP 40px OF DRAWER (where handle lives)
              if (height > 0)
                Positioned(
                  left: 0, right: 0, 
                  bottom: height - 40,  // ← Position at TOP of drawer
                  height: 40,           // Handle area only
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanEnd: (details) {
                      final velocity = details.velocity.pixelsPerSecond.dy;
                      if (velocity > 200) {
                        _drawerHeightNotifier.value = _closedHeight;  // Swipe down to close
                      } else if (velocity < -200) {
                        _drawerHeightNotifier.value = _openHeight;    // Swipe up to open
                      }
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }


  // ... rest of your methods unchanged: _onMapCreated, _buildDrawerContent, _routeTile, _circularIconButton
  // (paste them here exactly as they were)

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Logo & attribution positioning
    mapboxMap.logo.updateSettings(
      LogoSettings(position: OrnamentPosition.TOP_RIGHT, marginTop: 60, marginRight: 350),
    );
    mapboxMap.attribution.updateSettings(
      AttributionSettings(position: OrnamentPosition.TOP_RIGHT, marginTop: 60, marginRight: 10),
    );

    mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  Widget _buildDrawerContent(bool isOpen) {
    return Container(
      decoration: BoxDecoration(
        color: beige,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
      ),
      child: Column(children: [
        // Handle bar
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Container(
            height: 52,
            decoration: BoxDecoration(color: tan, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              SizedBox(width: 16),
              Icon(Icons.search, color: Colors.black, size: 20),
              SizedBox(width: 12),
              Text("Where to?", style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w500)),
              Spacer(),
              Icon(Icons.mic, color: Colors.black, size: 20),
              SizedBox(width: 16),
            ]),
          ),
        ),
        // Routes list
        if (isOpen)
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 60),
              children: _routes.map((route) => _routeTile(route)).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _routeTile(Map<String, String> data) {
    return Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_bus, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(data["num"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ),
        title: Text(data["dest"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(data["status"]!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: Text(data["time"]!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      const Divider(indent: 70, endIndent: 16, height: 1),
    ]);
  }

  Widget _circularIconButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      height: 44,
      width: 44,
      decoration: const BoxDecoration(
        color: beige,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: IconButton(icon: Icon(icon, color: Colors.black87, size: 20), onPressed: onPressed),
    );
  }
}
