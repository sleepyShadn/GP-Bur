// ========== lib/data/cutting_leaves_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class CuttingLeavesData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid};
    }
    return null;
  }

  Future<void> saveScoreToFirebase(
      String userId,
      int pointsEarned,
      int rosesHarvested,
      int targetCount,
      bool won,
      int level,
      String objective,
      int timeLeft,
      ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final gameStatsRef = _firestore.collection('game_stats').doc(userId);

      if (pointsEarned > 0) {
        await userRef.update({'points': FieldValue.increment(pointsEarned)});
      }

      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        int currentHighest = gameStatsDoc.data()?['highestScore'] ?? 0;
        int newHighest = pointsEarned > currentHighest ? pointsEarned : currentHighest;

        await gameStatsRef.update({
          'totalRosesHarvested': FieldValue.increment(rosesHarvested),
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(won ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set({
          'uid': userId,
          'totalRosesHarvested': rosesHarvested,
          'totalGamesPlayed': 1,
          'totalWins': won ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Rose Harvest',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add({
        'uid': userId,
        'gameName': 'Rose Harvest',
        'score': pointsEarned,
        'rosesHarvested': rosesHarvested,
        'targetCount': targetCount,
        'won': won,
        'level': level,
        'objective': objective,
        'timeRemaining': timeLeft,
        'playedAt': FieldValue.serverTimestamp(),
      });

      if (pointsEarned > 0) {
        debugPrint('Score saved successfully: $pointsEarned points');
      }
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }
}

