// ========== lib/domain/apple_picking_logic.dart ==========
import 'package:flutter/material.dart';

class ApplePickingLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xFFA5B68D);
  final Color colorGreenLight = const Color(0xFFC1CFA1);
  final Color colorPlaceholder = const Color(0xFF362427);

  String formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  bool checkCollision(Apple apple, double bucketPosition, double bucketWidth) {
    double bucketLeft = bucketPosition - bucketWidth / 2;
    double bucketRight = bucketPosition + bucketWidth / 2;
    double bucketTop = 0.8;
    double bucketBottom = 0.9;

    return (apple.x >= bucketLeft &&
        apple.x <= bucketRight &&
        apple.y >= bucketTop &&
        apple.y <= bucketBottom);
  }

  void showGameOverDialog(
      BuildContext context,
      int score,
      int missedApples,
      int timeLeft,
      VoidCallback onPlayAgain,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Game Over!',
          style: TextStyle(color: Color(0xFFA5B68D), fontWeight: FontWeight.bold, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: colorPinkish, shape: BoxShape.circle),
              child: Text(
                '$score',
                style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Total Points', style: TextStyle(color: Color(0xFF362427), fontSize: 16)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameStat('🍎', '${score ~/ 2}', 'Apples'),
                _buildGameStat('❌', '$missedApples', 'Missed'),
                _buildGameStat('⏱️', '${60 - timeLeft}s', 'Played'),
              ],
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

class Apple {
  double x;
  double y;
  double speed;

  Apple({required this.x, required this.y, required this.speed});
}

class FloatingScore {
  int value;
  double x;
  double y;
  double opacity;

  FloatingScore({required this.value, required this.x, required this.y, required this.opacity});
}