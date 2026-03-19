// ========== lib/presentation/auth_selection_screen.dart ==========
import 'package:flutter/material.dart';
import '../../domain/auth_selection_logic.dart';
import '../../data/auth_selection_data.dart';

class AuthSelectionScreen extends StatelessWidget {
  final AuthSelectionLogic _logic = AuthSelectionLogic();
  final AuthSelectionData _data = AuthSelectionData();

  AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _logic.colorPinkish,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Text(
                    _logic.welcomeText,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff7f9461),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _logic.subtitleText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff7f9461),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Image.asset(
                    _data.logoPath,
                    height: 240,
                    width: 290,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 300,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned(
                          bottom: 10,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _logic.colorCream.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC1CFA1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 280,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () {
                                  _data.navigateToLogin(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _logic.colorCream,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _logic.loginButtonText,
                                  style: const TextStyle(
                                    color: Color(0xff7f9461),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 280,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () {
                                  _data.navigateToRegister(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _logic.colorCream,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _logic.signUpButtonText,
                                  style: const TextStyle(
                                    color: Color(0xff7f9461),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}