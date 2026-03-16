import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xFFA5B68D);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Single error message state
  String? _loginErrorMessage;

  Future<void> _loginUser() async {
    // Clear previous errors
    setState(() {
      _loginErrorMessage = null;
    });

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _loginErrorMessage = 'tezt incorrect email or passwotrd';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        _showWelcomePopup();
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loginErrorMessage = ' incorrect email or passwotrd';
      });
    } catch (e) {
      setState(() {
        _loginErrorMessage = ' incorrect email or passwotrd';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showWelcomePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Icon(
          Icons.check_circle_outline,
          color: colorGreenDark,
          size: 60,
        ),
        content: const Text(
          "wellcpme back !",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorGreenDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                      (route) => false,
                );
              },
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: colorGreenDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_emailController.text.isEmpty) {
      _showErrorDialog('Please enter your email to reset password');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
        .hasMatch(_emailController.text.trim())) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());

      _showSuccessDialog('Password Reset Email Sent',
          'A password reset link has been sent to ${_emailController.text}. Check your email to change your password.');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email address';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address format';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('An error occurred. Please try again');
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

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: Text(title, style: const TextStyle(color: colorGreenDark)),
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
            top: -20,
            left: -30,
            child: CircleAvatar(
              radius: 70,
              backgroundColor: colorPinkish.withOpacity(0.4),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -50,
            child: CircleAvatar(
              radius: 90,
              backgroundColor: colorGreenLight.withOpacity(0.2),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: colorGreenDark),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        "Welcome Back\nto Bur' !",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colorGreenDark,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Email field
                    Container(
                      decoration: BoxDecoration(
                        color: colorPinkish,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "sara@example.com",
                          hintStyle: const TextStyle(
                            color: colorGreenDark,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                        onChanged: (value) {
                          if (_loginErrorMessage != null) {
                            setState(() {
                              _loginErrorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Password field
                    Container(
                      decoration: BoxDecoration(
                        color: colorPinkish,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "•••••••",
                          hintStyle: const TextStyle(
                            color: colorGreenDark,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: colorGreenDark,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                        onChanged: (value) {
                          if (_loginErrorMessage != null) {
                            setState(() {
                              _loginErrorMessage = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Single beautiful error message below all inputs
                    if (_loginErrorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _loginErrorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 5),
                    // Forgot Password button
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () async {
                          if (_emailController.text.isEmpty) {
                            _showEnterEmailDialog();
                          } else {
                            await _sendPasswordResetEmail();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: colorGreenDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginUser,
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
                          "LOG IN",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const Register()),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Color(0xFF362427),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                            children: [
                              TextSpan(
                                  text:
                                  "DON'T HAVE AN ACCOUNT? CREATE ACCOUNT "),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Extra padding at bottom
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnterEmailDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title:
        const Text('Enter Email', style: TextStyle(color: colorGreenDark)),
        content: TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'sara@gmail.com',
            hintStyle: const TextStyle(
              color: colorGreenDark,
              fontStyle: FontStyle.italic,
            ),
            filled: true,
            fillColor: colorPinkish,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancel', style: TextStyle(color: colorGreenDark)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_emailController.text.isNotEmpty) {
                await _sendPasswordResetEmail();
              }
            },
            child: const Text('Send Reset Link',
                style: TextStyle(color: colorGreenDark)),
          ),
        ],
      ),
    );
  }
}