import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../models/lab_models.dart';
import '../package_image_library.dart';

/// لوحة هوية الباقة (صورة أو Placeholder احترافي).
class PackageHeroImage extends StatelessWidget {
  const PackageHeroImage({
    super.key,
    required this.packageName,
    this.imageUrl = '',
    this.bytes,
    this.width = 112,
    this.height = 148,
    this.borderRadius = 16,
    this.showGiftBadge = true,
    this.isFeatured = false,
  });

  final String packageName;
  final String imageUrl;
  final Uint8List? bytes;
  final double width;
  final double height;
  final double borderRadius;
  final bool showGiftBadge;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final style = packagePlaceholderStyle(packageName);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: _buildMedia(style),
            ),
          ),
          if (isFeatured)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3C4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 12,
                      color: Color(0xFFB8860B),
                    ),
                    SizedBox(width: 3),
                    Text(
                      'مميزة',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8A6A00),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (showGiftBadge)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: Color(0xFF0FAFA3),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedia(({Color bg, Color accent, IconData icon}) style) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover);
    }
    final url = GhadeerBranding.normalizeEntityImageUrl(imageUrl.trim());
    if (url.isNotEmpty) {
      if (GhadeerBranding.isAssetPath(url)) {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(style),
        );
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(style),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: style.bg,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }
    return _placeholder(style);
  }

  Widget _placeholder(({Color bg, Color accent, IconData icon}) style) {
    return ColoredBox(
      color: style.bg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(style.icon, size: 36, color: style.accent),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              packageName.trim().isEmpty ? 'باقة مختبر' : packageName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: style.accent,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PackagePriceBlock extends StatelessWidget {
  const PackagePriceBlock({super.key, required this.package});

  final LabPackageItem package;

  @override
  Widget build(BuildContext context) {
    final discount = package.discountPercent;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        if (discount != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F8EE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  size: 14,
                  color: Color(0xFF1B8A4C),
                ),
                const SizedBox(width: 4),
                Text(
                  '$discount% خصم',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B8A4C),
                  ),
                ),
              ],
            ),
          ),
        if (package.newPrice != null)
          Text(
            '${formatLabPrice(package.newPrice)} د.ع',
            style: const TextStyle(
              color: Color(0xFF0FAFA3),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        if (package.hasOldPrice)
          Text(
            '${formatLabPrice(package.oldPrice)} د.ع',
            style: const TextStyle(
              color: Color(0xFF9AA6A8),
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
            ),
          )
        else if (package.newPrice == null && package.oldPrice != null)
          Text(
            '${formatLabPrice(package.oldPrice)} د.ع',
            style: const TextStyle(
              color: Color(0xFF0FAFA3),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}
