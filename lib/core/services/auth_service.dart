import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  /// Web Client ID from Firebase Console (used as serverClientId for Android ID Tokens)
  static const String _webClientId =
      '705882453832-hetbpbltedbh5j8nc61p2purfe05inp4.apps.googleusercontent.com';

  /// Sign In with Email & Password
  static Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign Up with Email & Password (sends email verification)
  static Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (fullName != null && fullName.isNotEmpty) {
        await credential.user?.updateDisplayName(fullName.trim());
      }
      try {
        await credential.user?.sendEmailVerification();
      } catch (e) {
        debugPrint('Email verification send error: $e');
      }
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  /// Send verification email to currently signed in user
  static Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      rethrow;
    }
  }

  /// Reload user and check if email is verified
  static Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  /// Update user display name in Firebase Auth
  static Future<void> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name.trim());
    } catch (e) {
      debugPrint('Error updating display name: $e');
    }
  }

  /// Google Sign In Hook (Native Android/iOS + Web)
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Native Mobile (Android / iOS) with serverClientId
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: _webClientId,
        );

        // Ensure sign out of previous session before triggering account selector
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          // User canceled sign-in
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      try {
        final googleProvider = GoogleAuthProvider();
        return await _auth.signInWithProvider(googleProvider);
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Sign Out
  static Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }
}
