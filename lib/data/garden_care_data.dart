// ========== lib/data/garden_care_data.dart ==========
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/garden_care_logic.dart';

/// Snapshot after reconcile, for UI + notification scheduling.
class GardenCarePublicState {
  const GardenCarePublicState({
    required this.vitality,
    required this.lastActivityDayKey,
    required this.hasPlants,
  });

  final int vitality;
  final String lastActivityDayKey;
  final bool hasPlants;
}

/// Persists garden vitality + day keys on `users/{uid}`.
class GardenCareData {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _kVitality = 'gardenVitality';
  static const String _kLastActivityDay = 'gardenLastActivityDay';
  static const String _kCareEvaluatedDay = 'gardenCareEvaluatedDay';

  Future<Map<String, dynamic>?> _readUserFields(String userId) async {
    if (userId.isEmpty) return null;
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Loads fields, reconciles idle decay (capped), writes back if needed.
  Future<int> loadAndReconcileVitality(String userId) async {
    if (userId.isEmpty) return GardenCareLogic.defaultVitality;

    final Map<String, dynamic>? data = await _readUserFields(userId);
    final DateTime now = DateTime.now();
    final String todayKey = GardenCareLogic.careDayKey(now);

    if (data == null) {
      await _firestore.collection('users').doc(userId).set(
        <String, dynamic>{
          _kVitality: GardenCareLogic.defaultVitality,
          _kLastActivityDay: todayKey,
          _kCareEvaluatedDay: todayKey,
        },
        SetOptions(merge: true),
      );
      return GardenCareLogic.defaultVitality;
    }

    int vitality = (data[_kVitality] as num?)?.toInt() ??
        GardenCareLogic.defaultVitality;
    vitality = vitality.clamp(0, 100);

    String? lastAct = data[_kLastActivityDay] as String?;
    String? evalDay = data[_kCareEvaluatedDay] as String?;

    if (lastAct == null || evalDay == null) {
      await _firestore.collection('users').doc(userId).set(
        <String, dynamic>{
          _kVitality: vitality,
          _kLastActivityDay: todayKey,
          _kCareEvaluatedDay: todayKey,
        },
        SetOptions(merge: true),
      );
      return vitality.clamp(0, 100);
    }

    final GardenCareReconcileResult out = GardenCareLogic.reconcile(
      vitality: vitality,
      lastActivityDayKey: lastAct,
      careEvaluatedDayKey: evalDay,
      now: now,
    );

    final bool changed = out.vitality != vitality ||
        out.careEvaluatedDayKey != evalDay;

    if (changed) {
      await _firestore.collection('users').doc(userId).update(<String, dynamic>{
        _kVitality: out.vitality,
        _kCareEvaluatedDay: out.careEvaluatedDayKey,
      });
    }

    return out.vitality;
  }

  /// Reconciles vitality then returns fields needed for Home + local notifications.
  Future<GardenCarePublicState> loadReconcileAndDescribe(String userId) async {
    if (userId.isEmpty) {
      return GardenCarePublicState(
        vitality: GardenCareLogic.defaultVitality,
        lastActivityDayKey: GardenCareLogic.careDayKey(DateTime.now()),
        hasPlants: false,
      );
    }

    final int vitality = await loadAndReconcileVitality(userId);
    final Map<String, dynamic>? data = await _readUserFields(userId);
    final String todayKey = GardenCareLogic.careDayKey(DateTime.now());
    final String lastAct = (data?[_kLastActivityDay] as String?) ?? todayKey;
    final bool hasPlants = await userHasAnyPlant(userId);

    return GardenCarePublicState(
      vitality: vitality.clamp(0, 100),
      lastActivityDayKey: lastAct,
      hasPlants: hasPlants,
    );
  }

  /// After completing a home activity for today.
  Future<int> recordActivityCareBoost(String userId) async {
    if (userId.isEmpty) return GardenCareLogic.defaultVitality;

    final Map<String, dynamic>? data = await _readUserFields(userId);
    final String todayKey = GardenCareLogic.careDayKey(DateTime.now());

    int vitality = (data?[_kVitality] as num?)?.toInt() ??
        GardenCareLogic.defaultVitality;
    vitality = vitality.clamp(0, 100);
    vitality = GardenCareLogic.boostedVitality(
      vitality,
      GardenCareLogic.activityBoost,
    );

    await _firestore.collection('users').doc(userId).set(
      <String, dynamic>{
        _kVitality: vitality,
        _kLastActivityDay: todayKey,
        _kCareEvaluatedDay: todayKey,
      },
      SetOptions(merge: true),
    );

    return vitality;
  }

  /// Small boost when the user plants a seed (garden engagement).
  Future<bool> userHasAnyPlant(String userId) async {
    if (userId.isEmpty) return false;
    final QuerySnapshot<Map<String, dynamic>> q = await _firestore
        .collection('users')
        .doc(userId)
        .collection('garden')
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  Future<void> recordPlantCareBoost(String userId) async {
    if (userId.isEmpty) return;

    final Map<String, dynamic>? data = await _readUserFields(userId);
    int vitality = (data?[_kVitality] as num?)?.toInt() ??
        GardenCareLogic.defaultVitality;
    vitality = GardenCareLogic.boostedVitality(
      vitality.clamp(0, 100),
      GardenCareLogic.plantCareBoost,
    );

    await _firestore.collection('users').doc(userId).set(
      <String, dynamic>{_kVitality: vitality},
      SetOptions(merge: true),
    );
  }
}
