import 'dart:ffi';

import 'package:flutter/material.dart';
import 'theme.dart';
import '../services/auth_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sakaylive/screens/map_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // New controllers for conductor-specific fields
  final TextEditingController _conductorLicenseController = TextEditingController();
  final TextEditingController _employeeNumberController = TextEditingController();

  bool _isLoading = false;
  bool _isConductor = false;

  Future<void> _handleSignUp() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      _showError('Please enter a password');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    // Extra validation when registering as conductor
    if (_isConductor) {
      if (_conductorLicenseController.text.trim().isEmpty) {
        _showError('Please enter your conductor license number');
        return;
      }
      if (_employeeNumberController.text.trim().isEmpty) {
        _showError('Please enter your employee number');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ FIXED: Pass _isConductor to handle BOTH user creation + request
      await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        isConductor: _isConductor,
        // pass these into your AuthService and Firestore model
        conductorLicense: _conductorLicenseController.text.trim(),
        employeeNumber: _employeeNumberController.text.trim(),
      );

      if (mounted) {
        // ✅ FIXED: Navigate to AuthWrapper root (handles ALL roles)
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',  // ← ROOT = AuthWrapper (Admin/Conductor/Commuter logic)
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isConductor
              ? 'Account created! Conductor request sent for admin approval.'
              : 'Account created successfully!'),
            backgroundColor: _isConductor ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError(_getErrorMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  String _getErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return 'This email is already registered';
    } else if (error.contains('invalid-email')) {
      return 'Invalid email address';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection';
    }
    return 'Sign up failed. Please try again';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _conductorLicenseController.dispose();
    _employeeNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beige,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(
                  color: beige,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: beige,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset(
                            'assets/images/sakaylive_logo.png',
                            height: 80,
                            width: 200,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kLightBrown,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'SIGN UP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: kDarkNavy,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Name
                          const Text(
                            'Name',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Enter username',
                            controller: _nameController,
                          ),
                          const SizedBox(height: 16),

                          // Email
                          const Text(
                            'Email',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Enter email',
                            keyboardType: TextInputType.emailAddress,
                            controller: _emailController,
                          ),

                          // Conductor checkbox
                          CheckboxListTile(
                            title: const Text(
                              'Request Conductor Access (Pending admin approval)',
                              style: TextStyle(
                                color: kDarkNavy,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            value: _isConductor,
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _isConductor = value ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: tan,
                          ),

                          // Conductor-only fields
                          if (_isConductor) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Conductor License Number',
                              style: TextStyle(
                                color: kDarkNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _FormField(
                              hint: 'Enter conductor license number',
                              controller: _conductorLicenseController,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Employee Number',
                              style: TextStyle(
                                color: kDarkNavy,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _FormField(
                              hint: 'Enter employee number',
                              controller: _employeeNumberController,
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Password
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Enter password',
                            obscure: true,
                            controller: _passwordController,
                          ),
                          const SizedBox(height: 16),

                          // Confirm password
                          const Text(
                            'Enter Password Again',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _FormField(
                            hint: 'Re-enter password to confirm',
                            obscure: true,
                            controller: _confirmPasswordController,
                          ),
                          const SizedBox(height: 24),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tan,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: kDarkNavy,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'SAKAY NA!',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: kDarkNavy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
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

class _FormField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final TextEditingController? controller;

  const _FormField({
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
