import '../../search/arabic_text_utils.dart';

/// سياسة سلامة للمتابعة المزمنة — لا تنافس 10E.
class ChronicCareSafetyPolicy {
  const ChronicCareSafetyPolicy();

  /// هل يجب الخروج من المتابعة الروتينية لصالح السلامة؟
  bool shouldYieldToUrgentSafety(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف|الم\s*صدر|ألم\s*صدر|'
      r'اغماء|إغماء|تشنج|حاله\s*طارئه|حالة\s*طارئة)',
    ).hasMatch(n);
  }

  bool looksLikeMedicationChangeRequest(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return RegExp(
      r'(?:غير\s*الجرعه|غير\s*الجرعة|ضاعف|وقف\s*الدوا|وقف\s*العلاج)',
    ).hasMatch(n);
  }
}
