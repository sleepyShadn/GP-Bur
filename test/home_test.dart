// ============================================
// ملف: test/home_test.dart
// ============================================
// اختبارات الوحدة لصفحة الرئيسية
// ============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:appforhumman/domain/home_logic.dart';

void main() {
  // ============================================
  // اختبارات HomeLogic - getWelcomeMessage
  // ============================================
  group('اختبارات HomeLogic - رسالة الترحيب', () {
    late HomeLogic logic;

    setUp(() {
      logic = HomeLogic();
    });

    test('u.1: يجب أن تعرض رسالة ترحيب عامة عندما لا يوجد تصنيف', () {
      String result = logic.getWelcomeMessage('');
      expect(result, "Welcome back! How are you feeling today?");
    });

    test('u.2: يجب أن تعرض رسالة مناسبة لـ anxiety', () {
      String result = logic.getWelcomeMessage('anxiety');
      expect(result, "Let's work on finding your calm today");
    });

    test('u.3: يجب أن تعرض رسالة مناسبة لـ depression', () {
      String result = logic.getWelcomeMessage('depression');
      expect(result, "Small steps lead to big changes");
    });

    test('u.4: يجب أن تعرض رسالة مناسبة لـ anorexia', () {
      String result = logic.getWelcomeMessage('anorexia');
      expect(result, "Nurture your body with kindness");
    });

    test('u.5: يجب أن تعرض رسالة مناسبة لـ bipolar', () {
      String result = logic.getWelcomeMessage('bipolar');
      expect(result, "Balance is key - you've got this");
    });

    test('u.6: يجب أن تعرض رسالة مناسبة لـ ADHD', () {
      String result = logic.getWelcomeMessage('ADHD');
      expect(result, "Focus on one thing at a time");
    });

    test('u.7: يجب أن تعرض رسالة مناسبة لـ antisocial personality', () {
      String result = logic.getWelcomeMessage('antisocial personality');
      expect(result, "Every connection starts with a smile");
    });

    test('u.8: يجب أن تعرض رسالة مناسبة لـ bulimia', () {
      String result = logic.getWelcomeMessage('bulimia');
      expect(result, "Be gentle with yourself today");
    });

    test('u.9: يجب أن تعرض رسالة افتراضية للتصنيفات غير المعروفة', () {
      String result = logic.getWelcomeMessage('unknown');
      expect(result, "Welcome back!");
    });
  });

  // ============================================
  // اختبارات HomeLogic - getGoalStatusMessage
  // ============================================
  group('اختبارات HomeLogic - حالة الهدف', () {
    late HomeLogic logic;

    setUp(() {
      logic = HomeLogic();
    });

    test('u.10: يجب أن تعرض رسالة اكتمال الهدف عند اكتماله', () {
      String result = logic.getGoalStatusMessage(true, null);
      expect(result, "✓ Goal Completed - Great job!");
    });

    test('u.11: يجب أن تعرض عدد الأيام المتبقية عندما يكون الهدف نشطاً', () {
      DateTime futureDate = DateTime.now().add(const Duration(days: 5));
      String result = logic.getGoalStatusMessage(false, futureDate);
      expect(result, "5 days remaining in goal period");
    });

    test('u.12: يجب أن تعرض رسالة انتهاء الفترة عندما تنتهي المدة', () {
      DateTime pastDate = DateTime.now().subtract(const Duration(days: 1));
      String result = logic.getGoalStatusMessage(false, pastDate);
      expect(result, "✓ Goal Period Ended - Well done!");
    });

    test('u.13: يجب أن تعرض سلسلة فارغة عندما لا يوجد تاريخ انتهاء', () {
      String result = logic.getGoalStatusMessage(false, null);
      expect(result, "");
    });
  });

  // ============================================
  // اختبارات HomeLogic - isActivityCompletedToday
  // ============================================
  group('اختبارات HomeLogic - حالة إكمال النشاط', () {
    late HomeLogic logic;

    setUp(() {
      logic = HomeLogic();
    });

    test('u.14: يجب أن تعيد true عندما يكون النشاط مكتملاً اليوم في dailyHistory', () {
      DateTime now = DateTime.now();
      String todayKey = '${now.year}-${now.month}-${now.day}';

      Map<String, dynamic> activity = {
        'dailyHistory': {todayKey: true},
      };

      bool result = logic.isActivityCompletedToday(activity);
      expect(result, true);
    });

    test('u.15: يجب أن تعيد true عندما يكون آخر تاريخ إكمال هو اليوم', () {
      DateTime today = DateTime.now();

      Map<String, dynamic> activity = {
        'dailyHistory': {},
        'lastCompletedDate': today,
      };

      bool result = logic.isActivityCompletedToday(activity);
      expect(result, true);
    });

    test('u.16: يجب أن تعيد false عندما يكون النشاط غير مكتمل', () {
      Map<String, dynamic> activity = {
        'dailyHistory': {},
        'lastCompletedDate': null,
      };

      bool result = logic.isActivityCompletedToday(activity);
      expect(result, false);
    });

    test('u.17: يجب أن تعيد false عندما يكون آخر تاريخ إكمال هو أمس', () {
      DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));

      Map<String, dynamic> activity = {
        'dailyHistory': {},
        'lastCompletedDate': yesterday,
      };

      bool result = logic.isActivityCompletedToday(activity);
      expect(result, false);
    });
  });
}

