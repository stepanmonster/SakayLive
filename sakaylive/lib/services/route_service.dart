import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sakaylive/models/cached_route.dart';
import 'package:sakaylive/models/trip_option.dart';
import 'package:sakaylive/utils/geo_utils.dart';

/// Service responsible for loading, caching, and calculating jeepney routes.
class RouteService {
  List<CachedRoute> _cachedRoutes = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<CachedRoute> get cachedRoutes => _cachedRoutes;

  /// Preload all routes from assets into memory for fast lookup.
  Future<void> preloadRoutes(List<Map<String, dynamic>> localRoutes) async {
    if (_isLoaded) return;

    for (var route in localRoutes) {
      List directions = route['directions'];
      for (int dirIdx = 0; dirIdx < directions.length; dirIdx++) {
        try {
          String assetPath = directions[dirIdx]['asset'];
          final String geojson = await rootBundle.loadString(assetPath);
          final Map<String, dynamic> data = json.decode(geojson);

          List<dynamic> rawCoords = _extractCoordinates(data);

          List<List<double>> parsedCoords = rawCoords.map((c) {
            return [(c[0] as num).toDouble(), (c[1] as num).toDouble()];
          }).toList();

          _cachedRoutes.add(
            CachedRoute(
              rawData: route,
              directionIndex: dirIdx,
              coordinates: parsedCoords,
            ),
          );
        } catch (e) {
          debugPrint("Error loading route ${route['num']}: $e");
        }
      }
    }
    _isLoaded = true;
  }

  List<dynamic> _extractCoordinates(Map<String, dynamic> data) {
    if (data['type'] == 'FeatureCollection') {
      return data['features'][0]['geometry']['coordinates'];
    }
    return data['geometry']['coordinates'];
  }

  /// Calculate efficient routes from user location to destination.
  /// Returns up to 3 best trip options.
  List<TripOption> calculateEfficientRoutes({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
  }) {
    if (!_isLoaded) return [];

    List<TripOption> results = [];
    List<_RouteCandidate> startCandidates = [];
    List<_RouteCandidate> endCandidates = [];

    // Step A: Find routes near start and end points
    for (var cached in _cachedRoutes) {
      final startCandidate = _findClosestPoint(
        cached,
        userLat,
        userLng,
        GeoUtils.maxWalkDistanceMeters,
      );
      final endCandidate = _findClosestPoint(
        cached,
        destLat,
        destLng,
        GeoUtils.maxWalkDistanceMeters,
      );

      if (startCandidate != null) startCandidates.add(startCandidate);
      if (endCandidate != null) endCandidates.add(endCandidate);
    }

    // Step B: Find direct trips (single route)
    for (var candidate in startCandidates) {
      final endIdx = _findClosestPointIndex(
        candidate.cachedRoute,
        destLat,
        destLng,
        GeoUtils.maxWalkDistanceMeters,
      );

      if (endIdx != null && candidate.pointIndex < endIdx) {
        results.add(
          _buildTripOption([
            TripLeg(
              cachedRoute: candidate.cachedRoute,
              pickupIndex: candidate.pointIndex,
              dropoffIndex: endIdx,
            ),
          ]),
        );
      }
    }

    // Step C: Find transfer trips (if not enough direct options)
    if (results.length < 3) {
      for (var leg1 in startCandidates) {
        for (var leg2 in endCandidates) {
          if (leg1.cachedRoute.routeNum == leg2.cachedRoute.routeNum) continue;

          final transfer = _findIntersection(
            leg1.cachedRoute.coordinates,
            leg1.pointIndex,
            leg2.cachedRoute.coordinates,
            leg2.pointIndex,
          );

          if (transfer != null) {
            final pickupIdx1 = leg1.pointIndex;
            final dropoffIdx1 = transfer.idx1;
            final pickupIdx2 = transfer.idx2;
            final dropoffIdx2 = leg2.pointIndex;

            // Validate direction (indices must increase)
            if (pickupIdx1 < dropoffIdx1 && pickupIdx2 < dropoffIdx2) {
              results.add(
                _buildTripOption([
                  TripLeg(
                    cachedRoute: leg1.cachedRoute,
                    pickupIndex: pickupIdx1,
                    dropoffIndex: dropoffIdx1,
                  ),
                  TripLeg(
                    cachedRoute: leg2.cachedRoute,
                    pickupIndex: pickupIdx2,
                    dropoffIndex: dropoffIdx2,
                  ),
                ]),
              );
            }
          }
        }
      }
    }

    // Sort by total time and return top 3
    results.sort((a, b) => a.totalTimeMinutes.compareTo(b.totalTimeMinutes));
    return results.take(3).toList();
  }

  _RouteCandidate? _findClosestPoint(
    CachedRoute cached,
    double lat,
    double lng,
    double maxDistance,
  ) {
    int? closestIdx;
    double minDist = maxDistance;

    for (int i = 0; i < cached.coordinates.length; i++) {
      double d = GeoUtils.fastDistance(
        lat,
        lng,
        cached.coordinates[i][1],
        cached.coordinates[i][0],
      );
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    if (closestIdx == null) return null;
    return _RouteCandidate(cachedRoute: cached, pointIndex: closestIdx);
  }

  int? _findClosestPointIndex(
    CachedRoute cached,
    double lat,
    double lng,
    double maxDistance,
  ) {
    int? closestIdx;
    double minDist = maxDistance;

    for (int i = 0; i < cached.coordinates.length; i++) {
      double d = GeoUtils.fastDistance(
        lat,
        lng,
        cached.coordinates[i][1],
        cached.coordinates[i][0],
      );
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  ({int idx1, int idx2})? _findIntersection(
    List<List<double>> coords1,
    int start1,
    List<List<double>> coords2,
    int end2,
  ) {
    for (int i = start1; i < coords1.length; i += 2) {
      double lat1 = coords1[i][1];
      double lng1 = coords1[i][0];

      for (int j = 0; j < end2; j += 2) {
        double lat2 = coords2[j][1];
        double lng2 = coords2[j][0];

        if (GeoUtils.fastDistance(lat1, lng1, lat2, lng2) <
            GeoUtils.transferToleranceMeters) {
          return (idx1: i, idx2: j);
        }
      }
    }
    return null;
  }

  TripOption _buildTripOption(List<TripLeg> legs) {
    int totalTime = 0;

    for (var leg in legs) {
      int nodes = (leg.dropoffIndex - leg.pickupIndex).abs();
      totalTime += GeoUtils.estimateTravelTime(nodes);
    }

    String description = legs.length == 1
        ? "Ride ${legs[0].cachedRoute.routeNum}"
        : "${legs[0].cachedRoute.routeNum} ➔ ${legs[1].cachedRoute.routeNum}";

    return TripOption(
      legs: legs,
      totalTimeMinutes: totalTime,
      description: description,
      isTransfer: legs.length > 1,
    );
  }
}

/// Internal helper class for route calculation.
class _RouteCandidate {
  final CachedRoute cachedRoute;
  final int pointIndex;

  _RouteCandidate({required this.cachedRoute, required this.pointIndex});
}
