import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import '../viewmodels/auth_view_model.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _conductorLicenseController =
      TextEditingController();
  final TextEditingController _employeeNumberController =
      TextEditingController();

  bool _localLoading = false;
  bool _isConductor = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSignUp() async {
    final authViewModel = context.read<AuthViewModel>();

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

    setState(() => _localLoading = true);

    final success = await authViewModel.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      isConductor: _isConductor,
      conductorLicense: _isConductor
          ? _conductorLicenseController.text.trim()
          : null,
      employeeNumber: _isConductor
          ? _employeeNumberController.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _localLoading = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isConductor
                      ? 'Account created! Conductor request sent for admin approval.'
                      : 'Account created successfully!',
                ),
              ),
            ],
          ),
          backgroundColor: _isConductor
              ? const Color(0xFFF59E0B)
              : const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else if (authViewModel.errorMessage != null) {
      _showError(authViewModel.errorMessage!);
      authViewModel.clearError();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top app bar
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: kDarkNavy,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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

                const SizedBox(height: 24),

                // Welcome text
                Row(
                  children: [
                    const Text(
                      'Create Account ',
                      style: TextStyle(
                        color: kDarkNavy,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Icon(
                      Icons.directions_bus_filled_rounded,
                      color: kDarkNavy,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Join SakayLive and never miss a ride',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Sign up form card
                Container(
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      _buildLabel('Full Name'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Enter your full name',
                        icon: Icons.person_outline_rounded,
                      ),

                      const SizedBox(height: 16),

                      // Email field
                      _buildLabel('Email'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 16),

                      // Conductor toggle
                      Container(
                        decoration: BoxDecoration(
                          color: _isConductor
                              ? const Color(0xFFFEF3C7)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isConductor
                                ? const Color(0xFFF59E0B)
                                : Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            'Register as Conductor',
                            style: TextStyle(
                              color: kDarkNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Requires admin approval',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          value: _isConductor,
                          onChanged: _localLoading
                              ? null
                              : (value) {
                                  setState(() => _isConductor = value ?? false);
                                },
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: const Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                      ),

                      // Conductor-only fields
                      if (_isConductor) ...[
                        const SizedBox(height: 16),
                        _buildLabel('Conductor License Number'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _conductorLicenseController,
                          hint: 'Enter your license number',
                          icon: Icons.badge_outlined,
                        ),

                        const SizedBox(height: 16),
                        _buildLabel('Employee Number'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _employeeNumberController,
                          hint: 'Enter your employee number',
                          icon: Icons.numbers_rounded,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Password field
                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController,
                        hint: 'Create a password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Confirm password field
                      _buildLabel('Confirm Password'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hint: 'Re-enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign up button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _localLoading ? null : _handleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDarkNavy,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: kDarkNavy.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _localLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Create Account',
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
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: kDarkNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: kDarkNavy,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(
          color: kDarkNavy,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
