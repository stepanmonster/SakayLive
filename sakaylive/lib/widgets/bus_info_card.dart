// lib/widgets/bus_info_card.dart
import 'package:flutter/material.dart';
import 'package:sakaylive/models/vehicle_position.dart';

/// A card widget that displays detailed information about a selected bus.
///
/// Shows:
/// - Bus ID and route
/// - Occupancy status with color indicator
/// - ETA and distance
/// - Conductor info (if available)
/// - Real-time vs simulated indicator
class BusInfoCard extends StatelessWidget {
  final TrackedVehicle vehicle;
  final VoidCallback? onDismiss;
  final VoidCallback? onTrack;

  const BusInfoCard({
    super.key,
    required this.vehicle,
    this.onDismiss,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final occupancyColor = _getOccupancyColor(vehicle.position.occupancy);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with occupancy color
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: occupancyColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: occupancyColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                // Bus icon with occupancy color
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: occupancyColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: occupancyColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Bus info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            vehicle.position.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (vehicle.isRealConductor)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: 12,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicle.routeName,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onDismiss,
                    color: Colors.grey.shade600,
                  ),
              ],
            ),
          ),

          // Status and ETA row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Occupancy status
                Expanded(
                  child: _buildInfoItem(
                    icon: _getOccupancyIcon(vehicle.position.occupancy),
                    iconColor: occupancyColor,
                    label: 'Status',
                    value: vehicle.position.occupancyText,
                    valueColor: occupancyColor,
                  ),
                ),
                // ETA
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.schedule,
                    iconColor: Colors.blue,
                    label: 'ETA',
                    value: vehicle.etaText,
                    valueColor: _getEtaColor(vehicle.etaMinutes),
                  ),
                ),
                // Distance
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.straighten,
                    iconColor: Colors.purple,
                    label: 'Distance',
                    value: vehicle.distanceText,
                    valueColor: Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          // Additional info (if available)
          if (vehicle.position.driverName != null ||
              vehicle.position.plateNumber != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (vehicle.position.driverName != null) ...[
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      vehicle.position.driverName!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (vehicle.position.plateNumber != null) ...[
                    Icon(
                      Icons.confirmation_number,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      vehicle.position.plateNumber!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    vehicle.position.lastSeenText,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Direction info
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.navigation,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          vehicle.direction,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Track button
                if (onTrack != null)
                  ElevatedButton.icon(
                    onPressed: onTrack,
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text('Track'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: occupancyColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Color _getOccupancyColor(String occupancy) {
    switch (occupancy) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'yellow':
        return const Color(0xFFF59E0B);
      case 'green':
      default:
        return const Color(0xFF22C55E);
    }
  }

  IconData _getOccupancyIcon(String occupancy) {
    switch (occupancy) {
      case 'red':
        return Icons.block;
      case 'yellow':
        return Icons.airline_seat_legroom_normal;
      case 'green':
      default:
        return Icons.event_seat;
    }
  }

  Color _getEtaColor(int? eta) {
    if (eta == null) return Colors.grey;
    if (eta <= 2) return const Color(0xFFEF4444); // Arriving soon - red/urgent
    if (eta <= 5) return const Color(0xFFF59E0B); // Soon - amber
    return const Color(0xFF3B82F6); // Normal - blue
  }
}

/// A compact bus info chip for inline display
class BusInfoChip extends StatelessWidget {
  final TrackedVehicle vehicle;
  final VoidCallback? onTap;

  const BusInfoChip({super.key, required this.vehicle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final occupancyColor = _getOccupancyColor(vehicle.position.occupancy);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: occupancyColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: occupancyColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              vehicle.position.id,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              vehicle.etaText,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (vehicle.isRealConductor) ...[
              const SizedBox(width: 6),
              Icon(Icons.verified, size: 14, color: Colors.green.shade600),
            ],
          ],
        ),
      ),
    );
  }

  Color _getOccupancyColor(String occupancy) {
    switch (occupancy) {
      case 'red':
        return const Color(0xFFEF4444);
      case 'yellow':
        return const Color(0xFFF59E0B);
      case 'green':
      default:
        return const Color(0xFF22C55E);
    }
  }
}
