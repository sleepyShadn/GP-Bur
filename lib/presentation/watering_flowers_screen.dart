// ========== lib/presentation/watering_flowers_screen.dart ==========
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import '../../domain/watering_flowers_logic.dart';
import '../../data/watering_flowers_data.dart';

class WateringFlowersScreen extends StatefulWidget {
  const WateringFlowersScreen({super.key});

  @override
  State<WateringFlowersScreen> createState() => _WateringFlowersScreenState();
}

class _WateringFlowersScreenState extends State<WateringFlowersScreen> {
  final WateringFlowersLogic _logic = WateringFlowersLogic();
  final WateringFlowersData _data = WateringFlowersData();

  int _score = 0;
  int _timeLeft = 60;
  int _flowersWatered = 0;
  int _totalFlowers = 9;
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _isPaused = false;

  List<Flower> _flowers = [];
  final Random _random = Random();
  Timer? _gameTimer;

  int? _wateringFlowerId;
  Timer? _waterEffectTimer;

  String _difficulty = 'Medium';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _waterEffectTimer?.cancel();
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
          _totalFlowers = 6;
          break;
        case 'Medium':
          _totalFlowers = 9;
          break;
        case 'Hard':
          _totalFlowers = 12;
          break;
      }
    });
  }

  void _initializeFlowers() {
    _flowers.clear();
    int columns = _difficulty == 'Hard' ? 4 : 3;
    int rows = (_totalFlowers / columns).ceil();
    double startX = 0.15;
    double startY = 0.25;
    double spacingX = 0.23;
    double spacingY = 0.2;
    int flowerIndex = 0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        if (flowerIndex >= _totalFlowers) break;
        double x = startX + (col * spacingX);
        double y = startY + (row * spacingY);
        List<Color> flowerColors = [_logic.colorFlowerPink, _logic.colorFlowerYellow, _logic.colorFlowerPurple];
        Color flowerColor = flowerColors[_random.nextInt(flowerColors.length)];

        _flowers.add(Flower(
          id: flowerIndex,
          x: x,
          y: y,
          isWatered: false,
          color: flowerColor,
          size: 45.0,
        ));
        flowerIndex++;
      }
    }
  }

  void _startGame() {
    _initializeFlowers();
    setState(() {
      _isGameActive = true;
      _isGameOver = false;
      _isGameWon = false;
      _score = 0;
      _timeLeft = 60;
      _flowersWatered = 0;
      _wateringFlowerId = null;
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
            if (_timeLeft == 0) _endGame(false);
          }
        });
      }
    });
  }

  void _waterFlower(int index) {
    if (!_isGameActive || _isPaused || _flowers[index].isWatered) return;

    setState(() {
      _flowers[index].isWatered = true;
      _flowersWatered++;
      _wateringFlowerId = _flowers[index].id;
      HapticFeedback.lightImpact();

      _waterEffectTimer?.cancel();
      _waterEffectTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _wateringFlowerId = null);
      });

      if (_flowersWatered == _totalFlowers) _endGame(true);
    });
  }

  Future<void> _endGame(bool won) async {
    _gameTimer?.cancel();
    _waterEffectTimer?.cancel();

    int pointsEarned = won ? 5 : 0;

    if (won) {
      setState(() => _score = pointsEarned);
      if (_userId != null && mounted) {
        await _data.saveScoreToFirebase(
          _userId!,
          pointsEarned,
          _flowersWatered,
          _totalFlowers,
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
      _logic.showGameOverDialog(context, won, pointsEarned, _flowersWatered, _totalFlowers, _timeLeft, _difficulty, _startGame);
    }
  }

  void _pauseGame() => setState(() => _isPaused = !_isPaused);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _logic.colorCream,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.lightBlue.shade50, _logic.colorCream],
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -30,
            child: CircleAvatar(radius: 80, backgroundColor: _logic.colorPinkish.withOpacity(0.4)),
          ),
          Positioned(
            bottom: 150,
            right: -40,
            child: CircleAvatar(radius: 100, backgroundColor: _logic.colorGreenLight.withOpacity(0.3)),
          ),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.exit_to_app, color: Color(0xFFA5B68D), size: 22),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.timer, color: Color(0xFFA5B68D), size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        _logic.formatTime(_timeLeft),
                                        style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Color(0xFFA5B68D), size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_score',
                                        style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '💧 WATERING FLOWERS',
                              style: TextStyle(color: Color(0xFFA5B68D), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            if (!_isGameActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(12)),
                                child: DropdownButton<String>(
                                  value: _difficulty,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFA5B68D), size: 16),
                                  items: ['Easy', 'Medium', 'Hard'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value, style: const TextStyle(color: Color(0xFFA5B68D), fontSize: 11)),
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
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          child: Stack(
                            children: [
                              ..._flowers.map((flower) {
                                return Positioned(
                                  left: screenSize.width * flower.x - flower.size / 2,
                                  top: screenSize.height * flower.y - flower.size / 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_isGameActive && !_isPaused) _waterFlower(flower.id);
                                    },
                                    child: Stack(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: flower.size,
                                          height: flower.size,
                                          decoration: BoxDecoration(
                                            color: flower.isWatered ? flower.color.withOpacity(0.8) : flower.color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: flower.isWatered ? Colors.green : Colors.white,
                                              width: flower.isWatered ? 3 : 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: flower.isWatered ? Colors.green.withOpacity(0.5) : flower.color.withOpacity(0.4),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              flower.isWatered ? '✅' : '🌸',
                                              style: TextStyle(fontSize: flower.size * 0.4),
                                            ),
                                          ),
                                        ),
                                        if (_wateringFlowerId == flower.id)
                                          Positioned.fill(
                                            child: TweenAnimationBuilder(
                                              tween: Tween<double>(begin: 1.0, end: 2.5),
                                              duration: const Duration(milliseconds: 300),
                                              builder: (context, double scale, child) {
                                                return Opacity(
                                                  opacity: (2.5 - scale) / 1.5,
                                                  child: Transform.scale(
                                                    scale: scale,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: _logic.colorWaterBlue.withOpacity(0.4),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        if (_wateringFlowerId == flower.id)
                                          Positioned(
                                            top: -5,
                                            left: flower.size / 2 - 8,
                                            child: TweenAnimationBuilder(
                                              tween: Tween<double>(begin: 0, end: 1),
                                              duration: const Duration(milliseconds: 300),
                                              builder: (context, double value, child) {
                                                return Opacity(
                                                  opacity: 1 - value,
                                                  child: Transform.translate(
                                                    offset: Offset(0, -15 * value),
                                                    child: const Icon(Icons.water_drop, color: Color(0xFF87CEEB), size: 20),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        if (flower.isWatered)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                              child: const Icon(Icons.check, color: Colors.white, size: 10),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      if (_isGameActive && !_isPaused)
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _logic.colorGreenDark),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Progress', style: TextStyle(color: _logic.colorGreenDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('$_flowersWatered/$_totalFlowers', style: TextStyle(color: _logic.colorGreenDark, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: _flowersWatered / _totalFlowers,
                                backgroundColor: _logic.colorPinkish,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(10),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _flowersWatered == _totalFlowers ? Colors.green : _logic.colorWaterBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isGameActive && !_isPaused)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _logic.colorGreenDark),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.water_drop, color: _logic.colorWaterBlue, size: 16),
                                  const SizedBox(width: 4),
                                  Text('Tap flowers to water!', style: TextStyle(color: _logic.colorGreenDark, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (!_isGameActive && !_isGameOver)
                    Container(
                      color: _logic.colorCream.withOpacity(0.95),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _logic.colorGreenDark, width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('💧', style: TextStyle(fontSize: 60)),
                                const SizedBox(height: 10),
                                const Text('Watering Flowers', style: TextStyle(color: Color(0xFFA5B68D), fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: _logic.colorPinkish, borderRadius: BorderRadius.circular(12)),
                                  child: const Column(
                                    children: [
                                      Text('How to Play:', style: TextStyle(color: Color(0xFFA5B68D), fontSize: 14, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 6),
                                      Text(
                                        '• Tap on flowers to water them\n• Water all within 60 seconds\n• Win 5 points',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF362427), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _logic.colorGreenDark,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  ),
                                  child: const Text('START GAME', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_isPaused && _isGameActive)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _logic.colorCream,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _logic.colorGreenDark, width: 2),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⏸️', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 10),
                              const Text('Game Paused', style: TextStyle(color: Color(0xFFA5B68D), fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 15),
                              ElevatedButton(
                                onPressed: _pauseGame,
                                style: ElevatedButton.styleFrom(backgroundColor: _logic.colorGreenDark, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
                                child: const Text('Resume', style: TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
      floatingActionButton: _isGameActive
          ? FloatingActionButton(
        mini: true,
        onPressed: _pauseGame,
        backgroundColor: _logic.colorPinkish,
        child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: _logic.colorGreenDark, size: 20),
      )
          : null,
    );
  }
}
