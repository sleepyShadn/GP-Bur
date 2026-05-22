import 'mood_input_verdict.dart';

/// Local rules before calling the API (English-only app; no Arabic).
class FeelingInputValidation {
  FeelingInputValidation._();

  static const int minCharsInitial = 3;
  static const int minWordsInitial = 1;
  static const int maxChars = 4000;

  /// Arabic + Arabic Supplement + Arabic Extended-A + Presentation forms.
  static final RegExp _arabicScript = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  /// Mood, stress, sleep, or emotional wellbeing (English).
  static final RegExp _wellbeingCue = RegExp(
    r"\b(feel(ing)?|felt|feels|mood|emotions?|emotional|mental|wellbeing|well-being|"
    r"stress(ed|ful)?|anxious|anxiety|worried|worry|worrying|nervous|panic|"
    r"sad(ness)?|depress(ed|ion)?|anger|angry|upset|frustrat(ed|ion)|"
    r"tired|exhaust(ed|ion)|overwhelm(ed|ing)?|lonely|loneliness|alone|isolated|"
    r"sleep|insomnia|nightmare|restless|hopeless|numb|empty|irritable|"
    r"cry(ing)?|tearful|burnout|tense|restless|unhappy|miserable|"
    r"self[- ]?harm|suicid|hurt myself|can't cope|cannot cope|struggling|"
    r"hard time|bad day|low energy|no energy|relationship|breakup|"
    r"social|isolation|concentrat(e|ion)|focus|brain fog|ruminat(e|ing))\b",
    caseSensitive: false,
  );

  /// Plans, chores, or hobbies with no emotional content.
  static final RegExp _offTopicActivityCue = RegExp(
    r"\b(gym|workout|exercis(e|ing)|jogging|running|yoga|pilates|"
    r"stud(y|ying|ies)|homework|exam(s)?|test(s)?|class(es)?|lecture|university|college|school|"
    r"assignment|coursework|revision|"
    r"shopping|groceries|supermarket|"
    r"cooking|recipe|baking|"
    r"netflix|movie|series|tv show|video game|gaming|football|basketball|soccer|"
    r"driving|commute|traffic|bus|train|"
    r"meeting at|at work|my job|office|shift|"
    r"code|coding|programming|debug|software|"
    r"pizza|restaurant|lunch|dinner|breakfast|"
    r"haircut|appointment|dentist|doctor visit)\b",
    caseSensitive: false,
  );

  static final RegExp _offTopicGoingTo = RegExp(
    r"\b(i\s*(am|'m)|we\s*(are|'re))\s+(going|headed|head|driving|walking)\s+to\b",
    caseSensitive: false,
  );

  /// True when text is coherent English but not about feelings / wellbeing.
  static bool looksOffTopicWithoutWellbeing(String text) {
    final String lower = text.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (_wellbeingCue.hasMatch(lower)) return false;

    if (_offTopicActivityCue.hasMatch(lower)) return true;

    if (_offTopicGoingTo.hasMatch(lower)) {
      if (RegExp(
        r'\b(gym|school|class|work|store|mall|cinema|movies?|library|campus|'
        r'university|college|office|park|beach|restaurant|cafe|coffee)\b',
        caseSensitive: false,
      ).hasMatch(lower)) {
        return true;
      }
    }

    if (RegExp(
      r"^\s*i\s*(am|'m)\s+(at|in|on)\s+(the\s+)?(gym|school|work|class|library|office)\s*\.?\s*$",
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    if (RegExp(
      r"^\s*(studying|working|shopping|cooking|gaming|exercising)\s*(\.|!|\?)?\s*$",
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    return false;
  }

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
    if (latinWordMatches < 1) {
      return MoodInputVerdict.englishOnlyViolation;
    }
    if (t.length < minCharsInitial) {
      return MoodInputVerdict.textTooShort;
    }
    if (looksOffTopicWithoutWellbeing(t)) {
      return MoodInputVerdict.offTopic;
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
