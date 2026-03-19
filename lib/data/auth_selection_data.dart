// ========== lib/data/auth_selection_data.dart ==========
import 'package:flutter/material.dart';

import '../presentation/login_screen.dart';
import '../presentation/register_screen.dart';


class AuthSelectionData {
  final String logoPath = 'assets/logo.png';

  void navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => Login()),
    );
  }

  void navigateToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => Register()),
    );
  }
}