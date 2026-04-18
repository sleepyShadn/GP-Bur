// ========== lib/domain/cutting_leaves_logic.dart ==========
import 'package:flutter/material.dart';

enum HarvestTool { shears, quickSnip }

class LevelConfig {
  final int id;
  final int timeLimit;
  final int targetCount;
  final int spawnCount;
  final double budRatio;
  final double thornRatio;
  final String objectiveLabel;
  final RoseColor? requiredColor;
  final double swaySpeed;

  const LevelConfig({
    required this.id,
    required this.timeLimit,
    required this.targetCount,
    required this.spawnCount,
    required this.budRatio,
    required this.thornRatio,
    required this.objectiveLabel,
    required this.requiredColor,
    required this.swaySpeed,
  });
}

enum RoseColor { red, pink, white }

class RoseTarget {
  final int id;
  final double x;
  final double y;
  final double stemHeight;
  final double size;
  final RoseColor color;
  final bool isBud;
  final bool hasThorns;
  double swayPhase;
  bool isHarvested;

  RoseTarget({
    required this.id,
    required this.x,
    required this.y,
    required this.stemHeight,
    required this.size,
    required this.color,
    required this.isBud,
    required this.hasThorns,
    required this.swayPhase,
    this.isHarvested = false,
  });
}

class CuttingLeavesLogic {
  final Color colorPinkish = const Color(0xFFF1D6DC);
  final Color colorCream = const Color(0xFFF7F4EC);
  final Color colorGreenDark = const Color(0xFF5F8B5C);
  final Color colorGreenLight = const Color(0xFFCFE6C8);
  final Color colorPlaceholder = const Color(0xFF2B3A2C);
  final Color colorFlowerPink = const Color(0xFFF3A7BD);

  static const List<LevelConfig> levels = <LevelConfig>[
    LevelConfig(
      id: 1,
      timeLimit: 65,
      targetCount: 12,
      spawnCount: 18,
      budRatio: 0.12,
      thornRatio: 0.08,
      objectiveLabel: 'Harvest any 12 roses',
      requiredColor: null,
      swaySpeed: 0.8,
    ),
    LevelConfig(
      id: 2,
      timeLimit: 60,
      targetCount: 14,
      spawnCount: 20,
      budRatio: 0.16,
      thornRatio: 0.10,
      objectiveLabel: 'Harvest 14 pink roses',
      requiredColor: RoseColor.pink,
      swaySpeed: 0.9,
    ),
    LevelConfig(
      id: 3,
      timeLimit: 55,
      targetCount: 16,
      spawnCount: 22,
      budRatio: 0.19,
      thornRatio: 0.12,
      objectiveLabel: 'Harvest 16 red roses',
      requiredColor: RoseColor.red,
      swaySpeed: 1.0,
    ),
    LevelConfig(
      id: 4,
      timeLimit: 52,
      targetCount: 17,
      spawnCount: 23,
      budRatio: 0.22,
      thornRatio: 0.14,
      objectiveLabel: 'Harvest 17 white roses',
      requiredColor: RoseColor.white,
      swaySpeed: 1.08,
    ),
    LevelConfig(
      id: 5,
      timeLimit: 50,
      targetCount: 18,
      spawnCount: 24,
      budRatio: 0.24,
      thornRatio: 0.16,
      objectiveLabel: 'Harvest 18 roses, avoid buds',
      requiredColor: null,
      swaySpeed: 1.12,
    ),
    LevelConfig(
      id: 6,
      timeLimit: 46,
      targetCount: 20,
      spawnCount: 26,
      budRatio: 0.27,
      thornRatio: 0.18,
      objectiveLabel: 'Finale: harvest 20 mixed roses',
      requiredColor: null,
      swaySpeed: 1.2,
    ),
  ];

  String formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String roseLabel(RoseColor color) {
    switch (color) {
      case RoseColor.red:
        return 'Red';
      case RoseColor.pink:
        return 'Pink';
      case RoseColor.white:
        return 'White';
    }
  }

  Color roseColorValue(RoseColor color) {
    switch (color) {
      case RoseColor.red:
        return const Color(0xFFC62828);
      case RoseColor.pink:
        return const Color(0xFFD81B60);
      case RoseColor.white:
        return const Color(0xFFF8F8F8);
    }
  }

  int pointsForHarvest(HarvestTool tool, {required bool preciseCut}) {
    final base = tool == HarvestTool.shears ? 3 : 2;
    return preciseCut ? base + 1 : base;
  }

  int starRating(double accuracy) {
    if (accuracy >= 0.9) return 3;
    if (accuracy >= 0.75) return 2;
    return 1;
  }

  void showGameOverDialog(
      BuildContext context,
      bool won,
      int pointsEarned,
      int rosesHarvested,
      int targetCount,
      int timeLeft,
      int totalTime,
      int level,
      String objective,
      int starsEarned,
      double harvestAccuracy,
      VoidCallback onPlayAgain,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          won ? 'Rose Harvest Complete' : 'Harvest Ended',
          style: TextStyle(
            color: won ? colorGreenDark : colorPlaceholder,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: won ? colorGreenLight : colorPinkish,
                shape: BoxShape.circle,
              ),
              child: Icon(
                won ? Icons.local_florist_rounded : Icons.spa_outlined,
                color: won ? colorGreenDark : colorPlaceholder,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '+$pointsEarned Points',
              style: TextStyle(
                color: pointsEarned > 0 ? colorGreenDark : colorPlaceholder,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              won ? 'Beautiful harvest in the rose fields.' : 'Try a cleaner cut next round.',
              style: const TextStyle(
                color: Color(0xFF5F6F52),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameStat('🌹', '$rosesHarvested', 'Harvested'),
                _buildGameStat('🎯', '$targetCount', 'Target'),
                _buildGameStat('⏱️', '${totalTime - timeLeft}s', 'Time'),
              ],
            ),
            const SizedBox(height: 10),
            Text('Level $level • $objective', style: const TextStyle(color: Color(0xFFA5B68D), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Harvest Accuracy: ${(harvestAccuracy * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF5F6F52),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    index < starsEarned ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < starsEarned ? const Color(0xFFFFC107) : const Color(0xFFB0BEC5),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colorPinkish,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Exit', style: TextStyle(color: Color(0xFFA5B68D))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onPlayAgain();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorGreenDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Play Again', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        Text(value, style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Color(0xFF362427), fontSize: 12)),
      ],
    );
  }

  void showExitDialog(BuildContext context, VoidCallback onExit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text('Exit Game?', style: TextStyle(color: Color(0xFFA5B68D))),
        content: const Text('Are you sure you want to exit? Your progress will be lost.', style: TextStyle(color: Color(0xFFA5B68D))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA5B68D))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onExit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorGreenDark),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
