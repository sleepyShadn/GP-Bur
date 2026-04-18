import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:appforhumman/domain/watering_flowers_models.dart';

/// أبعاد الرشاش (متطابقة مع الـ Lottie والواجهة).
const double kSprayerW = 168;
const double kSprayerH = 136;

/// نوع الرشّاش: اتجاه الفوهة داخل الصندوق (رشّاشان للوصول لكل النباتات).
enum WateringSprayerKind {
  /// أعلى اليمين، رسم معكوس أفقياً، الفوهة قرب الحافة **اليسرى** للصندوق.
  mirroredNozzleLeft,

  /// أعلى اليسار، رسم طبيعي، الفوهة قرب الحافة **اليمنى** للصندوق.
  naturalNozzleRight,
}

/// ركن الرشاش في أعلى منطقة اللعب حسب النوع.
Offset sprayerDockTopLeft(Size field, WateringSprayerKind kind) {
  final double top = (field.height * 0.03).clamp(8.0, 18.0);
  final double edge = (field.width * 0.02).clamp(6.0, 12.0);
  switch (kind) {
    case WateringSprayerKind.mirroredNozzleLeft:
      return Offset(
          (field.width - kSprayerW - edge).clamp(0.0, field.width), top);
    case WateringSprayerKind.naturalNozzleRight:
      return Offset(edge, top);
  }
}

Offset nozzleFromSprayerTopLeft(Offset topLeft, WateringSprayerKind kind) {
  switch (kind) {
    case WateringSprayerKind.mirroredNozzleLeft:
      return topLeft.translate(kSprayerW * 0.06, kSprayerH * 0.22);
    case WateringSprayerKind.naturalNozzleRight:
      return topLeft.translate(kSprayerW * 0.94, kSprayerH * 0.22);
  }
}

/// فوهة الرشاش في وضع الانتظار (للنوع المحدد).
Offset sprayerNozzleInField(Size field, WateringSprayerKind kind) =>
    nozzleFromSprayerTopLeft(sprayerDockTopLeft(field, kind), kind);

/// هدف الرش البصري (أعلى النبتة فوق الأصيص).
Offset plantCenterOnField(WateringPlant plant, Size field) {
  return Offset(
      field.width * plant.x, field.height * plant.y - plant.size * 0.95);
}

/// منطقة الري (وسط التربة داخل فتحة الأصيص — مُحاذاة لأصيص مرسوم).
Offset plantPourTargetOnField(WateringPlant plant, Size field) {
  return Offset(
      field.width * plant.x, field.height * plant.y + plant.size * 0.26);
}

double plantPourHitRadius(WateringPlant plant) => plant.size * 1.32;

/// شنطة سماد (أسفل الملعب — وسط).
const double kFertilizerBagW = 78;
const double kFertilizerBagH = 92;

Offset fertilizerBagDockTopLeft(Size field) {
  // بجوار الرشّاش الطبيعي (يسار الشاشة)؛ وإن ضاق العرض نضعه تحته في المنتصف.
  final double edge = (field.width * 0.02).clamp(6.0, 12.0);
  final Offset naturalDock =
      sprayerDockTopLeft(field, WateringSprayerKind.naturalNozzleRight);
  const double gap = 8;
  final double besideLeft = naturalDock.dx + kSprayerW + gap;
  if (besideLeft + kFertilizerBagW <= field.width - edge) {
    return Offset(besideLeft, naturalDock.dy);
  }
  final double topBelow = (naturalDock.dy + kSprayerH + 10)
      .clamp(6.0, math.max(6.0, field.height - kFertilizerBagH - 6));
  return Offset((field.width - kFertilizerBagW) * 0.5, topBelow);
}

Offset fertilizerNozzleFromBagTopLeft(Offset topLeft) {
  return topLeft.translate(kFertilizerBagW * 0.5, kFertilizerBagH * 0.9);
}

/// موضع أعلى-يسار الرشّاش بحيث تكون الفوهة عند [nozzle] (إحداثيات منطقة اللعب).
Offset sprayerTopLeftForNozzle(Offset nozzle, WateringSprayerKind kind) {
  switch (kind) {
    case WateringSprayerKind.mirroredNozzleLeft:
      return nozzle.translate(-kSprayerW * 0.06, -kSprayerH * 0.22);
    case WateringSprayerKind.naturalNozzleRight:
      return nozzle.translate(-kSprayerW * 0.94, -kSprayerH * 0.22);
  }
}

/// موضع أعلى-يسار كيس السماد بحيث تكون فوهة السكب عند [nozzle].
Offset fertilizerBagTopLeftForNozzle(Offset nozzle) {
  return nozzle.translate(-kFertilizerBagW * 0.5, -kFertilizerBagH * 0.9);
}

/// جزيئات ماء أو سماد من الأداة نحو النبتة.
class WaterSprayPainter extends CustomPainter {
  WaterSprayPainter({
    required this.nozzle,
    required this.target,
    required this.phase,
    required this.active,
    this.isFertilizer = false,
    this.intensity = 1,
  });

  final Offset nozzle;
  final Offset target;
  final double phase;
  final bool active;
  final bool isFertilizer;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;

    final double force = intensity.clamp(0.25, 1.0);
    final int n = (18 * force).round().clamp(8, 18);
    for (int i = 0; i < n; i++) {
      final double stagger = (i / n + phase) % 1.0;
      final double t = Curves.easeOut.transform(stagger);
      final Offset p = Offset.lerp(nozzle, target, t)!;
      final double jitter =
          math.sin(i * 1.7 + phase * math.pi * 2) * 6 * (1 - t);
      final double jy = math.cos(i * 2.1 + phase * math.pi * 3) * 5 * (1 - t);
      final Offset q = p.translate(jitter, jy + t * 8);
      final double r = (1.0 + (1 - t) * 2.8) * (0.8 + force * 0.3);
      final double a = ((1 - t) * 0.55 + 0.2) * (0.65 + force * 0.35);
      final Color particle = isFertilizer
          ? Color.lerp(
              const Color(0xFF8D6E63), const Color(0xFFFFE0B2), (i % 5) / 5.0)!
          : const Color(0xFF9FE7FF);
      canvas.drawCircle(
        q,
        r,
        Paint()..color = particle.withValues(alpha: a),
      );
    }

    final Paint mist = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, -0.2 + phase * 0.1),
        radius: 0.85,
        colors: isFertilizer
            ? [
                const Color(0xFFFFF8E1).withValues(alpha: 0.16),
                const Color(0xFFBCAAA4).withValues(alpha: 0.1),
                Colors.transparent,
              ]
            : [
                const Color(0xFFFFFFFF).withValues(alpha: 0.14),
                const Color(0xFF87CEEB).withValues(alpha: 0.08),
                Colors.transparent,
              ],
      ).createShader(Rect.fromCircle(
          center: target, radius: (24 + phase * 6) * (0.75 + force * 0.25)));
    canvas.drawCircle(target, (28 + phase * 8) * (0.75 + force * 0.25), mist);

    final Path beam = Path()
      ..moveTo(nozzle.dx, nozzle.dy)
      ..quadraticBezierTo(
        (nozzle.dx + target.dx) * 0.52,
        (nozzle.dy + target.dy) * 0.45 - 20,
        target.dx,
        target.dy,
      );
    final double beamA =
        (0.07 + 0.05 * (0.5 + 0.5 * math.sin(phase * math.pi * 2))) *
            (0.65 + force * 0.35);
    final Color beamColor =
        isFertilizer ? const Color(0xFF8D6E63) : const Color(0xFF87CEEB);
    canvas.drawPath(
      beam,
      Paint()
        ..color = beamColor.withValues(alpha: beamA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + 4 * force
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant WaterSprayPainter oldDelegate) {
    return oldDelegate.nozzle != nozzle ||
        oldDelegate.target != target ||
        oldDelegate.phase != phase ||
        oldDelegate.active != active ||
        oldDelegate.isFertilizer != isFertilizer ||
        oldDelegate.intensity != intensity;
  }
}

/// أصيص طيني احترافي (يُرسم أسفل نبتة Lottie).
class GardenTerraPotPainter extends CustomPainter {
  GardenTerraPotPainter({required this.accentGlaze});

  final Color accentGlaze;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset c = Offset(w * 0.5, h * 0.52);

    final Path saucer = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(c.dx, h * 0.92), width: w * 0.92, height: h * 0.14));
    canvas.drawPath(
      saucer,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5D4037),
            const Color(0xFF3E2723),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.82, w, h * 0.18)),
    );

    final Path body = Path()
      ..moveTo(w * 0.18, h * 0.28)
      ..lineTo(w * 0.82, h * 0.28)
      ..quadraticBezierTo(w * 0.88, h * 0.55, w * 0.78, h * 0.88)
      ..lineTo(w * 0.22, h * 0.88)
      ..quadraticBezierTo(w * 0.12, h * 0.55, w * 0.18, h * 0.28)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFB9714A),
            const Color(0xFF8D4E37),
            const Color(0xFF5D3A2A),
            const Color(0xFF4E2C20),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.black.withValues(alpha: 0.18),
    );

    final Rect rim = Rect.fromCenter(
      center: Offset(c.dx, h * 0.28),
      width: w * 0.68,
      height: h * 0.12,
    );
    canvas.drawOval(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6D4C41),
            const Color(0xFF4E342E),
          ],
        ).createShader(rim),
    );

    final Rect soil = Rect.fromCenter(
      center: Offset(c.dx, h * 0.29),
      width: w * 0.48,
      height: h * 0.09,
    );
    canvas.drawOval(
      soil,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF5D4037),
            const Color(0xFF3E2723),
            const Color(0xFF281A12),
          ],
        ).createShader(soil),
    );

    for (int i = 0; i < 6; i++) {
      final double u = i / 5.0;
      canvas.drawCircle(
        Offset(soil.left + 4 + u * (soil.width - 8),
            soil.center.dy + math.sin(u * math.pi) * 1.5),
        1.1,
        Paint()..color = const Color(0xFF1B120E).withValues(alpha: 0.4),
      );
    }

    final RRect hi = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.34, w * 0.14, h * 0.38),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      hi,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(hi.outerRect),
    );

    canvas.drawArc(
      Rect.fromLTWH(w * 0.58, h * 0.32, w * 0.22, h * 0.36),
      math.pi * 0.22,
      math.pi * 0.75,
      false,
      Paint()
        ..color = accentGlaze.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant GardenTerraPotPainter oldDelegate) {
    return oldDelegate.accentGlaze != accentGlaze;
  }
}

/// كيس سماد برسمة شبه واقعية (خيشة + طيّات + ملصق).
class FertilizerBagPainter extends CustomPainter {
  const FertilizerBagPainter({required this.empty});

  final bool empty;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect body = Rect.fromLTWH(size.width * 0.1, size.height * 0.16,
        size.width * 0.8, size.height * 0.74);
    final RRect bag =
        RRect.fromRectAndRadius(body, Radius.circular(size.width * 0.14));

    final List<Color> bagColors = empty
        ? [
            const Color(0xFF8D8D8D),
            const Color(0xFF6E6E6E),
            const Color(0xFF555555)
          ]
        : [
            const Color(0xFFC8A97E),
            const Color(0xFFA77C50),
            const Color(0xFF865D39)
          ];
    canvas.drawRRect(
      bag,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bagColors,
        ).createShader(body),
    );

    canvas.drawRRect(
      bag,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.2),
    );

    for (int i = 0; i < 3; i++) {
      final double x = body.left + body.width * (0.26 + i * 0.24);
      canvas.drawLine(
        Offset(x, body.top + body.height * 0.1),
        Offset(x - size.width * 0.02, body.bottom - body.height * 0.08),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.1)
          ..strokeWidth = 1.1,
      );
    }

    final Rect mouth = Rect.fromLTWH(size.width * 0.2, size.height * 0.08,
        size.width * 0.6, size.height * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mouth, Radius.circular(size.width * 0.08)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: empty
              ? [const Color(0xFF9E9E9E), const Color(0xFF757575)]
              : [const Color(0xFFB08968), const Color(0xFF8D6744)],
        ).createShader(mouth),
    );

    final Rect label = Rect.fromLTWH(size.width * 0.25, size.height * 0.36,
        size.width * 0.5, size.height * 0.28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, Radius.circular(size.width * 0.06)),
      Paint()
        ..color = empty ? const Color(0xFFE0E0E0) : const Color(0xFFF3E5AB),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, Radius.circular(size.width * 0.06)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(covariant FertilizerBagPainter oldDelegate) =>
      oldDelegate.empty != empty;
}
