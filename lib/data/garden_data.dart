// ========== lib/data/garden_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../presentation/garden_planted_item.dart';

class GardenData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid, 'email': user.email};
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    if (userId.isEmpty) return null;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        Map<String, int> seedsInventory = {
          'Regular Seeds': 2,
          'Rare Seeds': 2,
          'Legendary Seeds': 2,
          'Growth Accelerator': 1,
        };
        if (data.containsKey('seedsInventory')) {
          Map<String, dynamic> inventory = Map<String, dynamic>.from(data['seedsInventory']);
          seedsInventory = {
            'Regular Seeds': inventory['Regular Seeds']?.toInt() ?? 0,
            'Rare Seeds': inventory['Rare Seeds']?.toInt() ?? 0,
            'Legendary Seeds': inventory['Legendary Seeds']?.toInt() ?? 0,
            'Growth Accelerator': inventory['Growth Accelerator']?.toInt() ?? 0,
          };
        }
        return {
          'points': data['points'] ?? 0,
          'seedsInventory': seedsInventory,
        };
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
    return null;
  }

  Future<List<PlantedItem>?> loadGardenData(String userId, Color Function(String) getSeedColor) async {
    if (userId.isEmpty) return null;
    try {
      QuerySnapshot gardenSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('garden')
          .get();

      List<PlantedItem> loadedItems = [];
      for (var doc in gardenSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime plantTime = (data['plantTime'] as Timestamp).toDate();
        int durationSeconds = data['durationSeconds'] ?? 60;
        DateTime finishTime = plantTime.add(Duration(seconds: durationSeconds));
        bool isFullyGrown = DateTime.now().isAfter(finishTime);
        int remainingSeconds = isFullyGrown ? 0 : finishTime.difference(DateTime.now()).inSeconds;

        loadedItems.add(PlantedItem(
          id: doc.id,
          seedType: data['seedType'] ?? 'Regular Seeds',
          color: getSeedColor(data['seedType'] ?? 'Regular Seeds'),
          icon: Icons.spa,
          position: Offset(
            (data['positionX'] ?? 30.0).toDouble(),
            (data['positionY'] ?? 30.0).toDouble(),
          ),
          isAccelerated: data['isAccelerated'] ?? false,
          plantTime: plantTime,
          durationSeconds: durationSeconds,
          remainingSeconds: remainingSeconds,
          isFullyGrown: isFullyGrown,
          docId: doc.id,
        ));
      }
      return loadedItems;
    } catch (e) {
      print('Error loading garden data: $e');
      return null;
    }
  }

  Future<String?> plantSeed(String userId, String seedType, DateTime plantTime, int durationSeconds, double posX, double posY) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('garden')
          .add({
        'seedType': seedType,
        'plantTime': Timestamp.fromDate(plantTime),
        'durationSeconds': durationSeconds,
        'positionX': posX,
        'positionY': posY,
        'isAccelerated': false,
        'isFullyGrown': false,
      });
      return docRef.id;
    } catch (e) {
      print('Error planting seed: $e');
      return null;
    }
  }

  Future<void> updateSeedsInventory(String userId, String seedType, int newQuantity) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'seedsInventory.$seedType': newQuantity,
      });
    } catch (e) {
      print('Error updating seeds inventory: $e');
    }
  }

  Future<void> acceleratePlant(String userId, String docId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('garden')
          .doc(docId)
          .update({
        'plantTime': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: -1))),
        'isAccelerated': true,
      });
    } catch (e) {
      print('Error accelerating plant: $e');
    }
  }

  Future<void> harvestPlant(String userId, String docId, int points) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('garden')
          .doc(docId)
          .delete();

      if (points > 0) {
        await _firestore.collection('users').doc(userId).update({
          'points': FieldValue.increment(points),
        });
      }
    } catch (e) {
      print('Error harvesting: $e');
    }
  }

  Future<void> updateGardenName(String userId, String name) async {
    if (userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'gardenName': name,
      });
    }
  }
}
