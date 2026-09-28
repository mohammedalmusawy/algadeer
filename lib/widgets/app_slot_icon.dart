import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../services/app_icons_service.dart';

/// يعرض صورة الأيقونة إن وُجدت من الإدارة، وإلا الرمز الافتراضي.
/// لا يُستخدم لشعار الغدير — الشعار له [GhadeerBrandMark] فقط.
class AppSlotIcon extends StatelessWidget {
  const AppSlotIcon({
    super.key,
    required this.slotId,
    required this.fallback,
    this.size = 28,
    this.color,
  });

  final String slotId;
  final IconData fallback;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppIconsService.instance,
      builder: (context, _) {
        final url = AppIconsService.instance.urlFor(slotId);
        if (url == null || url.isEmpty) {
          return Icon(fallback, size: size, color: color);
        }
        return SizedBox(
          width: size,
          height: size,
          child: GhadeerResolvedImage(
            url,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => Icon(fallback, size: size, color: color),
          ),
        );
      },
    );
  }
}
