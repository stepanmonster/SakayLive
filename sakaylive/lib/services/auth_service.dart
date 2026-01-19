// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _emailKey(String email) =>
      email.trim().toLowerCase().replaceAll('.', ',');

  Future<bool> isEmailRegisteredInAppDb(String email) async {
    final snap = await _db.child('userEmails').child(_emailKey(email)).get();
    return snap.exists && snap.value != null;
  }

  Future<void> indexEmailForLookup(String email, String uid) async {
    await _db.child('userEmails').child(_emailKey(email)).set(uid);
  }

  // PUBLIC method to get route data
  Future<DataSnapshot> getRouteData(String path) async {
    final snapshot = await _db.child(path).get();
    return snapshot;
  }

  Future<bool> isConductor() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Custom claims first (keep existing)
    try {
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.claims?['conductor'] == true) return true;
    } catch (_) {} // Silent fail

    // RTDB - ✅ ONLY returns true for exact "conductor" string
    try {
      final snap = await _db.child('users').child(user.uid).child('role').get();
      
      // ✅ STRICT: Only true if role exists AND equals "conductor"
      if (snap.exists) {
        final role = snap.value?.toString().trim().toLowerCase();
        return role == 'conductor';
      }
      return false; // No role field = false
    } catch (_) {
      return false; // Any error = false
    }
  }


  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Custom claims first (future-proof)
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.claims?['admin'] == true) return true;
    } catch (_) {}

    // RTDB manual flag (your current method)
    try {
      final snap = await _db.child('users').child(user.uid).child('isAdmin').get();
      print('🔍 DEBUG RTDB isAdmin: ${snap.value}'); // Add this
      return snap.value == true;
    } catch (e) {
      print('🔍 isAdmin error: $e');
      return false;
    }
  }


    Future<void> signUpWithEmail(
  String email,
  String password,
  String name, {
  bool isConductor = false,
  String? conductorLicense,
  String? employeeNumber,
}) async {
  // Create auth user
  final credential = await _auth.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password.trim(),
  );

  final uid = credential.user!.uid;

  // Base user record
  await _db.child('users/$uid').set({
    'userId': uid,
    'email': email.trim(),
    'username': name.trim(),
    'role': null, // admin will set 'conductor' after approval
    'createdAt': ServerValue.timestamp,
  });

  // Index email for quick lookup (optional but you already support it)
  await indexEmailForLookup(email, uid);

  // Create conductor request if requested
  if (isConductor) {
    await _db.child('conductorRequests/$uid').set({
      'userId': uid,
      'username': name.trim(),
      'email': email.trim(),
      'conductorLicense': conductorLicense?.trim(),
      'employeeNumber': employeeNumber?.trim(),
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
    });
  }
}


    Future<User?> signInWithEmail(String email, String password) async {
      try {
        UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password.trim(),
        );
        return result.user;
      } on FirebaseAuthException catch (e) {
        print('Sign in error: ${e.message}');
        rethrow;
      }
    }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      rethrow;
    }
  }
}
