import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Morning sky & sun (Lottie) — garden watering backdrop.
const String kLottieMorningBackground =
    'assets/animations/Morning Background.json';

/// Full-screen animated sky (no soil layer).
class WateringGardenMorningBackdrop extends StatelessWidget {
  const WateringGardenMorningBackdrop({super.key, required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Lottie.asset(
          kLottieMorningBackground,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          repeat: !reduceMotion,
        ),
      ],
    );
  }
}
