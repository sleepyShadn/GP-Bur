// ========== lib/domain/garden_logic.dart ==========
import 'package:flutter/material.dart';

class GardenLogic {
  static const String fertilizerInventoryKey = 'Fertilizer';
  static const String legacyGrowthAcceleratorKey = 'Growth Accelerator';
  static const String defaultGardenName = 'My Secret Garden';
  static const String defaultSeason = 'Spring';
  static const List<String> validSeasons = <String>[
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];

  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xff7f9461);
  final Color colorGreenLight = const Color(0xFFC1CFA1);

  String? validateGardenName(String name) {
    if (name.length < 3) {
      return 'Garden name must be at least 3 characters';
    }
    if (name.length > 20) {
      return 'Garden name must not exceed 20 characters';
    }
    final specialChars = RegExp(r'[!@#<>?":_`~;[\]\\|=+)(*&^%$£€.]');
    if (specialChars.hasMatch(name)) {
      return 'Garden name cannot contain special characters like @';
    }
    return null;
  }

  Color getSeedColor(String seedType) {
    if (seedType.contains('Regular')) return Colors.green;
    if (seedType.contains('Rare')) return Colors.blue;
    if (seedType.contains('Legendary')) return Colors.purple;
    return Colors.green;
  }

  /// Real-world growth windows (seconds). Tied to daily habits: no more “minutes to mature”.
  static const int regularGrowSeconds = 86400; // 1 day
  static const int rareGrowSeconds = 259200; // 3 days
  static const int legendaryGrowSeconds = 604800; // 7 days

  /// One use of Fertilizer: advances real growth by this many seconds (≈ one day),
  /// capped by actual time left — does not replace daily care / vitality.
  static const int growthAcceleratorAdvanceSeconds = 86400;

  static String normalizeSeason(String? season) {
    if (season != null && validSeasons.contains(season)) {
      return season;
    }
    return defaultSeason;
  }

  static int _inventoryCount(Map<String, dynamic>? inventory, String key) {
    if (inventory == null) return 0;
    final dynamic value = inventory[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Reads seeds inventory and merges legacy Growth Accelerator into Fertilizer.
  static Map<String, int> parseSeedsInventory(Map<String, dynamic>? inventory) {
    final int fertilizer = _inventoryCount(inventory, fertilizerInventoryKey) +
        _inventoryCount(inventory, legacyGrowthAcceleratorKey);
    return <String, int>{
      'Regular Seeds': _inventoryCount(inventory, 'Regular Seeds'),
      'Rare Seeds': _inventoryCount(inventory, 'Rare Seeds'),
      'Legendary Seeds': _inventoryCount(inventory, 'Legendary Seeds'),
      fertilizerInventoryKey: fertilizer,
    };
  }

  int getSeedDuration(String seedType) {
    if (seedType.contains('Regular')) return regularGrowSeconds;
    if (seedType.contains('Rare')) return rareGrowSeconds;
    if (seedType.contains('Legendary')) return legendaryGrowSeconds;
    return regularGrowSeconds;
  }

  int getHarvestPoints(String seedType) {
    if (seedType.contains('Legendary')) return 20;
    if (seedType.contains('Rare')) return 12;
    if (seedType.contains('Regular')) return 7;
    return 0;
  }

  /// Mature / harvest-ready Lottie per seed type (three bloom variants).
  ///
  /// - **Regular** → green bloom (`Plants.json`)
  /// - **Rare** → blue bloom (`Flower growing Lottie JSON animation.json`)
  /// - **Legendary** → red bloom (`flower.json`, previous default for all tiers)
  String matureBloomLottieAsset(String seedType) {
    if (seedType.contains('Rare')) {
      return 'assets/animations/Flower growing Lottie JSON animation.json';
    }
    if (seedType.contains('Legendary')) {
      return 'assets/animations/flower.json';
    }
    if (seedType.contains('Regular')) {
      return 'assets/animations/Plants.json';
    }
    return 'assets/animations/Plants.json';
  }

  Map<String, dynamic> getSeedInfo(String seedType) {
    if (seedType == 'Rare Seeds') {
      return {'color': Colors.blue, 'icon': Icons.spa, 'displayName': 'Rare'};
    } else if (seedType == 'Legendary Seeds') {
      return {'color': Colors.purple, 'icon': Icons.spa, 'displayName': 'Legendary'};
    } else if (seedType == fertilizerInventoryKey ||
        seedType == legacyGrowthAcceleratorKey) {
      return {
        'color': Colors.orange,
        'icon': Icons.eco_outlined,
        'displayName': 'Fertilizer',
      };
    } else {
      return {'color': Colors.green, 'icon': Icons.spa, 'displayName': 'Regular'};
    }
  }

  Color getBoardColor(String season) {
    switch (season) {
      case 'Spring':
        return Colors.green.shade100;
      case 'Summer':
        return Colors.yellow.shade100;
      case 'Autumn':
        return Colors.orange.shade100;
      case 'Winter':
        return Colors.blue.shade100;
      default:
        return Colors.green.shade100;
    }
  }

  IconData getSeasonIcon(String season) {
    switch (season) {
      case 'Spring':
        return Icons.grass;
      case 'Summer':
        return Icons.wb_sunny;
      case 'Autumn':
        return Icons.eco;
      case 'Winter':
        return Icons.ac_unit;
      default:
        return Icons.grass;
    }
  }

  Color getSeasonIconColor(String season) {
    switch (season) {
      case 'Spring':
        return Colors.green;
      case 'Summer':
        return Colors.yellow;
      case 'Autumn':
        return Colors.orange;
      case 'Winter':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData getSeasonIconForPicker(String season) {
    switch (season) {
      case 'Spring':
        return Icons.grass;
      case 'Summer':
        return Icons.wb_sunny;
      case 'Autumn':
        return Icons.eco;
      case 'Winter':
        return Icons.ac_unit;
      default:
        return Icons.grass;
    }
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Countdown for long growth timers (farm overlay).
  String formatGrowthRemaining(int seconds) {
    if (seconds <= 0) return 'Ready';
    if (seconds >= 86400) {
      final int d = seconds ~/ 86400;
      final int h = (seconds % 86400) ~/ 3600;
      return '${d}d ${h}h';
    }
    if (seconds >= 3600) {
      final int h = seconds ~/ 3600;
      final int m = (seconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    return formatTime(seconds);
  }

  /// Optional full-width art for the plot board (spring / summer assets).
  String? seasonalBackgroundAsset(String season) {
    switch (season) {
      case 'Spring':
        return 'assets/images/watering/watering_bg_spring.png';
      case 'Summer':
        return 'assets/images/watering/watering_bg_summer.png';
      default:
        return null;
    }
  }

  /// Sky-to-soil gradient for farm-style pages.
  List<Color> seasonalFarmGradient(String season) {
    switch (season) {
      case 'Spring':
        return const [Color(0xFFB8E0D2), Color(0xFFE8F5E9), Color(0xFFF5F0E6)];
      case 'Summer':
        return const [Color(0xFF87CEEB), Color(0xFFFFF3CD), Color(0xFFFFE4B5)];
      case 'Autumn':
        return const [Color(0xFFD4A574), Color(0xFFE8C9A8), Color(0xFFF0E6DC)];
      case 'Winter':
        return const [Color(0xFF9EB8D4), Color(0xFFE8EEF5), Color(0xFFF0F4F8)];
      default:
        return const [Color(0xFFB8E0D2), Color(0xFFF5F0E6)];
    }
  }

  /// Short seasonal “ritual” line for the hub UI.
  String seasonalRitualLine(String season) {
    switch (season) {
      case 'Spring':
        return 'Spring thaw — plant early, light rains help everything sprout.';
      case 'Summer':
        return 'Long sunny days — water often and watch your garden glow.';
      case 'Autumn':
        return 'Harvest season — gather rewards and prep the soil for rest.';
      case 'Winter':
        return 'Quiet fields — slow growth, cozy routines, gentle care.';
      default:
        return 'Choose a season to set the mood of your farm.';
    }
  }
}