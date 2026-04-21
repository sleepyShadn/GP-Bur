// ========== lib/domain/harvest_run_logic.dart ==========
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
/// UI helpers + exit dialog (glass style, aligned with Apple / Watering games).
class HarvestRunLogic {
  String formatTime(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// [onExitConfirmed] يُنفَّذ بعد إغلاق الحوار عند الضغط على Exit.
  Future<void> showExitDialog(
    BuildContext context,
    Future<void> Function() onExitConfirmed,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E2A3A).withValues(alpha: 0.82),
                    const Color(0xFF26364A).withValues(alpha: 0.76),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.shopping_basket_outlined,
                      color: Color(0xFFEAF2FC),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Exit Game?',
                    style: TextStyle(
                      color: Color(0xFFF8FBFF),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to exit? Your progress will be lost.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFDCE6F2),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFFEAF2FC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            await onExitConfirmed();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD166),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Exit',
                            style: TextStyle(
                              color: Color(0xFF2A3A4F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
