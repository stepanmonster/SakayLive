import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool? _isConductor;
  bool? _isAdmin;
  bool _isLoading = false;
  String? _errorMessage;

  // Public getters
  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool? get isConductor => _isConductor;
  bool? get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AuthService get authService => _authService;

  AuthViewModel() {
    print('🔍 AuthViewModel: Constructor called');
    _initAuthListener();
  }

  void _initAuthListener() {
    print('🔍 AuthViewModel: Setting up auth listener');
    _authService.authStateChanges.listen((User? user) {
      print('🔍 Auth state: ${user?.email ?? "NULL"}');
      _user = user;

      if (user != null) {
        _checkRole();
      } else {
        _isConductor = null;
        _isAdmin = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> refreshRoles() async {
  await _checkRole();
}

  Future<void> _checkRole() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      print('🔍 Checking roles...');
      _isConductor = await _authService.isConductor();
      _isAdmin = await _authService.isAdmin();
      print('🔍 isConductor: $_isConductor, isAdmin: $_isAdmin');
    } catch (e) {
      print('🔍 Role check error: $e');
      _isConductor = false;
      _isAdmin = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signInWithEmail(email.trim(), password.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIGN UP
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    bool isConductor = false,
    String? conductorLicense,
    String? employeeNumber,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signUpWithEmail(
        email.trim(),
        password.trim(),
        name.trim(),
        isConductor: isConductor,
        conductorLicense: conductorLicense,
        employeeNumber: employeeNumber,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PASSWORD RESET
  // ═══════════════════════════════════════════════════════════════════════════
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      // Check if email exists in app database
      final exists = await _authService.isEmailRegisteredInAppDb(email.trim());
      if (!exists) {
        _setError('No account found with this email.');
        return false;
      }

      await _authService.resetPassword(email.trim());
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getAuthErrorMessage(e.code));
      return false;
    } catch (e) {
      _setError(_getAuthErrorMessage(e.toString()));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIGN OUT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
    } finally {
      _setLoading(false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'weak-password':
        return 'Password is too weak';
      default:
        if (code.contains('user-not-found'))
          return 'No account found with this email';
        if (code.contains('wrong-password')) return 'Incorrect password';
        if (code.contains('invalid-credential'))
          return 'Invalid email or password';
        if (code.contains('email-already-in-use'))
          return 'This email is already registered';
        return 'Authentication failed. Please try again';
    }
  }
}
