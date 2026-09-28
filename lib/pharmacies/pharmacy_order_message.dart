import 'package:url_launcher/url_launcher.dart';

import 'pharmacy_models.dart';

/// رسائل واتساب طلب الباقات — من منصة الغدير.
class PharmacyOrderMessage {
  PharmacyOrderMessage._();

  static String build({
    required String pharmacyName,
    required String packageName,
    required List<String> supplements,
    List<String> optionalIncluded = const [],
    String subtitle = '',
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
    if (subtitle.trim().isNotEmpty) {
      buf.writeln('الوصف: ${subtitle.trim()}');
    }
    if (note.trim().isNotEmpty) {
      buf.writeln('ملاحظة: ${note.trim()}');
    }
    if (price > 0) {
      buf.writeln('السعر: ${_fmt(price)} د.ع');
      if (oldPrice > price) {
        buf.writeln('قبل الخصم: ${_fmt(oldPrice)} د.ع');
      }
    }
    if (supplements.isNotEmpty) {
      buf.writeln('تفاصيل المكملات:');
      for (final s in supplements) {
        buf.writeln('- $s');
      }
    }
    if (optionalIncluded.isNotEmpty) {
      buf.writeln('اختياري مضاف:');
      for (final s in optionalIncluded) {
        buf.writeln('- $s');
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
    return build(
      pharmacyName: pharmacyName,
      packageName: b.title,
      supplements: b.supplements,
      optionalIncluded: optionalIncluded,
      subtitle: b.subtitle,
      note: b.note,
      price: b.price,
      oldPrice: b.oldPrice,
      isCustom: isCustom,
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

  static Future<bool> openWhatsApp({
    required String whatsapp,
    required String message,
  }) async {
    final digits = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return false;
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
