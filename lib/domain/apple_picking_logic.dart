// ========== lib/domain/apple_picking_logic.dart ==========
import 'package:flutter/material.dart';
import 'dart:ui';

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
    // Apple is rendered using y * 0.7 in the game screen,
    // so collision should use the same visual coordinate space.
    final visualY = apple.y * 0.7;
    const double bucketTop = 0.78;
    const double bucketBottom = 0.93;

    return (apple.x >= bucketLeft &&
        apple.x <= bucketRight &&
        visualY >= bucketTop &&
        visualY <= bucketBottom);
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E2A3A).withOpacity(0.82),
                    const Color(0xFF26364A).withOpacity(0.76),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.24),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🍎', style: TextStyle(fontSize: 38)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Game Over!',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Total Points',
                          style: TextStyle(
                            color: Color(0xFFDCE6F2),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildGameStat('🍎', '${score ~/ 2}', 'Apples'),
                      _buildGameStat('❌', '$missedApples', 'Missed'),
                      _buildGameStat('⏱️', '${60 - timeLeft}s', 'Played'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.white.withOpacity(0.10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              color: Color(0xFFEAF2FC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                            backgroundColor: const Color(0xFFFFD166),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                          child: const Text(
                            'Play Again',
                            style: TextStyle(
                              color: Color(0xFF2A3A4F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameStat(String emoji, String value, String label) {
    return Container(
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDCE6F2),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void showExitDialog(BuildContext context, VoidCallback onExit) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E2A3A).withOpacity(0.82),
                    const Color(0xFF26364A).withOpacity(0.76),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withOpacity(0.24),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.26),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: Color(0xFFEAF2FC),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Exit Game?',
                    style: TextStyle(
                      color: Color(0xFFF8FBFF),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to exit? Your progress will be lost.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFDCE6F2),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.white.withOpacity(0.10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFFEAF2FC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onExit();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD166),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              color: Color(0xFF2A3A4F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Apple {
  double x;
  double y;
  double speed;
  double size;
  double driftAmplitude;
  double driftSpeed;
  double rotationSpeed;
  double phase;
  bool isRotten;

  Apple({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.driftAmplitude,
    required this.driftSpeed,
    required this.rotationSpeed,
    required this.phase,
    this.isRotten = false,
  });
}

class FloatingScore {
  int value;
  double x;
  double y;
  double opacity;

  FloatingScore({required this.value, required this.x, required this.y, required this.opacity});
}

class CatchParticle {
  double x;
  double y;
  double dx;
  double dy;
  double size;
  double opacity;
  Color color;

  CatchParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

class BonusDrop {
  double x;
  double y;
  double speed;

  BonusDrop({
    required this.x,
    required this.y,
    required this.speed,
  });
}