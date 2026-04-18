// ========== lib/presentation/apple_picking_screen.dart ==========
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:math';
import '../../domain/apple_picking_logic.dart';
import '../../data/apple_picking_data.dart';
import '../../services/game_audio_service.dart';

class ApplePickingScreen extends StatefulWidget {
  const ApplePickingScreen({super.key});

  @override
  State<ApplePickingScreen> createState() => _ApplePickingScreenState();
}

class _ApplePickingScreenState extends State<ApplePickingScreen>
    with SingleTickerProviderStateMixin {
  final ApplePickingLogic _logic = ApplePickingLogic();
  final ApplePickingData _data = ApplePickingData();
  final GameAudioService _audio = GameAudioService();

  int _score = 0;
  int _timeLeft = 60;
  int _missedApples = 0;
  int _caughtApples = 0;
  int _comboCount = 0;
  int _level = 1;
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isPaused = false;

  double _bucketPosition = 0.5;
  final double _baseBucketWidth = 0.2;
  double _bucketWidth = 0.2;
  final double _bucketHeight = 60.0;

  List<Apple> _apples = [];
  int _maxApples = 5;
  final Random _random = Random();
  Timer? _gameTimer;
  Timer? _appleSpawnTimer;
  Timer? _levelUpBannerTimer;
  late AnimationController _animationController;

  double _baseSpeed = 2.8;
  double _currentSpeed = 2.0;
  int _spawnIntervalMs = 850;

  List<FloatingScore> _floatingScores = [];
  List<CatchParticle> _catchParticles = [];
  List<BonusDrop> _bonusDrops = [];
  String? _userId;
  bool _showLevelUpBanner = false;
  int _levelUpShown = 1;
  String _bannerText = '';
  double _bucketShakeIntensity = 0;
  double _bucketShakePhase = 0;
  bool _isBucketBoosted = false;
  int _bucketBoostLeft = 0;
  int _bonusCooldown = 0;
  bool _isBucketShrunk = false;
  int _rottenDebuffLeft = 0;
  static const List<int> _levelCatchTargets = <int>[0, 6, 14, 24, 36];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _audio.init().then((_) {
      if (!mounted) return;
      if (!_isGameActive && !_isGameOver) {
        _audio.startPreGameLoop();
      }
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateGame);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _appleSpawnTimer?.cancel();
    _levelUpBannerTimer?.cancel();
    _audio.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _userId = user['uid']);
    }
  }

  Future<void> _startGame() async {
    await _audio.stopPreGameLoop();
    await _audio.playButtonTap();
    setState(() {
      _isGameActive = true;
      _isGameOver = false;
      _score = 0;
      _timeLeft = 60;
      _missedApples = 0;
      _caughtApples = 0;
      _comboCount = 0;
      _level = 1;
      _showLevelUpBanner = false;
      _levelUpShown = 1;
      _bucketShakeIntensity = 0;
      _bucketShakePhase = 0;
      _bucketWidth = _baseBucketWidth;
      _isBucketBoosted = false;
      _bucketBoostLeft = 0;
      _bonusCooldown = 0;
      _isBucketShrunk = false;
      _rottenDebuffLeft = 0;
      _apples.clear();
      _floatingScores.clear();
      _catchParticles.clear();
      _bonusDrops.clear();
      _currentSpeed = _baseSpeed;
    });

    _startSpawnLoop();
    await _audio.playBgm();

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
            if (_bonusCooldown > 0) _bonusCooldown--;
            if (_bucketBoostLeft > 0) {
              _bucketBoostLeft--;
              if (_bucketBoostLeft == 0) {
                _isBucketBoosted = false;
                if (!_isBucketShrunk) _bucketWidth = _baseBucketWidth;
              }
            }
            if (_rottenDebuffLeft > 0) {
              _rottenDebuffLeft--;
              if (_rottenDebuffLeft == 0) {
                _isBucketShrunk = false;
                if (!_isBucketBoosted) _bucketWidth = _baseBucketWidth;
              }
            }
          } else {
            _endGame();
          }
        });
      }
    });

    _animationController.repeat();
  }

  void _startSpawnLoop() {
    _appleSpawnTimer?.cancel();
    _appleSpawnTimer =
        Timer.periodic(Duration(milliseconds: _spawnIntervalMs), (timer) {
      if (!_isPaused && _isGameActive && mounted && _apples.length < _maxApples) {
        _spawnApple();
      }
      if (!_isPaused &&
          _isGameActive &&
          mounted &&
          _bonusDrops.isEmpty &&
          _bonusCooldown == 0 &&
          _random.nextDouble() < _bonusSpawnChanceForLevel()) {
        _spawnBonusDrop();
      }
    });
  }

  void _updateDifficulty() {
    final previousLevel = _level;
    var newLevel = 1;
    for (int i = 1; i < _levelCatchTargets.length; i++) {
      if (_caughtApples >= _levelCatchTargets[i]) {
        newLevel = i + 1;
      }
    }
    _level = newLevel.clamp(1, 5);
    if (_level > previousLevel) {
      _showBanner('LEVEL $_level!');
    }

    _currentSpeed = _baseSpeed + ((_level - 1) * 0.8);
    _maxApples = 4 + (_level * 2);
    final targetInterval = (860 - ((_level - 1) * 130)).clamp(280, 860);

    if (targetInterval != _spawnIntervalMs) {
      _spawnIntervalMs = targetInterval;
      _startSpawnLoop();
    }
  }

  double _bonusSpawnChanceForLevel() {
    final chance = 0.09 - ((_level - 1) * 0.012);
    return chance.clamp(0.035, 0.09);
  }

  void _showBanner(String text) {
    _levelUpBannerTimer?.cancel();
    setState(() {
      _bannerText = text;
      _showLevelUpBanner = true;
    });
    if (text.startsWith('LEVEL')) {
      _audio.playLevelUp();
    }
    _levelUpBannerTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showLevelUpBanner = false);
      }
    });
  }

  void _spawnApple() {
    setState(() {
      _apples.add(Apple(
        x: 0.08 + (_random.nextDouble() * 0.84),
        y: 0.1,
        speed: _currentSpeed,
        size: 26 + (_random.nextDouble() * 10),
        driftAmplitude: 0.001 + (_random.nextDouble() * 0.002),
        driftSpeed: 0.04 + (_random.nextDouble() * 0.04),
        rotationSpeed: 0.01 + (_random.nextDouble() * 0.02),
        phase: _random.nextDouble() * pi * 2,
        isRotten: _random.nextDouble() < (0.07 + ((_level - 1) * 0.02)).clamp(0.07, 0.17),
      ));
    });
  }

  void _spawnBonusDrop() {
    setState(() {
      _bonusDrops.add(
        BonusDrop(
          x: 0.1 + (_random.nextDouble() * 0.8),
          y: 0.12,
          speed: _currentSpeed * 0.8,
        ),
      );
      _bonusCooldown = 16;
    });
  }

  void _updateGame() {
    if (!_isGameActive || _isPaused || _isGameOver) return;

    setState(() {
      for (int i = _apples.length - 1; i >= 0; i--) {
        Apple apple = _apples[i];
        apple.phase += apple.driftSpeed;
        apple.x += sin(apple.phase) * apple.driftAmplitude;
        apple.x = apple.x.clamp(0.06, 0.94);
        apple.y += apple.speed / 1000;

        if (_logic.checkCollision(apple, _bucketPosition, _bucketWidth)) {
          _apples.removeAt(i);
          if (apple.isRotten) {
            _comboCount = 0;
            _score = max(0, _score - 3);
            _floatingScores.add(FloatingScore(
              value: -3,
              x: _bucketPosition,
              y: 0.8,
              opacity: 1.0,
            ));
            _spawnCatchParticles(_bucketPosition, 0.82, const Color(0xFF8D6E63));
            _activateRottenDebuff();
            _showBanner('ROTTEN APPLE! -3');
            _audio.playRottenHit();
          } else {
            _caughtApples++;
            _updateDifficulty();
            _comboCount++;
            final comboBonus = _comboCount >= 5 ? 1 : 0;
            final earned = 2 + comboBonus;
            _score += earned;
            _floatingScores.add(FloatingScore(
              value: earned,
              x: _bucketPosition,
              y: 0.8,
              opacity: 1.0,
            ));
            _spawnCatchParticles(_bucketPosition, 0.82, const Color(0xFFFFF176));
            _audio.playAppleCatch();
          }
          _bucketShakeIntensity = 1;
        } else if (apple.y > 1.35) {
          _apples.removeAt(i);
          _missedApples++;
          _comboCount = 0;
        }
      }

      for (int i = _bonusDrops.length - 1; i >= 0; i--) {
        final bonus = _bonusDrops[i];
        bonus.y += bonus.speed / 1000;
        final bonusAsApple = Apple(
          x: bonus.x,
          y: bonus.y,
          speed: bonus.speed,
          size: 28,
          driftAmplitude: 0,
          driftSpeed: 0,
          rotationSpeed: 0,
          phase: 0,
        );
        if (_logic.checkCollision(bonusAsApple, _bucketPosition, _bucketWidth)) {
          _bonusDrops.removeAt(i);
          _activateBucketBonus();
        } else if (bonus.y > 1.35) {
          _bonusDrops.removeAt(i);
        }
      }

      for (int i = _floatingScores.length - 1; i >= 0; i--) {
        _floatingScores[i].y -= 0.01;
        _floatingScores[i].opacity -= 0.02;
        if (_floatingScores[i].opacity <= 0) {
          _floatingScores.removeAt(i);
        }
      }

      for (int i = _catchParticles.length - 1; i >= 0; i--) {
        final particle = _catchParticles[i];
        particle.x += particle.dx;
        particle.y += particle.dy;
        particle.dy += 0.0004;
        particle.opacity -= 0.03;
        if (particle.opacity <= 0) {
          _catchParticles.removeAt(i);
        }
      }

      if (_bucketShakeIntensity > 0) {
        _bucketShakePhase += 0.45;
        _bucketShakeIntensity -= 0.06;
        if (_bucketShakeIntensity < 0) _bucketShakeIntensity = 0;
      }
    });
  }

  void _spawnCatchParticles(double x, double y, Color color) {
    for (int i = 0; i < 8; i++) {
      final angle = (_random.nextDouble() * pi) + pi;
      final speed = 0.002 + (_random.nextDouble() * 0.003);
      _catchParticles.add(
        CatchParticle(
          x: x,
          y: y,
          dx: cos(angle) * speed,
          dy: sin(angle) * speed,
          size: 4 + (_random.nextDouble() * 3),
          opacity: 1,
          color: color,
        ),
      );
    }
  }

  void _activateBucketBonus() {
    _isBucketBoosted = true;
    _isBucketShrunk = false;
    _bucketWidth = (_baseBucketWidth * 1.45).clamp(0.2, 0.34);
    _bucketBoostLeft = 8;
    _showBanner('BONUS! BIG BASKET');
    _audio.playBonusCatch();
  }

  void _activateRottenDebuff() {
    _isBucketShrunk = true;
    _isBucketBoosted = false;
    _bucketBoostLeft = 0;
    _bucketWidth = (_baseBucketWidth * 0.78).clamp(0.14, 0.2);
    _rottenDebuffLeft = 5;
  }

  Future<void> _endGame() async {
    _gameTimer?.cancel();
    _appleSpawnTimer?.cancel();
    _animationController.stop();
    _audio.stopBgm();
    _audio.playGameOver();

    if (_userId != null && _score > 0 && mounted) {
      await _data.saveScoreToFirebase(
        _userId!,
        _score,
        _caughtApples,
        _missedApples,
        _timeLeft,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Earned $_score points!'),
            backgroundColor: _logic.colorGreenDark,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isGameActive = false;
        _isGameOver = true;
      });
      _logic.showGameOverDialog(context, _score, _missedApples, _timeLeft, _startGame);
    }
  }

  void _pauseGame() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _audio.playPause();
      _audio.pauseBgm();
    } else {
      _audio.playResume();
      _audio.resumeBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _logic.colorCream,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -30,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: _logic.colorPinkish.withOpacity(0.4),
            ),
          ),
          Positioned(
            bottom: 150,
            right: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: _logic.colorGreenLight.withOpacity(0.3),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_isGameActive && !_isPaused) {
                        setState(() {
                          double delta = details.delta.dx / MediaQuery.of(context).size.width;
                          _bucketPosition = (_bucketPosition + delta).clamp(0.1, 0.9);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        if (_showLevelUpBanner)
                          Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.16),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _bannerText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.72,
                                    child: Lottie.asset(
                                      'assets/animations/sky.json',
                                      fit: BoxFit.cover,
                                      repeat: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 80,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: SizedBox(
                                      height: 92,
                                      child: Lottie.asset(
                                        'assets/animations/flower_animation.json',
                                        fit: BoxFit.cover,
                                        repeat: true,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 14,
                                  child: GestureDetector(
                                    onTap: () {
                                      _audio.playButtonTap();
                                      if (_isGameActive) {
                                        _logic.showExitDialog(context, _endGame);
                                      } else {
                                        Navigator.pop(context);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(11),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withOpacity(0.34),
                                            Colors.white.withOpacity(0.20),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.7),
                                          width: 1.1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0B1F3A).withOpacity(0.24),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.exit_to_app_rounded,
                                        color: Color(0xFFF8FBFF),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 70,
                                  right: 14,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF0EA5E9).withOpacity(0.32),
                                              Colors.white.withOpacity(0.14),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.68),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0B1F3A).withOpacity(0.18),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.timer_outlined,
                                              color: Color(0xFFF8FBFF),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _logic.formatTime(_timeLeft),
                                              style: const TextStyle(
                                                color: Color(0xFFF8FBFF),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFFF59E0B).withOpacity(0.30),
                                              Colors.white.withOpacity(0.14),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.68),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0B1F3A).withOpacity(0.18),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFFFFF3C7),
                                                    Color(0xFFFFD166),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Color(0x73FFD166),
                                                    blurRadius: 6,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.workspace_premium_rounded,
                                                color: Color(0xFF7A4A00),
                                                size: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$_score',
                                              style: const TextStyle(
                                                color: Color(0xFFFFF8DE),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 66,
                                  left: 14,
                                  right: 14,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.white.withOpacity(0.26),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.55),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(9),
                                        child: LinearProgressIndicator(
                                          value: _level / 5,
                                          minHeight: 9,
                                          backgroundColor:
                                              const Color(0xFF1E293B).withOpacity(0.32),
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF22C55E),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ..._apples.map((apple) => Positioned(
                          left: MediaQuery.of(context).size.width * apple.x - (apple.size / 2),
                          top: MediaQuery.of(context).size.height * apple.y * 0.7,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.94, end: 1.04),
                            duration: const Duration(milliseconds: 420),
                            builder: (context, scale, child) {
                              return Transform.rotate(
                                angle: sin(apple.phase) * apple.rotationSpeed * 10,
                                child: Transform.scale(scale: scale, child: child),
                              );
                            },
                            child: apple.isRotten
                                ? _buildRottenAppleWidget(apple.size)
                                : _buildAppleWidget(apple.size),
                          ),
                        )).toList(),
                        ..._floatingScores.map((score) => Positioned(
                          left: MediaQuery.of(context).size.width * score.x - 15,
                          top: MediaQuery.of(context).size.height * score.y,
                          child: Opacity(
                            opacity: score.opacity,
                            child: Text(
                              '${score.value > 0 ? '+' : ''}${score.value}',
                              style: TextStyle(
                                color: score.value > 0
                                    ? Colors.green
                                    : const Color(0xFFD84315),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )).toList(),
                        ..._catchParticles.map(
                          (p) => Positioned(
                            left: MediaQuery.of(context).size.width * p.x,
                            top: MediaQuery.of(context).size.height * p.y * 0.9,
                            child: Opacity(
                              opacity: p.opacity.clamp(0, 1),
                              child: Container(
                                width: p.size,
                                height: p.size,
                                decoration: BoxDecoration(
                                  color: p.color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.color.withOpacity(0.75),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ..._bonusDrops.map(
                          (bonus) => Positioned(
                            left: MediaQuery.of(context).size.width * bonus.x - 14,
                            top: MediaQuery.of(context).size.height * bonus.y * 0.7,
                            child: _buildBonusGift(),
                          ),
                        ),
                        Positioned(
                          bottom: 68,
                          left: MediaQuery.of(context).size.width * (_bucketPosition - _bucketWidth / 2),
                          child: Transform.translate(
                            offset: Offset(
                              sin(_bucketShakePhase) * 5 * _bucketShakeIntensity,
                              0,
                            ),
                            child: Container(
                              width: MediaQuery.of(context).size.width * _bucketWidth,
                              height: _bucketHeight,
                              decoration: BoxDecoration(
                                color: _logic.colorPlaceholder,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: _buildBucketWidget(),
                            ),
                          ),
                        ),
                        if (!_isGameActive && !_isGameOver)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 24),
                                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF2D3F55).withOpacity(0.82),
                                        const Color(0xFF3A5068).withOpacity(0.76),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.24),
                                      width: 1.1,
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
                                    children: [
                                      Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.12),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.2),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text('🍎', style: TextStyle(fontSize: 54)),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        'Apple Picking Game',
                                        style: TextStyle(
                                          color: Color(0xFFF8FBFF),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Relax, pick, and repeat.\nA meditative apple-picking experience designed to help you unwind.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xFFDCE6F2),
                                          fontSize: 14,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.16),
                                          ),
                                        ),
                                        child: const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Game Benefits',
                                              style: TextStyle(
                                                color: Color(0xFFFFD166),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '• Helps you slow down and relax',
                                              style: TextStyle(
                                                color: Color(0xFFDCE6F2),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '• Improves focus through simple repetition',
                                              style: TextStyle(
                                                color: Color(0xFFDCE6F2),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '• Gives a calm, stress-free break',
                                              style: TextStyle(
                                                color: Color(0xFFDCE6F2),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Catch apples to earn points (2 points per apple)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: const Color(0xFFFFD166),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      ElevatedButton(
                                        onPressed: _startGame,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFFD166),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 42,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          elevation: 2,
                                          shadowColor: Colors.black.withOpacity(0.24),
                                        ),
                                        child: const Text(
                                          'START GAME',
                                          style: TextStyle(
                                            color: Color(0xFF2A3A4F),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_isPaused && _isGameActive)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 28),
                              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1E2A3A).withOpacity(0.84),
                                    const Color(0xFF26364A).withOpacity(0.78),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.24),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.pause_circle_outline_rounded,
                                      color: Color(0xFFEAF2FC),
                                      size: 38,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Game Paused',
                                    style: TextStyle(
                                      color: Color(0xFFF8FBFF),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Take a breath, then continue when ready.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFDCE6F2),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton(
                                    onPressed: _pauseGame,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFD166),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Resume',
                                      style: TextStyle(
                                        color: Color(0xFF2A3A4F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_isGameActive)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: _pauseGame,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.24),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.55),
                                        width: 1.1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isPaused ? Icons.play_arrow : Icons.pause,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.10),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🍎 ', style: TextStyle(fontSize: 16)),
                                      Text(
                                        '${_apples.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.10),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Lv $_level | Combo x$_comboCount${_isBucketBoosted ? ' | Bonus ${_bucketBoostLeft}s' : ''}${_isBucketShrunk ? ' | Rotten ${_rottenDebuffLeft}s' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleWidget(double size) {
    return Text(
      '🍎',
      style: TextStyle(
        fontSize: size + 6,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(1, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildRottenAppleWidget(double size) {
    return Text(
      '🍏',
      style: TextStyle(
        fontSize: size + 6,
        shadows: [
          Shadow(
            color: const Color(0xFF4E342E).withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(1, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildBucketWidget() {
    final pulse = (sin(_animationController.value * 2 * pi) + 1) / 2;
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * _bucketWidth - 10,
        height: _bucketHeight - 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: MediaQuery.of(context).size.width * _bucketWidth * 0.72,
                height: 17,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE2C19F), Color(0xFF9D6A42)],
                  ),
                  border: Border.all(color: const Color(0xFF5B3B25), width: 2.2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width * _bucketWidth - 10,
                height: _bucketHeight - 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD39C6D), Color(0xFF724222)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4B2E1A), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 3,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 13,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 2,
                        color: const Color(0xFF8D5B36).withOpacity(0.45),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 2,
                        color: const Color(0xFF8D5B36).withOpacity(0.40),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        color: const Color(0xFFFFE1BF).withOpacity(0.45),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            5,
                            (index) => Container(
                              width: 3,
                              color: const Color(0xFFE1B184).withOpacity(0.55),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.shopping_basket_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    if (!_isBucketBoosted)
                      Positioned(
                        top: 6,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              const Color(0xFFB0BEC5),
                              const Color(0xFFECEFF1),
                              pulse,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (_isBucketBoosted)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'BONUS',
                            style: TextStyle(
                              color: Color(0xFF5D4037),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusGift() {
    final pulse = (sin(_animationController.value * 2 * pi) + 1) / 2;
    final orbSize = 26 + (pulse * 4);
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: orbSize + 8,
            height: orbSize + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF80DEEA).withOpacity(0.18 + (pulse * 0.15)),
            ),
          ),
          Container(
            width: orbSize,
            height: orbSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.2, -0.3),
                radius: 0.9,
                colors: [Color(0xFF80D8FF), Color(0xFF0091EA)],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF40C4FF).withOpacity(0.55),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

}
