import 'package:flutter/material.dart';

import '../models/entity_social_links.dart';
import 'entity_social_sheet.dart';

/// لون أزرار الاتصال الموحّد (مرجع المختبر).
const kEntityActionTeal = Color(0xFF1197A8);
const kEntityWhatsAppGreen = Color(0xFF25D366);

/// زر اتصال بأسلوب المختبر: أيقونة فوق النص.
class EntityContactActionBtn extends StatelessWidget {
  const EntityContactActionBtn({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.filled,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final minH = compact ? 40.0 : 72.0;
    final iconSize = compact ? 16.0 : 22.0;
    final fontSize = compact ? 11.5 : 12.5;
    final radius = compact ? 12.0 : 16.0;
    final vPad = compact ? 8.0 : 12.0;

    return Material(
      color: filled ? color : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(minHeight: minH),
          padding: EdgeInsets.symmetric(vertical: vPad, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: filled ? Colors.white : color, size: iconSize),
              SizedBox(height: compact ? 4 : 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? Colors.white : const Color(0xFF123B42),
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف تفاصيل موحّد (RTL مثل المختبر): اتصال · واتساب · مواقع · الموقع؟
class EntityContactActionsRow extends StatelessWidget {
  const EntityContactActionsRow({
    super.key,
    required this.phone,
    required this.whatsapp,
    required this.social,
    required this.socialTitle,
    this.onCall,
    this.onWhatsapp,
    this.onLocation,
    this.showLocation = true,
  });

  final String phone;
  final String whatsapp;
  final EntitySocialLinks social;
  final String socialTitle;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onLocation;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (phone.trim().isNotEmpty && onCall != null) {
      buttons.add(
        EntityContactActionBtn(
          icon: Icons.phone_in_talk_rounded,
          title: 'اتصال',
          filled: true,
          color: kEntityActionTeal,
          onTap: onCall!,
        ),
      );
    }
    if (whatsapp.trim().isNotEmpty && onWhatsapp != null) {
      buttons.add(
        EntityContactActionBtn(
          icon: Icons.chat_rounded,
          title: 'واتساب',
          filled: true,
          color: kEntityWhatsAppGreen,
          onTap: onWhatsapp!,
        ),
      );
    }
    buttons.add(
      EntityContactActionBtn(
        icon: Icons.public_rounded,
        title: 'مواقع',
        filled: true,
        color: kEntityActionTeal,
        onTap: () => showEntitySocialSheet(
          context,
          links: social,
          title: socialTitle,
        ),
      ),
    );
    if (showLocation && onLocation != null) {
      buttons.add(
        EntityContactActionBtn(
          icon: Icons.near_me_rounded,
          title: 'الموقع',
          filled: false,
          color: kEntityActionTeal,
          onTap: onLocation!,
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}

/// صف قائمة موحّد (RTL): اتصال · واتساب · التفاصيل — نفس ألوان المختبر.
class EntityListContactRow extends StatelessWidget {
  const EntityListContactRow({
    super.key,
    required this.onCall,
    required this.onWhatsapp,
    required this.onDetails,
  });

  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Expanded(
            child: EntityContactActionBtn(
              icon: Icons.phone_in_talk_rounded,
              title: 'اتصال',
              filled: true,
              color: kEntityActionTeal,
              compact: true,
              onTap: onCall,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: EntityContactActionBtn(
              icon: Icons.chat_rounded,
              title: 'واتساب',
              filled: true,
              color: kEntityWhatsAppGreen,
              compact: true,
              onTap: onWhatsapp,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: EntityContactActionBtn(
              icon: Icons.info_outline_rounded,
              title: 'التفاصيل',
              filled: false,
              color: kEntityActionTeal,
              compact: true,
              onTap: onDetails,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر رجوع موحّد — نفس جهة هوية الطبيب (يسار الشاشة + chevron يمين).
class GhadeerBackButton extends StatelessWidget {
  const GhadeerBackButton({
    super.key,
    this.onPressed,
    this.color = const Color(0xFF1A4F58),
    this.size = 40,
  });

  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed ?? () => Navigator.maybePop(context),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.chevron_right_rounded,
            color: color,
            size: size * 0.7,
          ),
        ),
      ),
    );
  }
}
