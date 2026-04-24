// ========== lib/domain/garden_care_logic.dart ==========
// Garden "vitality" ties home activities to the garden hub: decay on missed care
// days (with caps), boosts on activity / planting. Copy with app language (English UI).

/// Visual / copy tier from 0–100 vitality.
enum GardenVitalityTier { thriving, steady, fading }

class GardenCareReconcileResult {
  const GardenCareReconcileResult({
    required this.vitality,
    required this.lastActivityDayKey,
    required this.careEvaluatedDayKey,
    required this.decayApplied,
  });

  final int vitality;
  final String lastActivityDayKey;
  final String careEvaluatedDayKey;
  final int decayApplied;
}

class GardenCareLogic {
  static const int defaultVitality = 94;
  static const int activityBoost = 16;
  static const int plantCareBoost = 4;
  static const int decayPerMissedDay = 10;
  static const int maxDecayPerReconcile = 32;

  static String careDayKey(DateTime d) =>
      '${d.year}-${d.month}-${d.day}';

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime dateFromCareDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return _dateOnly(DateTime.now());
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  static GardenVitalityTier tierFromVitality(int vitality) {
    if (vitality >= 70) return GardenVitalityTier.thriving;
    if (vitality >= 40) return GardenVitalityTier.steady;
    return GardenVitalityTier.fading;
  }

  /// Short line for Home / Garden (English).
  static String vitalityHeadline(int vitality, {required bool hasPlants}) {
    final GardenVitalityTier t = tierFromVitality(vitality);
    switch (t) {
      case GardenVitalityTier.thriving:
        return hasPlants
            ? 'Your blooms are getting plenty of care.'
            : 'Your garden energy is bright — keep today’s activities flowing.';
      case GardenVitalityTier.steady:
        return hasPlants
            ? 'Your plants could use a little more of today’s care.'
            : 'The garden is a bit quiet — one small activity helps a lot.';
      case GardenVitalityTier.fading:
        return hasPlants
            ? 'Your flowers are losing sparkle — today’s activities bring them back.'
            : 'Things look a little faded — completing an activity restores the garden.';
    }
  }

  /// One-line hint under the bar.
  static String vitalityHint(int vitality) {
    final GardenVitalityTier t = tierFromVitality(vitality);
    switch (t) {
      case GardenVitalityTier.thriving:
        return 'Completing a suggested activity boosts garden vitality.';
      case GardenVitalityTier.steady:
        return 'Finish one activity today to stop vitality from dropping further.';
      case GardenVitalityTier.fading:
        return 'Rescue: complete any activity today for a meaningful vitality boost.';
    }
  }

  /// Applies missed-day decay for each calendar day after [careEvaluatedDayKey]
  /// up to and including [todayDate], only when [lastActivityDay] is strictly before
  /// that day (user had not yet acted on that calendar date). Idempotent per day
  /// thanks to advancing [careEvaluatedDayKey] in storage to [todayKey].
  static GardenCareReconcileResult reconcile({
    required int vitality,
    required String lastActivityDayKey,
    required String? careEvaluatedDayKey,
    required DateTime now,
  }) {
    final DateTime todayDate = _dateOnly(now);
    final String todayKey = careDayKey(now);
    final DateTime lastAct = dateFromCareDayKey(lastActivityDayKey);

    DateTime evalEnd =
        dateFromCareDayKey(careEvaluatedDayKey ?? lastActivityDayKey);

    int v = vitality.clamp(0, 100);
    int decay = 0;

    while (decay < maxDecayPerReconcile) {
      final DateTime next = evalEnd.add(const Duration(days: 1));
      if (next.isAfter(todayDate)) break;

      if (next.isAfter(lastAct)) {
        final int room = maxDecayPerReconcile - decay;
        final int step = decayPerMissedDay > room ? room : decayPerMissedDay;
        v = (v - step).clamp(0, 100);
        decay += step;
      }
      evalEnd = next;
    }

    return GardenCareReconcileResult(
      vitality: v,
      lastActivityDayKey: lastActivityDayKey,
      careEvaluatedDayKey: todayKey,
      decayApplied: decay,
    );
  }

  static int boostedVitality(int current, int delta) =>
      (current + delta).clamp(0, 100);

  /// Progress 0–1 from elapsed grow time. When [vitality] is low (missed daily activities),
  /// the plant looks a bit “behind” until the user cares again — without changing real harvest time.
  static double growthVisualProgress({
    required double timeProgress01,
    required int vitality,
  }) {
    final double care = (vitality.clamp(0, 100)) / 100.0;
    return (timeProgress01 - (1.0 - care) * 0.22).clamp(0.0, 1.0);
  }
}
