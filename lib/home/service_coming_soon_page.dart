import 'package:flutter/material.dart';

import 'ghadeer_home_colors.dart';

/// شاشة مؤقتة لخدمات لم تُفعَّل بياناتها بعد (مرحلة 1).
class ServiceComingSoonPage extends StatelessWidget {
  const ServiceComingSoonPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: GhadeerHomeColors.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: GhadeerHomeColors.secondary,
          elevation: 0,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: GhadeerHomeColors.secondary,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, size: 44, color: accent),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: GhadeerHomeColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: GhadeerHomeColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'قريباً — نجهّز هذا القسم بعناية دون التأثير على خدماتك الحالية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A9A9E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
