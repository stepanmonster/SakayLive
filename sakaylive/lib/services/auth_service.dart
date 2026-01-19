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

  // ✅ Check if user is conductor (custom claims first, then RTDB)
  Future<bool> isConductor() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Try custom claims first (most secure)
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.claims?['conductor'] == true) {
        return true;
      }
    } catch (e) {
      print('Error reading custom claims: $e');
    }

    // Fallback to RTDB role
    try {
      final userSnap =
          await _db.child('users').child(user.uid).child('isConductor').get();
      return userSnap.value == true;
    } catch (e) {
      print('Error reading RTDB role: $e');
      return false;
    }
  }

  // ✅ UPDATED: extra fields for conductor
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String username, {
    bool isConductor = false,
    String? conductorLicense,
    String? employeeNumber,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = result.user;

      if (user != null) {
        final normalizedEmail = email.trim().toLowerCase();

        await _db.child('users').child(user.uid).set({
          'userId': user.uid,
          'username': username,
          'email': normalizedEmail,
          'role': isConductor ? 'conductor' : 'user',
          'isConductor': isConductor,             // Boolean for RTDB rules
          'conductorLicense':
              isConductor ? conductorLicense : null, // NEW
          'employeeNumber':
              isConductor ? employeeNumber : null,   // NEW
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        await indexEmailForLookup(normalizedEmail, user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.message}');
      rethrow;
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
