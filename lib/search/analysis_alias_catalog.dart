/// مصدر أسماء بديلة للتحاليل — قابل للاستبدال لاحقاً بـ Supabase/Admin.
///
/// Step 7: تنفيذ مضمَّن في الكود فقط — بدون جدول aliases جديد.
abstract class AnalysisAliasSource {
  /// يعيد أسماء بديلة معروفة لرمز/اسم أساسي (مطبَّعة للمقارنة).
  List<String> aliasesForCanonical(String canonicalKey);

  /// إن وُجدت مطابقة alias → المفتاح الكانوني (مثل CBC / Vitamin D / HbA1c).
  String? resolveCanonical(String query);
}

/// كتالوج aliases مركزي — بيانات طبية مكافئة فقط، بدون أعراض.
class AnalysisAliasCatalog implements AnalysisAliasSource {
  const AnalysisAliasCatalog();

  /// مفاتيح كانونية → aliases (لاتيني + عربي).
  /// يُدمَج مع aliases المخزّنة في صف التحليل عند المطابقة.
  static const Map<String, List<String>> builtin = {
    'CBC': [
      'CBC',
      'C.B.C',
      'C B C',
      'Complete Blood Count',
      'صورة الدم الكاملة',
      'صورة الدم',
      'تعداد الدم',
      'تعداد دم كامل',
      'فحص الدم الكامل',
      'Hemogram',
    ],
    'Vitamin D': [
      'Vitamin D',
      'Vit D',
      'Vit.D',
      'D3',
      '25-OH Vitamin D',
      '25 OH D',
      'Vitamin D3',
      'فيتامين د',
      'فيتامين دي',
      'فيتامين دال',
    ],
    'HbA1c': [
      'HbA1c',
      'HBA1C',
      'Hb A1c',
      'HbA1C',
      'A1C',
      'A1c',
      'Glycated Hemoglobin',
      'السكر التراكمي',
      'سكر تراكمي',
      'هيموغلوبين سكري',
    ],
  };

  @override
  List<String> aliasesForCanonical(String canonicalKey) {
    final key = canonicalKey.trim();
    if (key.isEmpty) return const [];
    for (final e in builtin.entries) {
      if (_eqKey(e.key, key)) return List<String>.unmodifiable(e.value);
    }
    return const [];
  }

  @override
  String? resolveCanonical(String query) {
    final n = AnalysisTextNormalizer.normalizeForMatch(query);
    if (n.isEmpty) return null;
    for (final e in builtin.entries) {
      for (final alias in e.value) {
        if (AnalysisTextNormalizer.normalizeForMatch(alias) == n) {
          return e.key;
        }
      }
      if (AnalysisTextNormalizer.normalizeForMatch(e.key) == n) {
        return e.key;
      }
    }
    return null;
  }

  static bool _eqKey(String a, String b) =>
      AnalysisTextNormalizer.normalizeForMatch(a) ==
      AnalysisTextNormalizer.normalizeForMatch(b);
}

/// تطبيع خاص بأسماء التحاليل فوق [ArabicTextUtils] — بدون تطبيع عام متعارض.
class AnalysisTextNormalizer {
  AnalysisTextNormalizer._();

  /// للمطابقة: حروف عربية عبر ArabicTextUtils + اختصارات لاتينية بدون نقاط/مسافات.
  static String normalizeForMatch(String raw) {
    // استيراد كسول عبر نفس منطق المشروع — نكرر الحد الأدنى الآمن هنا
    // لتجنب دورة اعتماد؛ يُستدعى ArabicTextUtils من المطابق.
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return '';

    // إزالة تشكيل وعلامات شائعة في الاختصارات الطبية.
    s = s
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[.,،؛;:!؟?\-_/\\()\[\]{}«»"′′]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // همزات عربية خفيفة
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    // اختصار لاتيني: أزل المسافات بين الحروف/الأرقام إن بدا اختصاراً.
    final latinOnly = RegExp(r'^[a-z0-9\s]+$').hasMatch(s);
    if (latinOnly) {
      final compact = s.replaceAll(RegExp(r'\s+'), '');
      // CBC, HBA1C, VITD — ابقَ مضغوطاً للاختصارات القصيرة.
      if (compact.length <= 12) return compact;
    }

    return s;
  }

  /// يزيل كلمة «تحليل/تحاليل» من الاستعلام ويترك التعبير النظيف.
  static String stripAnalysisRoleWords(String raw) {
    var s = normalizeForMatch(raw);
    s = s
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:تحليل|تحاليل|فحص)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }
}
