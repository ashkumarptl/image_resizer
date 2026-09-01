import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service responsible for authentication flows, primarily Google Sign-In with Firebase Auth.
class AuthService {
  FirebaseAuth? _authInstance;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _authInstance = auth,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  FirebaseAuth get _auth {
    return _authInstance ??= FirebaseAuth.instance;
  }

  /// Stream of user authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated Firebase user (null if signed out)
  User? get currentUser => _auth.currentUser;

  /// Sign in using Google OAuth flow across Web and Mobile
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Flutter Web uses Firebase Auth popup flow
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      } else {
        // Mobile (Android / iOS) uses native GoogleSignIn account picker
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User canceled the sign-in dialog
          return null;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Sign out the current user from both Firebase Auth and Google Sign-In
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Error during sign out: $e');
      rethrow;
    }
  }
}
