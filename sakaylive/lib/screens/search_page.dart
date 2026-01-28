import 'dart:async';
import 'package:flutter/material.dart';
// Import package and hide Color to prevent conflicts
import 'package:mapbox_search/mapbox_search.dart' hide Color;
import 'package:sakaylive/data/jeepney_routes.dart'; // Ensure this exists
import 'package:sakaylive/screens/theme.dart'; // Ensure orange/beige defined here

class SearchPage extends StatefulWidget {
  final SearchBoxAPI searchBoxApi;
  final String sessionToken;
  final List<Map<String, dynamic>> cachedRoutes;

  const SearchPage({
    super.key,
    required this.searchBoxApi,
    required this.sessionToken,
    required this.cachedRoutes,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final query = _controller.text;

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) return;

      try {
        final response = await widget.searchBoxApi.getSuggestions(query);
        response.fold((success) {
          final formattedApiResults = success.suggestions.map((suggestion) {
            return {
              "type": "place",
              "num": "📍",
              "dest": suggestion.name,
              "status": suggestion.fullAddress ?? "",
              "color": "grey",
              "mapbox_id": suggestion.mapboxId,
              "time": "",
            };
          }).toList();

          if (mounted) {
            setState(() {
              _searchResults = formattedApiResults.toList();
            });
          }
        }, (failure) => debugPrint("API Error: ${failure.message}"));
      } catch (e) {
        debugPrint("Search Ex: $e");
      }
    });
  }

  Color _getRouteColor(String c) {
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar with search
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button
                  Semantics(
                    button: true,
                    label: 'Go back',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF3D3D3D),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Search field
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // --- UPDATED ICON DESIGN ---
                          const SizedBox(width: 16), // Adjusted spacing
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF3B82F6), // Light Blue
                            size: 22,
                          ),
                          const SizedBox(width: 12),

                          // ---------------------------
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D2D2D),
                              ),
                              decoration: const InputDecoration(
                                hintText: "Search destination...",
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
                          if (_controller.text.isNotEmpty)
                            Semantics(
                              button: true,
                              label: 'Clear search',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _controller.clear();
                                    setState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF6B7280),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Results list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  final color = Colors.grey;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Semantics(
                      button: true,
                      label: 'Location: ${item['dest']}, ${item['status']}',
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, item),
                          borderRadius: BorderRadius.circular(16),
                          splashColor: color.withOpacity(0.1),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFF6B7280),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['dest'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF1F2937),
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['status'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
