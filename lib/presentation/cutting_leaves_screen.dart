// ========== lib/presentation/cutting_leaves_screen.dart ==========
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../domain/cutting_leaves_logic.dart';
import '../../data/cutting_leaves_data.dart';

class CuttingLeavesScreen extends StatefulWidget {
  const CuttingLeavesScreen({super.key});

  @override
  State<CuttingLeavesScreen> createState() => _CuttingLeavesScreenState();
}

class _CuttingLeavesScreenState extends State<CuttingLeavesScreen>
    with SingleTickerProviderStateMixin {
  final CuttingLeavesLogic _logic = CuttingLeavesLogic();
  final CuttingLeavesData _data = CuttingLeavesData();

  int _score = 0;
  int _timeLeft = 60;
  int _leavesCut = 0;
  int _totalLeaves = 12;
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _isPaused = false;

  List<Leaf> _leaves = [];
  final Random _random = Random();
  Timer? _gameTimer;
  late AnimationController _animationController;

  List<CutEffect> _cutEffects = [];
  bool _hapticEnabled = true;
  String? _userId;
  String _difficulty = 'Medium';

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateEffects);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _userId = user['uid']);
    }
  }

  void _setDifficulty(String difficulty) {
    setState(() {
      _difficulty = difficulty;
      switch (difficulty) {
        case 'Easy':
          _totalLeaves = 8;
          break;
        case 'Medium':
          _totalLeaves = 12;
          break;
        case 'Hard':
          _totalLeaves = 16;
          break;
      }
    });
  }

  void _initializeLeaves() {
    _leaves.clear();
    double centerX = 0.5;
    double centerY = 0.5;

    for (int i = 0; i < _totalLeaves; i++) {
      double angle = (2 * pi * i) / _totalLeaves;
      double radius = 0.15;
      if (_difficulty == 'Easy') radius = 0.2;
      if (_difficulty == 'Hard') radius = 0.12;

      double x = centerX + radius * cos(angle);
      double y = centerY + radius * sin(angle);

      x += (_random.nextDouble() - 0.5) * 0.05;
      y += (_random.nextDouble() - 0.5) * 0.05;

      _leaves.add(Leaf(
        id: i,
        x: x.clamp(0.1, 0.9),
        y: y.clamp(0.2, 0.8),
        isCut: false,
        size: _difficulty == 'Hard' ? 20.0 : 25.0,
      ));
    }
  }

  void _startGame() {
    _initializeLeaves();

    setState(() {
      _isGameActive = true;
      _isGameOver = false;
      _isGameWon = false;
      _score = 0;
      _timeLeft = 60;
      _leavesCut = 0;
      _cutEffects.clear();
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
            if (_timeLeft == 0) {
              _endGame(false);
            }
          }
        });
      }
    });

    _animationController.repeat();
  }

  void _updateEffects() {
    if (!_isGameActive || _isPaused) return;

    setState(() {
      for (int i = _cutEffects.length - 1; i >= 0; i--) {
        _cutEffects[i].opacity -= 0.02;
        _cutEffects[i].scale += 0.02;
        if (_cutEffects[i].opacity <= 0) {
          _cutEffects.removeAt(i);
        }
      }
    });
  }

  void _onTapLeaf(Offset localPosition, Size screenSize) {
    if (!_isGameActive || _isPaused || _isGameOver) return;

    double tapX = localPosition.dx / screenSize.width;
    double tapY = localPosition.dy / screenSize.height;

    for (int i = 0; i < _leaves.length; i++) {
      Leaf leaf = _leaves[i];
      if (leaf.isCut) continue;

      double distance = sqrt(pow(tapX - leaf.x, 2) + pow(tapY - leaf.y, 2));
      double hitRadius = leaf.size / screenSize.width * 1.5;

      if (distance < hitRadius) {
        _cutLeaf(i, tapX, tapY);
        if (_hapticEnabled) {
          HapticFeedback.lightImpact();
        }
        break;
      }
    }
  }

  void _cutLeaf(int index, double x, double y) {
    setState(() {
      _leaves[index].isCut = true;
      _leavesCut++;
      _cutEffects.add(CutEffect(x: x, y: y, opacity: 1.0, scale: 0.5));

      if (_leavesCut == _totalLeaves) {
        _endGame(true);
      }
    });
  }

  Future<void> _endGame(bool won) async {
    _gameTimer?.cancel();
    _animationController.stop();

    int pointsEarned = won ? 10 : 0;

    if (won) {
      setState(() => _score = pointsEarned);
      if (_userId != null && mounted) {
        await _data.saveScoreToFirebase(
          _userId!,
          pointsEarned,
          _leavesCut,
          _totalLeaves,
          won,
          _difficulty,
          _timeLeft,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isGameActive = false;
        _isGameOver = true;
        _isGameWon = won;
      });
      _logic.showGameOverDialog(context, won, pointsEarned, _leavesCut, _totalLeaves, _timeLeft, _difficulty, _startGame);
    }
  }

  void _pauseGame() {
    setState(() => _isPaused = !_isPaused);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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
                            _logic.showExitDialog(context, () => _endGame(false));
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '✂️ CUTTING LEAVES ✂️',
                        style: TextStyle(color: Color(0xFFA5B68D), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      if (!_isGameActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(15)),
                          child: DropdownButton<String>(
                            value: _difficulty,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFA5B68D), size: 16),
                            items: ['Easy', 'Medium', 'Hard'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: _isGameActive ? null : (String? newValue) {
                              if (newValue != null) _setDifficulty(newValue);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (details) => _onTapLeaf(details.localPosition, screenSize),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: screenSize.width * 0.5 - 40,
                            top: screenSize.height * 0.4,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _logic.colorFlowerPink,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(color: _logic.colorFlowerPink.withOpacity(0.5), blurRadius: 15, spreadRadius: 5),
                                ],
                              ),
                              child: const Center(child: Text('🌸', style: TextStyle(fontSize: 40))),
                            ),
                          ),
                          Positioned(
                            left: screenSize.width * 0.5 - 10,
                            top: screenSize.height * 0.4 + 70,
                            child: Container(
                              width: 20,
                              height: 100,
                              decoration: BoxDecoration(
                                color: _logic.colorGreenDark.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          ..._leaves.where((leaf) => !leaf.isCut).map((leaf) {
                            return Positioned(
                              left: screenSize.width * leaf.x - leaf.size / 2,
                              top: screenSize.height * leaf.y - leaf.size / 2,
                              child: TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0.8, end: 1.2),
                                duration: Duration(milliseconds: 800 + (leaf.id * 100)),
                                builder: (context, double scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: leaf.size,
                                      height: leaf.size,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 8)],
                                      ),
                                      child: const Icon(Icons.eco, color: Colors.white, size: 15),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                          ..._cutEffects.map((effect) {
                            return Positioned(
                              left: screenSize.width * effect.x - 15,
                              top: screenSize.height * effect.y - 15,
                              child: Opacity(
                                opacity: effect.opacity,
                                child: Transform.scale(
                                  scale: effect.scale,
                                  child: const Text('✂️', style: TextStyle(fontSize: 30)),
                                ),
                              ),
                            );
                          }).toList(),
                          if (_isGameActive)
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Text('Progress: ', style: TextStyle(color: Color(0xFFA5B68D))),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: _leavesCut / _totalLeaves,
                                        backgroundColor: _logic.colorPinkish,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _leavesCut == _totalLeaves ? Colors.green : _logic.colorGreenDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$_leavesCut/$_totalLeaves',
                                      style: const TextStyle(color: Color(0xFFA5B68D), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_isGameActive && !_isGameOver)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: _logic.colorCream.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            children: [
                              const Text('✂️', style: TextStyle(fontSize: 80)),
                              const SizedBox(height: 20),
                              const Text(
                                'Cutting Leaves Game',
                                style: TextStyle(color: Color(0xFFA5B68D), fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tap on leaves to cut them!\nCut all leaves within 60 seconds to win 10 points',
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
        ],
      ),
      floatingActionButton: _isGameActive
          ? FloatingActionButton(
        onPressed: _pauseGame,
        backgroundColor: _logic.colorPinkish,
        child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: _logic.colorGreenDark),
      )
          : null,
    );
  }
}
