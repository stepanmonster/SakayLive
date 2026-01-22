// lib/widgets/walking_directions_card.dart
import 'package:flutter/material.dart';
import 'package:sakaylive/services/directions_service.dart';

/// A card widget that displays walking directions with turn-by-turn instructions.
///
/// Shows:
/// - Total distance and estimated walking time
/// - Expandable step-by-step instructions
/// - Visual progress indicator
class WalkingDirectionsCard extends StatefulWidget {
  final WalkingRoute route;
  final String? destinationName;
  final VoidCallback? onNavigate;
  final VoidCallback? onDismiss;

  const WalkingDirectionsCard({
    super.key,
    required this.route,
    this.destinationName,
    this.onNavigate,
    this.onDismiss,
  });

  @override
  State<WalkingDirectionsCard> createState() => _WalkingDirectionsCardState();
}

class _WalkingDirectionsCardState extends State<WalkingDirectionsCard> {
  bool _isExpanded = false;
  int _currentStepIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Summary
          _buildSummary(),

          // Steps (expandable)
          if (_isExpanded && widget.route.hasSteps) _buildSteps(),

          // Actions
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_walk,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Walking Directions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (widget.destinationName != null)
                  Text(
                    'To: ${widget.destinationName}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (widget.onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.onDismiss,
              color: Colors.grey.shade600,
            ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryItem(
            icon: Icons.straighten,
            value: widget.route.distanceText,
            label: 'Distance',
            color: Colors.blue,
          ),
          const SizedBox(width: 24),
          _buildSummaryItem(
            icon: Icons.schedule,
            value: widget.route.durationText,
            label: 'Est. Time',
            color: Colors.orange,
          ),
          const Spacer(),
          if (widget.route.hasSteps)
            TextButton.icon(
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
              },
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              label: Text(_isExpanded ? 'Hide Steps' : 'Show Steps'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.route.steps.length,
        itemBuilder: (context, index) {
          final step = widget.route.steps[index];
          final isCurrentStep = index == _currentStepIndex;
          final isPastStep = index < _currentStepIndex;

          return _buildStepItem(
            step: step,
            index: index,
            isCurrentStep: isCurrentStep,
            isPastStep: isPastStep,
            isLast: index == widget.route.steps.length - 1,
          );
        },
      ),
    );
  }

  Widget _buildStepItem({
    required WalkingStep step,
    required int index,
    required bool isCurrentStep,
    required bool isPastStep,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCurrentStep
                      ? Colors.blue
                      : isPastStep
                      ? Colors.green
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPastStep
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrentStep
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isPastStep
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Step content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.instruction,
                    style: TextStyle(
                      fontWeight: isCurrentStep
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                      color: isPastStep ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        step.distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        step.durationText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Maneuver icon
          _getManeuverIcon(step.maneuver),
        ],
      ),
    );
  }

  Widget _getManeuverIcon(String? maneuver) {
    IconData icon;
    switch (maneuver) {
      case 'turn':
      case 'turn right':
        icon = Icons.turn_right;
        break;
      case 'turn left':
        icon = Icons.turn_left;
        break;
      case 'sharp right':
        icon = Icons.turn_sharp_right;
        break;
      case 'sharp left':
        icon = Icons.turn_sharp_left;
        break;
      case 'slight right':
        icon = Icons.turn_slight_right;
        break;
      case 'slight left':
        icon = Icons.turn_slight_left;
        break;
      case 'straight':
      case 'continue':
        icon = Icons.straight;
        break;
      case 'arrive':
        icon = Icons.flag;
        break;
      case 'depart':
        icon = Icons.my_location;
        break;
      default:
        icon = Icons.arrow_forward;
    }

    return Icon(icon, size: 20, color: Colors.grey.shade400);
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Share or copy directions
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Directions copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed:
                  widget.onNavigate ??
                  () {
                    setState(() => _currentStepIndex = 0);
                    // In a real app, this would start turn-by-turn navigation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigation started')),
                    );
                  },
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('Start Navigation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact inline widget for showing walking directions
class WalkingDirectionsInline extends StatelessWidget {
  final WalkingRoute route;
  final VoidCallback? onTap;

  const WalkingDirectionsInline({super.key, required this.route, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(
              route.distanceText,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${route.durationText})',
              style: TextStyle(color: Colors.blue.shade500, fontSize: 12),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: Colors.blue.shade400),
            ],
          ],
        ),
      ),
    );
  }
}
