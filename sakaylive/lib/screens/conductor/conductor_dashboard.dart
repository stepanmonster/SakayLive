import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BusStatus { green, yellow, red }

class ConductorDashboard extends StatefulWidget {
  const ConductorDashboard({super.key});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard> {
  final List<String> buses = ["E-Bus 01", "E-Bus 02", "E-Bus 03"];
  String selectedBus = "E-Bus 01";

  BusStatus status = BusStatus.green;
  DateTime? lastUpdated;

  // Trip toggle (future: will enable GPS sharing)
  bool _tripStarted = false;
  DateTime? _tripStartTime;

  // Clock tick + trip timer tick
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Color get statusColor {
    switch (status) {
      case BusStatus.green:
        return Colors.green;
      case BusStatus.yellow:
        return Colors.orange;
      case BusStatus.red:
        return Colors.red;
    }
  }

  String get statusLabel {
    switch (status) {
      case BusStatus.green:
        return "Seats Available";
      case BusStatus.yellow:
        return "Standing Only";
      case BusStatus.red:
        return "Full";
    }
  }

  String get lastUpdateText {
    if (lastUpdated == null) return "Not updated yet";
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inSeconds < 60) return "Updated just now";
    if (diff.inMinutes < 60) return "Updated ${diff.inMinutes} mins ago";
    return "Updated ${diff.inHours} hrs ago";
  }

  Duration get _tripDuration {
    if (!_tripStarted || _tripStartTime == null) return Duration.zero;
    return DateTime.now().difference(_tripStartTime!);
  }

  String get _tripDurationText {
    final d = _tripDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${h}h ${m}m";
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void setStatus(BusStatus newStatus) {
    if (!_tripStarted) return; // safety
    setState(() {
      status = newStatus;
      lastUpdated = DateTime.now();
    });

    // TODO: Send to backend
  }

  void _toggleTrip() {
    setState(() {
      _tripStarted = !_tripStarted;

      if (_tripStarted) {
        _tripStartTime = DateTime.now();
        // Optional: clear lastUpdated when starting
        // lastUpdated = null;
      } else {
        _tripStartTime = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tripStarted ? "Trip started." : "Trip ended."),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  String _playfulCaption(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    switch (status) {
      case BusStatus.green:
        return "It’s $h:$m — SEATS AVAILABLE";
      case BusStatus.yellow:
        return "It’s $h:$m — STANDING ONLY";
      case BusStatus.red:
        return "It’s $h:$m — FULL HOUSE";
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = statusColor;

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP ROW: Start/End Trip + duration on upper right
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleTrip,
                      icon: Icon(
                        _tripStarted
                            ? Icons.stop_circle
                            : Icons.play_circle_fill,
                        size: 22,
                      ),
                      label: Text(
                        _tripStarted ? "End Trip" : "Start Trip",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _tripStarted ? Colors.black : Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          _tripStarted ? _tripDurationText : "--:--",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _tripStarted ? Colors.black : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Assigned bus
              const Text(
                "Assigned Bus",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedBus,
                items: buses
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => selectedBus = v ?? selectedBus),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),

              const SizedBox(height: 14),

              // WATCH / STATUS DIAL
              Expanded(
                child: Center(
                  child: Opacity(
                    opacity: _tripStarted ? 1.0 : 0.6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Current Status: $statusLabel",
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

                              CustomPaint(
                                size: const Size(260, 260),
                                painter: _TickPainter(
                                  color: Colors.white.withOpacity(0.92),
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
                                      color: Colors.black.withOpacity(0.08),
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

                              Positioned(
                                bottom: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ring.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: ring.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    status.name.toUpperCase(),
                                    style: TextStyle(
                                      color: ring,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),
                        Text(
                          _playfulCaption(_now),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lastUpdateText,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom buttons (disabled when trip not started)
              _bigStatusButton(
                enabled: _tripStarted,
                label: "Green — Seats Available",
                color: Colors.green,
                icon: Icons.event_seat,
                onTap: () => setStatus(BusStatus.green),
              ),
              const SizedBox(height: 12),
              _bigStatusButton(
                enabled: _tripStarted,
                label: "Yellow — Standing Only",
                color: Colors.orange,
                icon: Icons.directions_bus,
                onTap: () => setStatus(BusStatus.yellow),
              ),
              const SizedBox(height: 12),
              _bigStatusButton(
                enabled: _tripStarted,
                label: "Red — Full",
                color: Colors.red,
                icon: Icons.block,
                onTap: () => setStatus(BusStatus.red),
              ),
            ],
          ),
        ),
      ),
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
    final busAngle =
        (math.pi * 2) * ((minutes % 60) / 60.0) - math.pi / 2;
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
