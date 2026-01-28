import 'package:flutter/material.dart';
import 'theme.dart';
import 'landing_page2.dart';

class LandingPage1 extends StatelessWidget {
  const LandingPage1({super.key});

  void _goToFeatures(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LandingPage2()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Logo row - matching map screen header style
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kDarkNavy,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: kDarkNavy.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Hero illustration area
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 64,
                  color: kDarkNavy.withOpacity(0.8),
                ),
              ),

              const SizedBox(height: 40),

              // Hero text
              const Text(
                'Real-time bus locations,\narrival times, and capacity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kDarkNavy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Supporting paragraph
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  'Know exactly when your bus arrives and how full it is. Make smarter commute decisions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Get Started button - matching map screen button style
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToFeatures(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(true),
                  const SizedBox(width: 8),
                  _buildDot(false),
                  const SizedBox(width: 8),
                  _buildDot(false),
                ],
              ),

              const SizedBox(height: 24),
            ],
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
