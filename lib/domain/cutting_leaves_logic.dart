// ========== lib/domain/cutting_leaves_logic.dart ==========
import 'package:flutter/material.dart';

class CuttingLeavesLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xFFA5B68D);
  final Color colorGreenLight = const Color(0xFFC1CFA1);
  final Color colorPlaceholder = const Color(0xFF362427);
  final Color colorFlowerPink = const Color(0xFFF2A6A6);

  String formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void showGameOverDialog(
      BuildContext context,
      bool won,
      int pointsEarned,
      int leavesCut,
      int totalLeaves,
      int timeLeft,
      String difficulty,
      VoidCallback onPlayAgain,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          won ? '🎉 You Won! 🎉' : '😢 Game Over! 😢',
          style: TextStyle(
            color: won ? Colors.green : colorPlaceholder,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: won ? Colors.green.withOpacity(0.2) : colorPinkish,
                shape: BoxShape.circle,
              ),
              child: Icon(
                won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                color: won ? Colors.green : colorPlaceholder,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            if (won)
              Text(
                '+$pointsEarned Points!',
                style: const TextStyle(color: Colors.green, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameStat('✂️', '$leavesCut', 'Cut'),
                _buildGameStat('🍃', '${totalLeaves - leavesCut}', 'Left'),
                _buildGameStat('⏱️', '${60 - timeLeft}s', 'Time'),
              ],
            ),
            const SizedBox(height: 10),
            Text('Difficulty: $difficulty', style: const TextStyle(color: Color(0xFFA5B68D), fontWeight: FontWeight.bold)),
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

class Leaf {
  final int id;
  double x;
  double y;
  bool isCut;
  double size;

  Leaf({
    required this.id,
    required this.x,
    required this.y,
    required this.isCut,
    required this.size,
  });
}

class CutEffect {
  double x;
  double y;
  double opacity;
  double scale;

  CutEffect({
    required this.x,
    required this.y,
    required this.opacity,
    required this.scale,
  });
}
