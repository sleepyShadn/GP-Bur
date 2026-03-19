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
      int leavesCut,
      int totalLeaves,
      bool won,
      String difficulty,
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
          'totalLeavesCut': FieldValue.increment(leavesCut),
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(won ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set({
          'uid': userId,
          'totalLeavesCut': leavesCut,
          'totalGamesPlayed': 1,
          'totalWins': won ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Cutting Leaves',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add({
        'uid': userId,
        'gameName': 'Cutting Leaves',
        'score': pointsEarned,
        'leavesCut': leavesCut,
        'totalLeaves': totalLeaves,
        'won': won,
        'difficulty': difficulty,
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

