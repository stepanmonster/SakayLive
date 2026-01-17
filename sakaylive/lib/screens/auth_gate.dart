// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Always show landing page - no auth required
    return const LoginPage();
  }
}