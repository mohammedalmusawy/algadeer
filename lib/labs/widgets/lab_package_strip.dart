import 'package:flutter/material.dart';

import '../../models/lab_models.dart';
import 'package_hero_image.dart';

/// شريط باقات أفقي — نفس ترتيب الصيدلية (عدة بطاقات + سحب).
class LabPackagesStrip extends StatelessWidget {
  const LabPackagesStrip({
    super.key,
    required this.packages,
    required this.onOpen,
    this.height = 248,
    this.cardWidth = 150,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<LabPackageItem> packages;
  final void Function(LabPackageItem package) onOpen;
  final double height;
  final double cardWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: padding,
        itemCount: packages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final pkg = packages[i];
          return LabPackageStripCard(
            package: pkg,
            width: cardWidth,
            onOpen: () => onOpen(pkg),
          );
        },
      ),
    );
  }
}

/// بطاقة باقة مضغوطة للشريط الأفقي.
class LabPackageStripCard extends StatelessWidget {
  const LabPackageStripCard({
    super.key,
    required this.package,
    required this.onOpen,
    this.width = 150,
  });

  final LabPackageItem package;
  final VoidCallback onOpen;
  final double width;

  @override
  Widget build(BuildContext context) {
    final discount = package.discountPercent;
    final price = package.newPrice;

    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4EEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F7F5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.biotech_rounded,
                    size: 16,
                    color: Color(0xFF0FAFA3),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    package.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123B42),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              package.analysesCount > 0
                  ? '${package.analysesCount} تحليل'
                  : 'باقة مختبر',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF708084),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                PackageHeroImage(
                  packageName: package.name,
                  imageUrl: package.imageUrl,
                  isFeatured: package.isFeatured,
                  width: double.infinity,
                  height: 86,
                  borderRadius: 12,
                ),
                if (discount != null && discount > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE25555),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-$discount%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (price != null && price > 0)
              Text(
                '${formatLabPrice(price)} د.ع',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0E8F9A),
                ),
              )
            else
              const Text(
                'السعر عند الطلب',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E8F9A),
                ),
              ),
            if (package.hasOldPrice)
              Text(
                '${formatLabPrice(package.oldPrice)} د.ع',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE74C3C),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF123B42),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'التفاصيل',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
