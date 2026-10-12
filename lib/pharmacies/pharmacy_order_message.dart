import 'package:url_launcher/url_launcher.dart';

import '../utils/contact_launch.dart';
import 'pharmacy_models.dart';

/// رسائل واتساب طلب الباقات — ترتيب مطابق لباقة المختبر.
class PharmacyOrderMessage {
  PharmacyOrderMessage._();

  static String build({
    required String pharmacyName,
    required String packageName,
    required List<String> supplements,
    List<String> optionalIncluded = const [],
    String subtitle = '',
    String description = '',
    String note = '',
    int price = 0,
    int oldPrice = 0,
    bool isCustom = false,
  }) {
    final buf = StringBuffer();
    buf.writeln('طلب من منصة الغدير');
    buf.writeln('الصيدلية: $pharmacyName');
    buf.writeln(
      isCustom ? 'الباقة: $packageName (مخصصة)' : 'الباقة: $packageName',
    );

    final desc = description.trim().isNotEmpty
        ? description.trim()
        : subtitle.trim();
    if (desc.isNotEmpty) {
      buf.writeln('الوصف: $desc');
    }

    // منتجات مشمولة أولاً (بدون تكرار آلي)، ثم السعر، ثم الاستفسار.
    final products = _uniqueLines(supplements);
    if (products.isNotEmpty) {
      buf.writeln('المنتجات المشمولة (${products.length}):');
      for (final s in products) {
        buf.writeln('- $s');
      }
    }
    final optional = _uniqueLines(optionalIncluded)
        .where((s) => !products.map((p) => p.toLowerCase()).contains(s.toLowerCase()))
        .toList();
    if (optional.isNotEmpty) {
      buf.writeln('اختياري مضاف:');
      for (final s in optional) {
        buf.writeln('- $s');
      }
    }

    if (note.trim().isNotEmpty) {
      buf.writeln('ملاحظة: ${note.trim()}');
    }

    if (price > 0) {
      buf.writeln('السعر الحالي: ${_fmt(price)} د.ع');
      if (oldPrice > price) {
        buf.writeln('السعر السابق: ${_fmt(oldPrice)} د.ع');
        final discount =
            (((oldPrice - price) / oldPrice) * 100).round();
        if (discount > 0) {
          buf.writeln('الخصم: $discount%');
        }
      }
    }

    buf.writeln();
    buf.writeln('يُرجى التواصل لتأكيد التوفر والسعر.');
    return buf.toString().trim();
  }

  /// رسالة كاملة من باقة ظاهرة مع تفاصيلها.
  static String buildFromBundle({
    required String pharmacyName,
    required PharmacyBundle bundle,
    List<String> optionalIncluded = const [],
    bool isCustom = false,
  }) {
    final b = PharmaciesCatalog.enrichBundle(bundle);
    final productNames = <String>[];
    final seen = <String>{};
    void addName(String raw) {
      final n = raw.trim();
      if (n.isEmpty) return;
      final key = n.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      productNames.add(n);
    }

    if (b.products.isNotEmpty) {
      for (final p in b.products) {
        if (!p.optional) addName(p.name);
      }
    } else {
      for (final s in b.supplements) {
        addName(s);
      }
    }

    return build(
      pharmacyName: pharmacyName,
      packageName: b.title,
      supplements: productNames,
      optionalIncluded: optionalIncluded,
      subtitle: b.subtitle,
      description: b.description,
      note: b.note,
      price: b.price,
      oldPrice: b.oldPrice,
      isCustom: isCustom,
    );
  }

  static List<String> _uniqueLines(List<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in raw) {
      final n = s.trim();
      if (n.isEmpty) continue;
      final key = n.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(n);
    }
    return out;
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

  static Future<bool> openWhatsApp({
    required String whatsapp,
    required String message,
  }) async {
    final uri = clinicWhatsAppUri(whatsapp, message: message);
    if (uri == null) return false;
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
