import 'package:flutter/material.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../../models/radiology_models.dart';
import '../radiology_default_images.dart';
import 'radiology_network_or_asset_image.dart';

class ClinicRadiologyCard extends StatelessWidget {
  const ClinicRadiologyCard({
    super.key,
    required this.center,
    required this.onOpen,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final RadiologyCenter center;
  final VoidCallback onOpen;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  static const _navy = Color(0xFF123B42);
  static const _teal = Color(0xFF0FAFA3);
  static const _muted = Color(0xFF6B7C80);
  static const _line = Color(0xFFE6EEEE);

  String get _subtitle {
    final slogan = center.slogan.trim();
    if (slogan.isNotEmpty) return slogan;
    final desc = center.description.trim();
    if (desc.isNotEmpty) return desc;
    return 'مركز أشعة';
  }

  /// عنوان جغرافي نظيف للبطاقة (بدون شعارات/رموز مزدحمة من البيانات).
  String get _cleanAddress {
    var raw = center.address.trim();
    if (raw.isEmpty) return '';
    raw = raw.replaceAll(RegExp(r'[✨🤍]+'), ' ').trim();
    final chunks = raw
        .split(RegExp(r'📍|\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final chunk in chunks.reversed) {
      final looksGeo = chunk.contains('شارع') ||
          chunk.contains('الشطرة') ||
          chunk.contains('قرب') ||
          chunk.contains('مقابل') ||
          chunk.contains('مجمع') ||
          chunk.contains('عيادة');
      final looksSlogan = chunk.contains('تشخيص') ||
          chunk.contains('أمانة') ||
          chunk.contains('تخجل');
      if (looksGeo && !looksSlogan) return chunk;
    }
    if (chunks.isNotEmpty) {
      final first = chunks.first;
      if (first.length <= 80) return first;
      return '${first.substring(0, 80)}…';
    }
    return raw.length <= 80 ? raw : '${raw.substring(0, 80)}…';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = RadiologyDefaultImages.displayUrl(
      imageUrl: center.imageUrl,
      centerId: center.id,
    );
    final address = _cleanAddress;

    return Semantics(
      button: true,
      label: 'فتح ${center.name}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  height: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: imageUrl.isNotEmpty
                              ? RadiologyNetworkOrAssetImage(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: Color(0xFFEAF4F3),
                                    child: Icon(
                                      Icons.radar_outlined,
                                      color: _teal,
                                    ),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xFFEAF4F3),
                                  child: Icon(
                                    Icons.radar_outlined,
                                    color: _teal,
                                  ),
                                ),
                        ),
                      ),
                      if (onToggleFavorite != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onToggleFavorite,
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: isFavorite
                                      ? const Color(0xFFE25555)
                                      : _navy,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _navy,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GhadeerTextWithLogo(
                        _subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        logoHeight: 18,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 15,
                                color: Color(0xFF1197A8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF445A5E),
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
