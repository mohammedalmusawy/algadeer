import 'package:flutter/material.dart';

import '../../models/lab_models.dart';
import '../lab_default_images.dart';
import 'lab_network_or_asset_image.dart';

/// بطاقة قائمة المختبرات — نفس ترتيب بطاقة الأطباء.
/// بدون أزرار اتصال/واتساب — الإجراءات داخل ملف المختبر.
class ClinicLabCard extends StatelessWidget {
  const ClinicLabCard({
    super.key,
    required this.lab,
    required this.onOpenPackages,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final LabItem lab;
  final VoidCallback onOpenPackages;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  static const _navy = Color(0xFF123B42);
  static const _teal = Color(0xFF0FAFA3);
  static const _muted = Color(0xFF6B7C80);
  static const _line = Color(0xFFE6EEEE);

  String get _subtitle {
    final slogan = lab.slogan.trim();
    if (slogan.isNotEmpty) return slogan;
    final desc = lab.description.trim();
    if (desc.isNotEmpty) return desc;
    return 'مختبر تحاليل';
  }

  ({String text, Color color, Color bg}) get _status {
    if (lab.isFeatured) {
      return (
        text: 'مميز',
        color: const Color(0xFF0FAFA3),
        bg: const Color(0xFFE6F8F6),
      );
    }
    if (lab.workingHours.trim().isNotEmpty) {
      return (
        text: 'مفتوح حسب الدوام',
        color: const Color(0xFF138B4C),
        bg: const Color(0xFFE6F8EE),
      );
    }
    return (
      text: 'متاح',
      color: const Color(0xFF138B4C),
      bg: const Color(0xFFE6F8EE),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final imageUrl = LabDefaultImages.displayUrl(
      imageUrl: lab.imageUrl,
      labId: lab.id,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onOpenPackages,
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
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: imageUrl.isNotEmpty
                            ? LabNetworkOrAssetImage(
                                imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                cacheWidth: 280,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (_, _, _) =>
                                    const _LabPortraitFallback(),
                              )
                            : const _LabPortraitFallback(),
                      ),
                    ),
                    if (onToggleFavorite != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Material(
                          color: Colors.white,
                          elevation: 1,
                          shadowColor: Colors.black26,
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
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF8A9A9E),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lab.name.isEmpty ? 'مختبر' : lab.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: _navy,
                            ),
                          ),
                        ),
                        if (lab.isFeatured)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF1A73E8),
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _teal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: status.bg,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        status.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (lab.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: _muted,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              lab.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFB0BEC2),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabPortraitFallback extends StatelessWidget {
  const _LabPortraitFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF4F3),
      alignment: Alignment.center,
      child: const Icon(
        Icons.biotech_rounded,
        size: 40,
        color: Color(0xFF9BB8B6),
      ),
    );
  }
}
