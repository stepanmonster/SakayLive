import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sakaylive/services/directions_service.dart';
import 'dart:ui' as ui;

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

/// Represents a bus marker with additional styling info.
class BusMarkerData {
  final List<double> coordinates;
  final String etaText;
  final String routeName;
  final Color routeColor;
  final double heading;

  BusMarkerData({
    required this.coordinates,
    required this.etaText,
    required this.routeName,
    required this.routeColor,
    required this.heading,
  });
}

/// Service responsible for drawing routes and markers on the Mapbox map.
class MapDrawingService {
  MapboxMap? _map;
  PointAnnotationManager? _annotationManager;
  PointAnnotationManager? _busAnnotationManager;

  // Cache of registered bus icon colors to avoid re-generating the same icons
  final Set<int> _registeredBusColors = {};

  /// Pending markers to be added in batch.
  final List<MarkerData> _pendingMarkers = [];
  final List<BusMarkerData> _pendingBusMarkers = [];

  bool get isInitialized => _map != null && _annotationManager != null;

  void initialize(MapboxMap map) {
    _map = map;
  }

  Future<void> initAnnotationManager() async {
    if (_map == null) return;
    _annotationManager = await _map!.annotations.createPointAnnotationManager();
    _busAnnotationManager = await _map!.annotations
        .createPointAnnotationManager();
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

  // =========================================================
  // BUS MARKER METHODS
  // =========================================================

  /// Generate a bus icon image with the specified color
  Future<Uint8List> _generateBusIcon(Color color) async {
    const double size = 80;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw circle background
    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4, bgPaint);

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      borderPaint,
    );

    // Draw bus emoji/icon as text
    final textPainter = TextPainter(
      text: const TextSpan(text: '🚌', style: TextStyle(fontSize: 36)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Queue a bus marker to be added
  void queueBusMarker({
    required List<double> coordinates,
    required String etaText,
    required String routeName,
    required Color routeColor,
    double heading = 0.0,
  }) {
    _pendingBusMarkers.add(
      BusMarkerData(
        coordinates: coordinates,
        etaText: etaText,
        routeName: routeName,
        routeColor: routeColor,
        heading: heading,
      ),
    );
  }

  /// Flush all queued bus markers to the map
  Future<void> flushBusMarkers() async {
    if (_busAnnotationManager == null || _pendingBusMarkers.isEmpty) return;

    if (_map != null) {
      // 1. Pre-register all necessary colored icons
      for (final marker in _pendingBusMarkers) {
        final colorValue = marker.routeColor.value;
        if (!_registeredBusColors.contains(colorValue)) {
          try {
            final iconId = 'bus-icon-$colorValue';
            final iconBytes = await _generateBusIcon(marker.routeColor);

            await _map!.style.addStyleImage(
              iconId,
              1.0, // Scale
              MbxImage(width: 80, height: 80, data: iconBytes),
              false, // sdf
              [], // stretchX
              [], // stretchY
              null, // content
            );

            _registeredBusColors.add(colorValue);
            debugPrint("🎨 Registered new bus icon: $iconId");
          } catch (e) {
            debugPrint(
              "❌ Failed to register bus icon for color $colorValue: $e",
            );
          }
        }
      }
    }

    final options = _pendingBusMarkers.map((marker) {
      final colorValue = marker.routeColor.value;

      return PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(marker.coordinates[0], marker.coordinates[1]),
        ),

        // ICON CONFIGURATION
        iconImage: 'bus-icon-$colorValue',
        iconSize: 0.6, // Smaller size (original was 80px)
        iconOpacity: 1.0,
        iconAnchor: IconAnchor.CENTER, // Center the bus on the actual location
        // iconRotate: marker.heading, // Option to rotate if desired

        // TEXT LABELS (ETA)
        textField: marker.etaText,
        textSize: 12.0,
        textOffset: [
          0,
          2.0,
        ], // Position text below the icon (approx 2 ems down)
        textAnchor: TextAnchor.CENTER,
        textColor: Colors.black.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 2.0,
        textHaloBlur: 1.0,
      );
    }).toList();

    await _busAnnotationManager!.createMulti(options);
    _pendingBusMarkers.clear();
  }

  /// Clear all bus markers
  Future<void> clearBusMarkers() async {
    _pendingBusMarkers.clear();
    await _busAnnotationManager?.deleteAll();
    // note: we do not clear _registeredBusColors as style images persist
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

  /// Helper to safely remove layer and source.
  /// FIXED: Now checks layer existence separately before removing.
  Future<void> _removeLayerIfExists(String sourceId, String layerId) async {
    final style = _map?.style;
    if (style == null) return;

    // 1. Remove Layer First (Visual)
    if (await style.styleLayerExists(layerId)) {
      await style.removeStyleLayer(layerId);
    }

    // 2. Remove Source Second (Data)
    if (await style.styleSourceExists(sourceId)) {
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
    // Safe cleanup before adding
    await _removeLayerIfExists("route-source", "route-layer");

    await style.addSource(
      GeoJsonSource(id: "route-source", data: json.encode(geoJsonData)),
    );
    await style.addLayer(
      LineLayer(
        id: "route-layer",
        sourceId: "route-source",
        lineColor: _getRouteColor(colorName).value,
        lineWidth: 5.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        lineOpacity: 0.8,
      ),
    );
  }

  Color _getRouteColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.blue;
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

  // =========================================================
  // FIX FOR USER LOCATION CRASH
  // =========================================================

  /// Draw a blue circle marker at the user's current location
  Future<void> drawUserLocationMarker({
    required double lat,
    required double lng,
  }) async {
    if (_map == null) return;

    final style = _map!.style;
    const sourceId = "user-location-source";
    const layerId = "user-location-layer";
    const pulseLayerId = "user-location-pulse-layer";

    // 1. SAFELY REMOVE ALL EXISTING LAYERS/SOURCES FIRST
    await clearUserLocationMarker();

    // Create GeoJSON point for user location
    final geoJson = {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "type": "Point",
        "coordinates": [lng, lat],
      },
    };

    // 2. Add Source
    await style.addSource(
      GeoJsonSource(id: sourceId, data: json.encode(geoJson)),
    );

    // 3. Add Layers (Outer pulse first, then inner dot)
    await style.addLayer(
      CircleLayer(
        id: pulseLayerId,
        sourceId: sourceId,
        circleRadius: 20.0,
        circleColor: Colors.blue.shade200.value,
        circleOpacity: 0.3,
        circleStrokeWidth: 0.0,
      ),
    );

    await style.addLayer(
      CircleLayer(
        id: layerId,
        sourceId: sourceId,
        circleRadius: 10.0,
        circleColor: Colors.blue.shade600.value,
        circleOpacity: 1.0,
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.value,
      ),
    );

    debugPrint("📍 User location marker drawn at: $lat, $lng");
  }

  /// Safely remove user location marker and all associated layers.
  /// FIXED: Removes layers first, then the source.
  Future<void> clearUserLocationMarker() async {
    if (_map == null) return;
    final style = _map!.style;
    const sourceId = "user-location-source";
    const layerId = "user-location-layer";
    const pulseLayerId = "user-location-pulse-layer";

    try {
      // 1. Remove Layers (Visuals)
      if (await style.styleLayerExists(pulseLayerId)) {
        await style.removeStyleLayer(pulseLayerId);
      }
      if (await style.styleLayerExists(layerId)) {
        await style.removeStyleLayer(layerId);
      }

      // 2. Remove Source (Data) - Only safe after layers are gone
      if (await style.styleSourceExists(sourceId)) {
        await style.removeStyleSource(sourceId);
      }
    } catch (e) {
      debugPrint("Error clearing user location: $e");
    }
  }
}
