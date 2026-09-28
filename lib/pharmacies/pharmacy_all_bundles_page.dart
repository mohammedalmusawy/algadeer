import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import '../widgets/clinic_app_bar.dart';
import 'pharmacy_bundle_detail_sheet.dart';
import 'pharmacy_custom_bundle_page.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';

/// كل باقات الصيدلية الظاهرة — موبايل أولاً.
class PharmacyAllBundlesPage extends StatelessWidget {
  const PharmacyAllBundlesPage({
    super.key,
    required this.pharmacy,
    required this.bundles,
  });

  final PharmacyItem pharmacy;
  final List<PharmacyBundle> bundles;

  @override
  Widget build(BuildContext context) {
    final items = PharmaciesCatalog.visibleOnly(bundles);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFC),
        appBar: ClinicAppBar(
          title: Text('باقات ${pharmacy.name}'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PharmacyCustomBundlePage(pharmacy: pharmacy),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text(
                    'اختر باقتك بنفسك',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GhadeerHomeColors.primary,
                    side: const BorderSide(
                      color: GhadeerHomeColors.primary,
                      width: 1.4,
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد باقات ظاهرة حالياً',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = items[i];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => showPharmacyBundleDetail(
                              context: context,
                              pharmacy: pharmacy,
                              bundle: b,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PharmacyFitImage(
                                    source: b.imageUrl,
                                    width: 92,
                                    height: 92,
                                    borderRadius: 14,
                                    fallback: Icons.medication_liquid_rounded,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                b.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  color: GhadeerHomeColors
                                                      .secondary,
                                                ),
                                              ),
                                            ),
                                            if (b.isPopular)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE8F6FB),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'رائج',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: GhadeerHomeColors
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (b.subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            b.subtitle,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: GhadeerHomeColors.muted,
                                            ),
                                          ),
                                        ],
                                        if (b.supplements.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            b.supplements.take(3).join(' · '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: GhadeerHomeColors.secondary,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          b.price > 0
                                              ? '${_fmt(b.price)} د.ع'
                                              : 'السعر عند الطلب',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            color: GhadeerHomeColors.primary,
                                          ),
                                        ),
                                        if (b.oldPrice > 0)
                                          Text(
                                            '${_fmt(b.oldPrice)} د.ع',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFE74C3C),
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
