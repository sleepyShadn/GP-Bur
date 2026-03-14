import 'package:appforhumman/register_screen.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class AuthSelectionScreen extends StatelessWidget {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorPinkish,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  const Text(
                    "Welcome to Bur'",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorGreenDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Track, grow, and bloom within.",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorGreenDark,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Added logo image in center
                  Image.asset(
                    'assets/logo.png',
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
                              color: colorCream.withOpacity(0.4),
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
                      color: colorGreenLight,
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

                                  Navigator.of(context).push(MaterialPageRoute(
                                         builder: (context) => Login()),
                                   );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorCream,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    color: colorGreenDark,
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

                                   Navigator.of(context).push(
                                     MaterialPageRoute(
                                         builder: (context) => Register()),
                                   );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorCream,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "SIGN UP",
                                  style: TextStyle(
                                    color: colorGreenDark,
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