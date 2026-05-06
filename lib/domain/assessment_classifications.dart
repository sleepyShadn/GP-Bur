/// Internal-only bucket: crisis / severe risk — no habit activities; user is
/// directed to professional or emergency care (see [analyzeMood] prompt).
const String kProfessionalSupportReferralClassification =
    'professional support referral';

/// Safe copy when the model omits a goal for [kProfessionalSupportReferralClassification].
const String kProfessionalEscalationFallbackGoal =
    'Your safety matters most. If you are in immediate danger or thinking about '
    'hurting yourself or someone else, contact your local emergency number right away. '
    'Otherwise, please reach out to a licensed mental health professional or your doctor '
    'as soon as you can. This app cannot replace in-person care.';

/// Categories the home AI may assign (lowercase for Firestore + API validation).
const List<String> kAssessmentClassifications = <String>[
  'sleeping disorder',
  'social disorder',
  'obsessive habits',
  'cognitive disorder',
  'adhd',
  'mood swings',
  'mild anger issues',
  kProfessionalSupportReferralClassification,
];
