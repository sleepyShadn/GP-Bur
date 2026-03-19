// ========== lib/domain/splash_logic.dart ==========
import 'package:flutter/material.dart';

class SplashLogic {
  static const Color _colorPinkish = Color(0xFFE7CCCC);
  static const Color _colorCream = Color(0xFFEDE8DC);
  static const Color _colorGreenDark = Color(0xff7f9461);
  static const Color _colorGreenLight = Color(0xFFC1CFA1);

  String get welcomeText => "Welcome to Bur'";
  String get subtitleText => "Track, grow, and bloom within.";
  String get buttonText => "GET STARTED";

  Color get colorPinkish => _colorPinkish;
  Color get colorCream => _colorCream;
  Color get colorGreenDark => _colorGreenDark;
  Color get colorGreenLight => _colorGreenLight;
}