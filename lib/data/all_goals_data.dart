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

  Stream<QuerySnapshot<Map<String, dynamic>>> getAnalysesStream(
    String userId,
  ) {
    if (userId.isEmpty) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('analyses')
        .orderBy('timestamp', descending: true)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (DocumentSnapshot<Map<String, dynamic>> snap, _) =>
              snap.data() ?? <String, dynamic>{},
          toFirestore: (Map<String, dynamic> data, _) => data,
        )
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

        final bool isGoalCompleted = data['isGoalCompleted'] ?? false;
        if (isGoalCompleted) {
          return false;
        }

        if (activityIndex < activities.length) {
          final DateTime now = DateTime.now();
          final String todayKey = '${now.year}-${now.month}-${now.day}';
          final Map<String, dynamic> target =
              Map<String, dynamic>.from(activities[activityIndex] as Map);
          final int points = (target['points'] as num?)?.toInt() ?? 5;

          target['completed'] = newValue;
          target['lastCompletedDate'] =
              newValue ? Timestamp.fromDate(now) : null;

          final Map<String, dynamic> history = Map<String, dynamic>.from(
            target['dailyHistory'] as Map? ?? <String, dynamic>{},
          );
          history[todayKey] = newValue;
          target['dailyHistory'] = history;
          activities[activityIndex] = target;

          final DocumentReference userRef =
              _firestore.collection('users').doc(userId);
          await userRef
              .collection('analyses')
              .doc(analysisId)
              .update(<String, dynamic>{'activities': activities});

          if (newValue) {
            await userRef.update(<String, dynamic>{
              'points': FieldValue.increment(points),
            });
          } else {
            final DocumentSnapshot userDoc = await userRef.get();
            final int currentPoints =
                ((userDoc.data() as Map<String, dynamic>?)?['points'] as num?)
                        ?.toInt() ??
                    0;
            final int updatedPoints =
                (currentPoints - points).clamp(0, 1 << 31);
            await userRef.update(<String, dynamic>{'points': updatedPoints});
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