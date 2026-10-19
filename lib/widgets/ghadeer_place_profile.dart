import 'package:flutter/material.dart';

import '../models/entity_social_links.dart';
import '../theme/ghadeer_tokens.dart';
import 'entity_contact_actions.dart';
import 'entity_optional_logo.dart';
import 'ghadeer_identity_card.dart';
import 'ghadeer_net_image.dart';

/// صفحة «مكان» موحّدة (التجهيزات، العلاج الطبيعي، …) بنفس هوية الطبيب
/// والمختبر: بطاقة الهوية (صورة يمين، كتابة يسار، الدوام تحتهم)، بعدها
/// أزرار التواصل، النبذة، الأقسام، والعنوان.
class GhadeerPlaceProfile extends StatelessWidget {
  const GhadeerPlaceProfile({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.badgeText = '',
    required this.name,
    required this.slogan,
    required this.isOpenNow,
    required this.openFrom,
    required this.openTo,
    required this.address,
    required this.description,
    required this.tags,
    required this.tagsTitle,
    required this.logoUrl,
    required this.phone,
    required this.whatsapp,
    required this.social,
    required this.onCall,
    required this.onWhatsapp,
    required this.onMaps,
    required this.onShare,
    required this.onBack,
    required this.speakButton,
    this.ownerAccess,
  });

  final String imageUrl;
  final IconData fallbackIcon;
  final String badgeText;
  final String name;
  final String slogan;
  final bool isOpenNow;
  final String openFrom;
  final String openTo;
  final String address;
  final String description;
  final List<String> tags;
  final String tagsTitle;
  final String logoUrl;
  final String phone;
  final String whatsapp;
  final EntitySocialLinks social;
  final VoidCallback onCall;
  final VoidCallback onWhatsapp;
  final VoidCallback onMaps;
  final VoidCallback onShare;
  final VoidCallback onBack;
  final Widget speakButton;
  final Widget? ownerAccess;

  Widget _fallback() => ColoredBox(
    color: GhadeerTokens.tealWash,
    child: Center(
      child: Icon(fallbackIcon, size: 56, color: GhadeerTokens.tealDeep),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final img = imageUrl.trim();
    final from = openFrom.trim();
    final to = openTo.trim();
    final hours = (from.isEmpty && to.isEmpty) ? '' : 'من $from إلى $to';
    final desc = description.trim();
    final addr = address.trim();
    final cleanTags = [
      for (final t in tags)
        if (t.trim().isNotEmpty) t.trim(),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        GhadeerIdentityCard(
          photo: img.isEmpty
              ? _fallback()
              : GhadeerNetImage(
                  img,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  errorBuilder: (_, _, _) => _fallback(),
                ),
          onPhotoTap: img.isEmpty
              ? null
              : () => showGhadeerPhotoViewer(
                  context,
                  GhadeerNetImage(
                    img,
                    fit: BoxFit.contain,
                    cacheWidth: 1400,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
          badgeText: badgeText,
          name: name,
          subtitle: slogan,
          logo: logoUrl.trim().isNotEmpty
              ? EntityOptionalLogo(url: logoUrl)
              : null,
          onShare: onShare,
          onBack: onBack,
          ownerAccess: ownerAccess,
          photoOverlay: _OpenChip(isOpen: isOpenNow),
          below: GhadeerIdentityInfoBox(
            icon: Icons.schedule_rounded,
            label: isOpenNow ? 'مفتوح الآن' : 'مغلق الآن',
            labelColor: isOpenNow ? GhadeerTokens.ok : GhadeerTokens.danger,
            text: hours.isEmpty ? 'أوقات الدوام غير مضافة' : hours,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: EntityContactActionsRow(
            phone: phone,
            whatsapp: whatsapp,
            social: social,
            socialTitle: 'مواقع تواصل $name',
            onCall: onCall,
            onWhatsapp: onWhatsapp,
            onLocation: onMaps,
            showLocation: addr.isNotEmpty,
          ),
        ),
        _card(
          title: 'نبذة',
          trailing: speakButton,
          child: Text(
            desc.isNotEmpty ? desc : 'لم تتم إضافة نبذة حتى الآن.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.8,
              color: desc.isNotEmpty
                  ? GhadeerTokens.ink
                  : GhadeerTokens.inkMuted,
            ),
          ),
        ),
        if (cleanTags.isNotEmpty)
          _card(
            title: tagsTitle,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in cleanTags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: GhadeerTokens.tealWash,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: GhadeerTokens.tealDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (addr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: GhadeerTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
                side: const BorderSide(color: GhadeerTokens.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
                onTap: onMaps,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: GhadeerTokens.tealWash,
                          borderRadius: BorderRadius.circular(
                            GhadeerTokens.radiusSm,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: GhadeerTokens.tealDeep,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('العنوان', style: GhadeerTokens.caption),
                            const SizedBox(height: 2),
                            Text(
                              addr,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: GhadeerTokens.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'الخريطة',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: GhadeerTokens.tealDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GhadeerTokens.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: GhadeerTokens.heading)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _OpenChip extends StatelessWidget {
  const _OpenChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? GhadeerTokens.ok : GhadeerTokens.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          // Flexible: الحبّة ما تطلع برا الصورة بالشاشات الصغيرة.
          Flexible(
            child: Text(
              isOpen ? 'مفتوح الآن' : 'مغلق الآن',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
