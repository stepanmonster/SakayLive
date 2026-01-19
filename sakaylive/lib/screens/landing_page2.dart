import 'package:flutter/material.dart';
import 'theme.dart';
import 'app.dart';
import 'landing_page3.dart';

class LandingPage2 extends StatelessWidget {
  const LandingPage2({super.key});

  void _goToApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const App()),
    );
  }

  void _goToLandingPage3(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LandingPage3()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // swipe left => negative velocity.x
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < 0) {
              _goToLandingPage3(context);
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top app bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kDarkNavy,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.directions_bus_filled_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SakayLive',
                          style: TextStyle(
                            color: kDarkNavy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: kDarkNavy,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Section title (centered)
                const Center(
                  child: Text(
                    'SakayLive Features',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: kDarkNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Section subtitle (centered, lighter gray)
                const Center(
                  child: Text(
                    'Everything you need to plan your ride,\n'
                    'in real time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Feature cards column
                _FeatureCard(
                  icon: Icons.location_on_rounded,
                  title: 'Live Tracking',
                  description:
                      'View the exact, real-time location of buses as they move along their routes, so you can plan when to leave and avoid unnecessary waiting.',
                ),
                const SizedBox(height: 16),
                _FeatureCard(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Arrival Time',
                  description:
                      'Get an accurate estimated arrival time of the bus to your current location or selected stop, updated continuously as traffic conditions change.',
                ),
                const SizedBox(height: 16),
                const _CapacityFeatureCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Generic feature card
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF2E6CF), // slightly darker beige card
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Small square icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kDarkNavy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: kDarkNavy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Capacity card with legend row
class _CapacityFeatureCard extends StatelessWidget {
  const _CapacityFeatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF2E6CF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kDarkNavy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.group_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Capacity Indicator',
              style: TextStyle(
                color: kDarkNavy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check how full a bus is before it arrives: green means seats are available, yellow means standing passengers only, and red means the bus is already full.',
              style: TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),

            // Capacity legend row
            Row(
              children: const [
                _LegendDot(color: Colors.green, label: 'Seats'),
                SizedBox(width: 16),
                _LegendDot(color: Colors.amber, label: 'Standing'),
                SizedBox(width: 16),
                _LegendDot(color: Colors.red, label: 'Full'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A8A8A),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
