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
        return "It's $h:$m — SEATS AVAILABLE";
      case BusStatus.yellow:
        return "It's $h:$m — STANDING ONLY";
      case BusStatus.red:
        return "It's $h:$m — FULL HOUSE";
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = statusColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conductor Panel"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 16),

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

                const SizedBox(height: 24),

                // Current Status Text
                Center(
                  child: Opacity(
                    opacity: _tripStarted ? 1.0 : 0.6,
                    child: Column(
                      children: [
                        Text(
                          "Current Status: $statusLabel",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 17 : 19,
                            fontWeight: FontWeight.w900,
                            color: ring,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // WATCH / STATUS DIAL
                Center(
                  child: Opacity(
                    opacity: _tripStarted ? 1.0 : 0.6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: isSmallScreen ? 200 : 260,
                          height: isSmallScreen ? 200 : 260,
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
                                size: Size(isSmallScreen ? 200 : 260, isSmallScreen ? 200 : 260),
                                painter: _TickPainter(
                                  color: Colors.white.withOpacity(0.92),
                                ),
                              ),

                              Container(
                                width: isSmallScreen ? 160 : 205,
                                height: isSmallScreen ? 160 : 205,
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
                                size: Size(isSmallScreen ? 160 : 205, isSmallScreen ? 160 : 205),
                                painter: _HandsPainter(
                                  now: _now,
                                  accent: ring,
                                ),
                              ),

                              Container(
                                width: isSmallScreen ? 65 : 82,
                                height: isSmallScreen ? 65 : 82,
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
                                  size: isSmallScreen ? 32 : 40,
                                  color: ring,
                                ),
                              ),

                              Positioned(
                                bottom: isSmallScreen ? 10 : 16,
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
                                      fontSize: isSmallScreen ? 10 : 12,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          _playfulCaption(_now),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w700,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastUpdateText,
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Status buttons
                Text(
                  "Update Status:",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _statusButton(
                  enabled: _tripStarted,
                  label: "Green – Seats Available",
                  color: Colors.green,
                  icon: Icons.event_seat,
                  onTap: () => setStatus(BusStatus.green),
                  isSmallScreen: isSmallScreen,
                ),
                const SizedBox(height: 10),
                _statusButton(
                  enabled: _tripStarted,
                  label: "Yellow – Standing Only",
                  color: Colors.orange,
                  icon: Icons.directions_bus,
                  onTap: () => setStatus(BusStatus.yellow),
                  isSmallScreen: isSmallScreen,
                ),
                const SizedBox(height: 10),
                _statusButton(
                  enabled: _tripStarted,
                  label: "Red – Full",
                  color: Colors.red,
                  icon: Icons.block,
                  onTap: () => setStatus(BusStatus.red),
                  isSmallScreen: isSmallScreen,
                ),
                
                // Extra bottom padding for scrolling
                SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusButton({
    required bool enabled,
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final Color bg = enabled ? color : Colors.grey.shade400;
    final Color fg = enabled ? Colors.white : Colors.white.withOpacity(0.95);

    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: enabled ? 4 : 0,
      minimumSize: Size.fromHeight(isSmallScreen ? 55 : 65),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 12 : 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      textStyle: TextStyle(
        fontSize: isSmallScreen ? 15 : 17,
        fontWeight: FontWeight.w700,
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: style,
        onPressed: enabled ? onTap : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: isSmallScreen ? 22 : 26),
            SizedBox(width: isSmallScreen ? 12 : 16),
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
      final tickLen = isHour ? size.width * 0.05 : size.width * 0.025;
      paint.strokeWidth = isHour ? 2.5 : 1.5;

      final angle = (math.pi * 2) * (i / 60) - math.pi / 2;

      final p1 = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 10 - tickLen) * math.cos(angle),
        center.dy + (radius - 10 - tickLen) * math.sin(angle),
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
      ..strokeWidth = size.width * 0.027 // Responsive stroke width
      ..strokeCap = StrokeCap.round;

    final hourEnd = Offset(
      center.dx + (radius * 0.45) * math.cos(hrAngle),
      center.dy + (radius * 0.45) * math.sin(hrAngle),
    );
    canvas.drawLine(center, hourEnd, hourPaint);

    final minutePaint = Paint()
      ..color = Colors.black.withOpacity(0.78)
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;

    final minEnd = Offset(
      center.dx + (radius * 0.62) * math.cos(minAngle),
      center.dy + (radius * 0.62) * math.sin(minAngle),
    );
    canvas.drawLine(center, minEnd, minutePaint);

    final secondPaint = Paint()
      ..color = accent
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round;

    final secEnd = Offset(
      center.dx + (radius * 0.72) * math.cos(secAngle),
      center.dy + (radius * 0.72) * math.sin(secAngle),
    );
    canvas.drawLine(center, secEnd, secondPaint);

    // Playful "bus hand" follows minutes
    final busAngle = (math.pi * 2) * ((minutes % 60) / 60.0) - math.pi / 2;
    final busNeedlePaint = Paint()
      ..color = accent.withOpacity(0.55)
      ..strokeWidth = size.width * 0.03
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

    canvas.drawCircle(busTip, size.width * 0.054, Paint()..color = Colors.white);
    final busPaint = Paint()..color = accent;
    final rect = Rect.fromCenter(
      center: busTip,
      width: size.width * 0.068,
      height: size.width * 0.044,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.015),
    );
    canvas.drawRRect(rrect, busPaint);

    final wheelPaint = Paint()..color = accent.withOpacity(0.9);
    final wheelRadius = size.width * 0.011;
    canvas.drawCircle(busTip.translate(-size.width * 0.019, size.width * 0.029), 
        wheelRadius, wheelPaint);
    canvas.drawCircle(busTip.translate(size.width * 0.019, size.width * 0.029), 
        wheelRadius, wheelPaint);

    canvas.drawCircle(center, size.width * 0.029, Paint()..color = Colors.white);
    canvas.drawCircle(center, size.width * 0.02, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _HandsPainter oldDelegate) =>
      oldDelegate.now.second != now.second || oldDelegate.accent != accent;
}