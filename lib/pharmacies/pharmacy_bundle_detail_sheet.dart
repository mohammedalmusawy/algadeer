import 'dart:async';

import 'package:flutter/material.dart';

import '../home/app_shell_bottom_nav.dart';
import '../home/ghadeer_home_colors.dart';
import '../widgets/clinic_app_bar.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';
import 'pharmacy_order_message.dart';

/// يفتح تفاصيل باقة الصيدلية كصفحة داخلية فوق الغلاف (شريط رئيسي + واتساب).
Future<void> showPharmacyBundleDetail({
  required BuildContext context,
  required PharmacyItem pharmacy,
  required PharmacyBundle bundle,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PharmacyBundleDetailPage(
        pharmacy: pharmacy,
        bundle: bundle,
      ),
    ),
  );
}

/// تفاصيل باقة ظاهرة + مسودة واتساب فوق الشريط الرئيسي المشترك.
class PharmacyBundleDetailPage extends StatefulWidget {
  const PharmacyBundleDetailPage({
    super.key,
    required this.pharmacy,
    required this.bundle,
  });

  final PharmacyItem pharmacy;
  final PharmacyBundle bundle;

  @override
  State<PharmacyBundleDetailPage> createState() =>
      _PharmacyBundleDetailPageState();
}

class _PharmacyBundleDetailPageState extends State<PharmacyBundleDetailPage> {
  late final PharmacyBundle _bundle =
      PharmaciesCatalog.enrichBundle(widget.bundle);
  final Set<String> _optionalOn = <String>{};

  String get _whatsappTarget {
    final wa = widget.pharmacy.whatsapp.trim();
    if (wa.isNotEmpty) return wa;
    return widget.pharmacy.phone.trim();
  }

  Future<void> _send() async {
    final msg = PharmacyOrderMessage.buildFromBundle(
      pharmacyName: widget.pharmacy.name,
      bundle: _bundle,
      optionalIncluded: _optionalOn.toList(),
    );
    final ok = await PharmacyOrderMessage.openWhatsApp(
      whatsapp: _whatsappTarget,
      message: msg,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bundle;
    final canSend = _whatsappTarget.isNotEmpty;
    final desc = b.description.trim().isNotEmpty
        ? b.description.trim()
        : b.subtitle.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(b.title),
          backgroundColor: GhadeerHomeColors.pharmacyAccent,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: PackageWhatsAppAboveShell(
          enabled: canSend,
          onPressed: () => unawaited(_send()),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PharmacyFitImage(
                  source: b.imageUrl,
                  width: 96,
                  height: 96,
                  borderRadius: 14,
                  fallback: Icons.medication_liquid_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.pharmacy.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: GhadeerHomeColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: GhadeerHomeColors.secondary,
                        ),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GhadeerHomeColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (b.price > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_fmt(b.price)} د.ع',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: GhadeerHomeColors.primary,
                            fontSize: 16,
                          ),
                        ),
                        if (b.oldPrice > b.price)
                          Text(
                            '${_fmt(b.oldPrice)} د.ع',
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: GhadeerHomeColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ] else ...[
                        const SizedBox(height: 8),
                        const Text(
                          'السعر عند الطلب',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: GhadeerHomeColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (b.note.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                b.note.trim(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: GhadeerHomeColors.muted,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'المنتجات المشمولة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 6),
            if (b.supplements.isEmpty && b.resolvedProducts.isEmpty)
              const Text(
                'لا توجد منتجات مسجّلة لهذه الباقة',
                style: TextStyle(
                  color: GhadeerHomeColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              for (final s in _productLines(b))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: GhadeerHomeColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            if (b.optionalSupplements.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'اختياري — أضفه إن تحتاجه',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              for (final s in b.optionalSupplements)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _optionalOn.contains(s),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _optionalOn.add(s);
                      } else {
                        _optionalOn.remove(s);
                      }
                    });
                  },
                  title: Text(
                    s,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
            const SizedBox(height: 8),
            const Text(
              'الرسالة تُفتح كمسودة واتساب دون إرسال تلقائي.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: GhadeerHomeColors.muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// منتج واحد لكل اسم — لا تكرار آلي بين المنتجات والمكملات.
  List<String> _productLines(PharmacyBundle b) {
    final seen = <String>{};
    final out = <String>[];
    void add(String raw) {
      final n = raw.trim();
      if (n.isEmpty) return;
      final key = n.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      out.add(n);
    }

    if (b.products.isNotEmpty) {
      for (final p in b.products) {
        if (!p.optional) add(p.name);
      }
    } else {
      for (final s in b.supplements) {
        add(s);
      }
    }
    return out;
  }
}

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    buf.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  return buf.toString();
}
