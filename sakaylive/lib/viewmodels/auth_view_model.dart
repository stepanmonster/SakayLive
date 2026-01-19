import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool? _isConductor;
  bool? _isAdmin;        // ✅ ADDED
  bool _isLoading = false;

  // ✅ KEEP your required public exposure
  late final AuthService authService;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool? get isConductor => _isConductor;
  bool? get isAdmin => _isAdmin;     // ✅ ADDED
  bool get isLoading => _isLoading;

  AuthViewModel() {
    print('🔍 AuthViewModel: Constructor called');
    authService = _authService;  // ✅ Proper initialization
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
        _isAdmin = null;       // ✅ ADDED
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkRole() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      print('🔍 Checking roles...');
      _isConductor = await _authService.isConductor();
      _isAdmin = await _authService.isAdmin();  // ✅ FIXED: Store result
      print('🔍 isConductor: $_isConductor, isAdmin: $_isAdmin');
    } catch (e) {
      print('🔍 Role check error: $e');
      _isConductor = false;
      _isAdmin = false;      // ✅ FIXED: Reset on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
