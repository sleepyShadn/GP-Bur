// ========== lib/data/harvest_run_data.dart ==========
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/harvest_run_models.dart';

class HarvestRunData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _kUnlocked = 'harvest_run_max_unlocked_v1';

  static final List<HarvestLevelConfig> levels = <HarvestLevelConfig>[
    HarvestLevelConfig(
      id: 1,
      title: 'Farm gate — warm up',
      seconds: 54,
      fieldSize: 8,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1 — Starter crate',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 2,
            HarvestCrop.carrot: 1,
          },
          patienceSeconds: 44,
        ),
        HarvestBasketOrder(
          title: 'Order 2 — Side salad',
          need: <HarvestCrop, int>{HarvestCrop.lettuce: 1},
          patienceSeconds: 30,
        ),
      ],
      pointsPerPick: 14,
      uselessTapPenalty: 2,
      completionBonus: 22,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 2,
      title: 'Two-stop market',
      seconds: 60,
      fieldSize: 10,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1 — Soup base',
          need: <HarvestCrop, int>{
            HarvestCrop.carrot: 2,
            HarvestCrop.tomato: 1,
          },
          patienceSeconds: 46,
        ),
        HarvestBasketOrder(
          title: 'Order 2 — Spice run',
          need: <HarvestCrop, int>{HarvestCrop.pepper: 1, HarvestCrop.corn: 1},
          patienceSeconds: 34,
        ),
      ],
      pointsPerPick: 13,
      uselessTapPenalty: 2,
      completionBonus: 24,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 3,
      title: 'Triple tickets',
      seconds: 66,
      fieldSize: 12,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1 — Red & green',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 2,
            HarvestCrop.lettuce: 1,
          },
          patienceSeconds: 42,
        ),
        HarvestBasketOrder(
          title: 'Order 2 — Roots',
          need: <HarvestCrop, int>{HarvestCrop.carrot: 2},
          patienceSeconds: 32,
        ),
        HarvestBasketOrder(
          title: 'Order 3 — Golden top',
          need: <HarvestCrop, int>{HarvestCrop.corn: 1},
          patienceSeconds: 26,
        ),
      ],
      pointsPerPick: 12,
      uselessTapPenalty: 3,
      completionBonus: 28,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 4,
      title: 'Rush hour crates',
      seconds: 66,
      fieldSize: 14,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1 — Salsa pack',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 3,
            HarvestCrop.pepper: 1,
          },
          patienceSeconds: 40,
        ),
        HarvestBasketOrder(
          title: 'Order 2 — Crunch mix',
          need: <HarvestCrop, int>{
            HarvestCrop.carrot: 2,
            HarvestCrop.lettuce: 1,
          },
          patienceSeconds: 36,
        ),
      ],
      pointsPerPick: 12,
      uselessTapPenalty: 3,
      completionBonus: 30,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 5,
      title: 'Four baskets',
      seconds: 72,
      fieldSize: 16,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1',
          need: <HarvestCrop, int>{HarvestCrop.tomato: 2, HarvestCrop.corn: 1},
          patienceSeconds: 38,
        ),
        HarvestBasketOrder(
          title: 'Order 2',
          need: <HarvestCrop, int>{HarvestCrop.carrot: 2},
          patienceSeconds: 30,
        ),
        HarvestBasketOrder(
          title: 'Order 3',
          need: <HarvestCrop, int>{HarvestCrop.lettuce: 2},
          patienceSeconds: 28,
        ),
        HarvestBasketOrder(
          title: 'Order 4',
          need: <HarvestCrop, int>{HarvestCrop.pepper: 1, HarvestCrop.tomato: 1},
          patienceSeconds: 32,
        ),
      ],
      pointsPerPick: 11,
      uselessTapPenalty: 3,
      completionBonus: 34,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 6,
      title: 'Heavy harvest',
      seconds: 74,
      fieldSize: 18,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1 — Grill pack',
          need: <HarvestCrop, int>{
            HarvestCrop.pepper: 2,
            HarvestCrop.corn: 2,
          },
          patienceSeconds: 38,
        ),
        HarvestBasketOrder(
          title: 'Order 2 — Salad bowl',
          need: <HarvestCrop, int>{
            HarvestCrop.lettuce: 2,
            HarvestCrop.tomato: 2,
          },
          patienceSeconds: 38,
        ),
        HarvestBasketOrder(
          title: 'Order 3 — Roots',
          need: <HarvestCrop, int>{HarvestCrop.carrot: 3},
          patienceSeconds: 34,
        ),
      ],
      pointsPerPick: 11,
      uselessTapPenalty: 3,
      completionBonus: 36,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 7,
      title: 'Wholesale lane',
      seconds: 78,
      fieldSize: 20,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 3,
            HarvestCrop.carrot: 2,
          },
          patienceSeconds: 40,
        ),
        HarvestBasketOrder(
          title: 'Order 2',
          need: <HarvestCrop, int>{
            HarvestCrop.lettuce: 2,
            HarvestCrop.pepper: 1,
            HarvestCrop.corn: 1,
          },
          patienceSeconds: 38,
        ),
        HarvestBasketOrder(
          title: 'Order 3',
          need: <HarvestCrop, int>{
            HarvestCrop.corn: 2,
            HarvestCrop.tomato: 2,
          },
          patienceSeconds: 36,
        ),
      ],
      pointsPerPick: 10,
      uselessTapPenalty: 4,
      completionBonus: 40,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 8,
      title: 'Full truck',
      seconds: 82,
      fieldSize: 22,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1',
          need: <HarvestCrop, int>{
            HarvestCrop.carrot: 3,
            HarvestCrop.lettuce: 2,
          },
          patienceSeconds: 42,
        ),
        HarvestBasketOrder(
          title: 'Order 2',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 3,
            HarvestCrop.pepper: 2,
          },
          patienceSeconds: 40,
        ),
        HarvestBasketOrder(
          title: 'Order 3',
          need: <HarvestCrop, int>{HarvestCrop.corn: 2, HarvestCrop.lettuce: 1},
          patienceSeconds: 34,
        ),
      ],
      pointsPerPick: 10,
      uselessTapPenalty: 4,
      completionBonus: 44,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 9,
      title: 'Night market',
      seconds: 86,
      fieldSize: 24,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 3,
            HarvestCrop.carrot: 2,
            HarvestCrop.pepper: 1,
          },
          patienceSeconds: 44,
        ),
        HarvestBasketOrder(
          title: 'Order 2',
          need: <HarvestCrop, int>{
            HarvestCrop.lettuce: 3,
            HarvestCrop.corn: 2,
          },
          patienceSeconds: 42,
        ),
        HarvestBasketOrder(
          title: 'Order 3',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 2,
            HarvestCrop.carrot: 2,
            HarvestCrop.corn: 1,
          },
          patienceSeconds: 40,
        ),
      ],
      pointsPerPick: 9,
      uselessTapPenalty: 4,
      completionBonus: 48,
      timeBonusPerSecondLeft: 2,
    ),
    HarvestLevelConfig(
      id: 10,
      title: 'Export rush',
      seconds: 90,
      fieldSize: 26,
      orders: <HarvestBasketOrder>[
        HarvestBasketOrder(
          title: 'Order 1',
          need: <HarvestCrop, int>{
            HarvestCrop.tomato: 4,
            HarvestCrop.lettuce: 2,
          },
          patienceSeconds: 46,
        ),
        HarvestBasketOrder(
          title: 'Order 2',
          need: <HarvestCrop, int>{
            HarvestCrop.carrot: 3,
            HarvestCrop.pepper: 2,
            HarvestCrop.corn: 1,
          },
          patienceSeconds: 44,
        ),
        HarvestBasketOrder(
          title: 'Order 3',
          need: <HarvestCrop, int>{
            HarvestCrop.corn: 3,
            HarvestCrop.tomato: 2,
            HarvestCrop.lettuce: 2,
          },
          patienceSeconds: 46,
        ),
        HarvestBasketOrder(
          title: 'Order 4 — Finale',
          need: <HarvestCrop, int>{
            HarvestCrop.carrot: 2,
            HarvestCrop.pepper: 2,
          },
          patienceSeconds: 36,
        ),
      ],
      pointsPerPick: 9,
      uselessTapPenalty: 4,
      completionBonus: 54,
      timeBonusPerSecondLeft: 2,
    ),
  ];

  static HarvestLevelConfig? levelById(int id) {
    for (final HarvestLevelConfig l in levels) {
      if (l.id == id) return l;
    }
    return null;
  }

  static String missionBrief(HarvestLevelConfig c) {
    final int n = c.orders.length;
    final int picks = c.totalPicksAllOrders;
    return '🧺 ${c.title}\n'
        'Complete $n basket order(s) — $picks picks total. '
        'Each order lists how many of each crop; tap the field rows to fill your crate. '
        'Wrong taps cost points. Each order has its own patience bar — don’t let it empty! '
        'Finish everything before the big timer hits zero.';
  }

  /// Short lines for the pre-game card (same spirit as Apple Picking benefits).
  static const List<String> gameBenefitLines = <String>[
    'Sharpens planning: read the receipt, then harvest in any order.',
    'Builds calm focus while each basket’s patience bar counts down.',
    'Rewards clean runs — finish early for time bonus points.',
  ];

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      return <String, dynamic>{'uid': user.uid};
    }
    return null;
  }

  Future<int> loadMaxUnlockedLevel() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getInt(_kUnlocked) ?? 1;
  }

  Future<void> saveMaxUnlockedLevel(int levelId) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final int cur = p.getInt(_kUnlocked) ?? 1;
    if (levelId > cur) await p.setInt(_kUnlocked, levelId);
  }

  /// Credits wallet points immediately, then writes stats/history in the background.
  Future<void> saveScoreToFirebase(
    String userId,
    int pointsEarned,
    int picksCompleted,
    int orderLength,
    bool won,
    String roundTitle,
    int timeLeft, {
    int? levelId,
  }) async {
    try {
      if (pointsEarned > 0) {
        await _firestore.collection('users').doc(userId).update(<String, dynamic>{
          'points': FieldValue.increment(pointsEarned),
        });
        debugPrint('Harvest Run wallet +$pointsEarned');
      }
      unawaited(
        _persistHarvestStatsAndHistory(
          userId: userId,
          pointsEarned: pointsEarned,
          picksCompleted: picksCompleted,
          orderLength: orderLength,
          won: won,
          roundTitle: roundTitle,
          timeLeft: timeLeft,
          levelId: levelId,
        ),
      );
    } catch (e) {
      debugPrint('Harvest Run save error: $e');
    }
  }

  Future<void> _persistHarvestStatsAndHistory({
    required String userId,
    required int pointsEarned,
    required int picksCompleted,
    required int orderLength,
    required bool won,
    required String roundTitle,
    required int timeLeft,
    int? levelId,
  }) async {
    try {
      final gameStatsRef = _firestore.collection('game_stats').doc(userId);
      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        final int currentHighest =
            (gameStatsDoc.data()?['highestScore'] as int?) ?? 0;
        final int newHighest =
            pointsEarned > currentHighest ? pointsEarned : currentHighest;

        await gameStatsRef.update(<String, dynamic>{
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(won ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set(<String, dynamic>{
          'uid': userId,
          'totalGamesPlayed': 1,
          'totalWins': won ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Harvest Run',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add(<String, dynamic>{
        'uid': userId,
        'gameName': 'Harvest Run',
        'score': pointsEarned,
        'picksCompleted': picksCompleted,
        'orderLength': orderLength,
        'won': won,
        'difficulty': roundTitle,
        'timeRemaining': timeLeft,
        if (levelId != null) 'levelId': levelId,
        'playedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Harvest Run stats/history error: $e');
    }
  }
}
