import 'package:flutter/material.dart';
import 'package:sakaylive/models/vehicle_position.dart';

/// A floating snippet card that shows bus info when a bus marker is tapped.
/// This provides a quick overview without opening a full modal.
class BusInfoSnippet extends StatelessWidget {
  final TrackedVehicle vehicle;
  final VoidCallback onClose;
  final VoidCallback? onTrackBus;

  const BusInfoSnippet({
    super.key,
    required this.vehicle,
    required this.onClose,
    this.onTrackBus,
  });

  Color _getRouteColor() {
    switch (vehicle.routeColor) {
      case 'blue':
        return const Color(0xFF3B82F6);
      case 'orange':
        return const Color(0xFFF97316);
      case 'green':
        return const Color(0xFF22C55E);
      case 'red':
        return const Color(0xFFEF4444);
      case 'purple':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getUrgencyColor() {
    switch (vehicle.urgencyLevel) {
      case 'arriving':
        return const Color(0xFF22C55E); // Green
      case 'soon':
        return const Color(0xFFF97316); // Orange
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  Color _getOccupancyColor() {
    switch (vehicle.position.occupancy) {
      case 'green':
        return const Color(0xFF22C55E); // Green - seats available
      case 'yellow':
        return const Color(0xFFF59E0B); // Yellow/Amber - standing only
      case 'red':
        return const Color(0xFFEF4444); // Red - full
      default:
        return const Color(0xFF22C55E); // Default to green
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeColor = _getRouteColor();
    final urgencyColor = _getUrgencyColor();
    final pos = vehicle.position;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bus icon with route color
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: routeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    size: 28,
                    color: routeColor,
                  ),
                ),
                const SizedBox(width: 14),
                // Info section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route badge + occupancy badge + close button row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: routeColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Route ${pos.routeId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Occupancy badge with accessibility label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getOccupancyColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getOccupancyColor(),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getOccupancyColor(),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pos.occupancyText,
                                  style: TextStyle(
                                    color: _getOccupancyColor(),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Close button
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Destination/Route name
                      Text(
                        vehicle.routeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Direction
                      Text(
                        '→ ${vehicle.direction}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // ETA
                _buildStat(
                  icon: Icons.schedule_rounded,
                  label: 'ETA',
                  value: vehicle.etaText,
                  valueColor: urgencyColor,
                ),
                _buildDivider(),
                // Occupancy status (accessibility: shows text + color)
                _buildStat(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  label: 'Capacity',
                  value: vehicle.position.occupancyText,
                  valueColor: _getOccupancyColor(),
                ),
                _buildDivider(),
                // Distance
                _buildStat(
                  icon: Icons.near_me_rounded,
                  label: 'Distance',
                  value: vehicle.distanceText,
                  valueColor: const Color(0xFF374151),
                ),
              ],
            ),
          ),
          // Extra info row (if available)
          if (pos.plateNumber != null || pos.passengerCount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Bus ID/Plate
                  if (pos.plateNumber != null) ...[
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pos.plateNumber!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (pos.plateNumber != null && pos.passengerCount != null)
                    const SizedBox(width: 16),
                  // Passenger count
                  if (pos.passengerCount != null) ...[
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '~${pos.passengerCount} passengers',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: const Color(0xFFE5E7EB));
  }
}
