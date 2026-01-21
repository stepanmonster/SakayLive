import 'package:flutter/material.dart';

/// A reusable empty state widget for when there's no content to display.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor,
  });

  /// Empty state for no saved routes
  factory EmptyState.noSavedRoutes({VoidCallback? onExplore}) {
    return EmptyState(
      icon: Icons.bookmark_border_rounded,
      title: 'No Saved Routes',
      message: 'Routes you save will appear here for quick access',
      buttonText: 'Explore Routes',
      onButtonPressed: onExplore,
      iconColor: const Color(0xFFF59E0B),
    );
  }

  /// Empty state for no buses available
  factory EmptyState.noBusesAvailable({VoidCallback? onRefresh}) {
    return EmptyState(
      icon: Icons.directions_bus_outlined,
      title: 'No Buses Available',
      message:
          'No buses are currently operating on this route.\nCheck back later!',
      buttonText: onRefresh != null ? 'Refresh' : null,
      onButtonPressed: onRefresh,
      iconColor: const Color(0xFF3B82F6),
    );
  }

  /// Empty state for no search results
  factory EmptyState.noSearchResults({String? query}) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      message: query != null
          ? 'No results for "$query"\nTry a different search term'
          : 'Try a different search term or check for typos',
      iconColor: const Color(0xFF6B7280),
    );
  }

  /// Empty state for no internet connection
  factory EmptyState.noInternet({VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'No Internet Connection',
      message: 'Please check your connection and try again',
      buttonText: 'Retry',
      onButtonPressed: onRetry,
      iconColor: const Color(0xFFEF4444),
    );
  }

  /// Empty state for location permission denied
  factory EmptyState.locationDenied({VoidCallback? onEnable}) {
    return EmptyState(
      icon: Icons.location_off_rounded,
      title: 'Location Access Needed',
      message: 'Enable location to see nearby buses and get accurate ETAs',
      buttonText: 'Enable Location',
      onButtonPressed: onEnable,
      iconColor: const Color(0xFF8B5CF6),
    );
  }

  /// Empty state for no routes on selected area
  factory EmptyState.noRoutesNearby() {
    return const EmptyState(
      icon: Icons.map_outlined,
      title: 'No Routes Nearby',
      message:
          'There are no jeepney routes in this area.\nTry searching for a different location.',
      iconColor: Color(0xFF22C55E),
    );
  }

  /// Empty state for tracking not started
  factory EmptyState.trackingNotStarted({VoidCallback? onStart}) {
    return EmptyState(
      icon: Icons.gps_not_fixed_rounded,
      title: 'Live Tracking Off',
      message: 'Start live tracking to see real-time bus locations',
      buttonText: 'Start Tracking',
      onButtonPressed: onStart,
      iconColor: const Color(0xFF22C55E),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? const Color(0xFF6B7280);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with background
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Action button
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonText!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
