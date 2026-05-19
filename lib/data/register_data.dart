// ========== lib/data/register_data.dart ==========
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterData {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<RegisterResult> registerUser(Map<String, dynamic> userData) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: userData['email'],
        password: userData['password'],
      );

      String userId = userCredential.user!.uid;

      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'name': userData['name'],
        'email': userData['email'],
        'dateOfBirth': userData['dateOfBirth'],
        'weight': userData['weight'],
        'height': userData['height'],
        'gender': userData['gender'],
        'createdAt': FieldValue.serverTimestamp(),
        'points': 0,
        'seedsInventory': {
          'Regular Seeds': 0,
          'Rare Seeds': 0,
          'Legendary Seeds': 0,
          'Fertilizer': 0,
        },
      });

      return RegisterResult(success: true);
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      String? errorField;

      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email has been used before';
        errorField = 'email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
        errorField = 'email';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else {
        errorMessage = e.message ?? 'An error occurred';
      }

      return RegisterResult(
        success: false,
        errorMessage: errorMessage,
        errorField: errorField,
      );
    } catch (e) {
      return RegisterResult(
        success: false,
        errorMessage: 'An error occurred. Please try again',
      );
    }
  }
}

class RegisterResult {
  final bool success;
  final String? errorMessage;
  final String? errorField;

  RegisterResult({
    required this.success,
    this.errorMessage,
    this.errorField,
  });
}