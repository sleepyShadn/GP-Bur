import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:appforhumman/domain/watering_flowers_models.dart';

/// نبتة ملوّنة (صحية) — ملف Lottie.
const String kLottiePlantGreen = 'assets/animations/Flower Animation.json';

/// وردة كبيرة / نمو — بديل عشوائي للنبتة الخضراء عند الرضا.
const String kLottieFlowerAnimation = 'assets/animations/Flower Animation.json';

/// نبتة تحتاج رياً (رمادي / جاف).
const String kLottiePlantGray = 'assets/animations/Plant Gray.json';

/// أي لوتي «صحي» يُعرض لهذه النبتة في هذا المستوى (ثابت طوال الجولة — توزيع عشوائي بين النبات والوردة).
String healthyPlantLottieAsset(WateringPlant plant, WateringLevelConfig cfg) {
  final int pick = (plant.id * 31 ^ cfg.id * 17) & 1;
  return pick == 0 ? kLottiePlantGreen : kLottieFlowerAnimation;
}

/// رشاش ماء (Lottie) — يُشغَّل فقط أثناء الري الفعلي.
const String kLottieWaterSprayer = 'assets/animations/water.json';

/// طبقة زينة: نباتات مكررة في حواف المشهد (لا تستقبل لمساً).
class GardenDecorPlantsLayer extends StatelessWidget {
  const GardenDecorPlantsLayer({
    super.key,
    required this.field,
    required this.reduceMotion,
  });

  final Size field;
  final bool reduceMotion;

  /// (nx, ny, useGray, scale) — على حواف الأرض فقط حتى لا تتعارض مع سماء الصباح.
  static const List<(double, double, bool, double)> _spots = [
    (0.04, 0.66, true, 0.1),
    (0.1, 0.72, false, 0.09),
    (0.88, 0.68, true, 0.1),
    (0.94, 0.74, false, 0.085),
    (0.02, 0.58, false, 0.075),
    (0.97, 0.6, true, 0.072),
    (0.46, 0.62, true, 0.068),
    (0.54, 0.64, false, 0.065),
  ];

  @override
  Widget build(BuildContext context) {
    if (field == Size.zero) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int si = 0; si < _spots.length; si++)
            Positioned(
              left: field.width * _spots[si].$1,
              top: field.height * _spots[si].$2,
              child: Opacity(
                opacity: 0.38,
                child: Transform.scale(
                  scale: _spots[si].$4 * (math.min(field.width, field.height) / 420).clamp(0.85, 1.15),
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: field.width * 0.22,
                    height: field.width * 0.22,
                    child: Lottie.asset(
                      _spots[si].$3
                          ? kLottiePlantGray
                          : ((si ^ 3) & 1) == 0
                              ? kLottiePlantGreen
                              : kLottieFlowerAnimation,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      repeat: !reduceMotion,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// نبتة اللعب: رمادي إن كانت تحتاج ماء، ملوّنة عند وصول الرطوبة للنطاق المطلوب.
class WateringPlantLottie extends StatelessWidget {
  const WateringPlantLottie({
    super.key,
    required this.plant,
    required this.cfg,
    required this.pouring,
    required this.fertPouring,
    required this.reduceMotion,
  });

  final WateringPlant plant;
  final WateringLevelConfig cfg;
  final bool pouring;
  final bool fertPouring;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (plant.isWeed) {
      return Icon(
        Icons.grass_rounded,
        size: plant.size * 2.2,
        color: const Color(0xFF558B2F),
      );
    }

    final bool thirsty =
        plant.awaitingWater || plant.moisture < plant.idealMin;
    final bool over = plant.moisture > plant.idealMax;
    final String asset = thirsty ? kLottiePlantGray : healthyPlantLottieAsset(plant, cfg);

    Widget core = Lottie.asset(
      asset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      repeat: !reduceMotion,
    );

    if (!thirsty) {
      core = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Color.lerp(Colors.white, plant.accentColor, 0.42)!,
          BlendMode.modulate,
        ),
        child: core,
      );
    }

    if (over) {
      core = ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFF5BA3D0).withValues(alpha: 0.45),
          BlendMode.srcATop,
        ),
        child: core,
      );
    }

    if (pouring) {
      core = ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFF87CEEB).withValues(alpha: 0.22),
          BlendMode.srcATop,
        ),
        child: core,
      );
    }

    if (fertPouring) {
      core = ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFF8D6E63).withValues(alpha: 0.28),
          BlendMode.srcATop,
        ),
        child: core,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<String>(asset),
        child: core,
      ),
    );
  }
}
