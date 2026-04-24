import 'package:flutter_test/flutter_test.dart';
import 'package:appforhumman/domain/garden_care_logic.dart';

void main() {
  group('GardenCareLogic.reconcile', () {
    test('no decay same calendar day as last activity', () {
      final DateTime t = DateTime(2026, 4, 23, 10, 0);
      final String day = GardenCareLogic.careDayKey(t);
      final GardenCareReconcileResult r = GardenCareLogic.reconcile(
        vitality: 90,
        lastActivityDayKey: day,
        careEvaluatedDayKey: day,
        now: t,
      );
      expect(r.vitality, 90);
      expect(r.decayApplied, 0);
    });

    test('decay after missed calendar days, capped per session', () {
      final String lastAct = GardenCareLogic.careDayKey(DateTime(2026, 4, 20));
      final DateTime now = DateTime(2026, 4, 23, 9, 0);
      final GardenCareReconcileResult r = GardenCareLogic.reconcile(
        vitality: 94,
        lastActivityDayKey: lastAct,
        careEvaluatedDayKey: lastAct,
        now: now,
      );
      expect(r.decayApplied, lessThanOrEqualTo(GardenCareLogic.maxDecayPerReconcile));
      expect(r.vitality, lessThan(94));
      expect(r.vitality, greaterThanOrEqualTo(0));
    });

    test('no extra pass when care already evaluated through today', () {
      final DateTime now = DateTime(2026, 4, 23, 15, 0);
      final String today = GardenCareLogic.careDayKey(now);
      final GardenCareReconcileResult r = GardenCareLogic.reconcile(
        vitality: 80,
        lastActivityDayKey: GardenCareLogic.careDayKey(DateTime(2026, 4, 10)),
        careEvaluatedDayKey: today,
        now: now,
      );
      expect(r.vitality, 80);
      expect(r.decayApplied, 0);
    });
  });

  group('GardenCareLogic.boostedVitality', () {
    test('clamps to 100', () {
      expect(GardenCareLogic.boostedVitality(95, 16), 100);
    });
  });
}
