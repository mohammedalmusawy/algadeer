import 'package:flutter/material.dart';

/// أيقونات ملوّنة لمواقع التواصل — مشتركة في الورقة والإدارة.
class EntitySocialBrandIcon extends StatelessWidget {
  const EntitySocialBrandIcon({
    super.key,
    required this.id,
    this.size = 40,
  });

  final String id;
  final double size;

  static Color colorFor(String id) {
    switch (id) {
      case 'website':
        return const Color(0xFF0FAFA3);
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'tiktok':
        return const Color(0xFF111111);
      case 'telegram':
        return const Color(0xFF229ED9);
      default:
        return const Color(0xFF5B6C70);
    }
  }

  static IconData iconFor(String id) {
    switch (id) {
      case 'website':
        return Icons.language_rounded;
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'facebook':
        return Icons.facebook_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      case 'telegram':
        return Icons.send_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  static String titleAr(String id) {
    switch (id) {
      case 'website':
        return 'الموقع الإلكتروني';
      case 'instagram':
        return 'إنستغرام';
      case 'facebook':
        return 'فيسبوك';
      case 'tiktok':
        return 'تيك توك';
      case 'telegram':
        return 'تليجرام';
      default:
        return 'رابط';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(id);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Icon(iconFor(id), color: color, size: size * 0.5),
    );
  }
}
