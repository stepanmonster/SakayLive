import 'package:flutter/material.dart';
import 'theme.dart';
import 'app.dart';
import 'landing_page2.dart';

class LandingPage1 extends StatelessWidget {
  const LandingPage1({super.key});

void _goToFeatures(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LandingPage2()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center, // center main content
            children: [
              const SizedBox(height: 32),

              // Logo row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kDarkNavy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SakayLive',
                    style: TextStyle(
                      color: kDarkNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 150),

              // Hero text
              const Text(
                'Real-time bus locations,\narrival times, and capacity —before you ride',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kDarkNavy,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              // Supporting paragraph
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: const Text(
                  'Know exactly when your bus arrives and how full it is. Make smarter commute decisions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 100),

              // Get Started button in the centered content group
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToFeatures(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Trust badge pinned near bottom
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEADFC7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: kDarkNavy,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Trusted by 50k+ daily commuters',
                      style: TextStyle(
                        color: kDarkNavy,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

      
class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureTile({
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2E6CF), // slightly darker beige tile
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: kDarkNavy,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kDarkNavy,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
