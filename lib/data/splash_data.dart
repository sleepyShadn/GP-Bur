// ========== lib/data/splash_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/auth_selection_screen.dart';
import '../presentation/home_screen.dart';


class SplashData {
  String get logoPath => 'assets/logo.png';
  static const String _rememberMeKey = 'remember_me';

  void navigateToAuthSelection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => AuthSelectionScreen()),
    );
  }

  Future<void> navigateFromSplash(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (rememberMe && currentUser != null) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
      return;
    }

    if (!context.mounted) return;
    navigateToAuthSelection(context);
  }
}