// ========== lib/data/shop_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/shop_logic.dart';

class ShopData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return {'uid': user.uid, 'email': user.email};
    }
    return null;
  }

  Future<int> loadUserPoints(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return (userDoc.data() as Map<String, dynamic>)['points'] ?? 0;
      }
    } catch (e) {
      print('Error loading points: $e');
    }
    return 0;
  }

  Future<bool> buyItem(String userId, ShopItem item, int userPoints) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);

      batch.update(userRef, {
        'points': FieldValue.increment(-item.price),
      });

      final userDoc = await userRef.get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      Map<String, dynamic> seedsInventory = {};
      if (userData.containsKey('seedsInventory')) {
        seedsInventory = Map<String, dynamic>.from(userData['seedsInventory']);
      } else {
        seedsInventory = {
          'Regular Seeds': 0,
          'Rare Seeds': 0,
          'Legendary Seeds': 0,
          'Growth Accelerator': 0,
        };
      }

      int currentCount = seedsInventory[item.inventoryKey] ?? 0;
      seedsInventory[item.inventoryKey] = currentCount + 1;

      batch.update(userRef, {'seedsInventory': seedsInventory});
      await batch.commit();

      return true;
    } catch (e) {
      print('Error buying item: $e');
      return false;
    }
  }
}
