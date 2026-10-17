import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// صورة من رابط تنحفظ على التلفون بعد أول تحميل (مثل إنستا/فيس):
/// المرة الثانية تطلع فوراً، وبدون نت تطلع من الذاكرة.
///
/// [cacheWidth] يصغّر الصورة بالذاكرة لحجم العرض حتى ما يثقل التطبيق
/// (صورة 4000px تنعرض بمربع 64px = هدر ذاكرة ومعالج).
class GhadeerNetImage extends StatelessWidget {
  const GhadeerNetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });

  /// الاختبارات تطفيه: مكتبة الحفظ تحتاج ملفات النظام اللي ما موجودة بالاختبار.
  static bool diskCache = true;

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  static bool get _useDisk => diskCache && !kIsWeb;

  @override
  Widget build(BuildContext context) {
    if (!_useDisk) {
      return Image.network(
        url,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      memCacheWidth: cacheWidth,
      filterQuality: filterQuality,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, _) => const ColoredBox(color: Color(0xFFF1F5F9)),
      errorWidget: (context, _, error) =>
          errorBuilder?.call(context, error, null) ?? const SizedBox.shrink(),
    );
  }
}

/// نفس الحفظ للأماكن اللي تحتاج ImageProvider (خلفيات، CircleAvatar).
ImageProvider ghadeerNetImageProvider(String url) => GhadeerNetImage._useDisk
    ? CachedNetworkImageProvider(url)
    : NetworkImage(url);
