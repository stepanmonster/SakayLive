import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for fetching walking directions from Mapbox Directions API.
/// Includes caching to minimize API calls.
class DirectionsService {
  static final String _accessToken = dotenv.get(
    'MAPBOX_ACCESS_TOKEN',
    fallback: '',
  );

  /// Cache for walking routes - key is rounded coordinates, value is route.
  static final Map<String, List<List<double>>> _routeCache = {};

  /// Maximum cache size to prevent memory issues.
  static const int _maxCacheSize = 50;

  /// Minimum distance (meters) to bother fetching a route.
  /// Shorter distances just use straight line.
  static const double _minDistanceForApi = 50.0;

  /// Generate cache key from coordinates (rounded to 4 decimal places ~11m accuracy).
  static String _cacheKey(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    // Round to 4 decimal places for cache key
    final sLat = startLat.toStringAsFixed(4);
    final sLng = startLng.toStringAsFixed(4);
    final eLat = endLat.toStringAsFixed(4);
    final eLng = endLng.toStringAsFixed(4);
    return '$sLat,$sLng->$eLat,$eLng';
  }

  /// Calculate approximate distance in meters using Haversine formula.
  static double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Fetch walking route coordinates between two points.
  /// Returns list of [lng, lat] coordinates or null if failed.
  /// Uses caching to avoid redundant API calls.
  static Future<List<List<double>>?> getWalkingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // Skip API for very short distances - just return straight line
    final distance = _calculateDistance(startLat, startLng, endLat, endLng);
    if (distance < _minDistanceForApi) {
      debugPrint(
        "📍 Walk distance ${distance.toInt()}m < ${_minDistanceForApi.toInt()}m - using straight line",
      );
      return [
        [startLng, startLat],
        [endLng, endLat],
      ];
    }

    // Check cache first
    final cacheKey = _cacheKey(startLat, startLng, endLat, endLng);
    if (_routeCache.containsKey(cacheKey)) {
      debugPrint("📦 Using cached walking route");
      return _routeCache[cacheKey];
    }

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

          final result = coordinates.map<List<double>>((coord) {
            return [(coord[0] as num).toDouble(), (coord[1] as num).toDouble()];
          }).toList();

          // Cache the result
          _cacheRoute(cacheKey, result);
          debugPrint(
            "🌐 Fetched & cached walking route (${distance.toInt()}m)",
          );

          return result;
        }
      } else {
        debugPrint("Directions API error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Directions fetch error: $e");
    }

    return null;
  }

  /// Add route to cache, evicting oldest entries if cache is full.
  static void _cacheRoute(String key, List<List<double>> route) {
    // Simple LRU-like eviction: remove first entries if cache is full
    if (_routeCache.length >= _maxCacheSize) {
      final keysToRemove = _routeCache.keys.take(10).toList();
      for (var k in keysToRemove) {
        _routeCache.remove(k);
      }
      debugPrint("🗑️ Evicted ${keysToRemove.length} cached routes");
    }
    _routeCache[key] = route;
  }

  /// Clear the route cache (call when user location changes significantly).
  static void clearCache() {
    _routeCache.clear();
    debugPrint("🗑️ Walking route cache cleared");
  }

  /// Get current cache size for debugging.
  static int get cacheSize => _routeCache.length;
}
