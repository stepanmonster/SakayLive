// lib/screens/conductor/conductor_dashboard.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakaylive/viewmodels/conductor_view_model.dart';

/// Conductor Dashboard with real GPS tracking integration.
///
/// Features:
/// - Start/End trip with GPS broadcasting to Firebase
/// - Real-time occupancy status updates
/// - Trip statistics and duration
/// - Location indicator
/// - Trip history
class ConductorDashboard extends StatefulWidget {
  const ConductorDashboard({super.key});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard>
    with SingleTickerProviderStateMixin {
  // Clock timer for live updates
  late DateTime _now;
  Timer? _clockTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConductorViewModel()..initialize(),
      child: Consumer<ConductorViewModel>(
        builder: (context, vm, _) {
          if (!vm.isInitialized && vm.isLoading) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Conductor Panel'),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              body: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing GPS...'),
                  ],
                ),
              ),
            );
          }

          return _buildDashboard(context, vm);
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, ConductorViewModel vm) {
    final statusColor = vm.currentStatus.color;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          vm.isTripActive ? 'Trip Active' : 'Conductor Panel',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: vm.isTripActive ? statusColor : Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (vm.isTripActive) {
              _showEndTripConfirmation(context, vm);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (vm.isTripActive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.2 + _pulseController.value * 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(
                                _pulseController.value,
                              ),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (vm.errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: vm.clearError,
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                ),

              // Trip Control Button & Timer
              _buildTripControl(context, vm, isSmallScreen),
              const SizedBox(height: 16),

              // Bus Selection (only when not on trip)
              if (!vm.isTripActive) ...[
                _buildBusSelector(vm),
                const SizedBox(height: 24),
              ],

              // Location & Stats Card (when trip active)
              if (vm.isTripActive) ...[
                _buildLocationCard(vm, isSmallScreen),
                const SizedBox(height: 16),
              ],

              // Status Dial
              _buildStatusDial(vm, statusColor, isSmallScreen),
              const SizedBox(height: 24),

              // Status Buttons
              if (vm.isTripActive) ...[
                _buildStatusButtons(vm, isSmallScreen),
                const SizedBox(height: 24),

                // Passenger Counter (Optional)
                _buildPassengerCounter(vm, isSmallScreen),
              ],

              // Trip History (when not active)
              if (!vm.isTripActive && vm.tripHistory.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildTripHistory(vm, isSmallScreen),
              ],

              // Bottom padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripControl(
    BuildContext context,
    ConductorViewModel vm,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: vm.isLoading
                ? null
                : () async {
                    if (vm.isTripActive) {
                      _showEndTripConfirmation(context, vm);
                    } else {
                      final success = await vm.startTrip();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Trip started! GPS tracking active.',
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
            icon: vm.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    vm.isTripActive
                        ? Icons.stop_circle
                        : Icons.play_circle_fill,
                    size: 22,
                  ),
            label: Text(
              vm.isLoading
                  ? 'Starting...'
                  : (vm.isTripActive ? 'End Trip' : 'Start Trip'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: vm.isTripActive
                  ? Colors.black
                  : Colors.indigoAccent,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: vm.isTripActive
                ? vm.currentStatus.color.withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: vm.isTripActive
                  ? vm.currentStatus.color.withOpacity(0.3)
                  : Colors.black12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TRIP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                vm.isTripActive ? vm.tripDurationText : '--:--',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: vm.isTripActive ? vm.currentStatus.color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusSelector(ConductorViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Bus',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<BusAssignment>(
          value: vm.selectedBus,
          items: vm.availableBuses.map((bus) {
            return DropdownMenuItem(
              value: bus,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${bus.busId} (${bus.plateNumber})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Route ${bus.routeId}: ${bus.routeName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (bus) {
            if (bus != null) vm.selectBus(bus);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon: const Icon(Icons.directions_bus),
          ),
          isExpanded: true,
          selectedItemBuilder: (context) {
            return vm.availableBuses.map((bus) {
              return Text('${bus.busId} - Route ${bus.routeId}');
            }).toList();
          },
        ),
      ],
    );
  }

  Widget _buildLocationCard(ConductorViewModel vm, bool isSmallScreen) {
    final pos = vm.currentPosition;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            vm.currentStatus.color.withOpacity(0.1),
            vm.currentStatus.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vm.currentStatus.color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: vm.currentStatus.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pos != null
                      ? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
                      : 'Acquiring GPS...',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: vm.forceLocationUpdate,
                tooltip: 'Force Update',
                color: vm.currentStatus.color,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.route,
                label: 'Distance',
                value: vm.tripDistanceText,
                color: Colors.blue,
              ),
              _buildStatItem(
                icon: Icons.update,
                label: 'Updates',
                value: '${vm.updateCount}',
                color: Colors.purple,
              ),
              _buildStatItem(
                icon: Icons.schedule,
                label: 'Last Sync',
                value: vm.lastUpdateText,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDial(
    ConductorViewModel vm,
    Color statusColor,
    bool isSmallScreen,
  ) {
    return Center(
      child: Opacity(
        opacity: vm.isTripActive ? 1.0 : 0.5,
        child: Column(
          children: [
            Text(
              'Status: ${vm.currentStatus.label}',
              style: TextStyle(
                fontSize: isSmallScreen ? 17 : 19,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: isSmallScreen ? 200 : 260,
              height: isSmallScreen ? 200 : 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring with gradient
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.95),
                          statusColor.withOpacity(0.55),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.28),
                          blurRadius: 22,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                  // Tick marks
                  CustomPaint(
                    size: Size(
                      isSmallScreen ? 200 : 260,
                      isSmallScreen ? 200 : 260,
                    ),
                    painter: _TickPainter(
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  // Inner white circle
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
                  // Clock hands
                  CustomPaint(
                    size: Size(
                      isSmallScreen ? 160 : 205,
                      isSmallScreen ? 160 : 205,
                    ),
                    painter: _HandsPainter(now: _now, accent: statusColor),
                  ),
                  // Center bus icon
                  Container(
                    width: isSmallScreen ? 65 : 82,
                    height: isSmallScreen ? 65 : 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withOpacity(0.12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.35),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      size: isSmallScreen ? 32 : 40,
                      color: statusColor,
                    ),
                  ),
                  // Status badge at bottom
                  Positioned(
                    bottom: isSmallScreen ? 10 : 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withOpacity(0.35),
                        ),
                      ),
                      child: Text(
                        vm.currentStatus.name.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
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
              _playfulCaption(vm),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
            if (vm.isTripActive) ...[
              const SizedBox(height: 4),
              Text(
                vm.lastUpdateText,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: isSmallScreen ? 12 : 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _playfulCaption(ConductorViewModel vm) {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');

    switch (vm.currentStatus) {
      case OccupancyStatus.green:
        return "It's $h:$m — SEATS AVAILABLE";
      case OccupancyStatus.yellow:
        return "It's $h:$m — STANDING ONLY";
      case OccupancyStatus.red:
        return "It's $h:$m — FULL HOUSE";
    }
  }

  Widget _buildStatusButtons(ConductorViewModel vm, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Status:',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _statusButton(
          vm: vm,
          status: OccupancyStatus.green,
          label: 'Green – Seats Available',
          isSmallScreen: isSmallScreen,
        ),
        const SizedBox(height: 10),
        _statusButton(
          vm: vm,
          status: OccupancyStatus.yellow,
          label: 'Yellow – Standing Only',
          isSmallScreen: isSmallScreen,
        ),
        const SizedBox(height: 10),
        _statusButton(
          vm: vm,
          status: OccupancyStatus.red,
          label: 'Red – Full',
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }

  Widget _statusButton({
    required ConductorViewModel vm,
    required OccupancyStatus status,
    required String label,
    required bool isSmallScreen,
  }) {
    final isSelected = vm.currentStatus == status;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: vm.isTripActive ? () => vm.setOccupancyStatus(status) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: vm.isTripActive
              ? status.color
              : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: vm.isTripActive && isSelected ? 6 : 2,
          minimumSize: Size.fromHeight(isSmallScreen ? 55 : 65),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 16,
            vertical: isSmallScreen ? 12 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
            side: isSelected
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Icon(status.icon, size: isSmallScreen ? 22 : 26),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (isSelected) const Icon(Icons.check_circle, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerCounter(ConductorViewModel vm, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Passenger Count (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: vm.decrementPassengers,
                icon: const Icon(Icons.remove_circle, size: 36),
                color: Colors.red,
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    '${vm.passengerCount}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: vm.currentStatus.color,
                    ),
                  ),
                  Text(
                    'of ${vm.selectedBus?.capacity ?? 30}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: vm.incrementPassengers,
                icon: const Icon(Icons.add_circle, size: 36),
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistory(ConductorViewModel vm, bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history, size: 20),
            SizedBox(width: 8),
            Text(
              'Recent Trips',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...vm.tripHistory.take(5).map((trip) {
          final startTime = DateTime.fromMillisecondsSinceEpoch(
            trip['start_time'] ?? 0,
          );
          final durationSec = trip['duration_seconds'] ?? 0;
          final distance = (trip['total_distance_m'] ?? 0) / 1000;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 20,
                    color: Colors.indigo.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['bus_id'] ?? 'Unknown Bus',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${startTime.day}/${startTime.month} at ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(durationSec / 60).round()} min',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${distance.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showEndTripConfirmation(BuildContext context, ConductorViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to end this trip?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _tripSummaryRow('Duration', vm.tripDurationText),
                  _tripSummaryRow('Distance', vm.tripDistanceText),
                  _tripSummaryRow('Updates', '${vm.updateCount}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final distanceText = vm.tripDistanceText;
              await vm.endTrip();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Text('Trip ended. Distance: $distanceText'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'End Trip',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Clock tick marks painter
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

// Clock hands painter
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

    // Hour hand
    final hourPaint = Paint()
      ..color = Colors.black.withOpacity(0.88)
      ..strokeWidth = size.width * 0.027
      ..strokeCap = StrokeCap.round;

    final hourEnd = Offset(
      center.dx + (radius * 0.45) * math.cos(hrAngle),
      center.dy + (radius * 0.45) * math.sin(hrAngle),
    );
    canvas.drawLine(center, hourEnd, hourPaint);

    // Minute hand
    final minutePaint = Paint()
      ..color = Colors.black.withOpacity(0.78)
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;

    final minEnd = Offset(
      center.dx + (radius * 0.62) * math.cos(minAngle),
      center.dy + (radius * 0.62) * math.sin(minAngle),
    );
    canvas.drawLine(center, minEnd, minutePaint);

    // Second hand
    final secondPaint = Paint()
      ..color = accent
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round;

    final secEnd = Offset(
      center.dx + (radius * 0.72) * math.cos(secAngle),
      center.dy + (radius * 0.72) * math.sin(secAngle),
    );
    canvas.drawLine(center, secEnd, secondPaint);

    // Center dot
    canvas.drawCircle(
      center,
      size.width * 0.029,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(center, size.width * 0.02, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _HandsPainter oldDelegate) =>
      oldDelegate.now.second != now.second || oldDelegate.accent != accent;
}
