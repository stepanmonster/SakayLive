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
import 'coming_soon_page.dart';
import 'package:sakaylive/viewmodels/map_view_model.dart';
import 'package:sakaylive/widgets/sakay_bottom_sheet.dart';
import 'package:sakaylive/widgets/live_bus_card.dart';
import 'package:sakaylive/widgets/bus_info_snippet.dart';
import 'package:sakaylive/widgets/empty_state.dart';
import 'package:sakaylive/widgets/skeleton_loader.dart';
import 'package:sakaylive/models/vehicle_position.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sakaylive/viewmodels/auth_view_model.dart';
import 'package:sakaylive/utils/haptics.dart';
import 'package:sakaylive/utils/toast_helper.dart';
import 'package:sakaylive/screens/account_page.dart';

/// Main map screen widget. Handles map display, controls, and navigation.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// State for MapScreen. Manages map, UI controls, and user actions.
class _MapScreenState extends State<MapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  /// Called when the Mapbox map is created.
  /// Sets up map ornaments, logo, attribution, and initializes the view model.
  void _onMapCreated(MapboxMap map, MapViewModel viewModel) async {
    _mapboxMap = map;

    // Enable user location with pulsing effect
    map.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Position Mapbox logo and attribution just above the bottom sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      final double screenHeight = MediaQuery.of(context).size.height;
      final double topPadding = MediaQuery.of(context).padding.top;

      const double headerH = 40.0;
      const double searchH = 74.0;
      final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
      final double minSize =
          (headerH + searchH + bottomPadding) / screenHeight - 0.02;
      final double bottomSheetTop = screenHeight * minSize;
      final double marginBottom = screenHeight - bottomSheetTop + 16;
      map.logo.updateSettings(
        LogoSettings(marginBottom: marginBottom - 625, marginLeft: 16),
      );
      map.attribution.updateSettings(
        AttributionSettings(marginBottom: marginBottom - 625, marginLeft: 100),
      );

      // Position compass below the login button
      map.compass.updateSettings(
        CompassSettings(
          enabled: true,
          position: OrnamentPosition.TOP_RIGHT,
          marginTop:
              topPadding + 80, // SafeArea + Padding(16) + Button(~48) + Gap(16)
          marginRight: 16,
        ),
      );
    });

    // Position scale bar below the menu button
    _positionScaleBarBelowMenu(map);

    // Initialize map view model and fetch user location
    await viewModel.initialize(map);
    viewModel.fetchUserLocation();
  }

  /// Positions the scale bar below the menu button (top left corner).
  void _positionScaleBarBelowMenu(MapboxMap mapboxMap) {
    const double marginTop = 44.0 + 16.0 + 56.0 + 8.0;
    mapboxMap.scaleBar.updateSettings(
      ScaleBarSettings(
        enabled: true,
        position: OrnamentPosition.TOP_LEFT,
        marginTop: marginTop,
        marginLeft: 16.0,
      ),
    );
  }

  /// Opens the search page and handles the result (route or place).
  void _openSearchPage(MapViewModel viewModel) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          searchBoxApi: viewModel.searchBoxApi,
          sessionToken: viewModel.sessionToken,
          cachedRoutes: viewModel.localRoutes,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      if (result['type'] == 'route') {
        viewModel.selectRoute(result);
        _sheetController.animateTo(
          0.18,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        final success = await viewModel.planTripToPlace(result);
        if (success) {
          _searchController.text = result['dest'];
          _sheetController.animateTo(
            0.85,
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
  }

  /// Opens the routes list page and handles route selection.
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
      Haptics.light();
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Shows a modal with all tracked buses grouped by route.
  void _showAllBusesModal(BuildContext context, MapViewModel viewModel) {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AllBusesModal(
        vehicles: viewModel.trackedVehicles,
        onBusTap: (vehicle) {
          Navigator.pop(context);
          Haptics.selection();
          // Fly to bus location
          viewModel.flyToLocation(vehicle.position.lat, vehicle.position.lng);
        },
      ),
    );
  }

  /// Handles selection of a trip option, route, or place from the UI.
  void _handleItemSelection(Map<String, dynamic> item, MapViewModel viewModel) {
    Haptics.light();
    if (item['type'] == 'trip_option') {
      viewModel.drawTripOnMap(item);
      // Collapse sheet after selecting a trip to show the map
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
          // Expand to mode 3 (0.85) to show all trip options
          _sheetController.animateTo(
            0.85,
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
      child: _buildScreen(
        context,
        mapVM,
        authVM,
      ), // ✅ Pass AuthViewModel instead
    );
  }

  /// Builds the main map screen UI, including map, controls, and bottom sheet.
  Widget _buildScreen(
    BuildContext context,
    MapViewModel viewModel,
    AuthViewModel authVM,
  ) {
    final double bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    const double headerH = 40.0;
    const double searchH = 74.0;
    const double buttonsH = 110.0;
    final double minSize =
        (headerH + searchH + bottomPadding) / screenHeight - 0.02;
    final double midSize =
        (headerH + searchH + buttonsH + bottomPadding) / screenHeight - 0.02;

    return FutureBuilder<bool>(
      future: Future.value(authVM.isConductor ?? false),
      initialData: authVM.isConductor ?? false,
      builder: (context, snapshot) {
        final bool isConductor = authVM.isConductor ?? false;
        final bool isLoggedIn = authVM.isLoggedIn;

        return Scaffold(
          key: _scaffoldKey,
          resizeToAvoidBottomInset: false,
          extendBody: true,
          drawer: _buildDrawer(authVM, isConductor),
          body: Stack(
            children: [
              // Map Layer - with tap handler for bus markers
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
                  onTapListener: (context) {
                    // Handle tap on map - check if bus was tapped
                    final lat = context.point.coordinates.lat.toDouble();
                    final lng = context.point.coordinates.lng.toDouble();
                    viewModel.handleMapTap(lat, lng);
                  },
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
                      onPressed: () {
                        Haptics.light();
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      semanticLabel: 'Open navigation menu',
                    ),
                  ),
                ),
              ),

              // Profile/Login Button
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Profile/Login Button - Modern design
                        Semantics(
                          button: true,
                          label: isLoggedIn
                              ? 'View your profile'
                              : 'Log in to your account',
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () {
                                  if (isConductor || isLoggedIn) {
                                    Navigator.pushNamed(context, '/profile');
                                  } else {
                                    Navigator.pushNamed(context, '/login');
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                splashColor: const Color(
                                  0xFF3B82F6,
                                ).withOpacity(0.15),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLoggedIn
                                            ? Icons.person_rounded
                                            : Icons.login_rounded,
                                        size: 20,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        isConductor || isLoggedIn
                                            ? 'Profile'
                                            : 'Login',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF2D2D2D),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Stats Popover Card
                        const SizedBox(height: 12),
                        _buildStatsPopover(viewModel),
                      ],
                    ),
                  ),
                ),
              ),

              // Bus Visibility Toggle
              Positioned(
                right: 16,
                bottom: (screenHeight * minSize) + 88,
                child: _circularIconButton(
                  viewModel.showAllBuses
                      ? Icons.directions_bus
                      : Icons.directions_bus_outlined,
                  isActive: viewModel.showAllBuses,
                  onPressed: () {
                    Haptics.light();
                    viewModel.toggleBusVisibility();
                  },
                  semanticLabel: viewModel.showAllBuses
                      ? 'Hide buses'
                      : 'Show all buses',
                ),
              ),
              // Location Button
              Positioned(
                right: 16,
                bottom: (screenHeight * minSize) + 20,
                child: _circularIconButton(
                  viewModel.isFetchingLocation
                      ? Icons.hourglass_top
                      : Icons.my_location,
                  onPressed: viewModel.isFetchingLocation
                      ? null
                      : () => viewModel.flyToCurrentLocation(),
                  semanticLabel: viewModel.isFetchingLocation
                      ? 'Getting your location, please wait'
                      : 'Go to my current location',
                ),
              ),

              // Bus Info Snippet
              if (viewModel.hasTappedVehicle)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (screenHeight * midSize) + 60,
                  child: BusInfoSnippet(
                    vehicle: viewModel.tappedVehicle!,
                    onClose: () => viewModel.clearTappedBus(),
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
                    trackedVehicles: viewModel.trackedVehicles,
                    isTrackingEnabled: viewModel.isTrackingEnabled,
                    showAllBuses: viewModel.showAllBuses,
                    onToggleBusVisibility: viewModel.toggleBusVisibility,
                    onToggleTracking: () {
                      if (viewModel.isTrackingEnabled) {
                        viewModel.stopVehicleTracking();
                      } else {
                        viewModel.startVehicleTracking();
                      }
                    },
                    onViewAllBuses: () {
                      // Show modal with all tracked buses
                      _showAllBusesModal(context, viewModel);
                    },
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
      },
    );
  }

  /// Builds the navigation drawer with user info, menu, and debug tools.
  Widget _buildDrawer(AuthViewModel authVM, bool isLoggedIn) {
    final user = authVM.user;
    final isLoggedIn = authVM.isLoggedIn;

    return Drawer(
      backgroundColor: const Color(0xFFFFFFFFF),
      child: SafeArea(
        child: Column(
          children: [
            // Header with logo
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFFF)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/sakaylive_logo.png', height: 50),
                  const SizedBox(height: 16),
                  if (isLoggedIn) ...[
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // Conductor Panel - Always visible for conductors
                  if (isLoggedIn)
                    _buildDrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Conductor Panel',
                      isHighlighted: true,
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
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ComingSoonPage(title: 'Settings'),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ComingSoonPage(title: 'Help & Support'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '🧪 Debug Tools',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final viewModel = Provider.of<MapViewModel>(context);
                      return Column(
                        children: [
                          _buildDrawerItem(
                            icon: Icons.add_location_alt_rounded,
                            label: 'Add Fake Buses',
                            onTap: () async {
                              Navigator.pop(context);
                              await viewModel.addFakeBuses();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.directions_bus_filled_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text('Added fake buses for all routes!'),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            icon: Icons.play_circle_rounded,
                            label: 'Start Moving Buses',
                            onTap: viewModel.hasFakeBuses
                                ? () {
                                    Navigator.pop(context);
                                    viewModel.startMovingFakeBuses();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(
                                              Icons.play_circle_filled_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 10),
                                            Text('Started moving buses!'),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                          _buildDrawerItem(
                            icon: Icons.stop_circle_rounded,
                            label: 'Stop Moving Buses',
                            onTap: () {
                              Navigator.pop(context);
                              viewModel.stopMovingFakeBuses();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.stop_circle_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Stopped moving buses'),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          _buildDrawerItem(
                            icon: Icons.delete_sweep_rounded,
                            label: 'Clear All Buses',
                            onTap: () {
                              Navigator.pop(context);
                              viewModel.clearFakeBuses();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.cleaning_services_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Cleared all fake buses'),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 16),
                  // Location Mode Toggle
                  _buildLocationModeToggle(context),
                ],
              ),
            ),
            // Bottom login/logout button
            Container(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: isLoggedIn
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () async {
                    if (isLoggedIn) {
                      await authVM.signOut();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Logged out successfully'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF22C55E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } else {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLoggedIn
                              ? Icons.logout_rounded
                              : Icons.login_rounded,
                          color: isLoggedIn
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isLoggedIn ? 'Logout' : 'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isLoggedIn
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single drawer menu item with icon and label.
  /// If [onTap] is null, the item is disabled (reduced opacity, no tap feedback).
  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isHighlighted = false,
    Widget? child,
  }) {
    final bool isDisabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Material(
          color: isHighlighted
              ? const Color(0xFF3B82F6).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: isDisabled
                ? Colors.transparent
                : const Color(0xFF3B82F6).withOpacity(0.15),
            highlightColor: isDisabled ? Colors.transparent : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isHighlighted
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF5C5C5C),
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  if (child != null)
                    Expanded(child: child)
                  else
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isHighlighted
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isHighlighted
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF3D3D3D),
                        ),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationModeToggle(BuildContext context) {
    final viewModel = Provider.of<MapViewModel>(context);
    final isDemoMode = viewModel.useDemoMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDemoMode
            ? const Color(0xFFFEF3C7) // Amber-100 for demo
            : const Color(0xFFDCFCE7), // Green-100 for live
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDemoMode
              ? const Color(0xFFFCD34D) // Amber-300
              : const Color(0xFF86EFAC), // Green-300
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDemoMode ? Icons.science_rounded : Icons.gps_fixed_rounded,
            color: isDemoMode
                ? const Color(0xFFD97706)
                : const Color(0xFF16A34A),
            size: 22,
          ),
          const SizedBox(width: 12),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDemoMode ? 'Demo Mode' : 'Live Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDemoMode
                        ? const Color(0xFFB45309)
                        : const Color(0xFF15803D),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isDemoMode
                      ? 'Using simulated location'
                      : 'Using real GPS location',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDemoMode
                        ? const Color(0xFF92400E)
                        : const Color(0xFF166534),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: Switch(
              value: !isDemoMode,
              onChanged: (value) async {
                if (value) {
                  // Switching to Live Mode: Request permissions first
                  bool serviceEnabled =
                      await geo.Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location services are disabled.'),
                        ),
                      );
                    }
                    return;
                  }

                  geo.LocationPermission permission =
                      await geo.Geolocator.checkPermission();
                  if (permission == geo.LocationPermission.denied) {
                    permission = await geo.Geolocator.requestPermission();
                    if (permission == geo.LocationPermission.denied) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location permissions are denied'),
                          ),
                        );
                      }
                      return;
                    }
                  }

                  if (permission == geo.LocationPermission.deniedForever) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Location permissions are permanently denied.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                }

                viewModel.setDemoMode(!value);
                viewModel.clearUserLocation();
                await viewModel.fetchUserLocation();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            value
                                ? Icons.gps_fixed_rounded
                                : Icons.science_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            value
                                ? 'Switched to Live Location mode'
                                : 'Switched to Demo mode',
                          ),
                        ],
                      ),
                      backgroundColor: value
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              activeColor: const Color(0xFF22C55E),
              inactiveThumbColor: const Color(0xFFF59E0B),
              inactiveTrackColor: const Color(0xFFFCD34D),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a minimal trip stats popover chip (shows when trip is active).
  Widget _buildStatsPopover(MapViewModel viewModel) {
    final tripStats = viewModel.activeTripStats;

    // Don't show anything if no active trip
    if (tripStats == null) {
      return const SizedBox.shrink();
    }

    final walkKm = tripStats['walkKm'] as double;
    final walkTimeMin = tripStats['walkTimeMin'] as int;
    final totalTime = tripStats['totalTime'] as int;
    final isTransfer = tripStats['isTransfer'] as bool;
    final routeNames = tripStats['routeNames'] as List;

    // Next bus info
    final hasNextBus = tripStats['hasNextBus'] as bool? ?? false;
    final nextBusEta = tripStats['nextBusEta'] as String?;
    final nextBusOccupancy = tripStats['nextBusOccupancy'] as String?;
    final nextBusDistanceToBoarding =
        tripStats['nextBusDistanceToBoarding'] as double?;

    // Build semantic description for screen readers
    final String semanticDescription =
        '${isTransfer ? 'Transfer' : 'Direct'} trip. '
        'Walking distance: ${walkKm.toStringAsFixed(1)} kilometers, approximately $walkTimeMin minutes. '
        'Routes: ${routeNames.join(' then ')}. '
        '${hasNextBus ? 'Next bus arriving in $nextBusEta. ' : ''}'
        'Total estimated time: $totalTime minutes.';

    return Semantics(
      label: semanticDescription,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with badge and close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Trip type badge with WCAG compliant colors
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isTransfer
                        ? const Color(0xFFEFF6FF) // Blue-50
                        : const Color(0xFFF0FDF4), // Green-50
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTransfer
                          ? const Color(0xFF93C5FD) // Blue-300
                          : const Color(0xFF86EFAC), // Green-300
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isTransfer ? '🔄 Transfer' : '✓ Direct',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isTransfer
                          ? const Color(0xFF1D4ED8) // Blue-700 WCAG
                          : const Color(0xFF15803D), // Green-700 WCAG
                    ),
                  ),
                ),
                // Close button to unselect trip
                Semantics(
                  button: true,
                  label: 'Close trip details',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => viewModel.clearSelection(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Walk info with time - WCAG compliant
            _buildStatChip(
              icon: Icons.directions_walk,
              value: '${walkKm.toStringAsFixed(1)} km (~$walkTimeMin min)',
              color: const Color(0xFF2563EB), // Blue-600 WCAG
            ),
            const SizedBox(height: 6),
            // Route names with better contrast
            ...routeNames.asMap().entries.map((entry) {
              final idx = entry.key;
              final name = entry.value;
              final isLast = idx == routeNames.length - 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_bus,
                      size: 15,
                      color: idx == 0
                          ? const Color(0xFF16A34A) // Green-600
                          : const Color(0xFF2563EB), // Blue-600
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151), // Gray-700 WCAG
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: Color(0xFF9CA3AF), // Gray-400
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            // Next Bus Info - only show if there's a bus available
            if (hasNextBus) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4), // Green-50
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF86EFAC), // Green-300
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E), // Green-500
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '★ Next Bus',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D), // Green-700
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextBusEta ?? 'Arriving soon',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF166534), // Green-800
                          ),
                        ),
                        if (nextBusOccupancy != null ||
                            nextBusDistanceToBoarding != null)
                          Text(
                            '${nextBusOccupancy ?? ''} ${nextBusDistanceToBoarding != null ? '• ${(nextBusDistanceToBoarding / 1000).toStringAsFixed(1)}km to stop' : ''}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4B5563), // Gray-600
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ] else ...[
              // No bus available message
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Amber-100
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFFD97706), // Amber-600
                    ),
                    SizedBox(width: 6),
                    Text(
                      'No active buses on this route',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309), // Amber-700
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Estimated total time with better contrast
            _buildStatChip(
              icon: Icons.schedule,
              value: '~$totalTime min total',
              color: const Color(0xFF4B5563), // Gray-600 WCAG
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single stat chip row with icon for trip stats.
  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a modern floating circular icon button with optional highlight.
  Widget _circularIconButton(
    IconData icon, {
    VoidCallback? onPressed,
    String? semanticLabel,
    bool isActive = false,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Button',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? const Color(0xFF3B82F6).withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFF3B82F6).withOpacity(0.15),
            highlightColor: const Color(0xFF3B82F6).withOpacity(0.08),
            child: Container(
              height: 52,
              width: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF3D3D3D),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet showing all tracked buses grouped by route.
class _AllBusesModal extends StatelessWidget {
  final List<TrackedVehicle> vehicles;
  final Function(TrackedVehicle) onBusTap;

  const _AllBusesModal({required this.vehicles, required this.onBusTap});

  @override
  /// Builds the modal bottom sheet UI for all tracked buses, grouped by route.
  @override
  Widget build(BuildContext context) {
    // Group vehicles by routeId
    final Map<String, List<TrackedVehicle>> groupedVehicles = {};
    for (var vehicle in vehicles) {
      groupedVehicles
          .putIfAbsent(vehicle.position.routeId, () => [])
          .add(vehicle);
    }

    final sortedRouteIds = groupedVehicles.keys.toList()..sort();

    // Modal height capped at 70% of screen
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with icon and summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Buses Nearby',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${vehicles.length} active ${vehicles.length == 1 ? 'bus' : 'buses'} across ${groupedVehicles.length} routes',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          // List of buses grouped by route
          Flexible(
            child: vehicles.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: sortedRouteIds.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, index) {
                      final routeId = sortedRouteIds[index];
                      final routeBuses = groupedVehicles[routeId] ?? [];
                      final routeName = routeBuses.isNotEmpty
                          ? routeBuses.first.routeName
                          : "Route $routeId";
                      return Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFDBEAFE),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.directions_bus,
                                      size: 14,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                    if (routeId.length <= 2)
                                      const SizedBox(width: 4),
                                    if (routeId.length <= 2)
                                      Text(
                                        routeId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1D4ED8),
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  routeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF1F2937),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  routeBuses.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: routeBuses.map((vehicle) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 4.0,
                              ),
                              child: LiveBusCard(
                                vehicle: vehicle,
                                onTap: () {
                                  Haptics.light();
                                  onBusTap(vehicle);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: EmptyState.noBusesAvailable(),
    );
  }
}
