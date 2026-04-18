// ========== lib/data/watering_flowers_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/watering_flowers_models.dart';

class WateringFlowersData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _kUnlocked = 'watering_max_unlocked_level_v1';
  static const _kReduceMotion = 'watering_reduce_motion_v1';

  static final List<WateringLevelConfig> levels = [
    WateringLevelConfig(
      id: 1,
      levelTitle: 'Round 1 — Two sprouts',
      tier: 'Easy',
      seconds: 60,
      waterMax: 150,
      plantCount: 2,
      waterCostPerTap: 5.0,
      patienceDrainPerSecond: 0.048,
      demandIntervalMinSec: 5,
      demandIntervalMaxSec: 10,
      pointsPerWater: 12,
      pointsLostPerDeadPlant: 16,
      uselessTapPenalty: 1,
    ),
    WateringLevelConfig(
      id: 2,
      levelTitle: 'Round 2 — Three beds',
      tier: 'Easy',
      seconds: 62,
      waterMax: 144,
      plantCount: 3,
      waterCostPerTap: 5.2,
      patienceDrainPerSecond: 0.054,
      demandIntervalMinSec: 4,
      demandIntervalMaxSec: 9,
      pointsPerWater: 12,
      pointsLostPerDeadPlant: 18,
      uselessTapPenalty: 1,
    ),
    WateringLevelConfig(
      id: 3,
      levelTitle: 'Round 3 — Four patches',
      tier: 'Easy',
      seconds: 64,
      waterMax: 138,
      plantCount: 4,
      waterCostPerTap: 5.4,
      patienceDrainPerSecond: 0.060,
      demandIntervalMinSec: 4,
      demandIntervalMaxSec: 8,
      pointsPerWater: 12,
      pointsLostPerDeadPlant: 20,
      uselessTapPenalty: 1,
    ),
    WateringLevelConfig(
      id: 4,
      levelTitle: 'Round 4 — Six in the field',
      tier: 'Easy+',
      seconds: 62,
      waterMax: 132,
      plantCount: 6,
      waterCostPerTap: 5.6,
      patienceDrainPerSecond: 0.068,
      demandIntervalMinSec: 3,
      demandIntervalMaxSec: 8,
      pointsPerWater: 11,
      pointsLostPerDeadPlant: 22,
      uselessTapPenalty: 2,
    ),
    WateringLevelConfig(
      id: 5,
      levelTitle: 'Round 5 — Thirst rush (6 plants)',
      tier: 'Medium',
      seconds: 60,
      waterMax: 126,
      plantCount: 6,
      waterCostPerTap: 5.9,
      patienceDrainPerSecond: 0.086,
      demandIntervalMinSec: 2,
      demandIntervalMaxSec: 5,
      pointsPerWater: 11,
      pointsLostPerDeadPlant: 24,
      uselessTapPenalty: 2,
    ),
    WateringLevelConfig(
      id: 6,
      levelTitle: 'Round 6 — Wave pressure',
      tier: 'Medium',
      seconds: 58,
      waterMax: 120,
      plantCount: 6,
      waterCostPerTap: 6.2,
      patienceDrainPerSecond: 0.096,
      demandIntervalMinSec: 2,
      demandIntervalMaxSec: 4,
      pointsPerWater: 11,
      pointsLostPerDeadPlant: 26,
      uselessTapPenalty: 2,
    ),
    WateringLevelConfig(
      id: 7,
      levelTitle: 'Round 7 — Tight timer',
      tier: 'Hard',
      seconds: 56,
      waterMax: 114,
      plantCount: 6,
      waterCostPerTap: 6.5,
      patienceDrainPerSecond: 0.106,
      demandIntervalMinSec: 2,
      demandIntervalMaxSec: 4,
      pointsPerWater: 10,
      pointsLostPerDeadPlant: 28,
      uselessTapPenalty: 2,
    ),
    WateringLevelConfig(
      id: 8,
      levelTitle: 'Round 8 — Dry spell',
      tier: 'Hard',
      seconds: 54,
      waterMax: 108,
      plantCount: 6,
      waterCostPerTap: 6.8,
      patienceDrainPerSecond: 0.116,
      demandIntervalMinSec: 1,
      demandIntervalMaxSec: 3,
      pointsPerWater: 10,
      pointsLostPerDeadPlant: 30,
      uselessTapPenalty: 3,
    ),
    WateringLevelConfig(
      id: 9,
      levelTitle: 'Round 9 — Expert garden',
      tier: 'Expert',
      seconds: 52,
      waterMax: 102,
      plantCount: 6,
      waterCostPerTap: 7.1,
      patienceDrainPerSecond: 0.124,
      demandIntervalMinSec: 1,
      demandIntervalMaxSec: 3,
      pointsPerWater: 10,
      pointsLostPerDeadPlant: 32,
      uselessTapPenalty: 3,
    ),
    WateringLevelConfig(
      id: 10,
      levelTitle: 'Round 10 — Final stand',
      tier: 'Expert',
      seconds: 50,
      waterMax: 96,
      plantCount: 6,
      waterCostPerTap: 7.4,
      patienceDrainPerSecond: 0.136,
      demandIntervalMinSec: 1,
      demandIntervalMaxSec: 2,
      pointsPerWater: 9,
      pointsLostPerDeadPlant: 34,
      uselessTapPenalty: 3,
    ),
  ];

  static WateringLevelConfig? levelById(int id) {
    for (final l in levels) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid};
    }
    return null;
  }

  Future<int> loadMaxUnlockedLevel() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kUnlocked) ?? 1;
  }

  Future<void> saveMaxUnlockedLevel(int levelId) async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt(_kUnlocked) ?? 1;
    if (levelId > cur) await p.setInt(_kUnlocked, levelId);
  }

  Future<bool> loadReduceMotion() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kReduceMotion) ?? false;
  }

  Future<void> saveReduceMotion(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kReduceMotion, value);
  }

  Future<void> saveScoreToFirebase(
    String userId,
    int pointsEarned,
    int flowersWatered,
    int totalFlowers,
    bool won,
    String difficulty,
    int timeLeft, {
    int? levelId,
    int? stars,
    double? waterRemainingRatio,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final gameStatsRef = _firestore.collection('game_stats').doc(userId);

      if (pointsEarned > 0) {
        await userRef.update({'points': FieldValue.increment(pointsEarned)});
      }

      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        final int currentHighest =
            (gameStatsDoc.data()?['highestScore'] as int?) ?? 0;
        final int newHighest =
            pointsEarned > currentHighest ? pointsEarned : currentHighest;

        await gameStatsRef.update({
          'totalFlowersWatered': FieldValue.increment(flowersWatered),
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(won ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set({
          'uid': userId,
          'totalFlowersWatered': flowersWatered,
          'totalGamesPlayed': 1,
          'totalWins': won ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Garden Care',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add({
        'uid': userId,
        'gameName': 'Garden Care',
        'score': pointsEarned,
        'flowersWatered': flowersWatered,
        'totalFlowers': totalFlowers,
        'won': won,
        'difficulty': difficulty,
        'timeRemaining': timeLeft,
        if (levelId != null) 'levelId': levelId,
        if (stars != null) 'stars': stars,
        if (waterRemainingRatio != null)
          'waterRemainingRatio': waterRemainingRatio,
        'playedAt': FieldValue.serverTimestamp(),
      });

      if (pointsEarned > 0) {
        debugPrint('Score saved successfully: $pointsEarned points');
      }
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }
}
