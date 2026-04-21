// ========== lib/domain/garden_logic.dart ==========
import 'package:flutter/material.dart';

class GardenLogic {
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

  int getSeedDuration(String seedType) {
    if (seedType.contains('Regular')) return 60;
    if (seedType.contains('Rare')) return 360;
    if (seedType.contains('Legendary')) return 900;
    return 60;
  }

  int getHarvestPoints(String seedType) {
    if (seedType.contains('Legendary')) return 20;
    if (seedType.contains('Rare')) return 12;
    if (seedType.contains('Regular')) return 7;
    return 0;
  }

  Map<String, dynamic> getSeedInfo(String seedType) {
    if (seedType == 'Rare Seeds') {
      return {'color': Colors.blue, 'icon': Icons.spa, 'displayName': 'Rare'};
    } else if (seedType == 'Legendary Seeds') {
      return {'color': Colors.purple, 'icon': Icons.spa, 'displayName': 'Legendary'};
    } else if (seedType == 'Growth Accelerator') {
      return {'color': Colors.orange, 'icon': Icons.bolt, 'displayName': 'Accelerator'};
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