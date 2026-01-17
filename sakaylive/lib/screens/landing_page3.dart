import 'package:flutter/material.dart';
import 'theme.dart';
import 'app.dart';

class LandingPage3 extends StatelessWidget {
  const LandingPage3({super.key});

  void _goToApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const App()),
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
            children: [
              const SizedBox(height: 24),

              // Centered title + tagline block
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/sakaylive_logo.png',
                      height: 120,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Biyaheng Walang Hula-Hula',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: kDarkNavy,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Buttons section – slightly above bottom
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToApp(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tan,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_walk,
                        color: kDarkNavy,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'COMMUTER',
                        style: TextStyle(
                          fontSize: 18,
                          color: kDarkNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _goToApp(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kDarkNavy, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: kDarkNavy,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'PAO',
                        style: TextStyle(
                          fontSize: 18,
                          color: kDarkNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
