// ========== lib/presentation/auth_selection_screen.dart ==========
import 'package:flutter/material.dart';
import '../../domain/auth_selection_logic.dart';
import '../../data/auth_selection_data.dart';

class AuthSelectionScreen extends StatefulWidget {
  AuthSelectionScreen({super.key});

  @override
  State<AuthSelectionScreen> createState() => _AuthSelectionScreenState();
}

class _AuthSelectionScreenState extends State<AuthSelectionScreen>
    with SingleTickerProviderStateMixin {
  final AuthSelectionLogic _logic = AuthSelectionLogic();
  final AuthSelectionData _data = AuthSelectionData();
  late final AnimationController _pulseController;
  bool _showContent = false;
  bool _showBottomPanel = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _showContent = true);
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _showBottomPanel = true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _logic.colorPinkish,
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _logic.colorPinkish,
                    _logic.colorCream.withOpacity(0.92),
                  ],
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 650),
              opacity: _showContent ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                offset: _showContent ? Offset.zero : const Offset(0, 0.06),
                child: Center(
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
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 0.98 + (_pulseController.value * 0.04);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          height: 220,
                          width: 290,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: _logic.colorGreenDark.withOpacity(0.14),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset(
                              _data.logoPath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 650),
                opacity: _showBottomPanel ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  offset:
                      _showBottomPanel ? Offset.zero : const Offset(0, 0.14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 300,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned(
                              bottom: 14,
                              child: Container(
                                width: 310,
                                height: 310,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _logic.colorCream.withOpacity(0.45),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 42,
                              child: Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: _logic.colorGreenLight,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(40),
                            topRight: Radius.circular(40),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _logic.colorGreenDark.withOpacity(0.10),
                              blurRadius: 18,
                              offset: const Offset(0, -2),
                            ),
                          ],
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
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      shadowColor:
                                          _logic.colorGreenDark.withOpacity(0.12),
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
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      shadowColor:
                                          _logic.colorGreenDark.withOpacity(0.12),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}