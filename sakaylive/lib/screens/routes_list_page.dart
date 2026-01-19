import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sakaylive/data/jeepney_routes.dart';
import 'package:sakaylive/screens/theme.dart';

class RoutesListPage extends StatelessWidget {
  const RoutesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We use a copy of the data so we don't mutate the global state permanently
    // just by scrolling (though changing direction here is a nice preview).
    final routes = localRoutesData;

    return Scaffold(
      backgroundColor: beige,
      appBar: AppBar(
        title: const Text(
          "All Jeepney Routes",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: beige,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    final color = _getRouteColor(widget.routeData['color']);
    final directionName = widget.routeData['directions'][_activeDir]['name'];
    final routeNum = widget.routeData['num'];
    final routeDest = widget.routeData['dest'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTap(widget.routeData),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // --- 1. BUS ICON (Left) ---
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions_bus, color: color, size: 28),
                ),

                const SizedBox(width: 16),

                // --- 2. INFO COLUMN ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Route Number + Name (Using Wrap for Flow)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8.0, // Horizontal gap
                        runSpacing: 4.0, // Vertical gap if it wraps
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Route $routeNum",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            routeDest,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            // Removed maxLines/overflow to allow full wrapping
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Direction
                      Row(
                        children: [
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "To: $directionName",
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Active Buses Indicator
                      Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$_activeBusesCount active buses",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- 3. SWAP BUTTON (Right) ---
                IconButton(
                  onPressed: _toggleDirection,
                  icon: Icon(Icons.swap_vert_circle, color: color, size: 32),
                  tooltip: "Change Direction",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
