// ========== lib/domain/home_logic.dart ==========
import 'package:flutter/material.dart';

import 'mood_input_verdict.dart';

class HomeLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xff7f9461);
  final Color colorGreenLight = const Color(0xFFC1CFA1);

  String getWelcomeMessage(String currentClassification) {
    if (currentClassification.isEmpty) {
      return "Welcome back! How are you feeling today?";
    }

    final String key = currentClassification.toLowerCase().trim();
    final Map<String, String> welcomeMessages = <String, String>{
      'sleeping disorder':
          'Rest is part of healing—take it one night at a time',
      'social disorder': 'Small social steps still count as wins',
      'obsessive habits': 'Gentle structure beats harsh pressure',
      'cognitive disorder': 'Clarity comes in layers—pace yourself',
      'adhd': 'Focus on one thing at a time',
      'mood swings': 'Feelings can shift—ride the waves with care',
      'mild anger issues': 'Pause and breathe—progress is in how you respond',
    };

    return welcomeMessages[key] ?? 'Welcome back!';
  }

  String getGoalStatusMessage(bool isGoalCompleted, DateTime? goalExpiryDate) {
    if (isGoalCompleted) {
      return "✓ Goal Completed - Great job!";
    } else if (goalExpiryDate != null) {
      int daysLeft = goalExpiryDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        return "✓ Goal Period Ended - Well done!";
      } else {
        return "$daysLeft days remaining in goal period";
      }
    }
    return "";
  }

  bool isActivityCompletedToday(Map<String, dynamic> activity) {
    DateTime now = DateTime.now();
    String todayKey = '${now.year}-${now.month}-${now.day}';

    Map<String, dynamic>? dailyHistory = activity['dailyHistory'];
    if (dailyHistory != null && dailyHistory[todayKey] == true) {
      return true;
    }

    DateTime? lastCompleted = activity['lastCompletedDate'];
    if (lastCompleted != null) {
      return lastCompleted.year == now.year &&
          lastCompleted.month == now.month &&
          lastCompleted.day == now.day;
    }

    return false;
  }

  void showDailyLimitMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Text(
            'You have reached the daily limit for symptom entries (2 per day). Please return tomorrow to provide further updates.',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        backgroundColor: colorGreenDark,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void showPositivePopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text(
          "Wonderful to hear!",
          style: TextStyle(color: Color(0xff7f9461), fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_very_satisfied, color: Color(0xff7f9461), size: 60),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff7f9461).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "No mental health conditions are flagged within our current system. Keep up the positive outlook!",
                style: TextStyle(color: Color(0xff7f9461), fontSize: 16, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xff7f9461),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text(
                "Got it!",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps screening outcomes to dialogs (English-only app).
  void showMoodInputRejection(BuildContext context, MoodInputVerdict verdict) {
    if (verdict == MoodInputVerdict.purelyPositive) {
      showPositivePopup(context);
      return;
    }
    if (verdict == MoodInputVerdict.gibberish) {
      showRandomTextError(context);
      return;
    }

    final String message = switch (verdict) {
      MoodInputVerdict.emptyInput =>
        'Please write something first before continuing.',
      MoodInputVerdict.textTooShort =>
        'Please write a bit more in English (at least a few words and 15 characters) about how you feel, your mood, stress, or sleep.',
      MoodInputVerdict.textTooLong =>
        'Your message is too long. Please shorten it and try again.',
      MoodInputVerdict.englishOnlyViolation =>
        'This check-in is English only. Do not use Arabic or other alphabets—describe your feelings or wellbeing in English.',
      MoodInputVerdict.offTopic =>
        'That doesn’t sound like feelings or mental wellbeing. Please write in English about your mood, stress, sleep, thoughts, relationships, or how your day feels.',
      MoodInputVerdict.gibberish => '',
      MoodInputVerdict.purelyPositive => '',
      MoodInputVerdict.okContinue => '',
    };

    if (message.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Icon(
          verdict == MoodInputVerdict.englishOnlyViolation
              ? Icons.translate_rounded
              : Icons.info_outline_rounded,
          color: const Color(0xff7f9461),
          size: 48,
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xff7f9461),
            fontSize: 16,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        actions: <Widget>[
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xff7f9461),
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showRandomTextError(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Icon(Icons.error_outline, color: Colors.red, size: 50),
        content: const Text(
          "That looks random or impossible to read (keyboard mash, nonsense, or filler). Please type real English about how you're feeling.",
          style: TextStyle(color: Color(0xff7f9461), fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xff7f9461),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text('Error', style: TextStyle(color: Color(0xff7f9461))),
        content: Text(message, style: const TextStyle(color: Color(0xff7f9461))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xff7f9461))),
          ),
        ],
      ),
    );
  }

  void showRecurringDiagnosisNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Our system identified a recurring pattern in your recent logs.'),
        backgroundColor: colorGreenDark,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

