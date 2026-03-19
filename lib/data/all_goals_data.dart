// ========== lib/data/all_goals_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AllGoalsData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid, 'email': user.email};
    }
    return null;
  }

  Stream<QuerySnapshot> getAnalysesStream(String userId) {
    if (userId.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('analyses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<bool> toggleActivity(String userId, String analysisId, int activityIndex, bool newValue) async {
    try {
      DocumentSnapshot analysisDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('analyses')
          .doc(analysisId)
          .get();

      if (analysisDoc.exists) {
        var data = analysisDoc.data() as Map<String, dynamic>;
        List<dynamic> activities = List.from(data['activities'] ?? []);

        Timestamp? expiryTimestamp = data['goalExpiryDate'];
        bool isGoalCompleted = data['isGoalCompleted'] ?? false;

        if (expiryTimestamp != null) {
          DateTime expiryDate = expiryTimestamp.toDate();
          if (DateTime.now().isAfter(expiryDate) || isGoalCompleted) {
            return false;
          }
        }

        if (activityIndex < activities.length) {
          DateTime now = DateTime.now();
          String todayKey = '${now.year}-${now.month}-${now.day}';

          activities[activityIndex]['completed'] = newValue;
          activities[activityIndex]['lastCompletedDate'] = Timestamp.fromDate(now);

          if (activities[activityIndex]['dailyHistory'] == null) {
            activities[activityIndex]['dailyHistory'] = {};
          }
          activities[activityIndex]['dailyHistory'][todayKey] = newValue;

          await _firestore
              .collection('users')
              .doc(userId)
              .collection('analyses')
              .doc(analysisId)
              .update({'activities': activities});

          if (newValue) {
            int points = activities[activityIndex]['points'] ?? 5;
            await _firestore.collection('users').doc(userId).update({
              'points': FieldValue.increment(points),
            });
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error updating activity: $e');
      return false;
    }
  }
}