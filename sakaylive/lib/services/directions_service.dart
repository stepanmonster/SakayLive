import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for fetching walking directions from Mapbox Directions API.
class DirectionsService {
  static final String _accessToken = dotenv.get(
    'MAPBOX_ACCESS_TOKEN',
    fallback: '',
  );

  /// Fetch walking route coordinates between two points.
  /// Returns list of [lng, lat] coordinates or null if failed.
  static Future<List<List<double>>?> getWalkingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    if (_accessToken.isEmpty) {
      debugPrint("⚠️ Mapbox token missing for directions");
      return null;
    }

    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/walking/'
      '$startLng,$startLat;$endLng,$endLat'
      '?geometries=geojson&overview=full&access_token=$_accessToken',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates.map<List<double>>((coord) {
            return [(coord[0] as num).toDouble(), (coord[1] as num).toDouble()];
          }).toList();
        }
      } else {
        debugPrint("Directions API error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Directions fetch error: $e");
    }

    return null;
  }
}
