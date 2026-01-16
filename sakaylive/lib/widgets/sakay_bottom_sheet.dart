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
  final double searchHeight;
  final double buttonsHeight;
  final double bottomPadding;
  final String? selectedRouteNum;

  // 1. ADD THIS LINE: Define the callback parameter
  final VoidCallback? onRoutesTap;

  const SakayBottomSheet({
    super.key,
    required this.scrollController,
    required this.searchController,
    required this.routes,
    required this.onRouteSelected,
    required this.onRouteSwap,
    required this.onSearchTap,
    required this.onSearchClear,
    this.searchHeight = 66.0,
    this.buttonsHeight = 80.0,
    this.bottomPadding = 20.0,
    this.selectedRouteNum,
    // 2. ADD THIS LINE: Add it to the constructor
    this.onRoutesTap,
  });

  @override
  Widget build(BuildContext context) {
    const double margin = 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, 0, margin, margin + bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: beige,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: CustomScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchBar(),

                    // 3. This builds the buttons row
                    _buildQuickActions(),

                    const Divider(
                      thickness: 1,
                      color: Colors.black12,
                      height: 1,
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _RouteTile(
                  route: routes[index],
                  isSelected: selectedRouteNum == routes[index]['num'],
                  onTap: () => onRouteSelected(routes[index]),
                  onSwap: () => onRouteSwap(routes[index]),
                ),
                childCount: routes.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: searchController,
                onTap: onSearchTap,
                readOnly: true, // Prevent keyboard from opening automatically
                decoration: const InputDecoration(
                  hintText: "Where to?",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(bottom: 5),
                ),
              ),
            ),
            if (searchController.text.isNotEmpty || selectedRouteNum != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                onPressed: onSearchClear,
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 4. CONNECT THE BUTTON HERE
          _actionIcon(Icons.directions_bus, "Routes", onTap: onRoutesTap),

          _actionIcon(Icons.home, "Home", onTap: () {}),
          _actionIcon(Icons.star, "Saved", onTap: () {}),
          _actionIcon(Icons.history, "Recent", onTap: () {}),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData i, String l, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              // Highlight the Routes button slightly
              child: Icon(
                i,
                color: l == "Routes" ? Colors.orange : Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  final Map<String, dynamic> route;
  final VoidCallback onTap;
  final VoidCallback onSwap;
  final bool isSelected;

  const _RouteTile({
    super.key, // Added super.key for best practice
    required this.route,
    required this.onTap,
    required this.onSwap,
    this.isSelected = false,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(
              isPlace ? Icons.location_on : Icons.directions_bus,
              color: Colors.white,
            ),
          ),
          title: Text(
            route['dest'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                route['status'],
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              if (!isPlace && route['directions'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.swap_calls, size: 14, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        // FIX: Added '?? 0' to prevent crash if activeDir is null
                        child: Text(
                          route['directions'][route['activeDir'] ?? 0]['name'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: isPlace
              ? const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      route['time'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    InkWell(
                      onTap: onSwap,
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.compare_arrows, size: 20),
                      ),
                    ),
                  ],
                ),
          onTap: onTap,
        ),
        const Divider(indent: 70, endIndent: 16, height: 1),
      ],
    );
  }
}
