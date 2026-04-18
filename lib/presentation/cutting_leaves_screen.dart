import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard }

class DifficultyConfig {
  final int seconds;
  final int branchDepth;
  final int leafCount;
  final int trimTargets;
  final double badCutPenalty;
  final int passScore;

  const DifficultyConfig({
    required this.seconds,
    required this.branchDepth,
    required this.leafCount,
    required this.trimTargets,
    required this.badCutPenalty,
    required this.passScore,
  });
}

class BranchSegment {
  final int id;
  final Offset start;
  final Offset end;
  final double thickness;
  final bool essential;
  bool active;

  BranchSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.thickness,
    required this.essential,
    this.active = true,
  });
}

class LeafNode {
  final int id;
  final Offset center;
  final double radius;
  final bool necessary;
  bool active;

  LeafNode({
    required this.id,
    required this.center,
    required this.radius,
    required this.necessary,
    this.active = true,
  });
}

class CutParticle {
  Offset position;
  Offset velocity;
  double life;
  final Color color;

  CutParticle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.color,
  });
}

class TrimPoint {
  final Offset position;
  final double radius;
  bool hit;

  TrimPoint({
    required this.position,
    required this.radius,
    this.hit = false,
  });
}

class CuttingLeavesScreen extends StatefulWidget {
  const CuttingLeavesScreen({super.key});

  @override
  State<CuttingLeavesScreen> createState() => _CuttingLeavesScreenState();
}

class _CuttingLeavesScreenState extends State<CuttingLeavesScreen>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  late final AnimationController _fxController;
  Timer? _timer;

  final Map<Difficulty, DifficultyConfig> _difficultyConfig =
      const <Difficulty, DifficultyConfig>{
    Difficulty.easy: DifficultyConfig(
      seconds: 55,
      branchDepth: 3,
      leafCount: 42,
      trimTargets: 8,
      badCutPenalty: 5,
      passScore: 65,
    ),
    Difficulty.medium: DifficultyConfig(
      seconds: 45,
      branchDepth: 4,
      leafCount: 56,
      trimTargets: 12,
      badCutPenalty: 8,
      passScore: 72,
    ),
    Difficulty.hard: DifficultyConfig(
      seconds: 36,
      branchDepth: 5,
      leafCount: 72,
      trimTargets: 16,
      badCutPenalty: 11,
      passScore: 78,
    ),
  };

  Difficulty _difficulty = Difficulty.medium;
  int _level = 1;
  int _timeLeft = 45;

  bool _playing = false;
  bool _finished = false;

  final List<BranchSegment> _branches = <BranchSegment>[];
  final List<LeafNode> _leaves = <LeafNode>[];
  final List<TrimPoint> _trimPoints = <TrimPoint>[];
  final List<CutParticle> _particles = <CutParticle>[];

  int _totalCuts = 0;
  int _badCuts = 0;
  int _removedExcess = 0;
  int _trimHits = 0;

  @override
  void initState() {
    super.initState();
    _fxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);
    _resetRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fxController.dispose();
    super.dispose();
  }

  DifficultyConfig get _cfg => _difficultyConfig[_difficulty]!;

  String get _difficultyLabel {
    switch (_difficulty) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  void _resetRound() {
    _timer?.cancel();
    _playing = false;
    _finished = false;
    _timeLeft = _cfg.seconds;
    _totalCuts = 0;
    _badCuts = 0;
    _removedExcess = 0;
    _trimHits = 0;
    _trimPoints.clear();
    _particles.clear();
    _generateProceduralTree();
    if (mounted) setState(() {});
  }

  void _startRound() {
    _resetRound();
    _playing = true;
    _fxController.repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_playing) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _finishRound();
        }
      });
    });
  }

  void _finishRound() {
    _playing = false;
    _finished = true;
    _timer?.cancel();
    _fxController.stop();
    final result = _computeResult();
    final passed = result.score >= _cfg.passScore;
    if (passed) _level++;
    _showResultDialog(result, passed);
  }

  void _generateProceduralTree() {
    _branches.clear();
    _leaves.clear();

    int branchId = 0;
    int leafId = 0;
    const Offset trunkBottom = Offset(0.5, 0.93);
    final trunkTopY = 0.63 - (_random.nextDouble() * 0.07);
    final Offset trunkTop = Offset(0.5 + (_random.nextDouble() - 0.5) * 0.03, trunkTopY);

    _branches.add(
      BranchSegment(
        id: branchId++,
        start: trunkBottom,
        end: trunkTop,
        thickness: 14,
        essential: true,
      ),
    );

    void growBranch(
      Offset start,
      double angle,
      int depth,
      double length,
      double thickness,
      bool essential,
    ) {
      if (depth <= 0) return;
      final Offset end = Offset(
        (start.dx + cos(angle) * length).clamp(0.08, 0.92),
        (start.dy + sin(angle) * length).clamp(0.12, 0.92),
      );

      _branches.add(
        BranchSegment(
          id: branchId++,
          start: start,
          end: end,
          thickness: thickness,
          essential: essential,
        ),
      );

      final int leavesHere = 1 + _random.nextInt(3);
      for (int i = 0; i < leavesHere; i++) {
        final p = _random.nextDouble();
        final Offset lp = Offset.lerp(start, end, p)!;
        _leaves.add(
          LeafNode(
            id: leafId++,
            center: Offset(
              (lp.dx + (_random.nextDouble() - 0.5) * 0.06).clamp(0.06, 0.94),
              (lp.dy + (_random.nextDouble() - 0.5) * 0.05).clamp(0.08, 0.9),
            ),
            radius: 12 + _random.nextDouble() * 8,
            necessary: _random.nextDouble() > 0.5,
          ),
        );
      }

      final branchCount = 3 + (_random.nextBool() ? 1 : 0);
      for (int i = 0; i < branchCount; i++) {
        final spread = (i - (branchCount - 1) / 2) * 0.5;
        final nextAngle = angle - 0.72 + spread + (_random.nextDouble() - 0.5) * 0.18;
        growBranch(
          end,
          nextAngle,
          depth - 1,
          length * (0.68 + _random.nextDouble() * 0.16),
          max(2.5, thickness * 0.7),
          depth > 2,
        );
      }
    }

    final depth = _cfg.branchDepth + ((_level - 1) ~/ 3).clamp(0, 2);
    growBranch(
      trunkTop,
      -pi / 2,
      depth,
      0.16,
      9,
      true,
    );

    final canopyCenters = <Offset>[
      const Offset(0.5, 0.28),
      const Offset(0.41, 0.35),
      const Offset(0.59, 0.35),
      const Offset(0.34, 0.42),
      const Offset(0.66, 0.42),
      const Offset(0.5, 0.44),
    ];
    while (_leaves.length < _cfg.leafCount) {
      final cc = canopyCenters[_random.nextInt(canopyCenters.length)];
      final dx = (_random.nextDouble() - 0.5) * 0.12;
      final dy = (_random.nextDouble() - 0.5) * 0.1;
      _leaves.add(
        LeafNode(
          id: leafId++,
          center: Offset(
            (cc.dx + dx).clamp(0.18, 0.82),
            (cc.dy + dy).clamp(0.14, 0.62),
          ),
          radius: 11 + _random.nextDouble() * 8,
          necessary: _random.nextDouble() > 0.58,
        ),
      );
    }
    _generateTrimPoints();
  }

  void _generateTrimPoints() {
    final excessLeaves = _leaves.where((l) => !l.necessary).toList();
    excessLeaves.shuffle(_random);
    final target = _cfg.trimTargets;
    for (int i = 0; i < min(target, excessLeaves.length); i++) {
      final l = excessLeaves[i];
      _trimPoints.add(
        TrimPoint(
          position: l.center,
          radius: 0.028 + _random.nextDouble() * 0.008,
        ),
      );
    }
    while (_trimPoints.length < target) {
      _trimPoints.add(
        TrimPoint(
          position: Offset(
            0.26 + _random.nextDouble() * 0.48,
            0.21 + _random.nextDouble() * 0.34,
          ),
          radius: 0.028 + _random.nextDouble() * 0.01,
        ),
      );
    }
  }

  void _updateParticles() {
    if (!_playing && _particles.isEmpty) return;
    setState(() {
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.position = p.position + p.velocity;
        p.velocity = Offset(p.velocity.dx, p.velocity.dy + 0.0015);
        p.life -= 0.022;
        if (p.life <= 0) _particles.removeAt(i);
      }
    });
  }

  void _onCutAt(Offset localPos, Size size) {
    if (!_playing) return;
    final Offset p = Offset(localPos.dx / size.width, localPos.dy / size.height);

    bool didCut = false;
    for (final t in _trimPoints) {
      if (t.hit) continue;
      if ((p - t.position).distance <= t.radius) {
        t.hit = true;
        _trimHits++;
        _totalCuts++;
        _removeNearbyExcessLeaves(t.position, radius: 0.06);
        _spawnParticles(p, const Color(0xFF81C784));
        didCut = true;
        break;
      }
    }

    if (!didCut) {
      _totalCuts++;
      _badCuts++;
      _spawnParticles(p, const Color(0xFF8D6E63));
    }
    setState(() {});
  }

  void _removeNearbyExcessLeaves(Offset point, {required double radius}) {
    for (final leaf in _leaves) {
      if (!leaf.active || leaf.necessary) continue;
      if ((leaf.center - point).distance <= radius) {
        leaf.active = false;
        _removedExcess++;
      }
    }
  }

  void _spawnParticles(Offset p, Color color) {
    for (int i = 0; i < 10; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = 0.003 + _random.nextDouble() * 0.004;
      _particles.add(
        CutParticle(
          position: p,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          life: 1,
          color: color,
        ),
      );
    }
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 == 0) return (p - a).distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / ab2).clamp(0, 1).toDouble();
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  _RoundResult _computeResult() {
    final left = _visibleLeafCount((leaf) => leaf.center.dx < 0.5);
    final right = _visibleLeafCount((leaf) => leaf.center.dx >= 0.5);
    final totalVisible = max(1, left + right);
    final symmetry = 100 - (((left - right).abs() / totalVisible) * 100).clamp(0, 100);

    final unnecessaryTotal = _leaves.where((l) => !l.necessary).length;
    final unnecessaryRemoved = _removedExcess;
    final cleanliness = unnecessaryTotal == 0
        ? 100.0
        : (unnecessaryRemoved / unnecessaryTotal * 100).clamp(0, 100);

    final unnecessaryCuts = max(1, _totalCuts);
    final efficiency = (100 - ((_badCuts / unnecessaryCuts) * 100)).clamp(0, 100);
    final trimCompletion = (_trimHits / max(1, _trimPoints.length) * 100).clamp(0, 100);

    final score = (trimCompletion * 0.45 + symmetry * 0.25 + cleanliness * 0.20 + efficiency * 0.10)
            .round() -
        (_badCuts * _cfg.badCutPenalty).round();

    return _RoundResult(
      symmetry: symmetry.toDouble(),
      cleanliness: cleanliness.toDouble(),
      efficiency: efficiency.toDouble(),
      trimCompletion: trimCompletion.toDouble(),
      score: max(0, score),
      badCuts: _badCuts,
      totalCuts: _totalCuts,
    );
  }

  int _visibleLeafCount(bool Function(LeafNode leaf) test) {
    return _leaves.where((l) => l.active).where(test).length;
  }

  void _showResultDialog(_RoundResult result, bool passed) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(passed ? 'Great Pruning!' : 'Round Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score: ${result.score}'),
              const SizedBox(height: 8),
              Text('Symmetry: ${result.symmetry.toStringAsFixed(0)}%'),
              Text('Cleanliness: ${result.cleanliness.toStringAsFixed(0)}%'),
              Text('Efficiency: ${result.efficiency.toStringAsFixed(0)}%'),
              Text('Trim points: ${result.trimCompletion.toStringAsFixed(0)}%'),
              const SizedBox(height: 8),
              Text('Bad cuts: ${result.badCuts}/${result.totalCuts}'),
              const SizedBox(height: 10),
              Text(
                passed
                    ? 'Level cleared. Next level unlocked.'
                    : 'Need ${_cfg.passScore}+ score to clear this level.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetRound();
              },
              child: const Text('Replay'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startRound();
              },
              child: const Text('Start New Round'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onTapDown: (d) => _onCutAt(d.localPosition, size),
              onPanStart: (d) => _onCutAt(d.localPosition, size),
              onPanUpdate: (d) => _onCutAt(d.localPosition, size),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GardenPainter(
                        branches: _branches,
                        leaves: _leaves,
                        trimPoints: _trimPoints,
                        particles: _particles,
                        level: _level,
                        playing: _playing,
                      ),
                    ),
                  ),
                  _buildTopHud(),
                  if (!_playing && !_finished) _buildStartCard(),
                  if (_finished) const SizedBox.shrink(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHud() {
    return Positioned(
      left: 14,
      right: 14,
      top: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.84),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _chip('Level $_level'),
                const SizedBox(width: 8),
                _chip(_difficultyLabel),
                const Spacer(),
                _chip('Time ${_timeLeft}s'),
                const SizedBox(width: 8),
                _chip('Trim ${_trimHits}/${_trimPoints.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<Difficulty>(
                    segments: const [
                      ButtonSegment(value: Difficulty.easy, label: Text('Easy')),
                      ButtonSegment(value: Difficulty.medium, label: Text('Medium')),
                      ButtonSegment(value: Difficulty.hard, label: Text('Hard')),
                    ],
                    selected: <Difficulty>{_difficulty},
                    onSelectionChanged: _playing
                        ? null
                        : (value) {
                            setState(() {
                              _difficulty = value.first;
                              _resetRound();
                            });
                          },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildStartCard() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Garden Pruner',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2E5E33)),
            ),
            const SizedBox(height: 10),
            const Text(
              'Trim a random procedural tree.\nHit the glowing trim points to shape the canopy cleanly.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Trim points: ${_cfg.trimTargets} • Pass score: ${_cfg.passScore} • Round: ${_cfg.seconds}s',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4E7C59)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startRound,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('START ROUND'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundResult {
  final double symmetry;
  final double cleanliness;
  final double efficiency;
  final double trimCompletion;
  final int score;
  final int badCuts;
  final int totalCuts;

  _RoundResult({
    required this.symmetry,
    required this.cleanliness,
    required this.efficiency,
    required this.trimCompletion,
    required this.score,
    required this.badCuts,
    required this.totalCuts,
  });
}

class _GardenPainter extends CustomPainter {
  final List<BranchSegment> branches;
  final List<LeafNode> leaves;
  final List<TrimPoint> trimPoints;
  final List<CutParticle> particles;
  final int level;
  final bool playing;

  _GardenPainter({
    required this.branches,
    required this.leaves,
    required this.trimPoints,
    required this.particles,
    required this.level,
    required this.playing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    _paintGround(canvas, size);
    _paintTree(canvas, size);
    _paintTrimTargets(canvas, size);
    _paintParticles(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE3F2FD), Color(0xFFFFF8E1)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final hillPaint = Paint()..color = const Color(0xFFC8E6C9).withOpacity(0.9);
    final hill = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(size.width * 0.22, size.height * 0.58, size.width * 0.45, size.height * 0.68)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.75, size.width, size.height * 0.64)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(hill, hillPaint);
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF59D).withOpacity(0.95), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.14, size.height * 0.14), radius: 80));
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.14), 80, sunPaint);
  }

  void _paintGround(Canvas canvas, Size size) {
    final ground = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF81C784), Color(0xFF4CAF50)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      ground,
    );
  }

  void _paintTree(Canvas canvas, Size size) {
    final activeLeaves = leaves.where((l) => l.active).toList();
    if (activeLeaves.isNotEmpty) {
      final cloud = Path()
        ..addOval(Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.31),
          width: size.width * 0.36,
          height: size.height * 0.2,
        ))
        ..addOval(Rect.fromCenter(
          center: Offset(size.width * 0.39, size.height * 0.39),
          width: size.width * 0.28,
          height: size.height * 0.18,
        ))
        ..addOval(Rect.fromCenter(
          center: Offset(size.width * 0.61, size.height * 0.39),
          width: size.width * 0.28,
          height: size.height * 0.18,
        ))
        ..addOval(Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.47),
          width: size.width * 0.38,
          height: size.height * 0.2,
        ));
      canvas.drawPath(
        cloud,
        Paint()..color = const Color(0xFF74B972).withOpacity(0.42),
      );
      final canopyBase = Paint()
        ..color = const Color(0xFF7CBF7A).withOpacity(0.28)
        ..style = PaintingStyle.fill;
      final canopyGlow = Paint()
        ..color = const Color(0xFFAEDFA4).withOpacity(0.22)
        ..style = PaintingStyle.fill;
      for (final l in activeLeaves) {
        final c = Offset(l.center.dx * size.width, l.center.dy * size.height);
        final r = l.radius * 1.35;
        canvas.drawCircle(c, r, canopyBase);
        canvas.drawCircle(c.translate(-3, -3), r * 0.72, canopyGlow);
      }
    }

    final trunkGlow = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF8D6E63), const Color(0xFF5D4037), const Color(0xFF3E2723)],
      ).createShader(Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.5));
    for (final b in branches) {
      if (!b.active) continue;
      final p1 = Offset(b.start.dx * size.width, b.start.dy * size.height);
      final p2 = Offset(b.end.dx * size.width, b.end.dy * size.height);
      final paint = Paint()
        ..shader = trunkGlow.shader
        ..strokeWidth = b.thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
      canvas.drawLine(
        p1.translate(-1.2, -1.0),
        p2.translate(-1.2, -1.0),
        Paint()
          ..color = const Color(0xFFD7CCC8).withOpacity(0.22)
          ..strokeWidth = max(1, b.thickness * 0.18)
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final l in leaves) {
      if (!l.active) continue;
      final c = Offset(l.center.dx * size.width, l.center.dy * size.height);
      final r = l.radius;
      final color = l.necessary ? const Color(0xFF66BB6A) : const Color(0xFFA5D6A7);
      final fill = Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.98), color.withOpacity(0.78)],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2.15, height: r * 1.8),
        fill,
      );
      if (!l.necessary) {
        canvas.drawCircle(c, r * 0.45, Paint()..color = Colors.white.withOpacity(0.25));
      }
    }
  }

  void _paintTrimTargets(Canvas canvas, Size size) {
    for (final t in trimPoints) {
      final c = Offset(t.position.dx * size.width, t.position.dy * size.height);
      final rr = t.radius * size.shortestSide;
      if (t.hit) {
        canvas.drawCircle(
          c,
          rr * 0.72,
          Paint()..color = const Color(0xFF66BB6A).withOpacity(0.55),
        );
        canvas.drawLine(
          c.translate(-rr * 0.35, 0),
          c.translate(-rr * 0.08, rr * 0.28),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          c.translate(-rr * 0.08, rr * 0.28),
          c.translate(rr * 0.38, -rr * 0.28),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..color = const Color(0xFFFFF3E0).withOpacity(0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..color = const Color(0xFFFFB74D)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke,
        );
        canvas.drawLine(
          c.translate(-rr * 0.45, 0),
          c.translate(rr * 0.45, 0),
          Paint()
            ..color = const Color(0xFFFFB74D)
            ..strokeWidth = 1.4,
        );
        canvas.drawLine(
          c.translate(0, -rr * 0.45),
          c.translate(0, rr * 0.45),
          Paint()
            ..color = const Color(0xFFFFB74D)
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  void _paintParticles(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.life.clamp(0, 1));
      canvas.drawCircle(
        Offset(p.position.dx * size.width, p.position.dy * size.height),
        2.5 + (1 - p.life) * 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GardenPainter oldDelegate) {
    return oldDelegate.branches != branches ||
        oldDelegate.leaves != leaves ||
        oldDelegate.trimPoints != trimPoints ||
        oldDelegate.particles != particles ||
        oldDelegate.level != level ||
        oldDelegate.playing != playing;
  }
}
