

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforhumman/domain/register_logic.dart';

void main() {
  group('اختبارات RegisterLogic - التحقق من الاسم', () {
    late RegisterLogic logic;

    setUp(() {
      logic = RegisterLogic();
    });

    // اختبار 1: اسم صحيح
    test('u.1: يجب أن يقبل الاسم الصحيح', () {
      String name = 'Ahmed';
      String? result = logic.validateName(name);
      expect(result, null);
    });

    // اختبار 2: اسم فارغ
    test('u.2: يجب أن يرفض الاسم الفارغ', () {
      String name = '';
      String? result = logic.validateName(name);
      expect(result, 'Name cannot be empty');
    });

    // اختبار 3: اسم به مسافات فقط
    test('u.3: يجب أن يرفض الاسم الذي يحتوي على مسافات فقط', () {
      String name = '   ';
      String? result = logic.validateName(name);
      expect(result, 'Name cannot be empty');
    });

    // اختبار 4: اسم قصير جداً (أقل من حرفين)
    test('u.4: يجب أن يرفض الاسم الأقل من حرفين', () {
      String name = 'A';
      String? result = logic.validateName(name);
      expect(result, 'Name must be at least 2 characters');
    });

    // اختبار 5: اسم طويل جداً (أكثر من 50 حرف)
    test('u.5: يجب أن يرفض الاسم الأطول من 50 حرف', () {
      String name = 'A' * 51;
      String? result = logic.validateName(name);
      expect(result, 'Name must be less than 50 characters');
    });

    // اختبار 6: اسم يحتوي على أرقام
    test('u.6: يجب أن يرفض الاسم الذي يحتوي على أرقام', () {
      String name = 'Ahmed123';
      String? result = logic.validateName(name);
      expect(result, 'Name can only contain letters and spaces');
    });

    // اختبار 7: اسم يحتوي على رموز خاصة
    test('u.7: يجب أن يرفض الاسم الذي يحتوي على رموز خاصة', () {
      String name = 'Ahmed@';
      String? result = logic.validateName(name);
      expect(result, 'Name can only contain letters and spaces');
    });

    // اختبار 8: اسم يحتوي على مسافات (صحيح)
    test('u.8: يجب أن يقبل الاسم الذي يحتوي على مسافات', () {
      String name = 'Ahmed Mohamed';
      String? result = logic.validateName(name);
      expect(result, null);
    });

    // اختبار 8.b: اسم صحيح مع مسافات حوله (trim)
    test('u.8.b: يجب أن يقبل الاسم بعد trim', () {
      String name = '  Ahmed Mohamed  ';
      String? result = logic.validateName(name);
      expect(result, null);
    });
  });

  group('اختبارات RegisterLogic - التحقق من الوزن', () {
    late RegisterLogic logic;

    setUp(() {
      logic = RegisterLogic();
    });

    // اختبار 9: وزن صحيح
    test('u.9: يجب أن يقبل الوزن الصحيح', () {
      String weight = '70.5';
      String? result = logic.validateWeight(weight);
      expect(result, null);
    });

    // اختبار 10: وزن فارغ
    test('u.10: يجب أن يرفض الوزن الفارغ', () {
      String weight = '';
      String? result = logic.validateWeight(weight);
      expect(result, 'Weight cannot be empty');
    });

    // اختبار 11: وزن صفر
    test('u.11: يجب أن يرفض الوزن صفر', () {
      String weight = '0';
      String? result = logic.validateWeight(weight);
      expect(result, 'Weight must be greater than 0');
    });

    // اختبار 12: وزن سالب
    test('u.12: يجب أن يرفض الوزن السالب', () {
      String weight = '-50';
      String? result = logic.validateWeight(weight);
      expect(result, 'Weight must be greater than 0');
    });

    // اختبار 13: وزن أقل من 20
    test('u.13: يجب أن يرفض الوزن الأقل من 20 كجم', () {
      String weight = '15';
      String? result = logic.validateWeight(weight);
      expect(result, 'Weight must be at least 20 kg');
    });

    // اختبار 14: وزن أكبر من 300
    test('u.14: يجب أن يرفض الوزن الأكبر من 300 كجم', () {
      String weight = '350';
      String? result = logic.validateWeight(weight);
      expect(result, 'Weight must be less than 300 kg');
    });

    // اختبار 15: وزن بعدد عشري أكثر من منزلة
    test('u.15: يجب أن يرفض الوزن بأكثر من منزلة عشرية', () {
      String weight = '70.55';
      String? result = logic.validateWeight(weight);
      expect(result, 'Weight can have at most 1 decimal place');
    });

    // اختبار 16: وزن غير رقم
    test('u.16: يجب أن يرفض الوزن غير الرقمي', () {
      String weight = 'abc';
      String? result = logic.validateWeight(weight);
      expect(result, 'Please enter a valid number');
    });
  });

  group('اختبارات RegisterLogic - التحقق من الطول', () {
    late RegisterLogic logic;

    setUp(() {
      logic = RegisterLogic();
    });

    // اختبار 17: طول صحيح
    test('u.17: يجب أن يقبل الطول الصحيح', () {
      String height = '175';
      String? result = logic.validateHeight(height);
      expect(result, null);
    });

    // اختبار 18: طول فارغ
    test('u.18: يجب أن يرفض الطول الفارغ', () {
      String height = '';
      String? result = logic.validateHeight(height);
      expect(result, 'Height cannot be empty');
    });

    // اختبار 19: طول صفر
    test('u.19: يجب أن يرفض الطول صفر', () {
      String height = '0';
      String? result = logic.validateHeight(height);
      expect(result, 'Height must be greater than 0');
    });

    // اختبار 20: طول سالب
    test('u.20: يجب أن يرفض الطول السالب', () {
      String height = '-50';
      String? result = logic.validateHeight(height);
      expect(result, 'Height must be greater than 0');
    });

    // اختبار 21: طول أقل من 50
    test('u.21: يجب أن يرفض الطول الأقل من 50 سم', () {
      String height = '40';
      String? result = logic.validateHeight(height);
      expect(result, 'Height must be at least 50 cm');
    });

    // اختبار 22: طول أكبر من 250
    test('u.22: يجب أن يرفض الطول الأكبر من 250 سم', () {
      String height = '260';
      String? result = logic.validateHeight(height);
      expect(result, 'Height must be less than 250 cm');
    });

    // اختبار 23: طول بعدد عشري (ممنوع)
    test('u.23: يجب أن يرفض الطول الذي يحتوي على أرقام عشرية', () {
      String height = '175.5';
      String? result = logic.validateHeight(height);
      expect(result, 'Height must be a whole number (no decimals)');
    });

    // اختبار 24: طول غير رقم
    test('u.24: يجب أن يرفض الطول غير الرقمي', () {
      String height = 'abc';
      String? result = logic.validateHeight(height);
      expect(result, 'Please enter a valid number');
    });
  });

  group('اختبارات RegisterLogic - الثوابت اللونية', () {
    late RegisterLogic logic;

    setUp(() {
      logic = RegisterLogic();
    });

    test('u.25: لون placeholder يجب أن يطابق المنطق الحالي', () {
      expect(logic.colorPlaceholder.value, const Color(0xFF362427).value);
    });
  });
}

