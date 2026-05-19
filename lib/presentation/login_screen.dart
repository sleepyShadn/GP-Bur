// ========== lib/presentation/login_screen.dart ==========
import 'dart:async';

import 'package:appforhumman/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import '../../domain/login_logic.dart';
import '../../data/login_data.dart';
import 'home_screen.dart';


class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final LoginLogic _logic = LoginLogic();
  final LoginData _data = LoginData();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isResettingPassword = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _loginErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberMePreference();
  }

  Future<void> _loadRememberMePreference() async {
    final remember = await _data.getRememberMe();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    setState(() {
      _loginErrorMessage = null;
    });

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _loginErrorMessage = 'Please enter both email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _data.loginUser(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (result.success) {
      await _data.setRememberMe(_rememberMe);
      _showWelcomePopup();
    } else {
      setState(() {
        _loginErrorMessage = 'Incorrect email or password.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showWelcomePopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _logic.colorCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Icon(
          Icons.check_circle_outline,
          color: _logic.colorBrown,
          size: 60,
        ),
        content: Text(
          "Welcome back!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _logic.colorBrown,
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
              child: Text(
                'Continue',
                style: TextStyle(
                  color: _logic.colorBrown,
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

  Future<void> _handleForgotPassword() async {
    if (_isLoading || _isResettingPassword) return;

    final String emailOnForm = _emailController.text.trim();
    if (emailOnForm.isEmpty) {
      await _showResetEmailDialog();
      return;
    }

    if (!_logic.isValidEmail(emailOnForm)) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    await _sendPasswordResetEmail(emailOnForm);
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    final String trimmed = email.trim();
    if (trimmed.isEmpty) {
      _showErrorDialog('Please enter your email to reset password');
      return;
    }

    if (!_logic.isValidEmail(trimmed)) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    if (!mounted) return;
    setState(() => _isResettingPassword = true);

    final LoginResult result = await _data.sendPasswordResetEmail(trimmed);

    if (!mounted) return;
    setState(() => _isResettingPassword = false);

    if (result.success) {
      _showSuccessDialog(
        'Password Reset Email Sent',
        'A password reset link has been sent to $trimmed. Check your inbox (and spam folder) to set a new password.',
      );
    } else {
      _showErrorDialog(
        result.errorMessage ?? 'Could not send reset email. Please try again.',
      );
    }
  }

  Future<void> _showResetEmailDialog() async {
    final TextEditingController dialogEmailController = TextEditingController();

    try {
      final String? submittedEmail = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          String? inlineError;

          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return AlertDialog(
                backgroundColor: _logic.colorCream,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Reset password',
                  style: TextStyle(color: Color(0xFFA5B68D)),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Enter the email you used to register. We will send you a reset link.',
                      style: TextStyle(color: Color(0xFFA5B68D), height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: dialogEmailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.email],
                      autocorrect: false,
                      style: const TextStyle(color: Color(0xFF362427)),
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8E8A83),
                          fontStyle: FontStyle.italic,
                        ),
                        errorText: inlineError,
                        filled: true,
                        fillColor: _logic.colorPinkish,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) {
                        final String value = dialogEmailController.text.trim();
                        if (value.isEmpty) {
                          setDialogState(() {
                            inlineError = 'Email is required';
                          });
                          return;
                        }
                        if (!_logic.isValidEmail(value)) {
                          setDialogState(() {
                            inlineError = 'Enter a valid email';
                          });
                          return;
                        }
                        Navigator.pop(dialogContext, value);
                      },
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFA5B68D)),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final String value = dialogEmailController.text.trim();
                      if (value.isEmpty) {
                        setDialogState(() {
                          inlineError = 'Email is required';
                        });
                        return;
                      }
                      if (!_logic.isValidEmail(value)) {
                        setDialogState(() {
                          inlineError = 'Enter a valid email';
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, value);
                    },
                    child: const Text(
                      'Send reset link',
                      style: TextStyle(
                        color: Color(0xFFA5B68D),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || submittedEmail == null || submittedEmail.trim().isEmpty) {
        return;
      }

      await _sendPasswordResetEmail(submittedEmail);
    } finally {
      dialogEmailController.dispose();
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _logic.colorCream,
        title: const Text('Error', style: TextStyle(color: Color(0xFFA5B68D))),
        content: Text(message, style: const TextStyle(color: Color(0xFFA5B68D))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFA5B68D))),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _logic.colorCream,
        title: Text(title, style: const TextStyle(color: Color(0xFFA5B68D))),
        content: Text(message, style: const TextStyle(color: Color(0xFFA5B68D))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFA5B68D))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _logic.colorCream,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _logic.colorCream,
                    _logic.colorPinkish.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -30,
              right: -20,
              child: CircleAvatar(
                radius: 90,
                backgroundColor: _logic.colorGreenLight.withOpacity(0.22),
              ),
            ),
            Positioned(
              top: 120,
              left: -40,
              child: CircleAvatar(
                radius: 72,
                backgroundColor: _logic.colorPinkish.withOpacity(0.35),
              ),
            ),
            Positioned(
              bottom: 150,
              right: -40,
              child: CircleAvatar(
                radius: 90,
                backgroundColor: _logic.colorGreenLight.withOpacity(0.18),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA5B68D).withOpacity(0.20),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: Color(0xFFA5B68D),
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          "Welcome Back\nto Bur' !",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF362427),
                            height: 1.18,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          "Log in to continue your growth journey",
                          style: TextStyle(
                            color: Color(0xFF7D7468),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA5B68D).withOpacity(0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              style: const TextStyle(color: Color(0xFF362427)),
                              decoration: InputDecoration(
                                hintText: "sara@example.com",
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8E8A83),
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFFA5B68D),
                                ),
                                filled: true,
                                fillColor: _logic.colorPinkish.withOpacity(0.75),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFA5B68D),
                                    width: 1.3,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              ),
                              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                              onChanged: (value) {
                                if (_loginErrorMessage != null) {
                                  setState(() {
                                    _loginErrorMessage = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              style: const TextStyle(color: Color(0xFF362427)),
                              decoration: InputDecoration(
                                hintText: "•••••••",
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8E8A83),
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFFA5B68D),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: const Color(0xFFA5B68D),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: _logic.colorPinkish.withOpacity(0.75),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFA5B68D),
                                    width: 1.3,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              ),
                              onSubmitted: (_) => _loginUser(),
                              onChanged: (value) {
                                if (_loginErrorMessage != null) {
                                  setState(() {
                                    _loginErrorMessage = null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 7),
                    Align(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFFA5B68D),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFA5B68D),
                                      width: 1.2,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                  ),
                                  const Text(
                                    'Remember me',
                                    style: TextStyle(
                                      color: Color(0xFF3A3832),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: (_isLoading || _isResettingPassword)
                                ? null
                                : () => unawaited(_handleForgotPassword()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              child: _isResettingPassword
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF356B24),
                                      ),
                                    )
                                  : const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Color(0xFF356B24),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA5B68D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          shadowColor: const Color(0xFFA5B68D).withOpacity(0.45),
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
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const Register(),
                              ),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: Color(0xFF2B2926),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: "Create account",
                                  style: TextStyle(
                                    color: Color(0xFF356B24),
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}