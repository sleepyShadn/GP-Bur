// ========== lib/domain/register_logic.dart ==========
import 'package:flutter/material.dart';

class RegisterLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xFFA5B68D);
  final Color colorGreenLight = const Color(0xFFC1CFA1);
  final Color colorPlaceholder = const Color(0xFF362427);

  String? validateName(String value) {
    if (value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? validateWeight(String value) {
    if (value.trim().isEmpty) {
      return 'Weight cannot be empty';
    }
    try {
      double weightValue = double.parse(value.trim());
      if (weightValue <= 0) {
        return 'Weight must be greater than 0';
      }
      if (weightValue < 20) {
        return 'Weight must be at least 20 kg';
      }
      if (weightValue > 300) {
        return 'Weight must be less than 300 kg';
      }
      if (value.trim().contains('.') && value.trim().split('.')[1].length > 1) {
        return 'Weight can have at most 1 decimal place';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }
    return null;
  }

  String? validateHeight(String value) {
    if (value.trim().isEmpty) {
      return 'Height cannot be empty';
    }
    try {
      double heightValue = double.parse(value.trim());
      if (heightValue <= 0) {
        return 'Height must be greater than 0';
      }
      if (heightValue < 50) {
        return 'Height must be at least 50 cm';
      }
      if (heightValue > 250) {
        return 'Height must be less than 250 cm';
      }
      if (value.trim().contains('.')) {
        return 'Height must be a whole number (no decimals)';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }
    return null;
  }
}