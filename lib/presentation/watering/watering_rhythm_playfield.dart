import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rhythm dial playfield: round progress, plant strip, dial, tap button (legacy).
class WateringRhythmPlayfield extends StatelessWidget {
  const WateringRhythmPlayfield({
    super.key,
    required this.phaseAnimation,
    required this.roundProgress,
    required this.roundPoints,
    required this.combo,
    required this.activePlantIndex,
    required this.plantStrip,
    required this.onRhythmTap,
    required this.hintText,
    required this.rhythmButtonLabel,
    this.rhythmButtonColor = const Color(0xFF2E7D32),
  });

  final Animation<double> phaseAnimation;
  final double roundProgress;
  final int roundPoints;
  final int combo;
  final int activePlantIndex;
  final Widget plantStrip;
  final VoidCallback onRhythmTap;
  final String hintText;

  /// Main action button label.
  final String rhythmButtonLabel;
  final Color rhythmButtonColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double ring =
            math.min(c.maxWidth * 0.88, c.maxHeight * 0.42).clamp(168.0, 272.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: roundProgress.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF66BB6A)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '⚡ Progress ${(roundProgress * 100).round()}% · Round pts $roundPoints · Combo $combo · Target: plant ${activePlantIndex + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    hintText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: plantStrip,
                ),
              ),
            ),
            SizedBox(
              height: ring + 20,
              child: Center(
                child: AnimatedBuilder(
                  animation: phaseAnimation,
                  builder: (context, child) {
                    final double ph = phaseAnimation.value.clamp(0.0, 1.0);
                    return CustomPaint(
                      size: Size.square(ring),
                      painter: _RhythmDialPainter(phase: ph),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: FilledButton(
                onPressed: onRhythmTap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: rhythmButtonColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  rhythmButtonLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 17, height: 1.15),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RhythmDialPainter extends CustomPainter {
  _RhythmDialPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 10;

    final Paint track = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(c, r, track);

    // Green sector at top (perfect-timing window)
    const double sector = math.pi * 0.22;
    final Rect arcRect = Rect.fromCircle(center: c, radius: r);
    final Paint green = Paint()
      ..color = const Color(0xFF66BB6A).withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2 - sector, 2 * sector, false, green);

    // Needle rotates with phase (0 = top)
    final double ang = -math.pi / 2 + 2 * math.pi * phase;
    final Offset tip = c + Offset(math.cos(ang), math.sin(ang)) * (r - 6);
    final Paint needle = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, tip, needle);
    canvas.drawCircle(c, 7, Paint()..color = const Color(0xFF37474F));
  }

  @override
  bool shouldRepaint(covariant _RhythmDialPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
