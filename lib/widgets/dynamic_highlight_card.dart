import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../services/dynamic_message_service.dart';
import 'dynamic_highlight_detail_sheet.dart';

/// بطاقة عبارة ديناميكية خفيفة — بهوية الغدير (تصميم نظيف بدون ثقل).
class DynamicHighlightCard extends StatelessWidget {
  const DynamicHighlightCard({
    super.key,
    required this.message,
    this.onTapFallback,
    this.previewImageBytes,
    this.openDetailsOnTap = true,
  });

  final DynamicMessage message;
  final VoidCallback? onTapFallback;

  /// معاينة محلية قبل الرفع (من معرض الجهاز).
  final Uint8List? previewImageBytes;

  /// عند true (الافتراضي): الضغط يفتح ورقة التفاصيل.
  final bool openDetailsOnTap;

  Future<void> _onTap(BuildContext context) async {
    if (openDetailsOnTap) {
      await showDynamicHighlightDetails(
        context,
        message,
        previewImageBytes: previewImageBytes,
      );
      return;
    }
    onTapFallback?.call();
  }

  @override
  Widget build(BuildContext context) {
    final title = message.title.trim().isEmpty
        ? 'عيادة الغدير'
        : message.title.trim();
    final body = message.body.trim();
    final badge = message.badge.trim().isEmpty
        ? 'عيادة الغدير'
        : message.badge.trim();
    final image = message.imageUrl.trim();

    return Semantics(
      button: true,
      label: 'فتح الإعلان: $title',
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF3FAFA),
                  Color(0xFFE8F6F6),
                ],
              ),
              border: Border.all(color: const Color(0xFFDCECEC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F6F4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0C7F76),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123B42),
                            height: 1.3,
                          ),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.8,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5B6C70),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HighlightThumb(
                    networkUrl: image,
                    previewBytes: previewImageBytes,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// مصغّر إعلاني — يظهر الصورة كاملة قدر الإمكان.
class _HighlightThumb extends StatelessWidget {
  const _HighlightThumb({
    required this.networkUrl,
    this.previewBytes,
  });

  final String networkUrl;
  final Uint8List? previewBytes;

  static const double _w = 64;
  static const double _h = 88;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: _w,
        height: _h,
        child: ColoredBox(
          color: const Color(0xFFF3F9FA),
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return Image.memory(
        previewBytes!,
        width: _w,
        height: _h,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    final url = networkUrl.trim();
    if (url.isEmpty) return const _LogoFallback();

    if (GhadeerBranding.isAssetPath(url)) {
      return Image.asset(
        url,
        width: _w,
        height: _h,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _LogoFallback(),
      );
    }

    return Image.network(
      url,
      width: _w,
      height: _h,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFFE8F7F5),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0FAFA3),
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFFFF1F0),
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFFC94A4A),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE8F7F5),
      child: Center(
        child: Image.asset(
          GhadeerBranding.officialLogoAsset,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.local_hospital_rounded,
            color: Color(0xFF0FAFA3),
          ),
        ),
      ),
    );
  }
}
