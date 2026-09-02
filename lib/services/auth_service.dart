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
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: '739988890096-5ufkdp2lec91avsfsb7sjvq94onvralt.apps.googleusercontent.com',
            );

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

  /// Re-authenticate the current user with Google if credentials expired
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }

    if (kIsWeb) {
      final GoogleAuthProvider authProvider = GoogleAuthProvider();
      await user.reauthenticateWithPopup(authProvider);
    } else {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Re-authentication was canceled.',
        );
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
  }

  /// Permanently delete the user's account from Firebase Auth and sign out from Google
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No user is currently signed in.',
      );
    }

    try {
      await user.delete();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } on FirebaseAuthException catch (e) {
      // If requires-recent-login, try re-authenticating and then retry deletion
      if (e.code == 'requires-recent-login') {
        debugPrint('[AuthService] requires-recent-login encountered. Attempting reauthentication...');
        await reauthenticateWithGoogle();
        // Retry delete
        await _auth.currentUser?.delete();
        if (!kIsWeb) {
          await _googleSignIn.signOut();
        }
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('[AuthService] Error deleting account: $e');
      rethrow;
    }
  }
}

