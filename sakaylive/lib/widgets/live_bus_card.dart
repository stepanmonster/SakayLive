import 'package:flutter/material.dart';
import 'package:sakaylive/models/vehicle_position.dart';

/// A card widget that displays live bus tracking information.
/// Shows ETA, distance, route info, and other relevant details.
class LiveBusCard extends StatelessWidget {
  final TrackedVehicle vehicle;
  final VoidCallback? onTap;
  final bool isCompact;

  const LiveBusCard({
    super.key,
    required this.vehicle,
    this.onTap,
    this.isCompact = false,
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

  @override
  Widget build(BuildContext context) {
    final routeColor = _getRouteColor();
    final urgencyColor = _getUrgencyColor();

    if (isCompact) {
      return _buildCompactCard(routeColor, urgencyColor);
    }

    return _buildFullCard(routeColor, urgencyColor);
  }

  /// Compact version for inline display
  Widget _buildCompactCard(Color routeColor, Color urgencyColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: urgencyColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgencyColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bus icon with route color
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: routeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              size: 16,
              color: routeColor,
            ),
          ),
          const SizedBox(width: 8),
          // ETA
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vehicle.etaText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: urgencyColor,
                ),
              ),
              Text(
                vehicle.distanceText,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Full card with all details
  Widget _buildFullCard(Color routeColor, Color urgencyColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with route badge and live indicator
            Row(
              children: [
                // Route badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: routeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Route ${vehicle.position.routeId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                // Live indicator
                _buildLiveIndicator(),
              ],
            ),

            const SizedBox(height: 12),

            // Main content - ETA prominent
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ETA
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Arriving in',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle.etaText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: urgencyColor,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Bus icon with animation hint
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: routeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    size: 32,
                    color: routeColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Divider
            Container(height: 1, color: const Color(0xFFF3F4F6)),

            const SizedBox(height: 12),

            // Info row
            Row(
              children: [
                // Distance
                _buildInfoChip(
                  Icons.place_outlined,
                  vehicle.distanceText,
                  const Color(0xFF6B7280),
                ),
                const SizedBox(width: 12),
                // Direction
                Expanded(
                  child: _buildInfoChip(
                    Icons.arrow_forward_rounded,
                    vehicle.direction,
                    const Color(0xFF6B7280),
                    expanded: true,
                  ),
                ),
              ],
            ),

            // Stops away (if available)
            if (vehicle.stopsAway != null && vehicle.stopsAway! > 0) ...[
              const SizedBox(height: 8),
              _buildInfoChip(
                Icons.linear_scale_rounded,
                '${vehicle.stopsAway} stops away',
                const Color(0xFF6B7280),
              ),
            ],

            // Additional info row
            const SizedBox(height: 12),
            Row(
              children: [
                // Passenger count (if available)
                if (vehicle.position.passengerCount != null)
                  _buildPassengerIndicator(vehicle.position.passengerCount!),
                const Spacer(),
                // Last updated
                Text(
                  'Updated ${vehicle.position.lastSeenText}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF22C55E),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text,
    Color color, {
    bool expanded = false,
  }) {
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        expanded
            ? Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }

  Widget _buildPassengerIndicator(int count) {
    // Determine crowding level
    String label;
    Color color;
    if (count < 10) {
      label = 'Not crowded';
      color = const Color(0xFF22C55E);
    } else if (count < 20) {
      label = 'Moderate';
      color = const Color(0xFFF97316);
    } else {
      label = 'Crowded';
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget that shows a summary of multiple tracked vehicles
class LiveBusSummary extends StatelessWidget {
  final List<TrackedVehicle> vehicles;
  final VoidCallback? onViewAll;

  const LiveBusSummary({super.key, required this.vehicles, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return _buildEmptyState();
    }

    final nearest = vehicles.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.05),
            const Color(0xFF2563EB).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  size: 20,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Bus Tracking',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '${vehicles.length} active ${vehicles.length == 1 ? 'bus' : 'buses'} nearby',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              // View all button
              if (onViewAll != null && vehicles.length > 1)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Nearest bus card (compact)
          LiveBusCard(vehicle: nearest, isCompact: true),

          // Show hint for more buses
          if (vehicles.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              '+${vehicles.length - 1} more ${vehicles.length - 1 == 1 ? 'bus' : 'buses'} on this route',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_bus_outlined,
              size: 20,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active buses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  'Buses will appear here when they\'re online',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
