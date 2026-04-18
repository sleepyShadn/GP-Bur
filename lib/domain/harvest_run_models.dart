// ========== lib/domain/harvest_run_models.dart ==========

/// Crops shown in the field and used in basket orders.
enum HarvestCrop {
  tomato,
  carrot,
  lettuce,
  pepper,
  corn,
}

extension HarvestCropVisual on HarvestCrop {
  String get emoji {
    return switch (this) {
      HarvestCrop.tomato => '🍅',
      HarvestCrop.carrot => '🥕',
      HarvestCrop.lettuce => '🥬',
      HarvestCrop.pepper => '🌶️',
      HarvestCrop.corn => '🌽',
    };
  }

  String get shortName {
    return switch (this) {
      HarvestCrop.tomato => 'Tomato',
      HarvestCrop.carrot => 'Carrot',
      HarvestCrop.lettuce => 'Lettuce',
      HarvestCrop.pepper => 'Pepper',
      HarvestCrop.corn => 'Corn',
    };
  }

  /// Row / patch label in the playfield.
  String get patchLabel {
    return switch (this) {
      HarvestCrop.tomato => 'Tomato rows',
      HarvestCrop.carrot => 'Carrot bed',
      HarvestCrop.lettuce => 'Lettuce patch',
      HarvestCrop.pepper => 'Pepper strip',
      HarvestCrop.corn => 'Corn lane',
    };
  }
}

/// One customer-style basket: pick counts per crop (any order of taps).
class HarvestBasketOrder {
  const HarvestBasketOrder({
    required this.title,
    required this.need,
    required this.patienceSeconds,
  });

  final String title;
  final Map<HarvestCrop, int> need;
  final int patienceSeconds;

  int get totalPicks {
    int s = 0;
    for (final int n in need.values) {
      s += n;
    }
    return s;
  }

  Map<HarvestCrop, int> copyNeed() {
    return Map<HarvestCrop, int>.from(need);
  }
}

/// One difficulty step: timed round with one or more basket orders.
class HarvestLevelConfig {
  const HarvestLevelConfig({
    required this.id,
    required this.title,
    required this.seconds,
    required this.fieldSize,
    required this.orders,
    required this.pointsPerPick,
    required this.uselessTapPenalty,
    required this.completionBonus,
    required this.timeBonusPerSecondLeft,
  });

  final int id;
  final String title;

  /// Countdown for the whole round (all orders).
  final int seconds;

  /// Number of tiles in the field (>= total picks + decoys).
  final int fieldSize;

  /// Complete in order: finish order[0], then order[1], …
  final List<HarvestBasketOrder> orders;

  final int pointsPerPick;
  final int uselessTapPenalty;
  final int completionBonus;

  /// Extra score per second remaining when all orders are done.
  final int timeBonusPerSecondLeft;

  int get totalPicksAllOrders {
    int s = 0;
    for (final HarvestBasketOrder o in orders) {
      s += o.totalPicks;
    }
    return s;
  }

  Map<HarvestCrop, int> totalNeedMerged() {
    final Map<HarvestCrop, int> m = <HarvestCrop, int>{};
    for (final HarvestBasketOrder o in orders) {
      for (final MapEntry<HarvestCrop, int> e in o.need.entries) {
        m[e.key] = (m[e.key] ?? 0) + e.value;
      }
    }
    return m;
  }
}

/// A single tappable tile in the patch.
class HarvestFieldTile {
  HarvestFieldTile({
    required this.slotIndex,
    required this.crop,
    this.harvested = false,
  });

  final int slotIndex;
  final HarvestCrop crop;
  bool harvested;
}
