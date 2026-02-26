// lib/screens/apple_picking_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

class ApplePickingScreen extends StatefulWidget {
  const ApplePickingScreen({super.key});

  @override
  State<ApplePickingScreen> createState() => _ApplePickingScreenState();
}

class _ApplePickingScreenState extends State<ApplePickingScreen>
    with SingleTickerProviderStateMixin {
  // Colors matching the app theme
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xFFA5B68D);
  static const Color colorGreenLight = Color(0xFFC1CFA1);
  static const Color colorPlaceholder = Color(0xFF362427);

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Game state
  int _score = 0;
  int _timeLeft = 60; // 60 seconds game
  int _missedApples = 0;
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isPaused = false;

  // Bucket position
  double _bucketPosition = 0.5; // 0 to 1 (percentage of screen width)
  final double _bucketWidth = 0.2; // 20% of screen width
  final double _bucketHeight = 60.0;

  // Apples
  List<Apple> _apples = [];
  final int _maxApples = 5;
  final Random _random = Random();
  Timer? _gameTimer;
  Timer? _appleSpawnTimer;
  late AnimationController _animationController;

  // Difficulty settings
  double _baseSpeed = 2.0;
  double _currentSpeed = 2.0;

  // Floating score animations
  List<FloatingScore> _floatingScores = [];

  // User ID
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
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
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
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

    // Start countdown timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;

            // Increase difficulty over time
            if (_timeLeft < 40) _currentSpeed = _baseSpeed * 1.3;
            if (_timeLeft < 20) _currentSpeed = _baseSpeed * 1.6;
          } else {
            _endGame();
          }
        });
      }
    });

    // Start apple spawner
    _appleSpawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isPaused && _isGameActive && mounted && _apples.length < _maxApples) {
        _spawnApple();
      }
    });

    // Start animation loop
    _animationController.repeat();
  }

  void _spawnApple() {
    setState(() {
      _apples.add(Apple(
        x: _random.nextDouble(), // 0 to 1 (percentage)
        y: 0.1, // Start near top (10% down)
        speed: _currentSpeed,
      ));
    });
  }

  void _updateGame() {
    if (!_isGameActive || _isPaused || _isGameOver) return;

    setState(() {
      // Update apple positions
      for (int i = _apples.length - 1; i >= 0; i--) {
        Apple apple = _apples[i];

        // Move apple down
        apple.y += apple.speed / 1000; // Normalized speed

        // Check collision with bucket
        if (_checkCollision(apple)) {
          // Apple caught
          _apples.removeAt(i);
          _score += 2;

          // Add floating score animation
          _floatingScores.add(FloatingScore(
            value: 2,
            x: _bucketPosition,
            y: 0.8, // Near bottom
            opacity: 1.0,
          ));
        }
        // Check if apple hit ground (y > 0.95)
        else if (apple.y > 0.95) {
          _apples.removeAt(i);
          _missedApples++;
        }
      }

      // Update floating scores
      for (int i = _floatingScores.length - 1; i >= 0; i--) {
        _floatingScores[i].y -= 0.01;
        _floatingScores[i].opacity -= 0.02;
        if (_floatingScores[i].opacity <= 0) {
          _floatingScores.removeAt(i);
        }
      }
    });
  }

  bool _checkCollision(Apple apple) {
    // Simple rectangle collision detection
    double bucketLeft = _bucketPosition - _bucketWidth / 2;
    double bucketRight = _bucketPosition + _bucketWidth / 2;
    double bucketTop = 0.8; // 80% down the screen
    double bucketBottom = 0.9; // 90% down the screen

    return (apple.x >= bucketLeft &&
        apple.x <= bucketRight &&
        apple.y >= bucketTop &&
        apple.y <= bucketBottom);
  }

  Future<void> _endGame() async {
    _gameTimer?.cancel();
    _appleSpawnTimer?.cancel();
    _animationController.stop();

    // Save score to Firebase
    if (_userId != null && _score > 0) {
      await _saveScoreToFirebase();
    }

    setState(() {
      _isGameActive = false;
      _isGameOver = true;
    });

    // Show game over dialog
    if (mounted) {
      _showGameOverDialog();
    }
  }

  // CORRECTED VERSION - No FieldValue.max() used
  Future<void> _saveScoreToFirebase() async {
    try {
      if (_userId == null) return;

      final userRef = _firestore.collection('users').doc(_userId);
      final gameStatsRef = _firestore.collection('game_stats').doc(_userId);

      // Update user's points (increment by current game score)
      await userRef.update({
        'points': FieldValue.increment(_score),
      });

      // Check if game stats document exists
      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        // Get current highest score
        int currentHighest = gameStatsDoc.data()?['highestScore'] ?? 0;
        int newHighest = _score > currentHighest ? _score : currentHighest;

        // Update existing stats
        await gameStatsRef.update({
          'totalApplesPicked': FieldValue.increment(_score ~/ 2), // Each apple is 2 points
          'totalGamesPlayed': FieldValue.increment(1),
          'highestScore': newHighest, // Manually set the highest score
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new stats document
        await gameStatsRef.set({
          'uid': _userId,
          'totalApplesPicked': _score ~/ 2,
          'totalGamesPlayed': 1,
          'highestScore': _score,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Apple Picking',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Also save to a game history collection
      await _firestore.collection('game_history').add({
        'uid': _userId,
        'gameName': 'Apple Picking',
        'score': _score,
        'applesPicked': _score ~/ 2,
        'missedApples': _missedApples,
        'timeRemaining': _timeLeft,
        'playedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Earned $_score points!'),
            backgroundColor: colorGreenDark,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Game Over!',
          style: TextStyle(
            color: colorGreenDark,
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
                color: colorPinkish,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_score',
                style: const TextStyle(
                  color: colorGreenDark,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Points',
              style: TextStyle(
                color: colorPlaceholder,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGameStat('🍎', '${_score ~/ 2}', 'Apples'),
                _buildGameStat('❌', '$_missedApples', 'Missed'),
                _buildGameStat('⏱️', '${60 - _timeLeft}s', 'Played'),
              ],
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
                    Navigator.pop(context); // Go back to previous screen
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
    return Scaffold(
      backgroundColor: colorCream,
      body: Stack(
        children: [
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
            child: Column(
              children: [
                // Top HUD Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                                      _endGame();
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorPinkish,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.exit_to_app,
                            color: colorGreenDark,
                            size: 24,
                          ),
                        ),
                      ),

                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorPinkish,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer,
                              color: colorGreenDark,
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatTime(_timeLeft),
                              style: const TextStyle(
                                color: colorGreenDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorPinkish,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: colorGreenDark,
                              size: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                color: colorGreenDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Game title
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    '🍎 APPLE PICKING 🍎',
                    style: TextStyle(
                      color: colorGreenDark,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                // Game area
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_isGameActive && !_isPaused) {
                        setState(() {
                          // Convert drag delta to relative position
                          double delta = details.delta.dx / MediaQuery.of(context).size.width;
                          _bucketPosition = (_bucketPosition + delta).clamp(0.1, 0.9);
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        // Tree background
                        Center(
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colorGreenLight.withOpacity(0.3),
                                  colorCream,
                                ],
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Tree trunk
                                Positioned(
                                  bottom: 0,
                                  left: MediaQuery.of(context).size.width * 0.45,
                                  child: Container(
                                    width: 50,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: colorPlaceholder.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                // Tree top
                                Positioned(
                                  top: 50,
                                  left: MediaQuery.of(context).size.width * 0.3,
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: colorGreenDark.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Apples
                        ..._apples.map((apple) => Positioned(
                          left: MediaQuery.of(context).size.width * apple.x - 15,
                          top: MediaQuery.of(context).size.height * apple.y * 0.7,
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, double scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: const Text(
                                  '🍎',
                                  style: TextStyle(fontSize: 30),
                                ),
                              );
                            },
                          ),
                        )).toList(),

                        // Floating score animations
                        ..._floatingScores.map((score) => Positioned(
                          left: MediaQuery.of(context).size.width * score.x - 15,
                          top: MediaQuery.of(context).size.height * score.y,
                          child: Opacity(
                            opacity: score.opacity,
                            child: const Text(
                              '+2',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )).toList(),

                        // Bucket
                        Positioned(
                          bottom: 50,
                          left: MediaQuery.of(context).size.width * (_bucketPosition - _bucketWidth / 2),
                          child: Container(
                            width: MediaQuery.of(context).size.width * _bucketWidth,
                            height: _bucketHeight,
                            decoration: BoxDecoration(
                              color: colorPlaceholder,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width * _bucketWidth - 10,
                                height: _bucketHeight - 10,
                                decoration: BoxDecoration(
                                  color: colorGreenDark,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.shopping_basket,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Game not started overlay
                        if (!_isGameActive && !_isGameOver)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: colorCream.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        '🍎',
                                        style: TextStyle(fontSize: 80),
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Apple Picking Game',
                                        style: TextStyle(
                                          color: colorGreenDark,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Catch falling apples to earn points!\nEach apple = 2 points',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colorPlaceholder,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      ElevatedButton(
                                        onPressed: _startGame,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorGreenDark,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 40,
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: const Text(
                                          'START GAME',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Pause overlay
                        if (_isPaused && _isGameActive)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: colorCream.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '⏸️',
                                    style: TextStyle(fontSize: 50),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Game Paused',
                                    style: TextStyle(
                                      color: colorGreenDark,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _pauseGame,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorGreenDark,
                                    ),
                                    child: const Text(
                                      'Resume',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Bottom controls
                if (_isGameActive)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pause button
                        GestureDetector(
                          onTap: _pauseGame,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorPinkish,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPaused ? Icons.play_arrow : Icons.pause,
                              color: colorGreenDark,
                              size: 30,
                            ),
                          ),
                        ),
                        // Stats
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: colorPinkish,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '🍎 ',
                                style: TextStyle(fontSize: 16),
                              ),
                              Text(
                                '${_apples.length}',
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// Apple model
class Apple {
  double x;
  double y;
  double speed;

  Apple({
    required this.x,
    required this.y,
    required this.speed,
  });
}

// Floating score animation
class FloatingScore {
  int value;
  double x;
  double y;
  double opacity;

  FloatingScore({
    required this.value,
    required this.x,
    required this.y,
    required this.opacity,
  });
}