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
import 'package:sakaylive/services/auth_service.dart';
import 'package:sakaylive/viewmodels/auth_view_model.dart';
import 'package:sakaylive/services/auth_service.dart';

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
  final AuthService _authService = AuthService();

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

  void _onMapCreated(MapboxMap map, MapViewModel viewModel) async {
    map.location.updateSettings(LocationComponentSettings(enabled: true, pulsingEnabled: true));
    map.logo.updateSettings(LogoSettings(marginBottom: 150, marginLeft: 16));
    map.attribution.updateSettings(AttributionSettings(marginBottom: 150, marginLeft: 100));

    await viewModel.initialize(map);  // Wait for completion
    print("✅ MapViewModel fully initialized");  // Debug
    viewModel.fetchUserLocation();
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
  final mapVM = Provider.of<MapViewModel>(context);
  final authVM = Provider.of<AuthViewModel>(context);
  
  return PopScope(
    canPop: false,
    onPopInvoked: (didPop) {
      if (!didPop) {
        Navigator.pushReplacementNamed(context, '/landing');
      }
    },
    child: _buildScreen(context, mapVM, authVM), // ✅ Pass AuthViewModel instead
  );
}




  Widget _buildScreen(BuildContext context, MapViewModel viewModel, AuthViewModel authVM) {
  final double bottomPadding = MediaQuery.of(context).padding.bottom;
  final double screenHeight = MediaQuery.of(context).size.height;

  const double headerH = 32.0;
  const double searchH = 66.0;
  const double buttonsH = 101.0;
  final double minSize = (headerH + searchH + bottomPadding) / screenHeight + 0.01;
  final double midSize = (headerH + searchH + buttonsH + bottomPadding) / screenHeight;

  return FutureBuilder<bool>(
    future: authVM.authService.isConductor(), // ✅ Use service through ViewModel
    initialData: false,
    builder: (context, snapshot) {
      final bool isConductor = snapshot.data ?? false;
      final bool isLoggedIn = authVM.isLoggedIn; // ✅ From Provider

      return Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        drawer: _buildDrawer(authVM.authService, isConductor),
        body: Stack(
          children: [
            // Map Layer - UNCHANGED
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

            // Menu Button - UNCHANGED
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

            // Profile/Login Button - ✅ Now uses FutureBuilder data
             Positioned(
              top: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () {
                      if (isConductor) {
                        Navigator.pushNamed(context, '/profile');
                      } else if (isLoggedIn) {
                        Navigator.pushNamed(context, '/profile');
                      } else {
                        Navigator.pushNamed(context, '/login');
                      }
                    },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),        // ✅ White background
                          borderRadius: BorderRadius.circular(20),      // ✅ Rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),     // ✅ Subtle shadow
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.8),       // ✅ Soft white border
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLoggedIn ? Icons.person : Icons.login, 
                              size: 20,
                              color: Colors.black87,                     // ✅ Dark icon for contrast
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConductor || isLoggedIn ? 'Profile' : 'Login',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600, 
                                fontSize: 14,
                                color: Colors.black87,                   // ✅ Dark text for contrast
                              ),
                            ),
                          ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Location Button - UNCHANGED
            Positioned(
              right: 16,
              bottom: (screenHeight * midSize) + 20,
              child: _circularIconButton(
                viewModel.isFetchingLocation ? Icons.hourglass_top : Icons.near_me_outlined,
                onPressed: viewModel.fetchUserLocation,
              ),
            ),

            // CONDUCTOR FAB - ✅ Uses FutureBuilder data
            if (isConductor)
              Positioned(
                right: 16,
                bottom: (screenHeight * minSize) + 30,
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(1.0),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ConductorDashboard()),
                      );
                    },
                  ),
                ),
              ),

            // Bottom Sheet - UNCHANGED
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
                  onRouteSelected: (item) => _handleItemSelection(item, viewModel),
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
    },
  );
}



  Widget _buildDrawer(AuthService authService, bool isConductor) {
  final user = authService.currentUser;
  final isLoggedIn = user != null;

  final drawerItems = <Widget>[
    ListTile(
      leading: const Icon(Icons.payment),
      title: const Text("Transit Passes"),
      onTap: () {
        // Add functionality here
      },
    ),
  ];

  // ONLY conductors see this item
  if (isConductor) {
    drawerItems.add(
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
    );
  }

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
              children: drawerItems,
            ),
          ),
          // ✅ DYNAMIC LOGIN/LOGOUT BUTTON
          ListTile(
            leading: Icon(isLoggedIn ? Icons.logout : Icons.person),
            title: Text(isLoggedIn ? "Logout" : "Login"),
            onTap: () async {
              if (isLoggedIn) {
                // ✅ LOGOUT LOGIC
                await authService.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context); // Close drawer
                }
              } else {
                // Navigate to login
                Navigator.pop(context); // Close drawer first
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
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