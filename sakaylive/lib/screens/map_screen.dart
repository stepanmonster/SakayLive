// lib/features/map/map_screen.dart
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sakaylive/screens/login_page.dart';
import 'package:sakaylive/screens/theme.dart';
import 'auth_gate.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- CONTROLLERS ---
  // 1. Add Sheet Controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();

  // State Variables
  bool _isFetchingLocation = false;
  List<Map<String, String>> _searchResults = [];

  // --- DATA ---
  final List<Map<String, String>> _allRoutes = [
    {
      "num": "17",
      "dest": "Villa Baybay",
      "status": "Arriving in 2 mins",
      "time": "2 min",
      "color": "green",
    },
    {
      "num": "04",
      "dest": "Ungka via Festive",
      "status": "Every 10 minutes",
      "time": "5 min",
      "color": "blue",
    },
    {
      "num": "10",
      "dest": "Tagbak Terminal",
      "status": "Delayed 5 mins",
      "time": "12 min",
      "color": "orange",
    },
    {
      "num": "11",
      "dest": "La Paz via Ticud",
      "status": "Seats available",
      "time": "8 min",
      "color": "purple",
    },
    {
      "num": "01",
      "dest": "Bo. Obrero Lapuz",
      "status": "On time",
      "time": "15 min",
      "color": "red",
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchResults = _allRoutes;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose(); // Dispose sheet controller
    super.dispose();
  }

  // --- METHODS ---

  void _runSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _searchResults = _allRoutes;
      } else {
        _searchResults = _allRoutes
            .where(
              (route) =>
                  route['dest']!.toLowerCase().contains(query.toLowerCase()) ||
                  route['num']!.contains(query),
            )
            .toList();
      }
    });
  }

  void _selectRoute(String routeNum) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Selected Route $routeNum")));
  }

  Future<void> _handleLocationPermission() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);

    try {
      geo.Position position = await geo.Geolocator.getCurrentPosition();
      if (!mounted) return;

      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    const double bottomClearance = 150.0;

    mapboxMap.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginBottom: bottomClearance,
        marginLeft: 16.0,
      ),
    );

    mapboxMap.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginBottom: bottomClearance,
        marginLeft: 100.0,
      ),
    );

    mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: false),
    );
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      drawer: Drawer(
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
                  width: 200,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
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
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double totalHeight = constraints.maxHeight;

          // --- 1. CALCULATE HEIGHTS ---
          const double searchSectionHeight = 90.0;
          const double buttonsSectionHeight = 80.0;
          const double dividerHeight = 1.0;
          const double sheetMargin = 16.0;

          // --- 2. SNAP POINTS ---
          final double minSheetSize =
              (searchSectionHeight + bottomPadding + sheetMargin) / totalHeight;

          final double midSheetSize =
              (searchSectionHeight +
                  buttonsSectionHeight +
                  dividerHeight +
                  bottomPadding +
                  sheetMargin) /
              totalHeight;

          const double maxSheetSize = 0.85;

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: MapWidget(
                    key: const ValueKey("mapbox_main"),
                    textureView: false,
                    styleUri: MapboxStyles.MAPBOX_STREETS,
                    onMapCreated: _onMapCreated,
                  ),
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

              // Location Button
              Positioned(
                right: 16,
                bottom: searchSectionHeight + bottomPadding + sheetMargin + 16,
                child: _circularIconButton(
                  _isFetchingLocation
                      ? Icons.hourglass_top
                      : Icons.near_me_outlined,
                  onPressed: _handleLocationPermission,
                ),
              ),

              DraggableScrollableSheet(
                controller: _sheetController, // 2. Assign Controller
                initialChildSize: minSheetSize,
                minChildSize: minSheetSize,
                maxChildSize: maxSheetSize,
                snap: true,
                snapSizes: [minSheetSize, midSheetSize, maxSheetSize],
                builder:
                    (BuildContext context, ScrollController scrollController) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: sheetMargin,
                          right: sheetMargin,
                          bottom: sheetMargin + bottomPadding,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: beige,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                              bottom: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CustomScrollView(
                            controller: scrollController,
                            physics: const ClampingScrollPhysics(),
                            slivers: [
                              // --- UNIFIED HEADER ---
                              SliverToBoxAdapter(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. Search Section
                                    Container(
                                      height: searchSectionHeight,
                                      alignment: Alignment.topCenter,
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 12),
                                          Center(
                                            child: Container(
                                              width: 40,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[400],
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                            ),
                                            child: Container(
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 16),
                                                  const Icon(
                                                    Icons.search,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          _searchController,
                                                      onChanged: _runSearch,
                                                      // 3. Expand on Tap
                                                      onTap: () {
                                                        _sheetController
                                                            .animateTo(
                                                              maxSheetSize,
                                                              duration:
                                                                  const Duration(
                                                                    milliseconds:
                                                                        300,
                                                                  ),
                                                              curve: Curves
                                                                  .easeOut,
                                                            );
                                                      },
                                                      decoration:
                                                          const InputDecoration(
                                                            hintText:
                                                                "Where to?",
                                                            border: InputBorder
                                                                .none,
                                                            hintStyle:
                                                                TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                            contentPadding:
                                                                EdgeInsets.only(
                                                                  bottom: 5,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                  if (_searchController
                                                      .text
                                                      .isNotEmpty)
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.clear,
                                                        color: Colors.grey,
                                                        size: 20,
                                                      ),
                                                      onPressed: () {
                                                        _searchController
                                                            .clear();
                                                        _runSearch("");
                                                      },
                                                    ),
                                                  const SizedBox(width: 8),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 2. Buttons Section
                                    Container(
                                      height: buttonsSectionHeight,
                                      alignment: Alignment.topCenter,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          _buildQuickAction(Icons.work, "Work"),
                                          _buildQuickAction(Icons.home, "Home"),
                                          _buildQuickAction(
                                            Icons.star,
                                            "Saved",
                                          ),
                                          _buildQuickAction(
                                            Icons.history,
                                            "Recent",
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 3. Divider
                                    const Divider(
                                      thickness: 1,
                                      height: dividerHeight,
                                      color: Colors.black12,
                                    ),
                                  ],
                                ),
                              ),

                              // --- LIST CONTENT ---
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final route = _searchResults[index];
                                  return Column(
                                    children: [
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 4,
                                            ),
                                        leading: Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: _getRouteColor(
                                              route['color']!,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.directions_bus,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        title: Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                route['num']!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                route['dest']!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          route['status']!,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                        trailing: Text(
                                          route['time']!,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        onTap: () =>
                                            _selectRoute(route['num']!),
                                      ),
                                      const Divider(
                                        indent: 70,
                                        endIndent: 16,
                                        height: 1,
                                      ),
                                    ],
                                  );
                                }, childCount: _searchResults.length),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 20),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Color _getRouteColor(String colorName) {
    switch (colorName) {
      case 'red':
        return Colors.red.shade700;
      case 'green':
        return Colors.green.shade700;
      case 'blue':
        return Colors.blue.shade700;
      case 'purple':
        return Colors.purple.shade700;
      case 'orange':
        return Colors.orange.shade700;
      default:
        return Colors.black;
    }
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: Icon(icon, color: Colors.blueGrey),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _circularIconButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      height: 44,
      width: 44,
      decoration: const BoxDecoration(
        color: beige,
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
