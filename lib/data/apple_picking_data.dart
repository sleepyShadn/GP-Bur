// ========== lib/data/apple_picking_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class ApplePickingData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid, 'email': user.email};
    }
    return null;
  }

  Future<void> saveScoreToFirebase(
    String userId,
    int score,
    int caughtApples,
    int missedApples,
    int timeLeft,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final gameStatsRef = _firestore.collection('game_stats').doc(userId);

      await userRef.update({'points': FieldValue.increment(score)});

      final gameStatsDoc = await gameStatsRef.get();

      if (gameStatsDoc.exists) {
        int currentHighest = gameStatsDoc.data()?['highestScore'] ?? 0;
        int newHighest = score > currentHighest ? score : currentHighest;

        await gameStatsRef.update({
          'totalApplesPicked': FieldValue.increment(caughtApples),
          'totalGamesPlayed': FieldValue.increment(1),
          'highestScore': newHighest,
          'lastPlayed': FieldValue.serverTimestamp(),
        });
      } else {
        await gameStatsRef.set({
          'uid': userId,
          'totalApplesPicked': caughtApples,
          'totalGamesPlayed': 1,
          'highestScore': score,
          'lastPlayed': FieldValue.serverTimestamp(),
          'gameName': 'Apple Picking',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _firestore.collection('game_history').add({
        'uid': userId,
        'gameName': 'Apple Picking',
        'score': score,
        'applesPicked': caughtApples,
        'missedApples': missedApples,
        'timeRemaining': timeLeft,
        'playedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving score: $e');
    }
  }
}