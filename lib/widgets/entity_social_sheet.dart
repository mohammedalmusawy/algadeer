import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../models/entity_social_links.dart';
import 'entity_social_icons.dart';

/// ورقة مواقع التواصل — زر «مواقع» يبقى ظاهراً دائماً مع أيقونات المنصات.
Future<void> showEntitySocialSheet(
  BuildContext context, {
  required EntitySocialLinks links,
  String title = 'مواقع التواصل',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final channels = links.channels;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7E4E4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: GhadeerHomeColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  channels.isEmpty
                      ? 'لا توجد روابط مضافة بعد'
                      : 'اختر المنصة للفتح',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: GhadeerHomeColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                if (channels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'أضف الموقع أو إنستغرام أو فيسبوك أو تيك توك أو تليجرام من الإدارة لتظهر هنا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: GhadeerHomeColors.secondary,
                      ),
                    ),
                  )
                else
                  for (final ch in channels) ...[
                    Material(
                      color: const Color(0xFFF7FBFC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await EntitySocialLinks.launch(ch.launchUrl);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              EntitySocialBrandIcon(id: ch.id, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ch.titleAr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    color: GhadeerHomeColors.secondary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: EntitySocialBrandIcon.colorFor(ch.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// بطاقة إجراء «مواقع» بأسلوب أزرار المختبر (أيقونات فوق النص).
class EntitySocialActionCard extends StatelessWidget {
  const EntitySocialActionCard({
    super.key,
    required this.links,
    required this.title,
    this.filled = true,
    this.color = const Color(0xFF1D9BF0),
  });

  final EntitySocialLinks links;
  final String title;
  final bool filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final channels = links.channels;
    return Material(
      color: filled ? color : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => showEntitySocialSheet(
          context,
          links: links,
          title: title,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (channels.isEmpty)
                Icon(
                  Icons.public_rounded,
                  color: filled ? Colors.white : color,
                  size: 22,
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final ch in channels.take(5))
                      EntitySocialBrandIcon(id: ch.id, size: 20),
                  ],
                ),
              const SizedBox(height: 6),
              Text(
                'مواقع',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زر «مواقع» مع أيقونات المنصات الملوّنة (إن وُجدت روابط).
class EntitySocialMawaqaeButton extends StatelessWidget {
  const EntitySocialMawaqaeButton({
    super.key,
    required this.links,
    required this.title,
    this.filled = false,
    this.color = const Color(0xFF1D9BF0),
    this.minimumSize = const Size.fromHeight(46),
  });

  final EntitySocialLinks links;
  final String title;
  final bool filled;
  final Color color;
  final Size minimumSize;

  void _open(BuildContext context) {
    showEntitySocialSheet(context, links: links, title: title);
  }

  @override
  Widget build(BuildContext context) {
    // زر ثابت وواضح: أيقونة عامة + نص. أيقونات المنصات تظهر داخل الورقة فقط
    // حتى لا يختفي الزر أو يفيض على الشاشات الضيقة.
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.public_rounded,
          size: 20,
          color: filled ? Colors.white : color,
        ),
        const SizedBox(width: 6),
        Text(
          'مواقع',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: filled ? Colors.white : color,
          ),
        ),
      ],
    );

    if (filled) {
      return FilledButton(
        onPressed: () => _open(context),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: minimumSize,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: () => _open(context),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: minimumSize,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: child,
    );
  }
}

/// حقول إدارة مواقع التواصل — مع أيقونة لكل منصة.
/// الترتيب: موقع إلكتروني → إنستغرام → فيسبوك → تيك توك → تليجرام.
class EntitySocialAdminFields extends StatelessWidget {
  const EntitySocialAdminFields({
    super.key,
    required this.website,
    required this.instagram,
    required this.facebook,
    required this.tiktok,
    required this.telegram,
    this.fieldBuilder,
  });

  final TextEditingController website;
  final TextEditingController instagram;
  final TextEditingController facebook;
  final TextEditingController tiktok;
  final TextEditingController telegram;
  final Widget Function(TextEditingController c, String label)? fieldBuilder;

  @override
  Widget build(BuildContext context) {
    Widget row(String id, TextEditingController c) {
      if (fieldBuilder != null) {
        return fieldBuilder!(c, EntitySocialBrandIcon.titleAr(id));
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: EntitySocialBrandIcon.titleAr(id),
            hintText: id == 'website'
                ? 'example.com أو رابط كامل'
                : 'رابط أو اسم المستخدم',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10),
              child: EntitySocialBrandIcon(id: id, size: 28),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'مواقع التواصل (اختياري)',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: GhadeerHomeColors.secondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'اترك الفارغ إن لا تحتاج. زر «مواقع» يظهر دائماً. واتساب زر منفصل.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: GhadeerHomeColors.muted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        row('website', website),
        row('instagram', instagram),
        row('facebook', facebook),
        row('tiktok', tiktok),
        row('telegram', telegram),
      ],
    );
  }
}
