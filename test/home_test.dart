

import 'package:flutter_test/flutter_test.dart';
import 'package:appforhumman/domain/home_logic.dart';

void main() {
  group('اختبارات HomeLogic - رسالة الترحيب', () {
    late HomeLogic logic;

    setUp(() {
      logic = HomeLogic();
    });

    test('u.1: يجب أن تعرض رسالة ترحيب عامة عندما لا يوجد تصنيف', () {
      String result = logic.getWelcomeMessage('');
      expect(result, "Welcome back! How are you feeling today?");
    });

    test('u.2: يجب أن تعرض رسالة مناسبة لـ sleeping disorder', () {
      String result = logic.getWelcomeMessage('sleeping disorder');
      expect(result, 'Rest is part of healing—take it one night at a time');
    });

    test('u.3: يجب أن تعرض رسالة مناسبة لـ social disorder', () {
      String result = logic.getWelcomeMessage('social disorder');
      expect(result, 'Small social steps still count as wins');
    });

    test('u.4: يجب أن تعرض رسالة مناسبة لـ obsessive habits', () {
      String result = logic.getWelcomeMessage('obsessive habits');
      expect(result, 'Gentle structure beats harsh pressure');
    });

    test('u.5: يجب أن تعرض رسالة مناسبة لـ cognitive disorder', () {
      String result = logic.getWelcomeMessage('cognitive disorder');
      expect(result, 'Clarity comes in layers—pace yourself');
    });

    test('u.6: يجب أن تعرض رسالة مناسبة لـ ADHD', () {
      String result = logic.getWelcomeMessage('ADHD');
      expect(result, "Focus on one thing at a time");
    });

    test('u.7: يجب أن تعرض رسالة مناسبة لـ mood swings', () {
      String result = logic.getWelcomeMessage('mood swings');
      expect(result, 'Feelings can shift—ride the waves with care');
    });

    test('u.8: يجب أن تعرض رسالة مناسبة لـ mild anger issues', () {
      String result = logic.getWelcomeMessage('mild anger issues');
      expect(result, 'Pause and breathe—progress is in how you respond');
    });

    test('u.9: يجب أن تعرض رسالة افتراضية للتصنيفات غير المعروفة', () {
      String result = logic.getWelcomeMessage('unknown');
      expect(result, "Welcome back!");
    });

    test('u.9.b: يجب أن تتعامل مع المسافات واختلاف حالة الأحرف', () {
      String result = logic.getWelcomeMessage('  ADHD  ');
      expect(result, 'Focus on one thing at a time');
    });
  });

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
      int expectedDays = futureDate.difference(DateTime.now()).inDays;
      expect(result, "$expectedDays days remaining in goal period");
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

