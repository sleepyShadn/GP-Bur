import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'garden_planted_item.dart';

class GardenFlameWorld extends FlameGame {
  GardenFlameWorld({
    required this.onPlotTap,
    required this.cropCols,
    required this.cropRows,
    required this.plotCell,
    required this.cropPad,
    required this.cropOriginX,
    required this.cropOriginY,
    required this.worldWidth,
    required this.worldHeight,
  });

  final ValueChanged<int> onPlotTap;
  final int cropCols;
  final int cropRows;
  final double plotCell;
  final double cropPad;
  final double cropOriginX;
  final double cropOriginY;
  final double worldWidth;
  final double worldHeight;

  Size _viewport = Size.zero;
  Offset _cameraOffset = Offset.zero;
  Offset _cameraVelocity = Offset.zero;
  bool _cameraAnchoredToNpc = false;

  /// Drives Flutter overlays (plants/trees) so they stay locked to world coords.
  final ValueNotifier<Offset> cameraListenable = ValueNotifier<Offset>(Offset.zero);
  String _season = 'Spring';
  List<PlantedItem> _plants = <PlantedItem>[];
  double _time = 0;
  final List<_HarvestBurst> _harvestBursts = <_HarvestBurst>[];
  final List<_FloatingLabel> _floatingLabels = <_FloatingLabel>[];

  int get _tileCount => cropCols * cropRows;
  Offset get cameraOffset => _cameraOffset;

  void _publishCamera() {
    if (cameraListenable.value != _cameraOffset) {
      cameraListenable.value = _cameraOffset;
    }
  }

  static const List<double> _cloudBaseX = <double>[40, 260, 540, 840, 1080];
  static const List<double> _cloudBaseY = <double>[82, 110, 72, 126, 90];
  static const List<double> _cloudSpeed = <double>[7, 11, 8.5, 9.2, 6.5];
  static const List<double> _cloudScale = <double>[1.0, 1.25, 0.9, 1.15, 1.05];

  void triggerHarvestFx({
    required Offset at,
    required int points,
  }) {
    _harvestBursts.add(_HarvestBurst(origin: at));
    _floatingLabels.add(
      _FloatingLabel(
        text: '+$points',
        origin: at.translate(0, -10),
        color: const Color(0xFFFFF59D),
      ),
    );
  }

  void setViewport(Size size) {
    _viewport = size;
    if (!_cameraAnchoredToNpc && size.width > 0 && size.height > 0) {
      _cameraOffset = _cameraOffsetForFocus(_npcPositionAt(_time));
      _cameraAnchoredToNpc = true;
    } else {
      _cameraOffset = _clampOffset(_cameraOffset);
    }
    _publishCamera();
  }

  void setScene({
    required String season,
    required List<PlantedItem> plants,
  }) {
    _season = season;
    _plants = List<PlantedItem>.from(plants);
  }

  void panBy(Offset delta) {
    final Offset next = Offset(
      _cameraOffset.dx - delta.dx,
      _cameraOffset.dy - delta.dy,
    );
    _cameraOffset = _clampOffset(next);
    _cameraVelocity = Offset(-delta.dx * 26, -delta.dy * 26);
    _publishCamera();
  }

  void handleTap(Offset localPosition) {
    final Offset world = localPosition + _cameraOffset;
    final int? idx = _cropIndexFromWorld(world);
    if (idx != null) onPlotTap(idx);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_cameraVelocity.distanceSquared > 0.0001) {
      final Offset moved = _cameraOffset + (_cameraVelocity * dt);
      _cameraOffset = _clampOffset(moved);
      final double decay = math.pow(0.9, dt * 60).toDouble();
      _cameraVelocity = _cameraVelocity * decay;
      _publishCamera();
    }
    for (final _HarvestBurst b in _harvestBursts) {
      b.life += dt;
    }
    _harvestBursts.removeWhere((_HarvestBurst b) => b.life > b.duration);

    for (final _FloatingLabel label in _floatingLabels) {
      label.life += dt;
    }
    _floatingLabels.removeWhere((_FloatingLabel l) => l.life > l.duration);
  }

  Offset _clampOffset(Offset value) {
    final double maxX = (worldWidth - _viewport.width).clamp(0, worldWidth);
    final double maxY = (worldHeight - _viewport.height).clamp(0, worldHeight);
    return Offset(
      value.dx.clamp(0, maxX),
      value.dy.clamp(0, maxY),
    );
  }

  int? _cropIndexFromWorld(Offset world) {
    final double localX = world.dx - cropOriginX - cropPad;
    final double localY = world.dy - cropOriginY - cropPad;
    if (localX < 0 || localY < 0) return null;
    final int col = (localX / plotCell).floor();
    final int row = (localY / plotCell).floor();
    if (col < 0 || col >= cropCols || row < 0 || row >= cropRows) return null;
    return row * cropCols + col;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _drawBackground(canvas);
    canvas.save();
    canvas.translate(-_cameraOffset.dx * 0.28, -_cameraOffset.dy * 0.18);
    _drawFarLayer(canvas);
    canvas.restore();

    canvas.save();
    canvas.translate(-_cameraOffset.dx, -_cameraOffset.dy);
    _drawGround(canvas);
    _drawField(canvas);
    _drawNpc(canvas);
    _drawHarvestFx(canvas);
    _drawSeasonParticles(canvas);

    canvas.restore();
    _drawFloatingLabels(canvas);
  }

  void _drawBackground(Canvas canvas) {
    final Rect worldRect = Rect.fromLTWH(0, 0, worldWidth, worldHeight);
    final List<Color> sky = _seasonGradient(_season);
    final Paint bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: sky,
      ).createShader(worldRect);
    canvas.drawRect(worldRect, bg);
    _drawSun(canvas);
    _drawClouds(canvas, parallax: 0.18);

    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.72),
        radius: 1.1,
        colors: <Color>[
          Colors.transparent,
          const Color(0xFF2E7D32).withValues(alpha: 0.08),
          const Color(0xFF4E342E).withValues(alpha: 0.14),
        ],
        stops: const <double>[0.3, 0.7, 1],
      ).createShader(worldRect);
    canvas.drawRect(worldRect, vignette);

    final double day = 0.5 + 0.5 * math.sin(_time * 0.12 - 1.3);
    final Color overlay = Color.lerp(
          const Color(0x663A4B7A),
          const Color(0x10FFBE76),
          day,
        ) ??
        const Color(0x201A2945);
    canvas.drawRect(worldRect, Paint()..color = overlay);
  }

  void _drawFarLayer(Canvas canvas) {
    final Paint ridge = Paint()
      ..color = const Color(0xFF33691E).withValues(alpha: 0.26);
    final Path hills = Path()
      ..moveTo(0, worldHeight * 0.52)
      ..quadraticBezierTo(worldWidth * 0.2, worldHeight * 0.4,
          worldWidth * 0.42, worldHeight * 0.52)
      ..quadraticBezierTo(
          worldWidth * 0.68, worldHeight * 0.64, worldWidth, worldHeight * 0.48)
      ..lineTo(worldWidth, worldHeight * 0.66)
      ..lineTo(0, worldHeight * 0.66)
      ..close();
    canvas.drawPath(hills, ridge);

    final Paint tree = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.28);
    for (int i = 0; i < 16; i++) {
      final double x = 40 + i * ((worldWidth - 80) / 15);
      final double y = worldHeight * 0.48 + 10 * math.sin(i * 0.8);
      canvas.drawCircle(Offset(x, y), 16 + (i % 3) * 2, tree);
      canvas.drawRect(Rect.fromLTWH(x - 2, y + 12, 4, 10),
          Paint()..color = const Color(0xFF4E342E).withValues(alpha: 0.25));
    }
  }

  void _drawSun(Canvas canvas) {
    final Offset sunCenter = Offset(worldWidth - 190, 116);
    final double pulse = 1 + 0.08 * (0.5 + 0.5 * math.sin(0.8 * _time));
    final double sunRadius = 42 * pulse;
    canvas.drawCircle(
      sunCenter,
      72 * pulse,
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: 0.25),
    );

    canvas.save();
    canvas.translate(sunCenter.dx, sunCenter.dy);
    canvas.rotate(_time * 0.3);
    final Paint ray = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (int i = 0; i < 14; i++) {
      final double a = i * (math.pi * 2 / 14);
      final Offset p1 = Offset(54 * math.cos(a), 54 * math.sin(a));
      final Offset p2 = Offset(76 * math.cos(a), 76 * math.sin(a));
      canvas.drawLine(p1, p2, ray);
    }
    canvas.restore();

    canvas.drawCircle(
      sunCenter,
      sunRadius,
      Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      sunCenter.translate(-10, -10),
      16,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _drawClouds(Canvas canvas, {required double parallax}) {
    for (int i = 0; i < _cloudBaseX.length; i++) {
      final double travel = (_time * _cloudSpeed[i]) % (worldWidth + 220);
      final double x =
          (_cloudBaseX[i] + travel) - 140 - (_cameraOffset.dx * parallax);
      final double y = _cloudBaseY[i] + 6 * math.sin((0.6 * _time) + i);
      _drawOneCloud(canvas, Offset(x, y), _cloudScale[i]);
    }
  }

  void _drawOneCloud(Canvas canvas, Offset origin, double scale) {
    final Paint cloud = Paint()..color = Colors.white.withValues(alpha: 0.68);
    canvas.drawCircle(
        origin + Offset(28 * scale, 24 * scale), 22 * scale, cloud);
    canvas.drawCircle(
        origin + Offset(54 * scale, 16 * scale), 25 * scale, cloud);
    canvas.drawCircle(
        origin + Offset(84 * scale, 24 * scale), 20 * scale, cloud);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + 20 * scale, origin.dy + 24 * scale,
            74 * scale, 24 * scale),
        Radius.circular(15 * scale),
      ),
      cloud,
    );
  }

  void _drawGround(Canvas canvas) {
    final Rect groundRect =
        Rect.fromLTWH(0, worldHeight * 0.62, worldWidth, worldHeight * 0.38);
    final Paint grass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF66BB6A),
          Color(0xFF388E3C),
          Color(0xFF2E7D32)
        ],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, grass);

    final Paint path = Paint()
      ..color = const Color(0xFFC58B52).withValues(alpha: 0.8);
    final Path walkway = Path()
      ..moveTo(0, worldHeight * 0.78)
      ..quadraticBezierTo(
          worldWidth * 0.45, worldHeight * 0.72, worldWidth, worldHeight * 0.79)
      ..lineTo(worldWidth, worldHeight)
      ..lineTo(0, worldHeight)
      ..close();
    canvas.drawPath(walkway, path);

    _drawFenceLoop(canvas);
    _drawGrassDots(canvas);
  }

  void _drawFenceLoop(Canvas canvas) {
    final Paint post = Paint()
      ..color = const Color(0xFF795548).withValues(alpha: 0.9);
    for (double x = 24; x < worldWidth - 24; x += 34) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, worldHeight * 0.64, 4, 24),
          const Radius.circular(2),
        ),
        post,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, worldHeight - 132, 4, 26),
          const Radius.circular(2),
        ),
        post,
      );
    }
    for (double y = worldHeight * 0.66; y < worldHeight - 130; y += 30) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(14, y, 4, 24),
          const Radius.circular(2),
        ),
        post,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(worldWidth - 18, y, 4, 24),
          const Radius.circular(2),
        ),
        post,
      );
    }
  }

  void _drawGrassDots(Canvas canvas) {
    final Paint tuft = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.22);
    for (int i = 0; i < 95; i++) {
      final double fx = ((i * 97) % worldWidth);
      final double fy = worldHeight * 0.64 + ((i * 71) % (worldHeight * 0.3));
      canvas.drawCircle(Offset(fx, fy), (i % 3) + 1.1, tuft);
    }
  }

  void _drawField(Canvas canvas) {
    final double bedW = (cropCols * plotCell) + 2 * cropPad;
    final double bedH = (cropRows * plotCell) + 2 * cropPad;
    final RRect bed = RRect.fromRectAndRadius(
      Rect.fromLTWH(cropOriginX, cropOriginY, bedW, bedH),
      const Radius.circular(22),
    );
    final Paint bedFill = Paint()..color = const Color(0xFF3E2723);
    final Paint bedBorder = Paint()
      ..color = const Color(0xFFC1784A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawRRect(bed, bedFill);
    canvas.drawRRect(bed, bedBorder);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cropOriginX + 6, cropOriginY + 6, bedW - 12, bedH - 12),
        const Radius.circular(18),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.14),
    );

    final Set<int> occupied = <int>{};
    for (final PlantedItem item in _plants) {
      final int? idx = _cropIndexFromWorld(item.position);
      if (idx != null) occupied.add(idx);
    }

    for (int i = 0; i < _tileCount; i++) {
      final int col = i % cropCols;
      final int row = i ~/ cropCols;
      final Rect tile = Rect.fromLTWH(
        cropOriginX + cropPad + col * plotCell + 3,
        cropOriginY + cropPad + row * plotCell + 3,
        plotCell - 6,
        plotCell - 6,
      );
      final bool isOccupied = occupied.contains(i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tile, const Radius.circular(11)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOccupied
                ? <Color>[const Color(0xFF5D4037), const Color(0xFF2E1E18)]
                : <Color>[const Color(0xFF7A5B3A), const Color(0xFF4E342E)],
          ).createShader(tile),
      );
      if (!isOccupied) {
        final Paint furrow = Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(tile.left + 6, tile.center.dy),
          Offset(tile.right - 6, tile.center.dy),
          furrow,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(tile.deflate(2), const Radius.circular(9)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFFFFF59D).withValues(alpha: 0.32),
        );
      }
    }
  }

  void _drawNpc(Canvas canvas) {
    final Offset p = _npcPositionAt(_time);
    canvas.drawOval(
      Rect.fromCenter(center: p.translate(0, 22), width: 26, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: 22, height: 34),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFF1565C0),
    );
    canvas.drawCircle(
        p.translate(0, -22), 11, Paint()..color = const Color(0xFFF6D7B0));
    canvas.drawOval(
      Rect.fromCenter(center: p.translate(0, -28), width: 28, height: 11),
      Paint()..color = const Color(0xFF9C6B2F),
    );
  }

  Offset _npcPositionAt(double t) {
    final double x = worldWidth * 0.2 +
        ((math.sin(t * 0.35) + 1) * 0.5) * (worldWidth * 0.5);
    final double y = worldHeight * 0.74 + 8 * math.sin(t * 0.8);
    return Offset(x, y);
  }

  Offset _cameraOffsetForFocus(Offset focus) {
    final Offset desired = Offset(
      focus.dx - (_viewport.width * 0.5),
      focus.dy - (_viewport.height * 0.68),
    );
    return _clampOffset(desired);
  }

  void _drawHarvestFx(Canvas canvas) {
    for (final _HarvestBurst burst in _harvestBursts) {
      final double t = (burst.life / burst.duration).clamp(0, 1);
      for (int i = 0; i < burst.count; i++) {
        final double angle = (i / burst.count) * math.pi * 2;
        final double radius = 8 + 34 * Curves.easeOut.transform(t);
        final Offset p = burst.origin +
            Offset(math.cos(angle) * radius, math.sin(angle) * radius - 18 * t);
        canvas.drawCircle(
          p,
          2.5 - (t * 1.3),
          Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 1 - t),
        );
      }
      canvas.drawCircle(
        burst.origin,
        12 + 22 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFF176).withValues(alpha: 0.5 * (1 - t)),
      );
    }
  }

  void _drawFloatingLabels(Canvas canvas) {
    for (final _FloatingLabel label in _floatingLabels) {
      final double t = (label.life / label.duration).clamp(0, 1);
      final Offset worldPos = label.origin.translate(0, -26 * t);
      final Offset screenPos = worldPos - _cameraOffset;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: label.color.withValues(alpha: 1 - t),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: const <Shadow>[
              Shadow(color: Color(0x99000000), blurRadius: 4)
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, screenPos.translate(-tp.width / 2, 0));
    }
  }

  void _drawSeasonParticles(Canvas canvas) {
    if (_season == 'Winter') {
      final Paint snow = Paint()..color = Colors.white.withValues(alpha: 0.75);
      for (int i = 0; i < 42; i++) {
        final double x =
            (((i * 97) + (_time * (20 + (i % 5) * 8))) % (worldWidth + 40)) -
                20;
        final double y =
            (((i * 59) + (_time * (36 + (i % 7) * 9))) % (worldHeight * 0.9));
        canvas.drawCircle(Offset(x, y), 1.5 + (i % 3) * 0.45, snow);
      }
      return;
    }
    if (_season == 'Autumn') {
      final Paint leaf = Paint()
        ..color = const Color(0xFFFFB74D).withValues(alpha: 0.66);
      for (int i = 0; i < 26; i++) {
        final double x =
            (((i * 121) + (_time * (18 + (i % 4) * 6))) % (worldWidth + 40)) -
                20;
        final double y =
            (((i * 77) + (_time * (30 + (i % 3) * 6))) % (worldHeight * 0.85));
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 5, height: 3), leaf);
      }
      return;
    }
    if (_season == 'Spring') {
      final Paint pollen = Paint()
        ..color = const Color(0xFFFFF59D).withValues(alpha: 0.45);
      for (int i = 0; i < 30; i++) {
        final double x =
            (((i * 89) + (_time * (14 + (i % 5) * 4))) % (worldWidth + 30)) -
                15;
        final double y = worldHeight * 0.44 +
            (((i * 47) + (_time * 26)) % (worldHeight * 0.45));
        canvas.drawCircle(Offset(x, y), 1.4, pollen);
      }
      return;
    }
    final Paint heat = Paint()..color = Colors.white.withValues(alpha: 0.1);
    for (int i = 0; i < 18; i++) {
      final double x = 40 + i * ((worldWidth - 80) / 17);
      final double y = worldHeight * 0.5 + ((i * 21 + _time * 55) % 140);
      canvas.drawLine(Offset(x, y), Offset(x + 3, y + 12), heat);
    }
  }

  List<Color> _seasonGradient(String season) {
    switch (season) {
      case 'Summer':
        return const <Color>[
          Color(0xFF7ED6FF),
          Color(0xFF4CAF50),
          Color(0xFF2E7D32)
        ];
      case 'Autumn':
        return const <Color>[
          Color(0xFFFFC46B),
          Color(0xFFB98037),
          Color(0xFF7B4B1E)
        ];
      case 'Winter':
        return const <Color>[
          Color(0xFFD9ECFF),
          Color(0xFF90CAF9),
          Color(0xFF607D8B)
        ];
      case 'Spring':
      default:
        return const <Color>[
          Color(0xFFA5E6A3),
          Color(0xFF66BB6A),
          Color(0xFF2E7D32)
        ];
    }
  }
}

class _HarvestBurst {
  _HarvestBurst({required this.origin});
  final Offset origin;
  double life = 0;
  final double duration = 0.65;
  final int count = 12;
}

class _FloatingLabel {
  _FloatingLabel({
    required this.text,
    required this.origin,
    required this.color,
  });
  final String text;
  final Offset origin;
  final Color color;
  double life = 0;
  final double duration = 0.9;
}
