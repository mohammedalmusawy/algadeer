import '../models/lab_models.dart';

/// رسالة واتساب لطلب باقة مختبر — من داخل تفاصيل الباقة.
class LabPackageOrderMessage {
  LabPackageOrderMessage._();

  static String build({
    required String labName,
    required LabPackageItem package,
    int maxAnalyses = 40,
  }) {
    final buf = StringBuffer();
    buf.writeln('طلب من منصة الغدير');
    if (labName.trim().isNotEmpty) {
      buf.writeln('المختبر: ${labName.trim()}');
    }
    buf.writeln('الباقة: ${package.name.trim()}');

    final desc = package.description.trim();
    if (desc.isNotEmpty) {
      buf.writeln('الوصف: $desc');
    }

    final price = package.newPrice;
    if (price != null && price > 0) {
      buf.writeln('السعر: ${_fmt(price)} د.ع');
      if (package.hasOldPrice &&
          package.oldPrice != null &&
          package.oldPrice! > price) {
        buf.writeln('قبل الخصم: ${_fmt(package.oldPrice!)} د.ع');
      }
      final discount = package.discountPercent;
      if (discount != null && discount > 0) {
        buf.writeln('الخصم: $discount%');
      }
    }

    final names = <String>[];
    for (final a in package.analyses) {
      final n = a.arabicDisplayName.trim().isNotEmpty
          ? a.arabicDisplayName.trim()
          : a.name.trim();
      if (n.isNotEmpty) names.add(n);
    }
    if (names.isEmpty) {
      for (final n in package.testNames) {
        if (n.trim().isNotEmpty) names.add(n.trim());
      }
    }

    if (names.isNotEmpty) {
      buf.writeln('التحاليل المشمولة (${names.length}):');
      for (final n in names.take(maxAnalyses)) {
        buf.writeln('- $n');
      }
      if (names.length > maxAnalyses) {
        buf.writeln('- … والمزيد');
      }
    } else if (package.analysesCount > 0) {
      buf.writeln('عدد التحاليل: ${package.analysesCount}');
    }

    buf.writeln();
    buf.writeln('يُرجى التواصل لتأكيد التوفر والموعد.');
    return buf.toString().trim();
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
