import 'package:flutter/material.dart';
import 'theme.dart';
import 'landing_page3.dart';

class LandingPage2 extends StatelessWidget {
  const LandingPage2({super.key});

  void _goToLandingPage3(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LandingPage3()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // swipe left => negative velocity.x
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < 0) {
              _goToLandingPage3(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Top app bar - matching map screen style
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kDarkNavy,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: kDarkNavy.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_bus_filled_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SakayLive',
                          style: TextStyle(
                            color: kDarkNavy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    // Skip button
                    TextButton(
                      onPressed: () => _goToLandingPage3(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section title (centered)
                const Text(
                  'SakayLive Features',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kDarkNavy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 4),

                // Section subtitle (centered, lighter gray)
                Text(
                  'Everything you need to plan your ride, in real time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 14),

                // Feature cards - using Expanded to fill available space
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _CompactFeatureCard(
                          icon: Icons.location_on_rounded,
                          title: 'Live Tracking',
                          description: 'See real-time bus locations on the map',
                          iconColor: const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _CompactFeatureCard(
                          icon: Icons.access_time_filled_rounded,
                          title: 'Arrival Time',
                          description: 'Get accurate ETAs updated continuously',
                          iconColor: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _CompactFeatureCard(
                          icon: Icons.group_rounded,
                          title: 'Capacity Status',
                          description:
                              'Check if seats are available before boarding',
                          iconColor: const Color(0xFF10B981),
                          showLegend: true,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom section: Page indicator + Next button
                const SizedBox(height: 10),
                // Page indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(false),
                    const SizedBox(width: 8),
                    _buildDot(true),
                    const SizedBox(width: 8),
                    _buildDot(false),
                  ],
                ),
                const SizedBox(height: 16),
                // Next button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _goToLandingPage3(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDarkNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? kDarkNavy : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Compact feature card for fitting all items without scrolling
class _CompactFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final bool showLegend;

  const _CompactFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = kDarkNavy,
    this.showLegend = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kDarkNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showLegend) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _MiniLegendDot(color: const Color(0xFF22C55E), label: 'Seats'),
                const SizedBox(width: 16),
                _MiniLegendDot(
                  color: const Color(0xFFF59E0B),
                  label: 'Standing',
                ),
                const SizedBox(width: 16),
                _MiniLegendDot(color: const Color(0xFFEF4444), label: 'Full'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _MiniLegendDot({required this.color, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
