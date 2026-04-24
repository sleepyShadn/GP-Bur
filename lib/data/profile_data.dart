// ========== lib/data/profile_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> loadUserData() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      String uid = currentUser.uid;
      String userEmail = currentUser.email ?? "";
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      Timestamp? createdAt = userData['createdAt'] as Timestamp?;
      DateTime birthDate = DateTime.now();
      if (userData['dateOfBirth'] != null) {
        try {
          String dateStr = userData['dateOfBirth'].toString();
          List<String> parts = dateStr.split('/');
          if (parts.length == 3) {
            int day = int.parse(parts[0]);
            int month = int.parse(parts[1]);
            int year = int.parse(parts[2]);
            birthDate = DateTime(year, month, day);
          } else {
            birthDate = DateTime.parse(dateStr);
          }
        } catch (e) {
          birthDate = DateTime.now();
        }
      }
      double weight = (userData['weight'] is int) ? (userData['weight'] as int).toDouble() : (userData['weight'] ?? 0.0).toDouble();
      double height = (userData['height'] is int) ? (userData['height'] as int).toDouble() : (userData['height'] ?? 0.0).toDouble();
      String gender = userData['gender'] ?? "";
      int totalPoints = userData['points'] ?? 0;
      Map<String, dynamic> seedsInventory = {};
      if (userData['seedsInventory'] != null) {
        seedsInventory = Map<String, dynamic>.from(userData['seedsInventory']);
      }
      int userRank = await _calculateUserRank(uid, totalPoints);
      int totalUsers = await _getTotalUsersCount();
      return {
        'uid': uid,
        'name': userData['name'] ?? "",
        'email': userData['email'] ?? userEmail,
        'profileImageBase64': userData['profileImageBase64'] as String?,
        'createdAt': createdAt,
        'birthDate': birthDate,
        'weight': weight,
        'height': height,
        'gender': gender,
        'points': totalPoints,
        'seedsInventory': seedsInventory,
        'rank': userRank,
        'totalUsers': totalUsers,
      };
    } catch (e) {
      print("Error loading user data: $e");
      return null;
    }
  }

  Future<bool> updateUserData(String uid, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(uid).update(userData);
      DocumentSnapshot updatedDoc = await _firestore.collection('users').doc(uid).get();
      return updatedDoc.exists;
    } catch (e) {
      print("Error updating user data: $e");
      return false;
    }
  }

  Future<int> _calculateUserRank(String currentUid, int currentPoints) async {
    try {
      QuerySnapshot usersSnapshot = await _firestore.collection('users').orderBy('points', descending: true).get();
      int rank = 1;
      for (var doc in usersSnapshot.docs) {
        if (doc.id == currentUid) break;
        rank++;
      }
      return rank;
    } catch (e) {
      print("Error calculating rank: $e");
      return 0;
    }
  }

  Future<int> _getTotalUsersCount() async {
    try {
      AggregateQuerySnapshot totalUsersSnapshot = await _firestore.collection('users').count().get();
      return totalUsersSnapshot.count ?? 0;
    } catch (e) {
      print("Error getting total users: $e");
      return 0;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await _auth.signOut();
  }

  /// Deletes user document then auth account (best effort).
  Future<bool> deleteAccount() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return false;

      final String uid = user.uid;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);

      await _firestore.collection('users').doc(uid).delete();
      await user.delete();
      return true;
    } catch (e) {
      print("Error deleting account: $e");
      return false;
    }
  }
}