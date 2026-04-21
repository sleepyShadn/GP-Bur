import 'mood_input_verdict.dart';

/// Local rules before calling the API (English-only app; no Arabic).
class FeelingInputValidation {
  FeelingInputValidation._();

  static const int minCharsInitial = 15;
  static const int minWordsInitial = 3;
  static const int maxChars = 4000;

  /// Arabic + Arabic Supplement + Arabic Extended-A + Presentation forms.
  static final RegExp _arabicScript = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  /// Initial “how are you feeling” box — stricter.
  static MoodInputVerdict checkLocalInitial(String text) {
    final String t = text.trim();
    if (t.isEmpty) {
      return MoodInputVerdict.emptyInput;
    }
    if (t.length > maxChars) {
      return MoodInputVerdict.textTooLong;
    }
    if (_arabicScript.hasMatch(t)) {
      return MoodInputVerdict.englishOnlyViolation;
    }
    final List<String> words = t
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.length < minWordsInitial) {
      return MoodInputVerdict.textTooShort;
    }
    final int latinWordMatches = RegExp(r'[A-Za-z]{2,}').allMatches(t).length;
    if (latinWordMatches < 2) {
      return MoodInputVerdict.englishOnlyViolation;
    }
    if (t.length < minCharsInitial) {
      return MoodInputVerdict.textTooShort;
    }
    return MoodInputVerdict.okContinue;
  }

  /// Follow-up answers — lighter length, same English / Arabic rules.
  static MoodInputVerdict checkLocalFollowUp(String text) {
    final String t = text.trim();
    if (t.isEmpty) {
      return MoodInputVerdict.emptyInput;
    }
    if (t.length > maxChars) {
      return MoodInputVerdict.textTooLong;
    }
    if (_arabicScript.hasMatch(t)) {
      return MoodInputVerdict.englishOnlyViolation;
    }
    if (t.length < 2) {
      return MoodInputVerdict.textTooShort;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(t)) {
      return MoodInputVerdict.englishOnlyViolation;
    }
    return MoodInputVerdict.okContinue;
  }
}
