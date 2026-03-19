


// ========== lib/data/watering_flowers_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class WateringFlowersData {
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
      int flowersWatered,
      int totalFlowers,
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
        int currentHighest = (gameStatsDoc.data()?['highestScore'] as int?) ?? 0;
        int newHighest = pointsEarned > currentHighest ? pointsEarned : currentHighest;

        await gameStatsRef.update({
          'totalFlowersWatered': FieldValue.increment(flowersWatered),
          'totalGamesPlayed': FieldValue.increment(1),
          'totalWins': FieldValue.increment(won ? 1 : 0),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set({
          'uid': userId,
          'totalFlowersWatered': flowersWatered,
          'totalGamesPlayed': 1,
          'totalWins': won ? 1 : 0,
          'highestScore': pointsEarned,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Watering Flowers',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add({
        'uid': userId,
        'gameName': 'Watering Flowers',
        'score': pointsEarned,
        'flowersWatered': flowersWatered,
        'totalFlowers': totalFlowers,
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

