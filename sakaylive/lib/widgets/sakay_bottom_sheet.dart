import 'package:flutter/material.dart';
import 'package:sakaylive/screens/theme.dart';

class SakayBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> routes;
  final Function(Map<String, dynamic>) onRouteSelected;
  final Function(Map<String, dynamic>) onRouteSwap;
  final VoidCallback onSearchTap;
  final VoidCallback onSearchClear;
  final VoidCallback? onRoutesTap;
  final double searchHeight;
  final double buttonsHeight;
  final double bottomPadding;
  final String? selectedRouteNum;

  const SakayBottomSheet({
    super.key,
    required this.scrollController,
    required this.searchController,
    required this.routes,
    required this.onRouteSelected,
    required this.onRouteSwap,
    required this.onSearchTap,
    required this.onSearchClear,
    this.onRoutesTap,
    this.searchHeight = 66.0,
    this.buttonsHeight = 80.0,
    this.bottomPadding = 20.0,
    this.selectedRouteNum,
  });

  @override
  Widget build(BuildContext context) {
    const double margin = 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, 0, margin, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            // --- FIXED: STICKY HEADER ---
            SliverAppBar(
              pinned: true,
              floating: false,
              primary: false,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 188,
              titleSpacing: 0,
              centerTitle: true,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade300],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Search Bar
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                ],
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
            // --- SCROLLABLE LIST WITH NAV-BAR SAFE PADDING ---
            SliverPadding(
              padding: EdgeInsets.only(bottom: bottomPadding + 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final route = routes[index];
                  bool isFastest = false;
                  bool isCheapest = false;

                  if (route['type'] == 'trip_option') {
                    final tripOptions = routes
                        .where((r) => r['type'] == 'trip_option')
                        .toList();
                    if (tripOptions.isNotEmpty) {
                      final firstTripIndex = routes.indexWhere(
                        (r) => r['type'] == 'trip_option',
                      );
                      isFastest = index == firstTripIndex;

                      final minRides = tripOptions
                          .map((r) => r['rideCount'] as int? ?? 999)
                          .reduce((a, b) => a < b ? a : b);
                      isCheapest = (route['rideCount'] ?? 999) == minRides;
                    }
                  }

                  return _RouteTile(
                    route: route,
                    isSelected: selectedRouteNum == route['num'],
                    onTap: () => onRouteSelected(route),
                    onSwap: () => onRouteSwap(route),
                    isFastest: isFastest,
                    isCheapest: isCheapest,
                  );
                }, childCount: routes.length),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // --- HELPER WIDGETS ---

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Semantics(
        textField: true,
        label: 'Search for destination',
        hint: 'Tap to search for routes or places',
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Adjusted spacing
              const SizedBox(width: 16),
              // --- REPLACED THE CONTAINER WITH JUST THE ICON ---
              const Icon(
                Icons.search_rounded,
                // Used the light blue from your brand colors
                color: Color(0xFF3B82F6),
                // Increased size slightly (from 18 to 22) to balance having no box
                size: 22,
              ),
              // --------------------------------------------------
              // Adjusted spacing
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onTap: onSearchTap,
                  readOnly: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D2D),
                  ),
                  decoration: const InputDecoration(
                    hintText: "Where to?",
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (searchController.text.isNotEmpty || selectedRouteNum != null)
                Semantics(
                  button: true,
                  label: 'Clear search',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSearchClear,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF6B7280),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _actionIcon(Icons.directions_bus, "Routes", onTap: onRoutesTap),
          _actionIcon(Icons.home, "Home", onTap: () {}),
          _actionIcon(Icons.star, "Saved", onTap: () {}),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData i, String l, {VoidCallback? onTap}) {
    final bool isRoutes = l == "Routes";
    return Semantics(
      button: true,
      label: '$l button',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF3B82F6).withOpacity(0.15),
          highlightColor: const Color(0xFF3B82F6).withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isRoutes
                        ? const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          )
                        : null,
                    color: isRoutes ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isRoutes
                            ? const Color(0xFF3B82F6).withOpacity(0.3)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: isRoutes ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isRoutes
                        ? null
                        : Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Icon(
                    i,
                    color: isRoutes ? Colors.white : const Color(0xFF5C5C5C),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isRoutes ? FontWeight.w700 : FontWeight.w600,
                    color: isRoutes
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF5C5C5C),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- ROUTE TILE (UPDATED) ---
class _RouteTile extends StatelessWidget {
  final Map<String, dynamic> route;
  final VoidCallback onTap;
  final VoidCallback onSwap;
  final bool isSelected;
  final bool isFastest;
  final bool isCheapest;

  const _RouteTile({
    super.key,
    required this.route,
    required this.onTap,
    required this.onSwap,
    this.isSelected = false,
    this.isFastest = false,
    this.isCheapest = false,
  });

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
      case 'purple':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRouteColor(route['color']);
    final isPlace = route['type'] == 'place';
    final isTripOption = route['type'] == 'trip_option';
    final isTransfer = route['isTransfer'] == true;
    final rideCount = route['rideCount'] ?? 1;

    // Get route numbers for trip options
    final routeNums = route['routeNums'] ?? route['num'];

    final String semanticLabel = isPlace
        ? 'Location: ${route['dest']}, ${route['status']}'
        : isTripOption
        ? '${isTransfer ? 'Transfer trip' : 'Direct trip'} via $routeNums, ${route['time']}'
        : 'Route ${route['num']}: ${route['dest']}, ${route['time']}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: color.withOpacity(0.1),
            highlightColor: color.withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? color.withOpacity(0.3)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: isTripOption
                  ? _buildTripOptionContent(
                      color,
                      isTransfer,
                      rideCount,
                      routeNums,
                    )
                  : _buildRegularRouteContent(color, isPlace),
            ),
          ),
        ),
      ),
    );
  }

  /// Build content for trip_option type tiles
  Widget _buildTripOptionContent(
    Color color,
    bool isTransfer,
    int rideCount,
    String routeNums,
  ) {
    // Use the first route's color for the icon
    final firstRouteColor = color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Row: Route Numbers (left) + Time (right)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route numbers with icon - using first route's color
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: firstRouteColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: firstRouteColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeNums,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          route['dest'] ?? 'Destination',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Time badge (top right)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: firstRouteColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                route['time'] ?? '-- min',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: firstRouteColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Middle: Visual journey chain with route colors
        _buildJourneyChain(isTransfer, rideCount, firstRouteColor),
        const SizedBox(height: 10),
        // Bottom: Badges row
        _buildBadgesRow(isTransfer, rideCount),
      ],
    );
  }

  /// Build visual journey chain (Walk > Bus > Walk or Walk > Bus > Walk > Bus > Walk)
  Widget _buildJourneyChain(
    bool isTransfer,
    int rideCount,
    Color firstRouteColor,
  ) {
    // Get second route color if transfer
    Color? secondRouteColor;
    if (isTransfer &&
        route['legs'] != null &&
        (route['legs'] as List).length > 1) {
      final secondLeg = (route['legs'] as List)[1];
      final secondRouteColorName = secondLeg['route']?['color'] ?? 'blue';
      secondRouteColor = _getRouteColor(secondRouteColorName);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 8,
        children: [
          // Walk to pickup
          _buildChainIcon(
            Icons.directions_walk_rounded,
            const Color(0xFF6B7280),
          ),
          _buildChainArrow(),
          // First bus - using first route color
          _buildChainIcon(Icons.directions_bus_rounded, firstRouteColor),
          if (isTransfer) ...[
            _buildChainArrow(),
            // Transfer walk
            _buildChainIcon(
              Icons.directions_walk_rounded,
              const Color(0xFF6B7280),
            ),
            _buildChainArrow(),
            // Second bus - using second route color
            _buildChainIcon(
              Icons.directions_bus_rounded,
              secondRouteColor ?? const Color(0xFF3B82F6),
            ),
          ],
          _buildChainArrow(),
          // Walk to destination
          _buildChainIcon(
            Icons.directions_walk_rounded,
            const Color(0xFF6B7280),
          ),
          _buildChainArrow(),
          // Destination flag
          _buildChainIcon(Icons.flag_rounded, const Color(0xFF22C55E)),
        ],
      ),
    );
  }

  Widget _buildChainIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildChainArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 16,
        color: Color(0xFFD1D5DB),
      ),
    );
  }

  /// Build badges row with dynamic tags
  Widget _buildBadgesRow(bool isTransfer, int rideCount) {
    return Row(
      children: [
        // Direct/Transfer badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isTransfer
                  ? [const Color(0xFFEFF6FF), const Color(0xFFBFDBFE)]
                  : [const Color(0xFFF0FDF4), const Color(0xFFBBF7D0)],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isTransfer ? '🔄 Transfer' : '✓ Direct',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isTransfer
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF16A34A),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Ride count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$rideCount ${rideCount == 1 ? 'ride' : 'rides'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const Spacer(),
        // Fastest badge (conditionally shown)
        if (isFastest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '⚡ Fastest',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
            ),
          ),
        if (isCheapest && !isFastest)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFA7F3D0)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '💰 Cheapest',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
      ],
    );
  }

  /// Build content for regular route/place tiles
  Widget _buildRegularRouteContent(Color color, bool isPlace) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isPlace ? Icons.location_on_rounded : Icons.directions_bus_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                route['dest'],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              _buildRegularSubtitle(isPlace, color),
            ],
          ),
        ),
        _buildRegularTrailing(isPlace, color),
      ],
    );
  }

  Widget _buildRegularSubtitle(bool isPlace, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          route['status'],
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!isPlace && route['directions'] != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  route['directions'][route['activeDir'] ?? 0]['name'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRegularTrailing(bool isPlace, Color color) {
    if (isPlace) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Color(0xFF9CA3AF),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            route['time'],
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: 'Swap route direction',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSwap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  size: 18,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
