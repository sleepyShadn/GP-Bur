/// Outcome of screening the user's mood text (local + API layers).
enum MoodInputVerdict {
  /// Proceed with the flow (ask questions or analyze).
  okContinue,

  emptyInput,
  textTooShort,
  textTooLong,

  /// Arabic or other blocked scripts / not enough English.
  englishOnlyViolation,

  /// Random or unintelligible (API or strict local fallback).
  gibberish,

  /// Coherent English but not about feelings / wellbeing context.
  offTopic,

  /// Clearly positive with nothing to assess (existing “wonderful” path).
  purelyPositive,
}
