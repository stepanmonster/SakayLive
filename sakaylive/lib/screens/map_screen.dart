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
    map.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    map.logo.updateSettings(LogoSettings(marginBottom: 150, marginLeft: 16));
    map.attribution.updateSettings(
      AttributionSettings(marginBottom: 150, marginLeft: 100),
    );

    await viewModel.initialize(map); // Wait for completion
    print("✅ MapViewModel fully initialized"); // Debug
    viewModel.fetchUserLocation();
  }

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
      // Handle route selection vs place selection
      if (result['type'] == 'route') {
        // Direct route selection - draw on map
        viewModel.selectRoute(result);
        _sheetController.animateTo(
          0.18,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        // Place search - plan trip
        final success = await viewModel.planTripToPlace(result);
        if (success) {
          _searchController.text = result['dest'];
          // Expand to mode 3 (0.85) to show all trip options
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

  Widget _buildScreen(
    BuildContext context,
    MapViewModel viewModel,
    AuthViewModel authVM,
  ) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    const double headerH = 40.0;
    const double searchH = 74.0;
    const double buttonsH = 110.0;
    final double minSize =
        (headerH + searchH + bottomPadding) / screenHeight - 0.02;
    final double midSize =
        (headerH + searchH + buttonsH + bottomPadding) / screenHeight - 0.02;

    return FutureBuilder<bool>(
      future: authVM.authService
          .isConductor(), // ✅ Use service through ViewModel
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

              // Menu Button - WCAG compliant with semantic label
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _circularIconButton(
                      Icons.menu,
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      semanticLabel: 'Open navigation menu',
                    ),
                  ),
                ),
              ),

              // Profile/Login Button - ✅ Now uses FutureBuilder data
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

              // Location Button - WCAG compliant with loading feedback
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
                      icon: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ConductorDashboard(),
                          ),
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

  Widget _buildDrawer(AuthService authService, bool isConductor) {
    final user = authService.currentUser;
    final isLoggedIn = user != null;

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
                  _buildDrawerItem(
                    icon: Icons.confirmation_num_rounded,
                    label: 'Transit Passes',
                    onTap: () {},
                  ),
                  if (isConductor)
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
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () {},
                  ),
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
                      await authService.signOut();
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isHighlighted
            ? const Color(0xFF3B82F6).withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFF3B82F6).withOpacity(0.15),
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
                Text(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a minimal trip stats chip - only shows when trip is active
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

    // Build semantic description for screen readers
    final String semanticDescription =
        '${isTransfer ? 'Transfer' : 'Direct'} trip. '
        'Walking distance: ${walkKm.toStringAsFixed(1)} kilometers, approximately $walkTimeMin minutes. '
        'Routes: ${routeNames.join(' then ')}. '
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
            const SizedBox(height: 4),
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

  /// Build a single stat chip row with icon - DUPLICATE REMOVED BELOW
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

  /// Modern floating icon button with gradient support
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
