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
    return snap.exists && snap.value != null; // one-time existence check
  }

  // call this in signUpWithEmail after writing /users/{uid}
  Future<void> indexEmailForLookup(String email, String uid) async {
    await _db.child('userEmails').child(_emailKey(email)).set(uid);
  }

  // Sign up with email & password
  Future<User?> signUpWithEmail(String email, String password, String username) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      User? user = result.user;
      
      // Store user data in Realtime Database
      if (user != null) {
        final normalizedEmail = email.trim().toLowerCase();

        await _db.child('users').child(user.uid).set({
          'userId': user.uid,
          'username': username,
          'email': normalizedEmail,
          'role': 'user',
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

  // Sign in with email & password
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

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      rethrow;
    }
  }
}