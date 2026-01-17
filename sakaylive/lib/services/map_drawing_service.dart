import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sakaylive/services/directions_service.dart';

/// Represents a marker to be added to the map.
class MarkerData {
  final List<double> coordinates;
  final String label;
  final Color textColor;

  MarkerData({
    required this.coordinates,
    required this.label,
    required this.textColor,
  });
}

/// Service responsible for drawing routes and markers on the Mapbox map.
class MapDrawingService {
  MapboxMap? _map;
  PointAnnotationManager? _annotationManager;

  /// Pending markers to be added in batch.
  final List<MarkerData> _pendingMarkers = [];

  bool get isInitialized => _map != null && _annotationManager != null;

  void initialize(MapboxMap map) {
    _map = map;
  }

  Future<void> initAnnotationManager() async {
    if (_map == null) return;
    _annotationManager = await _map!.annotations.createPointAnnotationManager();
  }

  PointAnnotationManager? get annotationManager => _annotationManager;

  /// Draw a polyline segment on the map.
  Future<void> drawPolyline({
    required List<List<double>> coordinates,
    required int startIndex,
    required int endIndex,
    required String colorName,
    required String layerId,
  }) async {
    if (_map == null) return;

    int s = min(startIndex, endIndex);
    int e = max(startIndex, endIndex);
    if (s >= e) return;

    List<List<double>> segment = coordinates.sublist(s, e + 1);

    final geoJson = {
      "type": "Feature",
      "properties": {},
      "geometry": {"type": "LineString", "coordinates": segment},
    };

    final style = _map!.style;
    await _removeLayerIfExists("$layerId-source", "$layerId-layer");

    await style.addSource(
      GeoJsonSource(id: "$layerId-source", data: json.encode(geoJson)),
    );
    await style.addLayer(
      LineLayer(
        id: "$layerId-layer",
        sourceId: "$layerId-source",
        lineColor: _getRouteColor(colorName).value,
        lineWidth: 6.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  /// Draw a dashed walking line between two points using actual walkable route.
  Future<void> drawWalkLine({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String layerId,
  }) async {
    if (_map == null) return;

    // Try to get actual walking route from Directions API
    final walkCoords = await DirectionsService.getWalkingRoute(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    // Use walking route if available, otherwise fallback to straight line
    final coordinates =
        walkCoords ??
        [
          [startLng, startLat],
          [endLng, endLat],
        ];

    final geoJson = {
      "type": "Feature",
      "properties": {},
      "geometry": {"type": "LineString", "coordinates": coordinates},
    };

    final style = _map!.style;
    await _removeLayerIfExists("$layerId-source", "$layerId-layer");

    await style.addSource(
      GeoJsonSource(id: "$layerId-source", data: json.encode(geoJson)),
    );
    await style.addLayer(
      LineLayer(
        id: "$layerId-layer",
        sourceId: "$layerId-source",
        lineColor: Colors.grey.shade600.value,
        lineWidth: 4.0,
        lineDasharray: [1.0, 1.5],
      ),
    );
  }

  /// Draw a full route from GeoJSON asset.
  Future<void> drawRouteFromAsset({
    required String assetPath,
    required String colorName,
  }) async {
    if (_map == null) return;

    String jsonStr = await rootBundle.loadString(assetPath);
    final style = _map!.style;

    await _removeLayerIfExists("route-source", "route-layer");

    await style.addSource(GeoJsonSource(id: "route-source", data: jsonStr));
    await style.addLayer(
      LineLayer(
        id: "route-layer",
        sourceId: "route-source",
        lineColor: _getRouteColor(colorName).value,
        lineWidth: 5.0,
      ),
    );
  }

  /// Add a labeled marker at coordinates with pill-style background.
  /// Note: Markers are queued and must be committed with flushMarkers().
  void queueMarker({
    required List<double> coordinates,
    required String label,
    required Color textColor,
  }) {
    _pendingMarkers.add(
      MarkerData(coordinates: coordinates, label: label, textColor: textColor),
    );
  }

  /// Legacy single marker method - immediately adds one marker.
  Future<void> addMarker({
    required List<double> coordinates,
    required String label,
    required Color textColor,
  }) async {
    if (_annotationManager == null) return;

    await _annotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(coordinates[0], coordinates[1])),
        textField: label,
        textSize: 14.0,
        textOffset: [0, 0],
        textColor: textColor.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 3.0,
        textHaloBlur: 1.0,
        iconOpacity: 0,
      ),
    );
  }

  /// Flush all queued markers to the map in a single batch operation.
  /// This is more efficient than adding markers one by one.
  Future<void> flushMarkers() async {
    if (_annotationManager == null || _pendingMarkers.isEmpty) return;

    final options = _pendingMarkers.map((marker) {
      return PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(marker.coordinates[0], marker.coordinates[1]),
        ),
        textField: marker.label,
        textSize: 14.0,
        textOffset: [0, 0],
        textColor: marker.textColor.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 3.0,
        textHaloBlur: 1.0,
        iconOpacity: 0,
      );
    }).toList();

    // Batch create all markers at once
    await _annotationManager!.createMulti(options);
    _pendingMarkers.clear();
  }

  /// Clear all markers.
  Future<void> clearMarkers() async {
    _pendingMarkers.clear();
    await _annotationManager?.deleteAll();
  }

  /// Clear all navigation-related layers.
  Future<void> clearNavigationLayers() async {
    if (_map == null) return;

    List<String> ids = ["walk-start", "walk-end", "route"];
    for (int i = 0; i < 5; i++) {
      ids.add("bus-leg-$i");
      ids.add("walk-transfer-$i");
    }

    for (String id in ids) {
      await _removeLayerIfExists("$id-source", "$id-layer");
    }
  }

  Future<void> _removeLayerIfExists(String sourceId, String layerId) async {
    final style = _map?.style;
    if (style == null) return;

    if (await style.styleSourceExists(sourceId)) {
      await style.removeStyleLayer(layerId);
      await style.removeStyleSource(sourceId);
    }
  }

  /// Fly camera to a specific location.
  void flyTo({
    required double lat,
    required double lng,
    double zoom = 14.5,
    int durationMs = 1500,
  }) {
    _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: durationMs),
    );
  }

  Future<void> drawGeoJsonRoute({
    required Map<String, dynamic> geoJsonData,
    required String colorName,
  }) async {
    if (_map == null) return;
    
    final style = _map!.style;
    if (await style.styleSourceExists("route-source")) {
      await style.removeStyleLayer("route-layer");
      await style.removeStyleSource("route-source");
    }
    
    await style.addSource(GeoJsonSource(id: "route-source", data: json.encode(geoJsonData)));
    await style.addLayer(LineLayer(
      id: "route-layer",
      sourceId: "route-source",
      lineColor: _getRouteColor(colorName).value,
      lineWidth: 5.0,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
      lineOpacity: 0.8,
    ));
  }

    Color _getRouteColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue': return Colors.blue;
      case 'orange': return Colors.orange;
      case 'green': return Colors.green;
      case 'red': return Colors.red;
      case 'purple': return Colors.purple;
      default: return Colors.blue;
    }
  }

  /// Fly camera to show both user and destination.
  void fitCameraToTrip({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
  }) {
    _map?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            (userLng + destLng) / 2,
            (userLat + destLat) / 2,
          ),
        ),
        zoom: 12.0,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }
}