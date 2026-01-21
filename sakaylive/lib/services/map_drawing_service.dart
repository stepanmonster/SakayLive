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
  final String? vehicleId; // For tap interaction
  final String occupancyLabel; // Accessibility: 🚍, 🚍⚠️, or 🚍⛔

  BusMarkerData({
    required this.coordinates,
    required this.etaText,
    required this.routeName,
    required this.routeColor,
    required this.heading,
    this.vehicleId,
    this.occupancyLabel = '🚍',
  });
}

/// Service responsible for drawing routes and markers on the Mapbox map.
class MapDrawingService {
  MapboxMap? _map;
  PointAnnotationManager? _annotationManager;
  PointAnnotationManager? _busAnnotationManager;

  // Cache of registered bus icon colors to avoid re-generating the same icons
  final Set<int> _registeredBusColors = {};

  // Callback for bus marker taps
  Function(String vehicleId, double lat, double lng)? onBusMarkerTapped;

  // Store bus marker annotations for tap detection
  final Map<String, BusMarkerData> _busMarkerLookup = {};

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
  Future<Uint8List> _generateBusIcon(Color color, String routeText) async {
    const double size = 32; // Significantly smaller icon size

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Draw Shadow
    final shadowPath = Path()..addOval(Rect.fromLTWH(1, 2, size - 2, size - 2));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.3), 3, true);

    // 2. Draw White Background Circle
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), (size / 2) - 1, bgPaint);

    // 3. Draw Colored Border (Ring)
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2; // Thinner border
    canvas.drawCircle(Offset(size / 2, size / 2), (size / 2) - 2, borderPaint);

    // 4. Draw Bus Icon (Centered)
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_bus_rounded.codePoint),
        style: TextStyle(
          fontSize: 20, // Smaller icon text
          fontFamily: Icons.directions_bus_rounded.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    // ACCESSIBILITY: Secondary Indicator
    if (color.value == 0xFFEF4444) {
      // Red = Full
      _drawBadge(canvas, '⛔', size, size);
    } else if (color.value == 0xFFF59E0B) {
      // Yellow = Standing
      _drawBadge(canvas, '⚠️', size, size);
    }

    // Convert to Image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawBadge(Canvas canvas, String icon, double w, double h) {
    final painter = TextPainter(
      text: TextSpan(
        text: icon,
        style: const TextStyle(fontSize: 10),
      ), // Smaller badge
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    // Position at bottom right
    painter.paint(canvas, Offset(w - painter.width, h - painter.height));
  }

  /// Queue a bus marker to be added
  void queueBusMarker({
    required List<double> coordinates,
    required String etaText,
    required String routeName,
    required Color routeColor,
    double heading = 0.0,
    String? vehicleId,
    String occupancyLabel = '🚍',
  }) {
    _pendingBusMarkers.add(
      BusMarkerData(
        coordinates: coordinates,
        etaText: etaText,
        routeName: routeName,
        routeColor: routeColor,
        heading: heading,
        vehicleId: vehicleId,
        occupancyLabel: occupancyLabel,
      ),
    );
  }

  /// Flush all queued bus markers to the map
  /// Uses a clean visual style: colored circle with bus icon
  /// Text labels (ETA) are hidden for a cleaner map - info shown on tap instead
  Future<void> flushBusMarkers() async {
    debugPrint(
      '🚌 flushBusMarkers called: ${_pendingBusMarkers.length} markers, manager=${_busAnnotationManager != null}',
    );

    if (_busAnnotationManager == null) {
      debugPrint('❌ Bus annotation manager is null!');
      return;
    }

    if (_pendingBusMarkers.isEmpty) {
      debugPrint('⚠️ No pending bus markers to draw');
      return;
    }

    // Clear the lookup map for fresh data
    _busMarkerLookup.clear();

    if (_map != null) {
      // 1. Pre-register all necessary colored icons
      for (final marker in _pendingBusMarkers) {
        final colorValue = marker.routeColor.value;
        // Unique ID per color AND route (since route text is baked in)
        final iconId = 'bus-icon-$colorValue-${marker.routeName}';
        final uniqueKey = iconId.hashCode;

        if (!_registeredBusColors.contains(uniqueKey)) {
          try {
            final iconBytes = await _generateBusIcon(
              marker.routeColor,
              marker.routeName,
            );

            await _map!.style.addStyleImage(
              iconId,
              1.0, // Scale
              MbxImage(width: 32, height: 32, data: iconBytes),
              false, // sdf
              [], // stretchX
              [], // stretchY
              null, // content
            );

            _registeredBusColors.add(uniqueKey);
            debugPrint("🎨 Registered new bus icon: $iconId");
          } catch (e) {
            debugPrint("❌ Failed to register bus icon for $iconId: $e");
          }
        }
      }
    }

    final options = _pendingBusMarkers.map((marker) {
      final colorValue = marker.routeColor.value;
      final iconId = 'bus-icon-$colorValue-${marker.routeName}';

      // Store marker data for tap lookup
      if (marker.vehicleId != null) {
        _busMarkerLookup[marker.vehicleId!] = marker;
      }

      return PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(marker.coordinates[0], marker.coordinates[1]),
        ),

        // ICON CONFIGURATION
        iconImage: iconId,
        iconSize: 1.0,
        iconOpacity: 1.0,
        iconAnchor: IconAnchor.CENTER, // Center for circular icon
        iconOffset: [0, 0],
        iconRotate: marker.heading,

        // TEXT LABEL: ETA Visual (Clean setup)
        // Only show ETA text if needed, floating above
        textField: marker.etaText,
        textSize: 11.0,
        textColor: Colors.black.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 3.0,
        // Position above the circle
        textOffset: [0, -3.0],
        textAnchor: TextAnchor.BOTTOM,
      );
    }).toList();

    await _busAnnotationManager!.createMulti(options);
    _pendingBusMarkers.clear();
  }

  /// Clear all bus markers
  Future<void> clearBusMarkers() async {
    _pendingBusMarkers.clear();
    _busMarkerLookup.clear();
    await _busAnnotationManager?.deleteAll();
    // note: we do not clear _registeredBusColors as style images persist
  }

  /// Get bus marker data by vehicle ID (for tap handling)
  BusMarkerData? getBusMarkerData(String vehicleId) {
    return _busMarkerLookup[vehicleId];
  }

  /// Handle potential tap on bus marker
  /// Call this with coordinates from a map tap event
  /// Returns the vehicleId if a bus was tapped, null otherwise
  String? checkBusTap(double tapLat, double tapLng, {double tolerance = 50.0}) {
    for (final entry in _busMarkerLookup.entries) {
      final marker = entry.value;
      final markerLat = marker.coordinates[1];
      final markerLng = marker.coordinates[0];

      // Simple distance check (in meters, roughly)
      final latDiff = (tapLat - markerLat).abs() * 111000;
      final lngDiff =
          (tapLng - markerLng).abs() * 111000 * cos(tapLat * pi / 180);
      final distance = sqrt(latDiff * latDiff + lngDiff * lngDiff);

      if (distance <= tolerance) {
        return entry.key;
      }
    }
    return null;
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

  /// Fly camera to show both user, destination, and optionally a bus.
  void fitCameraToTrip({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    List<double>? extraPoint, // [lng, lat]
  }) {
    // Calculate bounds manually since CameraForCoordinates calls can be complex
    double minLat = min(userLat, destLat);
    double maxLat = max(userLat, destLat);
    double minLng = min(userLng, destLng);
    double maxLng = max(userLng, destLng);

    if (extraPoint != null) {
      minLat = min(minLat, extraPoint[1]);
      maxLat = max(maxLat, extraPoint[1]);
      minLng = min(minLng, extraPoint[0]);
      maxLng = max(maxLng, extraPoint[0]);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Dynamic zoom estimation
    final delta = max(maxLat - minLat, maxLng - minLng);
    double zoom = 12.0;
    if (delta < 0.02)
      zoom = 14.5;
    else if (delta < 0.05)
      zoom = 13.5;
    else if (delta < 0.1)
      zoom = 12.5;
    else
      zoom = 11.0;

    // Shift center slightly down to account for bottom sheet
    final shiftedLat = centerLat; // Can adjust if needed

    _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, shiftedLat)),
        zoom: zoom,
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
