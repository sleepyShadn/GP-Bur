import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xFFA5B68D);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  String _gender = 'Female';
  bool _isLoading = false;

  Future<void> _registerUser() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _heightController.text.isEmpty) {
      _showErrorDialog('Please fill all fields');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorDialog('Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String userId = userCredential.user!.uid;

      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'weight': _weightController.text.trim(),
        'height': _heightController.text.trim(),
        'gender': _gender,
        'createdAt': FieldValue.serverTimestamp(),
        'points': 0,
        'seedsInventory': {
          'Regular Seeds': 5,
          'Rare Seeds': 2,
          'Legendary Seeds': 1,
          'Growth Accelerator': 1,
        },
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => Login()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email is already registered';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('An error occurred. Please try again');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text('Error', style: TextStyle(color: colorGreenDark)),
        content: Text(message, style: const TextStyle(color: colorGreenDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: colorGreenDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorCream,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -30,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: colorPinkish.withOpacity(0.4),
            ),
          ),
          Positioned(
            bottom: 150,
            right: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: colorGreenLight.withOpacity(0.3),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: colorGreenDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      "Create your account",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: colorGreenDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    decoration: _buildInputDecoration("Name"),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration("Email address"),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration:
                        _buildInputDecoration("Password", isPassword: true),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _dobController,
                    decoration: _buildInputDecoration("Date of Birth",
                        icon: Icons.calendar_month),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration:
                              _buildInputDecoration("Weight", suffix: "kg"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration:
                              _buildInputDecoration("Height", suffix: "cm"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    height: 55,
                    decoration: BoxDecoration(
                      color: colorPinkish,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Gender",
                          style: TextStyle(
                              color: colorGreenDark,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _gender = 'Female'),
                          child: Row(
                            children: [
                              Icon(
                                _gender == 'Female'
                                    ? Icons.check_circle
                                    : Icons.radio_button_off,
                                size: 18,
                                color: colorGreenDark,
                              ),
                              const SizedBox(width: 4),
                              const Text("Female",
                                  style: TextStyle(
                                      color: colorGreenDark, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () => setState(() => _gender = 'Male'),
                          child: Row(
                            children: [
                              Icon(
                                _gender == 'Male'
                                    ? Icons.check_circle
                                    : Icons.radio_button_off,
                                size: 18,
                                color: colorGreenDark,
                              ),
                              const SizedBox(width: 4),
                              const Text("Male",
                                  style: TextStyle(
                                      color: colorGreenDark, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorGreenDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "CREATE ACCOUNT",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const Login()),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              color: colorGreenDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(text: "ALREADY HAVE AN ACCOUNT? "),
                            TextSpan(
                              text: "LOG IN",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint,
      {bool isPassword = false, IconData? icon, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: colorGreenDark, fontSize: 14),
      filled: true,
      fillColor: colorPinkish,
      suffixText: suffix,
      suffixStyle:
          const TextStyle(color: colorGreenDark, fontWeight: FontWeight.bold),
      suffixIcon:
          icon != null ? Icon(icon, color: colorGreenDark, size: 20) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }
}
