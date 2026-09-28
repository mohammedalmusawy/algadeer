import 'package:flutter/material.dart';

import '../home/ghadeer_home_colors.dart';
import 'pharmacy_fit_image.dart';
import 'pharmacy_models.dart';
import 'pharmacy_order_message.dart';

/// تفاصيل باقة ظاهرة + إرسال اسمها وتفاصيلها عبر واتساب للصيدلية.
Future<void> showPharmacyBundleDetail({
  required BuildContext context,
  required PharmacyItem pharmacy,
  required PharmacyBundle bundle,
}) {
  final b = PharmaciesCatalog.enrichBundle(bundle);
  final optionalOn = <String>{};

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> send() async {
              final msg = PharmacyOrderMessage.buildFromBundle(
                pharmacyName: pharmacy.name,
                bundle: b,
                optionalIncluded: optionalOn.toList(),
              );
              final ok = await PharmacyOrderMessage.openWhatsApp(
                whatsapp: pharmacy.whatsapp.isNotEmpty
                    ? pharmacy.whatsapp
                    : pharmacy.phone,
                message: msg,
              );
              if (!ctx.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('تعذر فتح واتساب')),
                );
              } else {
                Navigator.pop(ctx);
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD0D8DA),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PharmacyFitImage(
                            source: b.imageUrl,
                            width: 88,
                            height: 88,
                            borderRadius: 14,
                            fallback: Icons.medication_liquid_rounded,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: GhadeerHomeColors.secondary,
                                  ),
                                ),
                                if (b.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    b.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: GhadeerHomeColors.muted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                if (b.note.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    b.note,
                                    style: const TextStyle(
                                      fontSize: 12.5,
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
                      const SizedBox(height: 14),
                      const Text(
                        'المكملات',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      if (b.supplements.isEmpty)
                        const Text(
                          'لا توجد مكملات مسجّلة لهذه الباقة',
                          style: TextStyle(
                            color: GhadeerHomeColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        for (final s in b.supplements)
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
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
                            value: optionalOn.contains(s),
                            onChanged: (v) {
                              setLocal(() {
                                if (v == true) {
                                  optionalOn.add(s);
                                } else {
                                  optionalOn.remove(s);
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
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: send,
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text(
                          'أرسل تفاصيل الباقة عبر واتساب',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'الرسالة تتضمن اسم الباقة والمكملات وتصل للصيدلية من منصة الغدير.',
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
              ),
            );
          },
        ),
      );
    },
  );
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
