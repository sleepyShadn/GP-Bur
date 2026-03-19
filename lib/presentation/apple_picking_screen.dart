// ========== lib/presentation/apple_picking_screen.dart ==========
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../domain/apple_picking_logic.dart';
import '../../data/apple_picking_data.dart';

class ApplePickingScreen extends StatefulWidget {
  const ApplePickingScreen({super.key});

  @override
  State<ApplePickingScreen> createState() => _ApplePickingScreenState();
}

class _ApplePickingScreenState extends State<ApplePickingScreen>
    with SingleTickerProviderStateMixin {
  final ApplePickingLogic _logic = ApplePickingLogic();
  final ApplePickingData _data = ApplePickingData();

  int _score = 0;
  int _timeLeft = 60;
  int _missedApples = 0;
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isPaused = false;

  double _bucketPosition = 0.5;
  final double _bucketWidth = 0.2;
  final double _bucketHeight = 60.0;

  List<Apple> _apples = [];
  final int _maxApples = 5;
  final Random _random = Random();
  Timer? _gameTimer;
  Timer? _appleSpawnTimer;
  late AnimationController _animationController;

  double _baseSpeed = 2.0;
  double _currentSpeed = 2.0;

  List<FloatingScore> _floatingScores = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateGame);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _appleSpawnTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _userId = user['uid']);
    }
  }

  void _startGame() {
    setState(() {
      _isGameActive = true;
      _isGameOver = false;
      _score = 0;
      _timeLeft = 60;
      _missedApples = 0;
      _apples.clear();
      _floatingScores.clear();
      _currentSpeed = _baseSpeed;
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
            if (_timeLeft < 40) _currentSpeed = _baseSpeed * 1.3;
            if (_timeLeft < 20) _currentSpeed = _baseSpeed * 1.6;
          } else {
            _endGame();
          }
        });
      }
    });

    _appleSpawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isPaused && _isGameActive && mounted && _apples.length < _maxApples) {
        _spawnApple();
      }
    });

    _animationController.repeat();
  }

  void _spawnApple() {
    setState(() {
      _apples.add(Apple(
        x: _random.nextDouble(),
        y: 0.1,
        speed: _currentSpeed,
      ));
    });
  }

  void _updateGame() {
    if (!_isGameActive || _isPaused || _isGameOver) return;

    setState(() {
      for (int i = _apples.length - 1; i >= 0; i--) {
        Apple apple = _apples[i];
        apple.y += apple.speed / 1000;

        if (_logic.checkCollision(apple, _bucketPosition, _bucketWidth)) {
          _apples.removeAt(i);
          _score += 2;
          _floatingScores.add(FloatingScore(
            value: 2,
            x: _bucketPosition,
            y: 0.8,
            opacity: 1.0,
          ));
        } else if (apple.y > 0.95) {
          _apples.removeAt(i);
          _missedApples++;
        }
      }

      for (int i = _floatingScores.length - 1; i >= 0; i--) {
        _floatingScores[i].y -= 0.01;
        _floatingScores[i].opacity -= 0.02;
        if (_floatingScores[i].opacity <= 0) {
          _floatingScores.removeAt(i);
        }
      }
    });
  }

  Future<void> _endGame() async {
    _gameTimer?.cancel();
    _appleSpawnTimer?.cancel();
    _animationController.stop();

    if (_userId != null && _score > 0 && mounted) {
      await _data.saveScoreToFirebase(_userId!, _score, _missedApples, _timeLeft);
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isGameActive) {
                            _logic.showExitDialog(context, _endGame);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _logic.colorPinkish,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.exit_to_app, color: Color(0xFFA5B68D), size: 24),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: _logic.colorPinkish,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer, color: Color(0xFFA5B68D), size: 20),
                            const SizedBox(width: 5),
                            Text(
                              _logic.formatTime(_timeLeft),
                              style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: _logic.colorPinkish,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFA5B68D), size: 20),
                            const SizedBox(width: 5),
                            Text(
                              '$_score',
                              style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    '🍎 APPLE PICKING 🍎',
                    style: TextStyle(color: Color(0xFFA5B68D), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
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
                        Center(
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _logic.colorGreenLight.withOpacity(0.3),
                                  _logic.colorCream,
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: 0,
                                  left: MediaQuery.of(context).size.width * 0.45,
                                  child: Container(
                                    width: 50,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: _logic.colorPlaceholder.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 50,
                                  left: MediaQuery.of(context).size.width * 0.3,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: _logic.colorGreenDark.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ..._apples.map((apple) => Positioned(
                          left: MediaQuery.of(context).size.width * apple.x - 15,
                          top: MediaQuery.of(context).size.height * apple.y * 0.7,
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, double scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: const Text('🍎', style: TextStyle(fontSize: 30)),
                              );
                            },
                          ),
                        )).toList(),
                        ..._floatingScores.map((score) => Positioned(
                          left: MediaQuery.of(context).size.width * score.x - 15,
                          top: MediaQuery.of(context).size.height * score.y,
                          child: Opacity(
                            opacity: score.opacity,
                            child: const Text('+2', style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                        )).toList(),
                        Positioned(
                          bottom: 50,
                          left: MediaQuery.of(context).size.width * (_bucketPosition - _bucketWidth / 2),
                          child: Container(
                            width: MediaQuery.of(context).size.width * _bucketWidth,
                            height: _bucketHeight,
                            decoration: BoxDecoration(
                              color: _logic.colorPlaceholder,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width * _bucketWidth - 10,
                                height: _bucketHeight - 10,
                                decoration: BoxDecoration(
                                  color: _logic.colorGreenDark,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Center(
                                  child: Icon(Icons.shopping_basket, color: Colors.white, size: 30),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!_isGameActive && !_isGameOver)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: _logic.colorCream.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('🍎', style: TextStyle(fontSize: 80)),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Apple Picking Game',
                                        style: TextStyle(color: Color(0xFFA5B68D), fontSize: 24, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Catch falling apples to earn points!\nEach apple = 2 points',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF362427), fontSize: 14),
                                      ),
                                      const SizedBox(height: 30),
                                      ElevatedButton(
                                        onPressed: _startGame,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _logic.colorGreenDark,
                                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                        ),
                                        child: const Text(
                                          'START GAME',
                                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: _logic.colorCream.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('⏸️', style: TextStyle(fontSize: 50)),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Game Paused',
                                    style: TextStyle(color: Color(0xFFA5B68D), fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _pauseGame,
                                    style: ElevatedButton.styleFrom(backgroundColor: _logic.colorGreenDark),
                                    child: const Text('Resume', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_isGameActive)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: _pauseGame,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _logic.colorPinkish, shape: BoxShape.circle),
                            child: Icon(
                              _isPaused ? Icons.play_arrow : Icons.pause,
                              color: _logic.colorGreenDark,
                              size: 30,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              const Text('🍎 ', style: TextStyle(fontSize: 16)),
                              Text(
                                '${_apples.length}',
                                style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
