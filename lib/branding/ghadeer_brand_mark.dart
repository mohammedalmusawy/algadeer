import 'package:flutter/material.dart';

/// هوية الغدير المعتمدة — مصدر واحد للوغو في كل التطبيق.
class GhadeerBranding {
  GhadeerBranding._();

  /// اللوغو الرسمي داخل التطبيق (لا يُستبدل من الإدارة بنسخة أخرى).
  static const String officialLogoAsset = 'assets/branding/ghadeer_logo.png';

  /// تطبيع خفيف للنص العربي (همزات/مسافات/تشكيل) قبل المطابقة.
  static String _normalizeArabicLabel(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), ''); // تشكيل + تطويل
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    s = s.replaceAll(RegExp(r'\s+'), '');
    return s;
  }

  /// هل النص/المسار يُقصد به لوغو عيادة الغدير؟
  static bool looksLikeGhadeerLogo(String? pathOrLabel) {
    final ar = (pathOrLabel ?? '').trim();
    if (ar.isEmpty) return false;
    // روابط الشبكة (صور مرفوعة) ليست تسمية لوغو — لا نستبدلها أبدًا.
    if (ar.startsWith('http://') || ar.startsWith('https://')) return false;
    final p = ar.toLowerCase();
    if (p == officialLogoAsset.toLowerCase()) return true;
    if (p.contains('ghadeer_logo')) return true;
    if (p.contains('logo_ghadeer')) return true;
    if (p.contains('assets/branding/ghadeer')) return true;
    if (p.contains('logo') && p.contains('ghadeer')) return true;

    final compact = _normalizeArabicLabel(ar);
    if (compact == 'لوغوالغدير' ||
        compact == 'لوجوالغدير' ||
        compact == 'شعارالغدير' ||
        compact == 'شعارعيادهالغدير' ||
        compact == 'لوغوعيادهالغدير' ||
        compact == 'لوجوعيادهالغدير') {
      return true;
    }
    // أي صيغة فيها كلمة لوغو/لوجو/شعار + غدير
    final hasLogoWord = compact.contains('لوغو') ||
        compact.contains('لوجو') ||
        compact.contains('شعار') ||
        compact.contains('logo');
    final hasGhadeer = compact.contains('غدير') || compact.contains('ghadeer');
    if (hasLogoWord && hasGhadeer) return true;
    return false;
  }

  /// يطبّق استبدال «لوغو الغدير» على حقل نص بعد الإطار الحالي (آمن مع onChanged).
  static void applyOfficialLogoToField(
    TextEditingController controller, {
    VoidCallback? onApplied,
  }) {
    void apply() {
      final trimmed = controller.text.trim();
      if (!looksLikeGhadeerLogo(trimmed)) return;
      if (trimmed == officialLogoAsset) {
        onApplied?.call();
        return;
      }
      controller.value = TextEditingValue(
        text: officialLogoAsset,
        selection: TextSelection.collapsed(offset: officialLogoAsset.length),
      );
      onApplied?.call();
    }

    // تطبيق فوري إن أمكن، وإلا بعد الإطار (لوحة المفاتيح العربية).
    final trimmed = controller.text.trim();
    if (!looksLikeGhadeerLogo(trimmed)) return;
    if (trimmed == officialLogoAsset) {
      onApplied?.call();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      apply();
    });
  }

  /// إن كانت صورة الكيان (طبيب/مختبر/أشعة) لوغو غدير → المعتمد.
  static String normalizeEntityImageUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (looksLikeGhadeerLogo(u)) return officialLogoAsset;
    return u;
  }

  static bool isAssetPath(String path) => path.trim().startsWith('assets/');

  /// أنماط شائعة يكتبها المدير داخل النبذة/الشعار بدل الصورة.
  static final RegExp logoPlaceholderPattern = RegExp(
    r'\[\s*(?:لوغو|لوجو|شعار)\s*الغدير\s*\]|'
    r'(?:لوغو|لوجو|شعار)\s+الغدير|'
    r'(?:لوغو|لوجو|شعار)\s+عيادة\s+الغدير',
    caseSensitive: false,
  );

  static bool textContainsLogoPlaceholder(String text) =>
      logoPlaceholderPattern.hasMatch(text);
}

/// نص يعرض صورة الشعار المعتمد مكان أي «[لوغو الغدير]» / «لوغو الغدير».
class GhadeerTextWithLogo extends StatelessWidget {
  const GhadeerTextWithLogo(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.logoHeight = 22,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow overflow;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final raw = text.trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    if (!GhadeerBranding.textContainsLogoPlaceholder(raw)) {
      return Text(
        raw,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: true,
      );
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in GhadeerBranding.logoPlaceholderPattern.allMatches(raw)) {
      if (match.start > start) {
        spans.add(TextSpan(text: raw.substring(start, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Image.asset(
              GhadeerBranding.officialLogoAsset,
              height: logoHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => Icon(
                Icons.local_hospital_rounded,
                size: logoHeight * 0.9,
                color: const Color(0xFF0FAFA3),
              ),
            ),
          ),
        ),
      );
      start = match.end;
    }
    if (start < raw.length) {
      spans.add(TextSpan(text: raw.substring(start)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: true,
    );
  }
}

/// صورة كيان تدعم الرابط + الـ asset + استبدال «لوغو الغدير» تلقائيًا.
class GhadeerResolvedImage extends StatelessWidget {
  const GhadeerResolvedImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });

  final String path;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final resolved = GhadeerBranding.normalizeEntityImageUrl(path.trim());
    if (resolved.isEmpty) {
      return errorBuilder?.call(context, 'empty', null) ??
          const SizedBox.shrink();
    }
    if (GhadeerBranding.isAssetPath(resolved)) {
      return Image.asset(
        resolved,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        errorBuilder: errorBuilder,
      );
    }
    return Image.network(
      resolved,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }
}

ImageProvider? ghadeerResolvedImageProvider(String path) {
  final resolved = GhadeerBranding.normalizeEntityImageUrl(path.trim());
  if (resolved.isEmpty) return null;
  if (GhadeerBranding.isAssetPath(resolved)) return AssetImage(resolved);
  if (resolved.startsWith('http')) return NetworkImage(resolved);
  // نص غير رابط (مثل «لوغو الغدير») بعد التطبيع يجب أن يكون asset
  if (GhadeerBranding.looksLikeGhadeerLogo(path)) {
    return const AssetImage(GhadeerBranding.officialLogoAsset);
  }
  return null;
}

/// علامة هوية الغدير — الشعار المعتمد الحالي.
class GhadeerBrandMark extends StatelessWidget {
  const GhadeerBrandMark({
    super.key,
    this.size = 44,
    this.color = const Color(0xFF0FAFA3),
    this.backgroundColor = const Color(0xFFE8F7F5),
  });

  final double size;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      GhadeerBranding.officialLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.local_hospital_rounded,
          size: size * 0.7,
          color: color,
        );
      },
    );

    if (backgroundColor == null) {
      return SizedBox(width: size, height: size, child: mark);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.08),
      child: mark,
    );
  }
}

/// صف شعار الغدير + النص — للهيرو (طبيب / مختبر / أشعة).
class GhadeerBrandHeaderRow extends StatelessWidget {
  const GhadeerBrandHeaderRow({
    super.key,
    this.logoSize = 48,
  });

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    const brandNavy = Color(0xFF123B42);
    const brandNavySoft = Color(0xFF1A4F58);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            GhadeerBranding.officialLogoAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                SizedBox(width: logoSize, height: logoSize),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عيادة الغدير',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    color: brandNavy,
                  ),
                ),
                Text(
                  'معاً لصحة أفضل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: brandNavySoft,
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
