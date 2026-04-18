// ========== lib/domain/watering_flowers_logic.dart ==========
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'watering_flowers_models.dart';

class WateringFlowersLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xFFA5B68D);
  final Color colorGreenLight = const Color(0xFFC1CFA1);
  final Color colorPlaceholder = const Color(0xFF362427);
  final Color colorFlowerPink = const Color(0xFFF2A6A6);
  final Color colorFlowerYellow = const Color(0xFFFFD700);
  final Color colorFlowerPurple = const Color(0xFFDDA0DD);
  final Color colorWaterBlue = const Color(0xFF87CEEB);
  final Color colorEmerald = const Color(0xFF2D6A4F);
  final Color colorGold = const Color(0xFFC9A227);

  String formatTime(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Stars: completion, water left, enough time remaining.
  static int computeStars({
    required bool won,
    required int timeLeft,
    required int timeMax,
    required double waterRemaining,
    required double waterMax,
  }) {
    if (!won || waterMax <= 0) return 0;
    final double ratio = waterRemaining / waterMax;
    if (ratio < 0.18) return 1;
    if (timeLeft < (timeMax * 0.26).ceil()) return 2;
    return 3;
  }

  Color moistureRingColor(double idealMin, double idealMax, double m) {
    if (m < idealMin) {
      final double t = (m / (idealMin + 1e-6)).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF8B4513), colorFlowerYellow, t)!;
    }
    if (m > idealMax) {
      final double t = ((1 - m) / (1 - idealMax + 1e-6)).clamp(0.0, 1.0);
      return Color.lerp(colorWaterBlue, const Color(0xFF1E3A5F), 1 - t)!;
    }
    return const Color(0xFF52B788);
  }

  Color fertilizerRingColor(WateringPlant p, WateringLevelConfig cfg) {
    if (!p.wantsFertilizer || p.isWeed) return Colors.grey.shade500;
    final double m = p.fertilizer;
    if (m < p.fertIdealMin) {
      final double t = (m / (p.fertIdealMin + 1e-6)).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF5D4037), const Color(0xFFFFE082), t)!;
    }
    if (m > p.fertIdealMax) {
      return const Color(0xFF4E342E);
    }
    return const Color(0xFF8BC34A);
  }

  /// Plant mood emoji for UI.
  String plantMoodEmoji(WateringPlant p, WateringLevelConfig cfg) {
    if (p.isWeed) return '🌾';
    if (p.isDead) return '💀';
    if (p.awaitingWater) return '😰';
    final bool wOk =
        !p.wantsWater || (p.moisture >= p.idealMin && p.moisture <= p.idealMax);
    final bool fOk = !p.wantsFertilizer ||
        (p.fertilizer >= p.fertIdealMin && p.fertilizer <= p.fertIdealMax);
    if (wOk && fOk) return '😊';
    if (!wOk && !fOk) return '😢';
    return '😐';
  }

  void showGameOverDialog(
    BuildContext context, {
    required bool won,
    required int pointsEarned,
    required int satisfiedPlants,
    required int totalPlants,
    required int timeLeft,
    required String difficultyLabel,
    required int stars,
    required VoidCallback onPlayAgain,
    required VoidCallback onLevelSelect,
    VoidCallback? onNextLevel,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          won ? 'Great job!' : 'Time is up',
          style: TextStyle(
            color: won ? colorEmerald : colorPlaceholder,
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
                color: won
                    ? Colors.green.withValues(alpha: 0.15)
                    : colorPinkish,
                shape: BoxShape.circle,
              ),
              child: Icon(
                won ? Icons.local_florist : Icons.water_drop_outlined,
                color: won ? colorEmerald : colorPlaceholder,
                size: 48,
              ),
            ),
            const SizedBox(height: 12),
            if (won) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final bool on = i < stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star_rounded,
                      size: 36,
                      color: on ? colorGold : Colors.grey.shade400,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '+$pointsEarned pts',
                style: TextStyle(color: colorEmerald, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameStat('💧', '$satisfiedPlants', 'Happy'),
                _buildGameStat('🌿', '${totalPlants - satisfiedPlants}', 'Left'),
                _buildGameStat('⏱', formatTime(timeLeft), 'Remaining'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              difficultyLabel,
              style: TextStyle(color: colorGreenDark, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          if (won && onNextLevel != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onNextLevel();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Next level',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onLevelSelect();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colorPinkish,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Levels',
                      style: TextStyle(color: colorGreenDark)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Exit',
                      style: TextStyle(color: colorPlaceholder)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPlayAgain();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorGreenDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Play again',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        Text(value, style: TextStyle(color: colorGreenDark, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: colorPlaceholder, fontSize: 11)),
      ],
    );
  }

  /// Same glass dialog pattern as [ApplePickingLogic.showExitDialog].
  void showExitDialog(BuildContext context, VoidCallback onExit) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                    const Color(0xFF1E2A3A).withValues(alpha: 0.82),
                    const Color(0xFF26364A).withValues(alpha: 0.76),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
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
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
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
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
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
