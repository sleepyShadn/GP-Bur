// lib/screens/watering_flowers_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';

class WateringFlowersScreen extends StatefulWidget {
  const WateringFlowersScreen({super.key});

  @override
  State<WateringFlowersScreen> createState() => _WateringFlowersScreenState();
}

class _WateringFlowersScreenState extends State<WateringFlowersScreen> {
  // Colors matching the app theme
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xFFA5B68D);
  static const Color colorGreenLight = Color(0xFFC1CFA1);
  static const Color colorPlaceholder = Color(0xFF362427);
  static const Color colorFlowerPink = Color(0xFFF2A6A6);
  static const Color colorFlowerYellow = Color(0xFFFFD700);
  static const Color colorFlowerPurple = Color(0xFFDDA0DD);
  static const Color colorWaterBlue = Color(0xFF87CEEB);

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Game state
  int _score = 0;
  int _timeLeft = 60;
  int _flowersWatered = 0;
  int _totalFlowers = 9;
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _isPaused = false;

  // Flowers
  List<Flower> _flowers = [];
  final Random _random = Random();
  Timer? _gameTimer;

  // Animation for water effect
  int? _wateringFlowerId;
  Timer? _waterEffectTimer;

  // Difficulty
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
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
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

        List<Color> flowerColors = [colorFlowerPink, colorFlowerYellow, colorFlowerPurple];
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
            if (_timeLeft == 0) {
              _endGame(false);
            }
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
        if (mounted) {
          setState(() {
            _wateringFlowerId = null;
          });
        }
      });

      if (_flowersWatered == _totalFlowers) {
        _endGame(true);
      }
    });
  }

  Future<void> _endGame(bool won) async {
    _gameTimer?.cancel();
    _waterEffectTimer?.cancel();

    int pointsEarned = won ? 5 : 0;

    if (won) {
      setState(() {
        _score = pointsEarned;
      });

      if (_userId != null) {
        await _saveScoreToFirebase(pointsEarned);
      }
    }

    setState(() {
      _isGameActive = false;
      _isGameOver = true;
      _isGameWon = won;
    });

    if (mounted) {
      _showGameOverDialog(won, pointsEarned);
    }
  }

  Future<void> _saveScoreToFirebase(int pointsEarned) async {
    try {
      if (_userId == null) return;

      final userRef = _firestore.collection('users').doc(_userId);
      final gameStatsRef = _firestore.collection('game_stats').doc(_userId);

      await userRef.update({
        'points': FieldValue.increment(pointsEarned),
      });

      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        int currentHighest = (gameStatsDoc.data()?['highestScore'] as int?) ?? 0;
        int newHighest = pointsEarned > currentHighest ? pointsEarned : currentHighest;

        await gameStatsRef.update({
          'totalFlowersWatered': FieldValue.increment(_flowersWatered),
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(_isGameWon ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set({
          'uid': _userId,
          'totalFlowersWatered': _flowersWatered,
          'totalGamesPlayed': 1,
          'totalWins': _isGameWon ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Watering Flowers',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add({
        'uid': _userId,
        'gameName': 'Watering Flowers',
        'score': pointsEarned,
        'flowersWatered': _flowersWatered,
        'totalFlowers': _totalFlowers,
        'won': _isGameWon,
        'difficulty': _difficulty,
        'timeRemaining': _timeLeft,
        'playedAt': FieldValue.serverTimestamp(),
      });

      if (mounted && pointsEarned > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Earned $pointsEarned points!'),
            backgroundColor: colorGreenDark,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }

  void _showGameOverDialog(bool won, int pointsEarned) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          won ? '🎉 You Won! 🎉' : '😢 Game Over! 😢',
          style: TextStyle(
            color: won ? Colors.green : colorPlaceholder,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: won ? Colors.green.withOpacity(0.2) : colorPinkish,
                shape: BoxShape.circle,
              ),
              child: Icon(
                won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                color: won ? Colors.green : colorPlaceholder,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            if (won)
              Text(
                '+$pointsEarned Points!',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameStat('💧', '$_flowersWatered', 'Watered'),
                _buildGameStat('🌸', '${_totalFlowers - _flowersWatered}', 'Left'),
                _buildGameStat('⏱️', '${60 - _timeLeft}s', 'Time'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Difficulty: $_difficulty',
              style: TextStyle(
                color: colorGreenDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colorPinkish,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(color: colorGreenDark),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorGreenDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Play Again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
        Text(
          value,
          style: const TextStyle(
            color: colorGreenDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: colorPlaceholder,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _pauseGame() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorCream,
      body: Stack(
        children: [
          // Garden background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.lightBlue.shade50,
                  colorCream,
                ],
              ),
            ),
          ),

          // Background decorations
          Positioned(
            top: -50,
            left: -30,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: colorPinkish.withOpacity(0.4),
            ),
          ),
          Positioned(
            bottom: 150,
            right: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: colorGreenLight.withOpacity(0.3),
            ),
          ),

          // Main game area
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Content
                    Column(
                      children: [
                        // Top HUD Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Exit button
                              GestureDetector(
                                onTap: () {
                                  if (_isGameActive) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: colorCream,
                                        title: const Text(
                                          'Exit Game?',
                                          style: TextStyle(color: colorGreenDark),
                                        ),
                                        content: const Text(
                                          'Are you sure you want to exit? Your progress will be lost.',
                                          style: TextStyle(color: colorGreenDark),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(color: colorGreenDark),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _endGame(false);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: colorGreenDark,
                                            ),
                                            child: const Text(
                                              'Exit',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    Navigator.pop(context);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: colorPinkish,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.exit_to_app,
                                    color: colorGreenDark,
                                    size: 22,
                                  ),
                                ),
                              ),

                              // Timer and Score Row
                              Row(
                                children: [
                                  // Timer
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorPinkish,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.timer,
                                          color: colorGreenDark,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTime(_timeLeft),
                                          style: const TextStyle(
                                            color: colorGreenDark,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Score
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorPinkish,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: colorGreenDark,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$_score',
                                          style: const TextStyle(
                                            color: colorGreenDark,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Game title and difficulty
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '💧 WATERING FLOWERS',
                                style: TextStyle(
                                  color: colorGreenDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (!_isGameActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorPinkish,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _difficulty,
                                    underline: const SizedBox(),
                                    icon: const Icon(Icons.arrow_drop_down, color: colorGreenDark, size: 16),
                                    items: ['Easy', 'Medium', 'Hard'].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: const TextStyle(color: colorGreenDark, fontSize: 11),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _isGameActive ? null : (String? newValue) {
                                      if (newValue != null) {
                                        _setDifficulty(newValue);
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Game area with flowers
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            child: Stack(
                              children: [
                                // Flowers
                                ..._flowers.map((flower) {
                                  return Positioned(
                                    left: screenSize.width * flower.x - flower.size / 2,
                                    top: screenSize.height * flower.y - flower.size / 2,
                                    child: GestureDetector(
                                      onTap: () {
                                        if (_isGameActive && !_isPaused) {
                                          _waterFlower(flower.id);
                                        }
                                      },
                                      child: Stack(
                                        children: [
                                          // Flower
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            width: flower.size,
                                            height: flower.size,
                                            decoration: BoxDecoration(
                                              color: flower.isWatered
                                                  ? flower.color.withOpacity(0.8)
                                                  : flower.color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: flower.isWatered ? Colors.green : Colors.white,
                                                width: flower.isWatered ? 3 : 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: flower.isWatered
                                                      ? Colors.green.withOpacity(0.5)
                                                      : flower.color.withOpacity(0.4),
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

                                          // Water effect
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
                                                          color: colorWaterBlue.withOpacity(0.4),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),

                                          // Water drop
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
                                                      child: const Icon(
                                                        Icons.water_drop,
                                                        color: colorWaterBlue,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),

                                          // Check mark
                                          if (flower.isWatered)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 10,
                                                ),
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

                        // Progress indicator
                        if (_isGameActive && !_isPaused)
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorGreenDark),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progress',
                                      style: TextStyle(
                                        color: colorGreenDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '$_flowersWatered/$_totalFlowers',
                                      style: TextStyle(
                                        color: colorGreenDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: _flowersWatered / _totalFlowers,
                                  backgroundColor: colorPinkish,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(10),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _flowersWatered == _totalFlowers ? Colors.green : colorWaterBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Instruction
                        if (_isGameActive && !_isPaused)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colorGreenDark),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.water_drop, color: colorWaterBlue, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap flowers to water!',
                                      style: TextStyle(
                                        color: colorGreenDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Game not started overlay
                    if (!_isGameActive && !_isGameOver)
                      Container(
                        color: colorCream.withOpacity(0.95),
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colorGreenDark, width: 2),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '💧',
                                    style: TextStyle(fontSize: 60),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Watering Flowers',
                                    style: TextStyle(
                                      color: colorGreenDark,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorPinkish,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      children: [
                                        Text(
                                          'How to Play:',
                                          style: TextStyle(
                                            color: colorGreenDark,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          '• Tap on flowers to water them\n'
                                              '• Water all within 60 seconds\n'
                                              '• Win 5 points',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colorPlaceholder,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _startGame,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorGreenDark,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text(
                                      'START GAME',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Pause overlay
                    if (_isPaused && _isGameActive)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colorCream,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorGreenDark, width: 2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '⏸️',
                                  style: TextStyle(fontSize: 40),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Game Paused',
                                  style: TextStyle(
                                    color: colorGreenDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                ElevatedButton(
                                  onPressed: _pauseGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorGreenDark,
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                                  ),
                                  child: const Text(
                                    'Resume',
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isGameActive
          ? FloatingActionButton(
        mini: true,
        onPressed: _pauseGame,
        backgroundColor: colorPinkish,
        child: Icon(
          _isPaused ? Icons.play_arrow : Icons.pause,
          color: colorGreenDark,
          size: 20,
        ),
      )
          : null,
    );
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// Flower model
class Flower {
  final int id;
  double x;
  double y;
  bool isWatered;
  Color color;
  double size;

  Flower({
    required this.id,
    required this.x,
    required this.y,
    required this.isWatered,
    required this.color,
    required this.size,
  });
}