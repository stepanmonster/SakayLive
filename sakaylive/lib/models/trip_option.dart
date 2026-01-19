import 'package:sakaylive/models/cached_route.dart';

/// Represents a single leg of a trip (one jeepney ride).
class TripLeg {
  final CachedRoute cachedRoute;
  final int pickupIndex;
  final int dropoffIndex;

  TripLeg({
    required this.cachedRoute,
    required this.pickupIndex,
    required this.dropoffIndex,
  });

  List<double> get pickupCoords => cachedRoute.coordinates[pickupIndex];
  List<double> get dropoffCoords => cachedRoute.coordinates[dropoffIndex];

  Map<String, dynamic> get routeData => cachedRoute.rawData;
  int get activeDir => cachedRoute.directionIndex;
  List<List<double>> get coordinates => cachedRoute.coordinates;
}

/// Represents a complete trip option (may have 1 or 2 legs).
class TripOption {
  final List<TripLeg> legs;
  final int totalTimeMinutes;
  final String description;
  final bool isTransfer;

  TripOption({
    required this.legs,
    required this.totalTimeMinutes,
    required this.description,
    required this.isTransfer,
  });

  String get primaryRouteNum => legs.first.cachedRoute.routeNum;
  String get primaryColor => legs.first.cachedRoute.color;
  Map<String, dynamic> get primaryRouteData => legs.first.routeData;

  /// Convert to Map for UI compatibility with existing widgets.
  Map<String, dynamic> toDisplayMap() {
    final primaryRoute = legs.first.routeData;

    return {
      "type": "trip_option",
      "num": primaryRouteNum,
      "dest": description,
      "status": isTransfer ? "Transfer" : "Direct",
      "color": primaryColor,
      "time": "$totalTimeMinutes min",
      "totalTime": totalTimeMinutes,
      "walk_dist_text": "View Map",
      "activeDir": legs.first.activeDir,
      "route_data": primaryRoute,
      "directions": primaryRoute['directions'],
      "legs": legs
          .map(
            (leg) => {
              'route': leg.routeData,
              'activeDir': leg.activeDir,
              'coords': leg.coordinates,
              'pickup': leg.pickupCoords,
              'dropoff': leg.dropoffCoords,
              'pickupIndex': leg.pickupIndex,
              'dropoffIndex': leg.dropoffIndex,
            },
          )
          .toList(),
    };
  }
}
