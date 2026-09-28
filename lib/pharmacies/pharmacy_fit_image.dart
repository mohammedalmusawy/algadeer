import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../home/ghadeer_home_colors.dart';

/// رفع صورة من الجهاز مضغوطة على قد الموبايل (التخطيط ثابت؛ الصورة تتكيّف).
class PharmacyImageHelper {
  PharmacyImageHelper._();

  /// أقصى ضلع للصورة المحفوظة — يمنع تضخم التخزين وتأثيرها على الواجهة.
  static const int mobileMaxSide = 720;
  static const int mobileQuality = 72;

  /// يعيد data-URI جاهزاً للحفظ في الحقول المحلية، أو null إن ألغى المستخدم.
  static Future<String?> pickFromDevice({
    int maxSide = mobileMaxSide,
    int quality = mobileQuality,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSide.toDouble(),
      maxHeight: maxSide.toDouble(),
      imageQuality: quality,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;
    final mime = (picked.mimeType != null && picked.mimeType!.startsWith('image/'))
        ? picked.mimeType!
        : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static bool isDataUrl(String url) =>
      url.trim().toLowerCase().startsWith('data:image/');

  static bool isNetworkUrl(String url) {
    final u = url.trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }
}

/// صورة داخل إطار ثابت — دائماً BoxFit.cover حتى لا تكسّر تخطيط الموبايل.
class PharmacyFitImage extends StatelessWidget {
  const PharmacyFitImage({
    super.key,
    required this.source,
    this.fallback = Icons.image_outlined,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final String source;
  final IconData fallback;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: _build(),
      ),
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: const Color(0xFFE8F6FB),
      child: Icon(fallback, color: GhadeerHomeColors.primary),
    );
  }

  Widget _build() {
    final url = source.trim();
    if (url.isEmpty) return _fallback();

    if (PharmacyImageHelper.isDataUrl(url)) {
      try {
        final comma = url.indexOf(',');
        if (comma < 0) return _fallback();
        final bytes = base64Decode(url.substring(comma + 1));
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: width,
          height: height,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }

    if (PharmacyImageHelper.isNetworkUrl(url)) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return _fallback();
  }
}
