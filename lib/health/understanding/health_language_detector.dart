import 'health_language_normalizer.dart';

/// كاشف محافظ لوجود لغة صحية/أعراض — لا يبدأ تدفقاً صحياً.
class HealthLanguageDetector {
  HealthLanguageDetector({
    HealthLanguageNormalizer? normalizer,
  }) : _normalizer = normalizer ?? const HealthLanguageNormalizer();

  final HealthLanguageNormalizer _normalizer;

  /// true فقط عند أدلة أعراض/ألم واضحة، وليس أوامر تطبيق.
  bool containsHealthLanguage(
    String raw, {
    bool Function(String normalized)? hasStructuredSymptoms,
  }) {
    final n = _normalizer.normalize(raw);
    if (n.isEmpty) return false;
    if (isAppCommand(n)) return false;

    if (hasStructuredSymptoms != null && hasStructuredSymptoms(n)) {
      return true;
    }

    return RegExp(
      r'(?:صداع|دوخه|دوخة|سعال|كحه|كحة|حراره|حرارة|غثيان|لوعه|لوعة|'
      r'استفراغ|ضيق\s*نفس|يوجعني|يعورني|وجع|الم\s*ب|ألم\s*ب|'
      r'خدر|تنميل|كتمه|كتمة|مغص|تعبان|اعراض|أعراض|'
      // شكاوى جسدية غامضة محافظة — بدون تشخيص
      r'بجسمي|في\s*جسمي|شي\s*غريب|ما\s*اعرف\s*(?:اوصف|أوصف)|ما\s*أعرف\s*(?:اوصف|أوصف))',
    ).hasMatch(n);
  }

  bool isAppCommand(String rawOrNormalized) {
    final n = _normalizer.normalize(rawOrNormalized);
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور).{0,20}(?:مختبر|تحليل|باقه|باقة|طبيب|دكتور|عرض)',
        ).hasMatch(n) ||
        RegExp(
          r'(?:اتصل|دز|دزله|واتساب|افتح).{0,24}(?:دكتور|طبيب|مختبر)',
        ).hasMatch(n) ||
        RegExp(r'(?:أريد|اريد)\s+تحليل\s+\S+').hasMatch(n);
  }
}
