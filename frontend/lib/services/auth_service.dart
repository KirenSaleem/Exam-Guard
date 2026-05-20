import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase + Google authentication for teachers.
/// Handles email/password sign-in and Google account picker / switch flows.
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to register user.');
    } catch (_) {
      throw Exception('An unexpected error occurred during registration.');
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to sign in.');
    } catch (_) {
      throw Exception('An unexpected error occurred during sign in.');
    }
  }

  /// Google sign-in. Returns null if the user cancels the account picker.
  /// Set [forceAccountPicker] true to sign out Google first (switch account).
  Future<UserCredential?> signInWithGoogle({bool forceAccountPicker = false}) async {
    try {
      if (forceAccountPicker) {
        await _googleSignIn.signOut();
      }

      await _googleSignIn.initialize();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (kDebugMode) debugPrint('[ExamGuard] Google sign-in cancelled');
        return null;
      }
      throw Exception('Google sign-in failed. Please try again.');
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to sign in with Google.');
    } catch (e) {
      if (kDebugMode) debugPrint('[ExamGuard] Google sign-in error: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('aborted')) {
        return null;
      }
      throw Exception('Google sign-in was interrupted. Please try again.');
    }
  }

  /// Clears Firebase session and Google cached account so user can pick another email.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {
      throw Exception('Failed to sign out.');
    }
  }

  /// Use before "Switch Google account" — only clears Google, not Firebase until new pick.
  Future<void> signOutGoogleOnly() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Non-fatal: picker may still open.
    }
  }
}
