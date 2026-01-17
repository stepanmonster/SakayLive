// lib/features/map/map_screen.dart
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sakaylive/screens/login_page.dart';
import 'package:sakaylive/screens/routes_list_page.dart';
import 'package:sakaylive/screens/search_page.dart';
import 'package:sakaylive/screens/theme.dart';
import 'package:sakaylive/screens/conductor/conductor_dashboard.dart';
import 'auth_gate.dart';
import 'package:sakaylive/viewmodels/map_view_model.dart';
import 'package:sakaylive/widgets/sakay_bottom_sheet.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Map Screen - View layer following MVVM pattern.
/// Only responsible for UI rendering and user interaction forwarding.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _cachedRoutes = [];

  @override
  void initState() {
    super.initState();
    // You might want to initialize Firebase here if needed
    // But Firebase initialization should typically be in main.dart
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map, MapViewModel viewModel) {
    map.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    map.logo.updateSettings(LogoSettings(marginBottom: 150, marginLeft: 16));
    map.attribution.updateSettings(
      AttributionSettings(marginBottom: 150, marginLeft: 100),
    );

    viewModel.initialize(map).then((_) {
      viewModel.fetchUserLocation();
    });
  }

  void _openSearchPage(MapViewModel viewModel) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          searchBoxApi: viewModel.searchBoxApi,
          sessionToken: viewModel.sessionToken,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final success = await viewModel.planTripToPlace(result);
      if (success) {
        _searchController.text = result['dest'];
        _sheetController.animateTo(
          0.4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No routes found within walking distance."),
            ),
          );
        }
      }
    }
  }

  void _openRoutesPage(MapViewModel viewModel) async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutesListPage()),
    );

    if (selected != null && selected is Map<String, dynamic>) {
      final route = viewModel.localRoutes.firstWhere(
        (r) => r['num'] == selected['num'],
        orElse: () => selected,
      );
      if (selected['activeDir'] != null) {
        route['activeDir'] = selected['activeDir'];
      }
      viewModel.selectRoute(route);
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleItemSelection(Map<String, dynamic> item, MapViewModel viewModel) {
    if (item['type'] == 'trip_option') {
      viewModel.drawTripOnMap(item);
      _sheetController.animateTo(
        0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (item['type'] == 'route') {
      viewModel.selectRoute(item);
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      viewModel.planTripToPlace(item).then((success) {
        if (success) {
          _searchController.text = item['dest'];
          _sheetController.animateTo(
            0.4,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MapViewModel(),
      child: Consumer<MapViewModel>(
        builder: (context, viewModel, _) {
          return _buildScreen(context, viewModel);
        },
      ),
    );
  }

  Widget _buildScreen(BuildContext context, MapViewModel viewModel) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

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

      // ✅ TEMP DEBUG ACCESS (remove later when login routes here)
      floatingActionButton: FloatingActionButton(
        heroTag: "conductor_fab",
        backgroundColor: Colors.black,
        child: const Icon(Icons.admin_panel_settings, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConductorDashboard()),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Map Layer
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey("mapbox_main"),
              textureView: false,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(122.5644, 10.7202)),
                zoom: 13.5,
              ),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: (map) => _onMapCreated(map, viewModel),
              onStyleLoadedListener: (_) {},
            ),
          ),

          // Menu Button
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
            bottom: (screenHeight * midSize) + 20,
            child: _circularIconButton(
              viewModel.isFetchingLocation
                  ? Icons.hourglass_top
                  : Icons.near_me_outlined,
              onPressed: viewModel.fetchUserLocation,
            ),
          ),

          // Bottom Sheet
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
                routes: viewModel.displayList,
                selectedRouteNum: viewModel.selectedRouteNum,
                bottomPadding: bottomPadding,
                onRouteSelected: (item) =>
                    _handleItemSelection(item, viewModel),
                onRouteSwap: (item) {
                  if (item['type'] == 'route') {
                    viewModel.swapRouteDirection(item);
                    if (viewModel.selectedRouteNum == item['num']) {
                      viewModel.selectRoute(item);
                    }
                  }
                },
                onSearchTap: () => _openSearchPage(viewModel),
                onSearchClear: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                  viewModel.clearSelection();
                  _sheetController.animateTo(
                    midSize,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                onRoutesTap: () => _openRoutesPage(viewModel),
              );
            },
          ),
        ],
      ),
    );
  }

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
                    onTap: () {
                      // Add functionality here
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text("Conductor Panel"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConductorDashboard(),
                        ),
                      );
                    },
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
  }

  Widget _circularIconButton(IconData icon, {VoidCallback? onPressed}) {
    return Container(
      height: 44,
      width: 44,
      decoration: const BoxDecoration(
        color: beige,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}