import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool? _isConductor;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool? get isConductor => _isConductor;
  bool get isLoading => _isLoading;

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
        _isLoading = false;
        notifyListeners(); // ✅ Only called ONCE here
      }
    });
  }

  Future<void> _checkRole() async {
    if (_isLoading) return; // Prevent duplicate calls
    
    _isLoading = true;
    notifyListeners();
    
    try {
      print('🔍 AuthViewModel: Checking conductor role...');
      _isConductor = await _authService.isConductor();
      print('🔍 AuthViewModel: isConductor = $_isConductor');
    } catch (e) {
      print('🔍 AuthViewModel: Role check error: $e');
      _isConductor = false;
    } finally {
      _isLoading = false;
      notifyListeners(); // ✅ Only called ONCE here
    }
  }
}
