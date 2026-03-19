// ========== lib/data/splash_data.dart ==========
import 'package:flutter/material.dart';

import '../presentation/auth_selection_screen.dart';


class SplashData {
  String get logoPath => 'assets/logo.png';

  void navigateToAuthSelection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => AuthSelectionScreen()),
    );
  }
}