import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:sakaylive/models/vehicle_position.dart';

class BusRtdbService {
  BusRtdbService({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _vehiclesRef => _db.ref('vehicles');

  /// ✅ Main: Watch all buses under /vehicles in realtime
  Stream<List<VehiclePosition>> watchVehicles() {
    return _vehiclesRef.onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <VehiclePosition>[];

      if (value is! Map<dynamic, dynamic>) return <VehiclePosition>[];

      final vehicles = <VehiclePosition>[];

      value.forEach((key, raw) {
        if (raw is Map<dynamic, dynamic>) {
          try {
            vehicles.add(VehiclePosition.fromMap(key.toString(), raw));
          } catch (_) {
            // ignore malformed records
          }
        }
      });

      // Nice dropdown ordering: plate_number first, fallback to id
      vehicles.sort((a, b) {
        final ap = (a.plateNumber ?? a.id).toLowerCase();
        final bp = (b.plateNumber ?? b.id).toLowerCase();
        return ap.compareTo(bp);
      });

      return vehicles;
    });
  }

  /// ✅ Optional: read a single bus once
  Future<VehiclePosition?> getVehicle(String vehicleId) async {
    final snap = await _vehiclesRef.child(vehicleId).get();
    if (!snap.exists || snap.value == null) return null;

    final data = snap.value;
    if (data is! Map<dynamic, dynamic>) return null;

    return VehiclePosition.fromMap(vehicleId, data);
  }

  /// ✅ Conductor sets occupancy (green/yellow/red)
  Future<void> setOccupancy({
    required String vehicleId,
    required String occupancy, // "green" | "yellow" | "red"
    int? passengerCount,
  }) async {
    final update = <String, Object?>{
      'occupancy': occupancy.toLowerCase(),
      // Use client timestamp so it's always an int (your model expects int)
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (passengerCount != null) {
      update['passenger_count'] = passengerCount;
    }

    await _vehiclesRef.child(vehicleId).update(update);
  }

  /// ✅ (For later) update conductor GPS position for a bus
  Future<void> updatePosition({
    required String vehicleId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
    double? accuracy,
    String? conductorId,
    String? tripId,
    bool isRealConductor = true,
    int? directionIndex,
  }) async {
    final update = <String, Object?>{
      'lat': lat,
      'lng': lng,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'is_real_conductor': isRealConductor,
    };

    if (heading != null) update['heading'] = heading;
    if (speed != null) update['speed'] = speed;
    if (accuracy != null) update['accuracy'] = accuracy;
    if (conductorId != null) update['conductor_id'] = conductorId;
    if (tripId != null) update['trip_id'] = tripId;
    if (directionIndex != null) update['direction_index'] = directionIndex;

    await _vehiclesRef.child(vehicleId).update(update);
  }
}
