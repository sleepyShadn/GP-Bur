// ========== lib/presentation/garden_planted_item.dart ==========
import 'package:flutter/material.dart';

class PlantedItem {
  final String id;
  final String seedType;
  final Color color;
  final IconData icon;
  final Offset position;
  bool isAccelerated;
  DateTime? plantTime;
  int durationSeconds;
  int remainingSeconds;
  bool isFullyGrown;
  final String docId;

  PlantedItem({
    required this.id,
    required this.seedType,
    required this.color,
    required this.icon,
    required this.position,
    required this.isAccelerated,
    this.plantTime,
    required this.durationSeconds,
    required this.remainingSeconds,
    required this.isFullyGrown,
    required this.docId,
  });

  void updateRemainingTime() {
    if (plantTime != null && !isFullyGrown) {
      final DateTime finishTime = plantTime!.add(Duration(seconds: durationSeconds));
      final DateTime now = DateTime.now();
      if (now.isAfter(finishTime)) {
        isFullyGrown = true;
        remainingSeconds = 0;
      } else {
        remainingSeconds = finishTime.difference(now).inSeconds;
      }
    }
  }

  void applyAccelerator() {
    isAccelerated = true;
    isFullyGrown = true;
    remainingSeconds = 0;
  }
}
