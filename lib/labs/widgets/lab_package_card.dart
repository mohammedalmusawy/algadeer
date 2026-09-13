import 'package:flutter/material.dart';

import '../../models/lab_models.dart';
import 'package_hero_image.dart';

/// بطاقة باقة للمستخدم — صورة هوية + أسعار (قريبة من المرجع البصري).
class LabPackageCard extends StatelessWidget {
  const LabPackageCard({
    super.key,
    required this.package,
    required this.onOpen,
  });

  final LabPackageItem package;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4EEEE)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF123B42),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${package.analysesCount} تحليل',
                          style: const TextStyle(
                            color: Color(0xFF708084),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (package.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            package.description.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF5B6C70),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        PackagePriceBlock(package: package),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  PackageHeroImage(
                    packageName: package.name,
                    imageUrl: package.imageUrl,
                    isFeatured: package.isFeatured,
                    width: 108,
                    height: 136,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF123B42),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'التفاصيل',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
