/// Lottie asset paths for the garden watering mini-game.
abstract final class WateringGardenLottieAssets {
  static const String flowerAnimation =
      'assets/animations/Flower Animation.json';
  static const String flower = 'assets/animations/flower.json';
  static const String plant123 = 'assets/animations/PLANT 123.json';
  static const String plantGray = 'assets/animations/Plant Gray.json';
  static const String waterSpray = 'assets/animations/water.json';

  /// Four plant styles, duplicated and shuffled for eight slots per round.
  static const List<String> diversePlants = <String>[
    flowerAnimation,
    flower,
    plant123,
    plantGray,
  ];
}
