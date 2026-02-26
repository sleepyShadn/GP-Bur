// lib/screens/cutting_leaves_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

class CuttingLeavesScreen extends StatefulWidget {
  const CuttingLeavesScreen({super.key});

  @override
  State<CuttingLeavesScreen> createState() => _CuttingLeavesScreenState();
}

class _CuttingLeavesScreenState extends State<CuttingLeavesScreen>
    with SingleTickerProviderStateMixin {
  // Colors matching the app theme
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xFFA5B68D);
  static const Color colorGreenLight = Color(0xFFC1CFA1);
  static const Color colorPlaceholder = Color(0xFF362427);
  static const Color colorFlowerPink = Color(0xFFF2A6A6);

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Game state
  int _score = 0;
  int _timeLeft = 60; // 60 seconds game
  int _leavesCut = 0;
  int _totalLeaves = 12; // Default number of leaves
  bool _isGameActive = false;
  bool _isGameOver = false;
  bool _isGameWon = false;
  bool _isPaused = false;

  // Leaves
  List<Leaf> _leaves = [];
  final Random _random = Random();
  Timer? _gameTimer;
  late AnimationController _animationController;

  // Cutting animations
  List<CutEffect> _cutEffects = [];

  // Haptic feedback (optional)
  bool _hapticEnabled = true;

  // User ID
  String? _userId;

  // Difficulty level
  String _difficulty = 'Medium'; // Easy, Medium, Hard

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..addListener(_updateEffects);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
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

    // Calculate positions around the flower
    double centerX = 0.5; // Center of screen (50%)
    double centerY = 0.5; // Center of screen (50%)

    for (int i = 0; i < _totalLeaves; i++) {
      // Position leaves in a circular pattern around the flower
      double angle = (2 * pi * i) / _totalLeaves;

      // Different radius for different difficulties
      double radius = 0.15; // 15% of screen
      if (_difficulty == 'Easy') radius = 0.2;
      if (_difficulty == 'Hard') radius = 0.12;

      double x = centerX + radius * cos(angle);
      double y = centerY + radius * sin(angle);

      // Add some randomness to make it look natural
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

    // Start countdown timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;

            // Check if time ran out
            if (_timeLeft == 0) {
              _endGame(false); // Lose
            }
          }
        });
      }
    });

    // Start animation loop
    _animationController.repeat();
  }

  void _updateEffects() {
    if (!_isGameActive || _isPaused) return;

    setState(() {
      // Update cut effects (fade out)
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

    // Calculate tap position as percentage
    double tapX = localPosition.dx / screenSize.width;
    double tapY = localPosition.dy / screenSize.height;

    // Check if tap hits any leaf
    for (int i = 0; i < _leaves.length; i++) {
      Leaf leaf = _leaves[i];
      if (leaf.isCut) continue;

      // Calculate distance from tap to leaf
      double distance = sqrt(pow(tapX - leaf.x, 2) + pow(tapY - leaf.y, 2));

      // Leaf hit radius (normalized)
      double hitRadius = leaf.size / screenSize.width * 1.5;

      if (distance < hitRadius) {
        _cutLeaf(i, tapX, tapY);

        // Haptic feedback
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

      // Add cut effect
      _cutEffects.add(CutEffect(
        x: x,
        y: y,
        opacity: 1.0,
        scale: 0.5,
      ));

      // Check win condition
      if (_leavesCut == _totalLeaves) {
        _endGame(true); // Win
      }
    });
  }

  Future<void> _endGame(bool won) async {
    _gameTimer?.cancel();
    _animationController.stop();

    int pointsEarned = won ? 10 : 0;

    if (won) {
      setState(() {
        _score = pointsEarned;
      });

      // Save score to Firebase if user is logged in
      if (_userId != null) {
        await _saveScoreToFirebase(pointsEarned);
      }
    }

    setState(() {
      _isGameActive = false;
      _isGameOver = true;
      _isGameWon = won;
    });

    // Show game over dialog
    if (mounted) {
      _showGameOverDialog(won, pointsEarned);
    }
  }

  Future<void> _saveScoreToFirebase(int pointsEarned) async {
    try {
      if (_userId == null) return;

      final userRef = _firestore.collection('users').doc(_userId);
      final gameStatsRef = _firestore.collection('game_stats').doc(_userId);

      // Update user's points (increment by points earned)
      await userRef.update({
        'points': FieldValue.increment(pointsEarned),
      });

      // Check if game stats document exists
      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        // Get current highest score
        int currentHighest = gameStatsDoc.data()?['highestScore'] ?? 0;
        int newHighest = pointsEarned > currentHighest ? pointsEarned : currentHighest;

        // Update existing stats
        await gameStatsRef.update({
          'totalLeavesCut': FieldValue.increment(_leavesCut),
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(_isGameWon ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new stats document
        await gameStatsRef.set({
          'uid': _userId,
          'totalLeavesCut': _leavesCut,
          'totalGamesPlayed': 1,
          'totalWins': _isGameWon ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Cutting Leaves',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Save to game history
      await _firestore.collection('game_history').add({
        'uid': _userId,
        'gameName': 'Cutting Leaves',
        'score': pointsEarned,
        'leavesCut': _leavesCut,
        'totalLeaves': _totalLeaves,
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
                _buildGameStat('✂️', '$_leavesCut', 'Cut'),
                _buildGameStat('🍃', '${_totalLeaves - _leavesCut}', 'Left'),
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
    final screenSize = MediaQuery.of(context).size;

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

                // Game title and difficulty selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '✂️ CUTTING LEAVES ✂️',
                        style: TextStyle(
                          color: colorGreenDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (!_isGameActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorPinkish,
                            borderRadius: BorderRadius.circular(15),
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
                                  style: const TextStyle(color: colorGreenDark, fontSize: 12),
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

                const SizedBox(height: 10),

                // Game area with flower and leaves
                Expanded(
                  child: GestureDetector(
                    onTapDown: (details) {
                      _onTapLeaf(details.localPosition, screenSize);
                    },
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
                          // Flower center
                          Positioned(
                            left: screenSize.width * 0.5 - 40,
                            top: screenSize.height * 0.4,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorFlowerPink,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorFlowerPink.withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '🌸',
                                  style: TextStyle(fontSize: 40),
                                ),
                              ),
                            ),
                          ),

                          // Flower stem
                          Positioned(
                            left: screenSize.width * 0.5 - 10,
                            top: screenSize.height * 0.4 + 70,
                            child: Container(
                              width: 20,
                              height: 100,
                              decoration: BoxDecoration(
                                color: colorGreenDark.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          // Leaves
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withOpacity(0.5),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.eco,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),

                          // Cut effects (scissors animation)
                          ..._cutEffects.map((effect) {
                            return Positioned(
                              left: screenSize.width * effect.x - 15,
                              top: screenSize.height * effect.y - 15,
                              child: Opacity(
                                opacity: effect.opacity,
                                child: Transform.scale(
                                  scale: effect.scale,
                                  child: const Text(
                                    '✂️',
                                    style: TextStyle(fontSize: 30),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

                          // Progress indicator
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
                                    const Text(
                                      'Progress: ',
                                      style: TextStyle(color: colorGreenDark),
                                    ),
                                    Expanded(
                                      child: LinearProgressIndicator(
                                        value: _leavesCut / _totalLeaves,
                                        backgroundColor: colorPinkish,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _leavesCut == _totalLeaves ? Colors.green : colorGreenDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$_leavesCut/$_totalLeaves',
                                      style: const TextStyle(
                                        color: colorGreenDark,
                                        fontWeight: FontWeight.bold,
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
                ),

                // Game not started overlay
                if (!_isGameActive && !_isGameOver)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
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
                                '✂️',
                                style: TextStyle(fontSize: 80),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Cutting Leaves Game',
                                style: TextStyle(
                                  color: colorGreenDark,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tap on leaves to cut them!\nCut all leaves within 60 seconds to win 10 points',
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
        ],
      ),
      floatingActionButton: _isGameActive
          ? FloatingActionButton(
        onPressed: _pauseGame,
        backgroundColor: colorPinkish,
        child: Icon(
          _isPaused ? Icons.play_arrow : Icons.pause,
          color: colorGreenDark,
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

// Leaf model
class Leaf {
  final int id;
  double x;
  double y;
  bool isCut;
  double size;

  Leaf({
    required this.id,
    required this.x,
    required this.y,
    required this.isCut,
    required this.size,
  });
}

// Cut effect animation
class CutEffect {
  double x;
  double y;
  double opacity;
  double scale;

  CutEffect({
    required this.x,
    required this.y,
    required this.opacity,
    required this.scale,
  });
}