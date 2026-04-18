import 'package:flutter/material.dart';

/// Level config: eight small plants, countdown, random water requests, patience bar.
class WateringLevelConfig {
  const WateringLevelConfig({
    required this.id,
    required this.levelTitle,
    required this.tier,
    required this.seconds,
    required this.waterMax,
    required this.plantCount,
    required this.waterCostPerTap,
    required this.patienceDrainPerSecond,
    required this.demandIntervalMinSec,
    required this.demandIntervalMaxSec,
    required this.pointsPerWater,
    required this.pointsLostPerDeadPlant,
    this.uselessTapPenalty = 2,
  });

  final int id;
  final String levelTitle;
  final String tier;

  /// Round length in seconds (countdown).
  final int seconds;

  /// Water tank — each tap uses [waterCostPerTap].
  final double waterMax;

  /// Target plant count (UI uses eight slots).
  final int plantCount;

  final double waterCostPerTap;

  /// Patience bar drain per second while a plant is waiting for water.
  final double patienceDrainPerSecond;

  /// Seconds between demand waves (random between min and max).
  final int demandIntervalMinSec;
  final int demandIntervalMaxSec;

  final int pointsPerWater;

  /// Points subtracted per plant that died during the round (at score tally).
  final int pointsLostPerDeadPlant;

  /// Small penalty for tapping a plant that is not thirsty.
  final int uselessTapPenalty;
}

class WateringPlant {
  WateringPlant({
    required this.id,
    required this.x,
    required this.y,
    required this.accentColor,
    required this.size,
    required this.lottieAsset,
    required this.idealMin,
    required this.idealMax,
    this.wantsWater = true,
    this.wantsFertilizer = false,
    this.isWeed = false,
    this.fertIdealMin = 0.34,
    this.fertIdealMax = 0.82,
    this.moisture = 0.72,
    this.fertilizer = 0.28,
    this.awaitingWater = false,
    this.isDead = false,
    this.patience = 1.0,
  });

  final int id;
  final double x;
  final double y;
  final Color accentColor;
  final double size;

  /// One of the plant Lottie asset paths.
  final String lottieAsset;

  final double idealMin;
  final double idealMax;
  final bool wantsWater;
  final bool wantsFertilizer;
  final bool isWeed;
  final double fertIdealMin;
  final double fertIdealMax;
  double moisture;
  double fertilizer;

  /// Random thirst — [patience] drains until death if not watered.
  bool awaitingWater;

  bool isDead;

  /// 1.0 = full patience; at 0 the plant dies if it was waiting for water.
  double patience;

  /// Legacy helper for decorative Lottie / mood.
  bool isSatisfied(WateringLevelConfig cfg) {
    if (isWeed) return true;
    if (isDead) return false;
    if (awaitingWater) return false;
    if (wantsWater && (moisture < idealMin || moisture > idealMax)) {
      return false;
    }
    if (wantsFertilizer &&
        (fertilizer < fertIdealMin || fertilizer > fertIdealMax)) {
      return false;
    }
    return wantsWater || wantsFertilizer;
  }
}
