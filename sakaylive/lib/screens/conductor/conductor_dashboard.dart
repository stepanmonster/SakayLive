// SECTION 1/2 — ConductorDashboard + Trip persistence + DB-powered bus dropdown
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ DB bus list + model
import 'package:sakaylive/models/vehicle_position.dart';
import 'package:sakaylive/services/bus_rtdb_service.dart';

enum BusStatus { green, yellow, red }

@immutable
class TripSession {
  final bool isActive;
  final DateTime? startedAt;
  final String? busId;

  const TripSession({
    required this.isActive,
    this.startedAt,
    this.busId,
  });

  Duration get duration {
    if (!isActive || startedAt == null) return Duration.zero;
    return DateTime.now().difference(startedAt!);
  }

  TripSession copyWith({
    bool? isActive,
    DateTime? startedAt,
    String? busId,
  }) {
    return TripSession(
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      busId: busId ?? this.busId,
    );
  }
}

/// Global controller:
/// - survives page navigation (in-memory notifier)
/// - survives app restart (SharedPreferences)
class TripStateController {
  TripStateController._();

  static final TripStateController instance = TripStateController._();

  // Exposed state for UI
  final ValueNotifier<TripSession> session =
      ValueNotifier(const TripSession(isActive: false));

  // Also persist status + lastUpdated for nicer continuity (optional but helpful)
  final ValueNotifier<BusStatus> status = ValueNotifier(BusStatus.green);
  final ValueNotifier<DateTime?> lastUpdated = ValueNotifier(null);

  static const _kTripActive = "trip_active";
  static const _kTripStartedAt = "trip_started_at";
  static const _kTripBusId = "trip_bus_id";

  static const _kStatusIndex = "bus_status_index";
  static const _kLastUpdatedAt = "bus_status_updated_at";

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();

    final active = prefs.getBool(_kTripActive) ?? false;
    final startedAtMs = prefs.getInt(_kTripStartedAt);
    final busId = prefs.getString(_kTripBusId);

    final statusIndex = prefs.getInt(_kStatusIndex);
    final lastUpdatedMs = prefs.getInt(_kLastUpdatedAt);

    session.value = TripSession(
      isActive: active,
      startedAt: startedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedAtMs),
      busId: busId,
    );

    if (statusIndex != null &&
        statusIndex >= 0 &&
        statusIndex < BusStatus.values.length) {
      status.value = BusStatus.values[statusIndex];
    }

    if (lastUpdatedMs != null) {
      lastUpdated.value = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs);
    }
  }

  Future<void> startTrip({required String busId}) async {
    final newSession = TripSession(
      isActive: true,
      startedAt: DateTime.now(),
      busId: busId,
    );
    session.value = newSession;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTripActive, true);
    await prefs.setInt(
      _kTripStartedAt,
      newSession.startedAt!.millisecondsSinceEpoch,
    );
    await prefs.setString(_kTripBusId, busId);
  }

  Future<void> endTrip() async {
    session.value = const TripSession(isActive: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTripActive, false);
    await prefs.remove(_kTripStartedAt);
    await prefs.remove(_kTripBusId);
  }

  Future<void> setBusStatus(BusStatus newStatus) async {
    status.value = newStatus;
    lastUpdated.value = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStatusIndex, newStatus.index);
    await prefs.setInt(
      _kLastUpdatedAt,
      lastUpdated.value!.millisecondsSinceEpoch,
    );
  }
}

class ConductorDashboard extends StatefulWidget {
  const ConductorDashboard({super.key});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard> {
  // ✅ RTDB service
  final BusRtdbService _busService = BusRtdbService();

  // ✅ Persist "last selected bus" even when trip is not active
  static const _kSelectedBusId = "selected_bus_id";

  // ✅ Selected bus is now the RTDB vehicle key (VehiclePosition.id)
  String? selectedBusId;

  // Clock tick + trip timer tick
  late DateTime _now;
  Timer? _clockTimer;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });

    _initPersistedState();
  }

  Future<void> _initPersistedState() async {
    await TripStateController.instance.init();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final trip = TripStateController.instance.session.value;

    // If trip was active, prefer the trip bus id; otherwise, remember last selection.
    selectedBusId = trip.busId ?? prefs.getString(_kSelectedBusId);

    setState(() => _loading = false);
  }

  Future<void> _saveSelectedBusId(String busId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedBusId, busId);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Color _colorForStatus(BusStatus s) {
    switch (s) {
      case BusStatus.green:
        return Colors.green;
      case BusStatus.yellow:
        return Colors.orange;
      case BusStatus.red:
        return Colors.red;
    }
  }

  String _labelForStatus(BusStatus s) {
    switch (s) {
      case BusStatus.green:
        return "Seats Available";
      case BusStatus.yellow:
        return "Standing Only";
      case BusStatus.red:
        return "Full";
    }
  }

  String _lastUpdateText(DateTime? lastUpdated) {
    if (lastUpdated == null) return "Not updated yet";
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 60) return "Updated just now";
    if (diff.inMinutes < 60) return "Updated ${diff.inMinutes} mins ago";
    return "Updated ${diff.inHours} hrs ago";
  }

  String _tripDurationText(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${h}h ${m}m";
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  Future<void> _toggleTrip(bool isActive) async {
    if (!isActive) {
      if (selectedBusId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please select a bus first."),
            duration: Duration(milliseconds: 900),
          ),
        );
        return;
      }
      await TripStateController.instance.startTrip(busId: selectedBusId!);
    } else {
      await TripStateController.instance.endTrip();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!isActive ? "Trip started." : "Trip ended."),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _setStatus(BusStatus newStatus, bool tripActive) async {
    if (!tripActive) return;

    await TripStateController.instance.setBusStatus(newStatus);

    // ✅ Also push occupancy to RTDB so passengers see it
    if (selectedBusId != null) {
      await _busService.setOccupancy(
        vehicleId: selectedBusId!,
        occupancy: newStatus.name, // "green" | "yellow" | "red"
      );
    }
  }

  String _playfulCaption(DateTime dt, BusStatus s) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    switch (s) {
      case BusStatus.green:
        return "It’s $h:$m — SEATS AVAILABLE";
      case BusStatus.yellow:
        return "It’s $h:$m — STANDING ONLY";
      case BusStatus.red:
        return "It’s $h:$m — BUSS FULL";
    }
  }

  @override
Widget build(BuildContext context) {
  if (_loading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return ValueListenableBuilder<TripSession>(
    valueListenable: TripStateController.instance.session,
    builder: (context, trip, _) {
      final tripActive = trip.isActive;
      final tripDuration = trip.duration;

      return ValueListenableBuilder<BusStatus>(
        valueListenable: TripStateController.instance.status,
        builder: (context, busStatus, __) {
          final ring = _colorForStatus(busStatus);

          return ValueListenableBuilder<DateTime?>(
            valueListenable: TripStateController.instance.lastUpdated,
            builder: (context, lastUpdated, ___) {
              final double bottomPadding = 12.0 - MediaQuery.of(context).padding.bottom * 0.1;
              return Scaffold(
                appBar: AppBar(
                  title: const Text("Conductor Panel"),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                body: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOP ROW: Start/End Trip + duration upper right
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _toggleTrip(tripActive),
                                  icon: Icon(
                                    tripActive
                                        ? Icons.stop_circle
                                        : Icons.play_circle_fill,
                                    size: 22,
                                  ),
                                  label: Text(
                                    tripActive ? "End Trip" : "Start Trip",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: tripActive
                                        ? Colors.black
                                        : Colors.indigoAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "TRIP",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.grey,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    Text(
                                      tripActive
                                          ? _tripDurationText(tripDuration)
                                          : "--:--",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: tripActive
                                            ? Colors.black
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Assigned bus (DB powered)
                          const Text(
                            "Assigned Bus",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          StreamBuilder<List<VehiclePosition>>(
                            stream: _busService.watchVehicles(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                      ConnectionState.waiting &&
                                  !snap.hasData) {
                                return const SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final vehicles = snap.data ?? [];

                              if (vehicles.isEmpty) {
                                return const Text(
                                  "No buses found in database.",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              }

                              final ids = vehicles.map((v) => v.id).toSet();

                              if (selectedBusId == null ||
                                  !ids.contains(selectedBusId)) {
                                selectedBusId = vehicles.first.id;
                                _saveSelectedBusId(selectedBusId!);
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedBusId,
                                items: vehicles.map((v) {
                                  final label =
                                      (v.plateNumber?.trim().isNotEmpty == true)
                                          ? v.plateNumber!
                                          : v.id;

                                  return DropdownMenuItem(
                                    value: v.id,
                                    child: Text(label),
                                  );
                                }).toList(),
                                onChanged: tripActive
                                    ? null
                                    : (busId) async {
                                        if (busId == null) return;
                                        setState(() => selectedBusId = busId);
                                        await _saveSelectedBusId(busId);
                                      },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 14),

                          // WATCH / STATUS DIAL
                          Center(
                            child: Opacity(
                              opacity: tripActive ? 1.0 : 0.6,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Current Status: ${_labelForStatus(busStatus)}",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: ring,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  SizedBox(
                                    width: 260,
                                    height: 260,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                ring.withOpacity(0.95),
                                                ring.withOpacity(0.55),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: ring.withOpacity(0.28),
                                                blurRadius: 22,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                        ),

                                        ClipOval(
                                          child: CustomPaint(
                                            size: const Size(260, 260),
                                            painter: _TickPainter(
                                              color: Colors.white
                                                  .withOpacity(0.92),
                                            ),
                                          ),
                                        ),

                                        Container(
                                          width: 205,
                                          height: 205,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.08),
                                                blurRadius: 10,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                        ),

                                        CustomPaint(
                                          size: const Size(205, 205),
                                          painter: _HandsPainter(
                                            now: _now,
                                            accent: ring,
                                          ),
                                        ),

                                        Container(
                                          width: 82,
                                          height: 82,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: ring.withOpacity(0.12),
                                            border: Border.all(
                                              color: ring.withOpacity(0.35),
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.directions_bus,
                                            size: 40,
                                            color: ring,
                                          ),
                                        ),
                                        // ✅ REMOVED Positioned - no more overlap!
                                      ],
                                    ),
                                  ),

                                  // ✅ NEW: Status label BELOW clock (no overlap)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 12,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ring.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: ring.withOpacity(0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      busStatus.name.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ring,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                  Text(
                                    _playfulCaption(_now, busStatus),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _lastUpdateText(lastUpdated),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom buttons
                          _bigStatusButton(
                            enabled: tripActive,
                            label: "Green — Seats Available",
                            color: Colors.green,
                            icon: Icons.event_seat,
                            onTap: () => _setStatus(
                              BusStatus.green,
                              tripActive,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _bigStatusButton(
                            enabled: tripActive,
                            label: "Yellow — Standing Only",
                            color: Colors.orange,
                            icon: Icons.directions_bus,
                            onTap: () => _setStatus(
                              BusStatus.yellow,
                              tripActive,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _bigStatusButton(
                            enabled: tripActive,
                            label: "Red — Full",
                            color: Colors.red,
                            icon: Icons.block,
                            onTap: () => _setStatus(
                              BusStatus.red,
                              tripActive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

  Widget _bigStatusButton({
    required bool enabled,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final Color bg = enabled ? color : Colors.grey.shade400;
    final Color fg = enabled ? Colors.white : Colors.white.withOpacity(0.95);

    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: enabled ? 6 : 0,
      minimumSize: const Size.fromHeight(78),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: style,
        onPressed: enabled ? onTap : null,
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// SECTION 2/2 — Painters (unchanged except kept compatible with Section 1)
class _TickPainter extends CustomPainter {
  final Color color;

  _TickPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final isHour = i % 5 == 0;
      final tickLen = isHour ? 14.0 : 7.0;
      paint.strokeWidth = isHour ? 3.0 : 2.0;

      final angle = (math.pi * 2) * (i / 60) - math.pi / 2;

      final p1 = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 12 - tickLen) * math.cos(angle),
        center.dy + (radius - 12 - tickLen) * math.sin(angle),
      );

      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HandsPainter extends CustomPainter {
  final DateTime now;
  final Color accent;

  _HandsPainter({required this.now, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final seconds = now.second.toDouble();
    final minutes = now.minute.toDouble() + seconds / 60.0;
    final hours = (now.hour % 12).toDouble() + minutes / 60.0;

    final secAngle = (math.pi * 2) * (seconds / 60.0) - math.pi / 2;
    final minAngle = (math.pi * 2) * (minutes / 60.0) - math.pi / 2;
    final hrAngle = (math.pi * 2) * (hours / 12.0) - math.pi / 2;

    final hourPaint = Paint()
      ..color = Colors.black.withOpacity(0.88)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    final hourEnd = Offset(
      center.dx + (radius * 0.45) * math.cos(hrAngle),
      center.dy + (radius * 0.45) * math.sin(hrAngle),
    );
    canvas.drawLine(center, hourEnd, hourPaint);

    final minutePaint = Paint()
      ..color = Colors.black.withOpacity(0.78)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final minEnd = Offset(
      center.dx + (radius * 0.62) * math.cos(minAngle),
      center.dy + (radius * 0.62) * math.sin(minAngle),
    );
    canvas.drawLine(center, minEnd, minutePaint);

    final secondPaint = Paint()
      ..color = accent
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final secEnd = Offset(
      center.dx + (radius * 0.72) * math.cos(secAngle),
      center.dy + (radius * 0.72) * math.sin(secAngle),
    );
    canvas.drawLine(center, secEnd, secondPaint);

    // Playful “bus hand” follows minutes
    final busAngle = (math.pi * 2) * ((minutes % 60) / 60.0) - math.pi / 2;
    final busNeedlePaint = Paint()
      ..color = accent.withOpacity(0.55)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final busNeedleEnd = Offset(
      center.dx + (radius * 0.78) * math.cos(busAngle),
      center.dy + (radius * 0.78) * math.sin(busAngle),
    );
    canvas.drawLine(center, busNeedleEnd, busNeedlePaint);

    final busTip = Offset(
      center.dx + (radius * 0.83) * math.cos(busAngle),
      center.dy + (radius * 0.83) * math.sin(busAngle),
    );

    canvas.drawCircle(busTip, 11, Paint()..color = Colors.white);

    final busPaint = Paint()..color = accent;
    final rect = Rect.fromCenter(center: busTip, width: 14, height: 9);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, busPaint);

    final wheelPaint = Paint()..color = accent.withOpacity(0.9);
    canvas.drawCircle(busTip.translate(-4, 6), 2.2, wheelPaint);
    canvas.drawCircle(busTip.translate(4, 6), 2.2, wheelPaint);

    canvas.drawCircle(center, 6, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _HandsPainter oldDelegate) =>
      oldDelegate.now.second != now.second || oldDelegate.accent != accent;
}
