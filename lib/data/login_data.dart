// ========== lib/data/login_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _rememberMeKey = 'remember_me';

  Future<LoginResult> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return LoginResult(success: true);
      }
      return LoginResult(success: false, errorMessage: 'Login failed');
    } catch (e) {
      return LoginResult(success: false, errorMessage: 'incorrect email or passwotrd');
    }
  }

  Future<LoginResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return LoginResult(success: true);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email address';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address format';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection';
      }
      return LoginResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      return LoginResult(success: false, errorMessage: 'An error occurred. Please try again');
    }
  }

  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }
}

class LoginResult {
  final bool success;
  final String? errorMessage;

  LoginResult({required this.success, this.errorMessage});
}
