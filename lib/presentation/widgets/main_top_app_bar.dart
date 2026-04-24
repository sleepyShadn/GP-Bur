import 'package:flutter/material.dart';

class MainTopAppBar extends StatelessWidget {
  const MainTopAppBar({
    super.key,
    required this.title,
    required this.coins,
    this.primaryTint = const Color(0xffeef5e3),
    this.secondaryTint = const Color(0xffffffff),
    this.accentColor = const Color(0xff5f7744),
    this.unreadNotificationsCount = 0,
    this.onNotificationsPressed,
  });

  final String title;
  final int coins;
  final Color primaryTint;
  final Color secondaryTint;
  final Color accentColor;
  /// When [onNotificationsPressed] is non-null, a bell action is shown (e.g. on Home).
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            secondaryTint.withOpacity(0.96),
            primaryTint.withOpacity(0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/icon.jpeg',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 40,
                color: primaryTint,
                child: Icon(
                  Icons.spa_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          if (onNotificationsPressed != null) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNotificationsPressed,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: accentColor,
                        size: 26,
                      ),
                      if (unreadNotificationsCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB54A4A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadNotificationsCount > 99
                                  ? '99+'
                                  : '$unreadNotificationsCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_rounded, color: accentColor, size: 15),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
