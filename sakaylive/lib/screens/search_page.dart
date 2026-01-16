import 'dart:async';
import 'package:flutter/material.dart';
// Import package and hide Color to prevent conflicts
import 'package:mapbox_search/mapbox_search.dart' hide Color;
import 'package:sakaylive/data/jeepney_routes.dart'; // Ensure this exists
import 'package:sakaylive/screens/theme.dart'; // Ensure orange/beige defined here

class SearchPage extends StatefulWidget {
  final SearchBoxAPI searchBoxApi;

  const SearchPage({super.key, required this.searchBoxApi});

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
    // Initially show local jeepney routes as "Suggested"
    _searchResults = List.from(localRoutesData);
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
        _searchResults = List.from(localRoutesData);
      });
      return;
    }

    // 1. Local Search
    final localResults = localRoutesData.where((route) {
      final num = route['num'].toString().toLowerCase();
      final dest = route['dest'].toString().toLowerCase();
      return num.contains(query.toLowerCase()) ||
          dest.contains(query.toLowerCase());
    }).toList();

    // Show local results immediately
    setState(() => _searchResults = localResults);

    // 2. API Search (Debounced)
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
              _searchResults = [...localResults, ...formattedApiResults];
            });
          }
        }, (failure) => debugPrint("API Error: ${failure.message}"));
      } catch (e) {
        debugPrint("Search Ex: $e");
      }
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true, // Key feature: Focus immediately
          decoration: const InputDecoration(
            hintText: "Search destination or route...",
            border: InputBorder.none,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          final bool isPlace = item['type'] == 'place';
          final color = _getRouteColor(item['color']);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: isPlace ? Colors.grey[200] : color,
              child: Icon(
                isPlace ? Icons.location_on : Icons.directions_bus,
                color: isPlace ? Colors.black54 : Colors.white,
              ),
            ),
            title: Text(
              item['dest'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              item['status'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              // Return the selected item back to MapScreen
              Navigator.pop(context, item);
            },
          );
        },
      ),
    );
  }
}
