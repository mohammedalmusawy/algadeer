import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../theme/ghadeer_tokens.dart';
import '../utils/ghadeer_haptics.dart';
import 'entity_contact_actions.dart';

/// بطاقة الهوية الموحّدة (Phase 5C) — نفس شكل هوية الطبيب:
/// الصورة بإطار مدوّر يمين (عليها الرجوع)، والكتابة بعمود مستقل يسار،
/// وبعدهم شي اختياري بعرض البطاقة كامل (ساعات العمل مثلاً).
/// ماكو تداخل بين الصورة والكتابة، والطول يكبر حسب المحتوى.
class GhadeerIdentityCard extends StatelessWidget {
  const GhadeerIdentityCard({
    super.key,
    required this.photo,
    this.badgeText = '',
    required this.name,
    required this.subtitle,
    this.favorite = false,
    this.onToggleFavorite,
    required this.onShare,
    required this.onBack,
    this.subtitleWidget,
    this.snippet = '',
    this.logo,
    this.onPhotoTap,
    this.ownerAccess,
    this.photoOverlay,
    this.below,
    this.wrapName,
  });

  final Widget photo;

  /// شارة صغيرة فوق الشعار — فارغة = ما تطلع (الشعار يگول «منصة الغدير»).
  final String badgeText;
  final String name;
  final String subtitle;
  final Widget? subtitleWidget;
  final String snippet;
  final Widget? logo;
  final bool favorite;

  /// إذا null ما يطلع زر المفضلة (أقسام بدون مفضلة).
  final VoidCallback? onToggleFavorite;
  final VoidCallback onShare;
  final VoidCallback onBack;
  final VoidCallback? onPhotoTap;
  final Widget? ownerAccess;
  final Widget? photoOverlay;
  final Widget? below;

  /// يلف الاسم (مثلاً ضغطات صاحب البطاقة السرّية).
  final Widget Function(Widget name)? wrapName;

  static const _base = Color(0xFFEFF7F6);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusXl),
            border: Border.all(color: GhadeerTokens.line),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), _base],
            ),
            boxShadow: [
              BoxShadow(
                color: GhadeerTokens.deepWater.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final photoW = (constraints.maxWidth * 0.42).clamp(124.0, 200.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _textColumn()),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: photoW,
                          height: photoW * 1.32,
                          child: _photoFrame(),
                        ),
                      ],
                    ),
                  ),
                  if (below != null) ...[
                    const SizedBox(height: 12),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: below!,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _textColumn() {
    final title = name.trim();
    final sub = subtitle.trim();
    final snip = snippet.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (onToggleFavorite != null) ...[
              _iconBtn(
                icon: favorite ? Icons.favorite_rounded : Icons.favorite_border,
                label: favorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                color: favorite ? const Color(0xFFE25555) : GhadeerTokens.ink,
                onTap: () {
                  ghadeerToggleFeedback();
                  onToggleFavorite!();
                },
              ),
              const SizedBox(width: 8),
            ],
            _iconBtn(
              icon: Icons.ios_share_rounded,
              label: 'مشاركة البطاقة',
              onTap: onShare,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (badgeText.trim().isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _VerifiedPill(text: badgeText),
          ),
          const SizedBox(height: 8),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: GhadeerBrandHeaderRow(logoSize: 40),
        ),
        const SizedBox(height: 6),
        const Text(
          'التشخيص قبل كل شيء',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: GhadeerTokens.tealDeep,
          ),
        ),
        if (logo != null) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: logo!),
        ],
        const SizedBox(height: 14),
        _wrap(
          Text(
            title,
            key: const Key('identity_card_name'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: GhadeerTokens.ink,
            ),
          ),
        ),
        if (subtitleWidget != null || sub.isNotEmpty) ...[
          const SizedBox(height: 6),
          subtitleWidget ??
              Text(
                sub,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: GhadeerTokens.tealDeep,
                ),
              ),
        ],
        if (snip.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            snip,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: GhadeerTokens.inkMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _wrap(Widget nameText) =>
      wrapName == null ? nameText : wrapName!(nameText);

  Widget _photoFrame() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('identity_card_photo'),
            onTap: onPhotoTap,
            child: photo,
          ),
          // الرجوع أعلى اليمين — موحّد بكل التطبيق.
          Positioned(
            top: 8,
            right: 8,
            child: GhadeerBackButton(onPressed: onBack),
          ),
          if (ownerAccess != null)
            Positioned(top: 8 + 44 + 6, right: 8, child: ownerAccess!),
          if (photoOverlay != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Center(child: photoOverlay!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: GhadeerTokens.surface,
        shape: const CircleBorder(side: BorderSide(color: GhadeerTokens.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: color ?? GhadeerTokens.ink),
          ),
        ),
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 186),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        decoration: BoxDecoration(
          color: GhadeerTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GhadeerTokens.line),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 15,
                color: GhadeerTokens.teal,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: GhadeerTokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مربع معلومة بعرض البطاقة (ساعات العمل مثلاً): أيقونة + عنوان صغير + نص.
class GhadeerIdentityInfoBox extends StatelessWidget {
  const GhadeerIdentityInfoBox({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final String text;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
        border: Border.all(color: GhadeerTokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: GhadeerTokens.tealWash,
              borderRadius: BorderRadius.circular(GhadeerTokens.radiusSm),
            ),
            child: Icon(icon, size: 20, color: GhadeerTokens.tealDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: labelColor == null
                      ? GhadeerTokens.caption
                      : GhadeerTokens.caption.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w800,
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: GhadeerTokens.ink,
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

/// يفتح صورة الهوية كاملة بشاشة غامقة، تتكبّر بالأصابع.
void showGhadeerPhotoViewer(BuildContext context, Widget image) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(maxScale: 4, child: Center(child: image)),
          ),
          Positioned(
            top: MediaQuery.paddingOf(ctx).top + 12,
            right: 16,
            child: GhadeerBackButton(onPressed: () => Navigator.of(ctx).pop()),
          ),
        ],
      ),
    ),
  );
}
