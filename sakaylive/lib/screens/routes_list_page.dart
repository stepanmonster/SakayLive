import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakaylive/viewmodels/map_view_model.dart';

class RoutesListPage extends StatelessWidget {
  const RoutesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Access routes from MapViewModel via Provider
    final viewModel = Provider.of<MapViewModel>(context);
    final routes =
        viewModel.displayList; // Uses cached routes from Firebase or fallback

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "All Jeepney Routes",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF374151),
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: routes.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _RouteCard(
            routeData: routes[index],
            onTap: (updatedRoute) {
              Navigator.pop(context, updatedRoute);
            },
          );
        },
      ),
    );
  }
}

class _RouteCard extends StatefulWidget {
  final Map<String, dynamic> routeData;
  final Function(Map<String, dynamic>) onTap;

  const _RouteCard({required this.routeData, required this.onTap});

  @override
  State<_RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<_RouteCard> {
  // Local state to handle direction swapping
  late int _activeDir;

  // Simulated "Active Buses" count (randomized for realism)
  late int _activeBusesCount;

  @override
  void initState() {
    super.initState();
    _activeDir = widget.routeData['activeDir'] ?? 0;
    _activeBusesCount =
        3 + Random().nextInt(5); // Random number between 3 and 7
  }

  void _toggleDirection() {
    setState(() {
      _activeDir = (_activeDir + 1) % 2;
      // Update the actual map object so when we tap it, it passes the correct direction
      widget.routeData['activeDir'] = _activeDir;
    });
  }

  Color _getRouteColor(String c) {
    switch (c) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'orange':
        return const Color(0xFFF97316);
      case 'green':
        return const Color(0xFF22C55E);
      case 'red':
        return const Color(0xFFEF4444);
      case 'purple':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRouteColor(widget.routeData['color']);
    final directionName = widget.routeData['directions'][_activeDir]['name'];
    final routeNum = widget.routeData['num'];
    final routeDest = widget.routeData['dest'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTap(widget.routeData),
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // --- 1. BUS ICON (Left) ---
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: color,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                // --- 2. INFO COLUMN ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Route Number + Name (Using Wrap for Flow)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Route $routeNum",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              routeDest,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Direction
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "To: $directionName",
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Active Buses Indicator
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$_activeBusesCount active buses",
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 3. SWAP BUTTON (Right) ---
                Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _toggleDirection,
                    icon: Icon(Icons.swap_vert_rounded, color: color, size: 24),
                    tooltip: "Change Direction",
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
