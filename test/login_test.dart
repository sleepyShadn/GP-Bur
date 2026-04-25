
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforhumman/domain/login_logic.dart';

void main() {
  group('اختبارات LoginLogic - التحقق من صحة البريد الإلكتروني', () {
    late LoginLogic logic;

    setUp(() {
      logic = LoginLogic();
    });

    // اختبار 1: البريد الإلكتروني الصحيح
    test('u.1: يجب أن يقبل البريد الإلكتروني الصحيح', () {
      String email = 'test@gmail.com';
      bool result = logic.isValidEmail(email);
      expect(result, true);
    });

    // اختبار 2: البريد الإلكتروني بدون @
    test('u.2: يجب أن يرفض البريد الإلكتروني بدون @', () {
      String email = 'testgmail.com';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });

    // اختبار 3: البريد الإلكتروني بدون نقطة
    test('u.3: يجب أن يرفض البريد الإلكتروني بدون نقطة', () {
      String email = 'test@gmailcom';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });

    // اختبار 4: البريد الإلكتروني فارغ
    test('u.4: يجب أن يرفض البريد الإلكتروني الفارغ', () {
      String email = '';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });

    // اختبار 5: البريد الإلكتروني بدون اسم
    test('u.5: يجب أن يرفض البريد الإلكتروني بدون اسم', () {
      String email = '@gmail.com';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });

    // اختبار 6: البريد الإلكتروني بدون domain
    test('u.6: يجب أن يرفض البريد الإلكتروني بدون domain', () {
      String email = 'test@';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });

    // اختبار 7: البريد الإلكتروني صيغة خاطئة (نقطة في البداية)
    test('u.7: يجب أن يرفض البريد الإلكتروني بصيغة خاطئة', () {
      String email = 'test@.com';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });

    // اختبار 8: التحقق من اللون Pinkish
    test('u.8: يجب أن يكون اللون Pinkish صحيح', () {
      expect(logic.colorPinkish, const Color(0xFFE7CCCC));
    });

    // اختبار 9: التحقق من اللون Cream
    test('u.9: يجب أن يكون اللون Cream صحيح', () {
      expect(logic.colorCream, const Color(0xFFEDE8DC));
    });

    // اختبار 10: التحقق من اللون GreenDark
    test('u.10: يجب أن يكون اللون GreenDark صحيح', () {
      expect(logic.colorGreenDark, const Color(0xFFA5B68D));
    });

    // اختبار 11: التحقق من اللون GreenLight
    test('u.11: يجب أن يكون اللون GreenLight صحيح', () {
      expect(logic.colorGreenLight, const Color(0xFFC1CFA1));
    });

    // اختبار 12: بريد إلكتروني بصيغة subdomain
    test('u.12: يجب أن يقبل البريد الإلكتروني بصيغة subdomain', () {
      String email = 'user@mail.example.com';
      bool result = logic.isValidEmail(email);
      expect(result, true);
    });

    // اختبار 13: بريد يحتوي على مسافة في البداية (غير trim داخل المنطق)
    test('u.13: يجب أن يرفض البريد مع مسافة بادئة', () {
      String email = ' test@gmail.com';
      bool result = logic.isValidEmail(email);
      expect(result, false);
    });
  });
}