// ========== lib/data/garden_data.dart ==========
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain/garden_logic.dart';
import '../presentation/garden_planted_item.dart';

class GardenData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _pointsSubscription;

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
          GardenLogic.fertilizerInventoryKey: 1,
        };
        if (data.containsKey('seedsInventory')) {
          final Map<String, dynamic> inventory =
              Map<String, dynamic>.from(data['seedsInventory'] as Map);
          seedsInventory = GardenLogic.parseSeedsInventory(inventory);
        }
        return {
          'points': data['points'] ?? 0,
          'seedsInventory': seedsInventory,
          'gardenName': data['gardenName'] as String?,
          'gardenSeason': data['gardenSeason'] as String?,
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
        int durationSeconds =
            data['durationSeconds'] ?? GardenLogic.regularGrowSeconds;
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

  /// Moves [plantTime] earlier by up to [GardenLogic.growthAcceleratorAdvanceSeconds],
  /// or by all remaining time if less — never replaces the multi-day habit model.
  Future<DateTime?> acceleratePlantGrowDay(String userId, String docId) async {
    if (userId.isEmpty) return null;
    try {
      final DocumentReference<Map<String, dynamic>> ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('garden')
          .doc(docId);
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      if (!snap.exists) return null;
      final Map<String, dynamic> data = snap.data()!;
      final DateTime plantTime = (data['plantTime'] as Timestamp).toDate();
      final int durationSeconds =
          (data['durationSeconds'] as num?)?.toInt() ??
              GardenLogic.regularGrowSeconds;
      final DateTime finish =
          plantTime.add(Duration(seconds: durationSeconds));
      final DateTime now = DateTime.now();
      final int remaining = finish.difference(now).inSeconds;
      if (remaining <= 0) {
        return null;
      }
      final int skip = remaining < GardenLogic.growthAcceleratorAdvanceSeconds
          ? remaining
          : GardenLogic.growthAcceleratorAdvanceSeconds;
      final DateTime newPlantTime = plantTime.subtract(Duration(seconds: skip));
      await ref.update(<String, dynamic>{
        'plantTime': Timestamp.fromDate(newPlantTime),
        'isAccelerated': true,
      });
      return newPlantTime;
    } catch (e) {
      print('Error accelerating plant: $e');
      return null;
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

  Future<void> updateGardenSeason(String userId, String season) async {
    if (userId.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'gardenSeason': season,
      });
    }
  }

  void listenToUserPoints(String userId, void Function(int points) onPoints) {
    _pointsSubscription?.cancel();
    if (userId.isEmpty) return;
    _pointsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> doc) {
        final int points = (doc.data()?['points'] as num?)?.toInt() ?? 0;
        onPoints(points);
      },
      onError: (Object error) {
        print('Error listening to garden points: $error');
      },
    );
  }

  void cancelPointsListener() {
    _pointsSubscription?.cancel();
  }
}
