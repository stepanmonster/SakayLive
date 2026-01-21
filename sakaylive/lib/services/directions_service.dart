import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Walking instruction step for turn-by-turn navigation
class WalkingStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String? maneuver;
  final double? bearing;
  final List<List<double>> geometry;

  WalkingStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.maneuver,
    this.bearing,
    required this.geometry,
  });

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }

  String get durationText {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 1) return 'Less than 1 min';
    if (minutes == 1) return '1 min';
    return '$minutes mins';
  }

  factory WalkingStep.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']?['coordinates'] as List? ?? [];
    return WalkingStep(
      instruction: json['maneuver']?['instruction'] ?? 'Continue walking',
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0,
      maneuver: json['maneuver']?['type'],
      bearing: (json['maneuver']?['bearing_after'] as num?)?.toDouble(),
      geometry: geometry
          .map<List<double>>(
            (c) => [(c[0] as num).toDouble(), (c[1] as num).toDouble()],
          )
          .toList(),
    );
  }
}

/// Complete walking route with steps and summary
class WalkingRoute {
  final List<List<double>> coordinates;
  final List<WalkingStep> steps;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final DateTime fetchedAt;

  WalkingRoute({
    required this.coordinates,
    required this.steps,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  String get distanceText {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.round()}m';
    }
    return '${(totalDistanceMeters / 1000).toStringAsFixed(1)}km';
  }

  String get durationText {
    final minutes = (totalDurationSeconds / 60).round();
    if (minutes < 1) return 'Less than 1 min';
    if (minutes == 1) return '1 min walk';
    return '$minutes min walk';
  }

  bool get hasSteps => steps.isNotEmpty;
}

/// Service for fetching walking directions from Mapbox Directions API.
/// Includes caching to minimize API calls.
class DirectionsService {
  static final String _accessToken = dotenv.get(
    'MAPBOX_ACCESS_TOKEN',
    fallback: '',
  );

  /// Cache for walking routes - key is rounded coordinates, value is route.
  static final Map<String, WalkingRoute> _routeCache = {};

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

  /// Fetch walking route with full details including steps.
  /// Returns WalkingRoute with coordinates and turn-by-turn instructions.
  static Future<WalkingRoute?> getWalkingRouteDetailed({
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
      return WalkingRoute(
        coordinates: [
          [startLng, startLat],
          [endLng, endLat],
        ],
        steps: [
          WalkingStep(
            instruction: 'Walk to your destination',
            distanceMeters: distance,
            durationSeconds: distance / 1.4, // ~5 km/h walking speed
            geometry: [
              [startLng, startLat],
              [endLng, endLat],
            ],
          ),
        ],
        totalDistanceMeters: distance,
        totalDurationSeconds: distance / 1.4,
      );
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
      '?geometries=geojson&overview=full&steps=true&access_token=$_accessToken',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          final legs = route['legs'] as List?;

          // Parse steps from first leg
          List<WalkingStep> steps = [];
          if (legs != null && legs.isNotEmpty) {
            final legSteps = legs[0]['steps'] as List?;
            if (legSteps != null) {
              steps = legSteps.map((s) => WalkingStep.fromJson(s)).toList();
            }
          }

          final result = WalkingRoute(
            coordinates: coordinates.map<List<double>>((coord) {
              return [
                (coord[0] as num).toDouble(),
                (coord[1] as num).toDouble(),
              ];
            }).toList(),
            steps: steps,
            totalDistanceMeters:
                (route['distance'] as num?)?.toDouble() ?? distance,
            totalDurationSeconds:
                (route['duration'] as num?)?.toDouble() ?? distance / 1.4,
          );

          // Cache the result
          _cacheRoute(cacheKey, result);
          debugPrint(
            "🌐 Fetched & cached walking route (${distance.toInt()}m, ${steps.length} steps)",
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

  /// Fetch walking route coordinates between two points.
  /// Returns list of [lng, lat] coordinates or null if failed.
  /// Uses caching to avoid redundant API calls.
  static Future<List<List<double>>?> getWalkingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final route = await getWalkingRouteDetailed(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );
    return route?.coordinates;
  }

  /// Add route to cache, evicting oldest entries if cache is full.
  static void _cacheRoute(String key, WalkingRoute route) {
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

  /// Get bearing from one point to another in degrees (0-360)
  static double getBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = _toRadians(lng2 - lng1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final x = math.sin(dLng) * math.cos(lat2Rad);
    final y =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    var bearing = math.atan2(x, y) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Get cardinal direction from bearing
  static String getCardinalDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  /// Get human-readable direction instruction
  static String getDirectionText(double bearing) {
    final cardinal = getCardinalDirection(bearing);
    switch (cardinal) {
      case 'N':
        return 'Head north';
      case 'NE':
        return 'Head northeast';
      case 'E':
        return 'Head east';
      case 'SE':
        return 'Head southeast';
      case 'S':
        return 'Head south';
      case 'SW':
        return 'Head southwest';
      case 'W':
        return 'Head west';
      case 'NW':
        return 'Head northwest';
      default:
        return 'Continue walking';
    }
  }
}
