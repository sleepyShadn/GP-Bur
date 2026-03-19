// ========== lib/domain/login_logic.dart ==========
import 'package:flutter/material.dart';

class LoginLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xFFA5B68D);
  final Color colorGreenLight = const Color(0xFFC1CFA1);

  bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }
}