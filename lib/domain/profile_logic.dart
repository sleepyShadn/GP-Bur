// ========== lib/domain/profile_logic.dart ==========
import 'package:flutter/material.dart';

class ProfileLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xff7f9461);
  final Color colorGreenLight = const Color(0xFFC1CFA1);
  final Color colorBrown = const Color(0xFF5C4018);
  final Color colorBrownDark = const Color(0xFF4A3728);

  String? validateName(String value) {
    if (value.trim().isEmpty) return 'Name cannot be empty';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    if (value.trim().length > 50) return 'Name must be less than 50 characters';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) return 'Name can only contain letters and spaces';
    return null;
  }

  String? validateEmail(String value) {
    if (value.trim().isEmpty) return 'Email cannot be empty';
    final emailRegex = RegExp(r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$');
    if (!emailRegex.hasMatch(value.trim())) return 'Please enter a valid email address';
    return null;
  }

  String? validateBirthDate(String value) {
    if (value.trim().isEmpty) return 'Birth date cannot be empty';
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(value.trim())) return 'Please enter date in DD/MM/YYYY format';
    try {
      List<String> parts = value.trim().split('/');
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      if (day < 1 || day > 31) return 'Day must be between 1 and 31';
      if (month < 1 || month > 12) return 'Month must be between 1 and 12';
      DateTime date = DateTime(year, month, day);
      DateTime now = DateTime.now();
      if (date.isAfter(now)) return 'Birth date cannot be in the future';
      if (year < 1900) return 'Year must be 1900 or later';
      DateTime eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
      if (date.isAfter(eighteenYearsAgo)) return 'You must be at least 18 years old';
      if (date.day != day || date.month != month || date.year != year) return 'Invalid date';
    } catch (e) {
      return 'Invalid date format';
    }
    return null;
  }

  String? validateWeight(String value) {
    if (value.trim().isEmpty) return 'Weight cannot be empty';
    try {
      double weightValue = double.parse(value.trim());
      if (weightValue <= 0) return 'Weight must be greater than 0';
      if (weightValue < 20) return 'Weight must be at least 20 kg';
      if (weightValue > 300) return 'Weight must be less than 300 kg';
      if (value.trim().contains('.') && value.trim().split('.')[1].length > 1) return 'Weight can have at most 1 decimal place';
    } catch (e) {
      return 'Please enter a valid number';
    }
    return null;
  }

  String? validateHeight(String value) {
    if (value.trim().isEmpty) return 'Height cannot be empty';
    try {
      double heightValue = double.parse(value.trim());
      if (heightValue <= 0) return 'Height must be greater than 0';
      if (heightValue < 50) return 'Height must be at least 50 cm';
      if (heightValue > 250) return 'Height must be less than 250 cm';
      if (value.trim().contains('.') && value.trim().split('.')[1].length > 1) return 'Height can have at most 1 decimal place';
    } catch (e) {
      return 'Please enter a valid number';
    }
    return null;
  }

  String? validateGender(String value) {
    if (value.isEmpty) return 'Please select your gender';
    if (value != "Male" && value != "Female") return 'Please select a valid gender option';
    return null;
  }

  String formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String getMonthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }

  String formatTime(DateTime dateTime) {
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String second = dateTime.second.toString().padLeft(2, '0');
    return "$hour:$minute:$second";
  }
}