import '../../search/arabic_text_utils.dart';
import '../../search/analysis_name_matcher.dart';
import 'extracted_entities.dart';

/// تجريد استخراج الكيانات — Step 4 يوسّع الأطباء/الاختصاص/الترتيب/تلميح الإجراء فقط.
abstract class EntityExtractor {
  ExtractedEntities extract(String originalText, String normalizedText);
}

/// مستخرج قاعدي آمن — بدون أسماء أطباء ثابتة وبدون مختبرات/باقات.
class RuleBasedEntityExtractor implements EntityExtractor {
  const RuleBasedEntityExtractor();

  static final _indexWords = <String, int>{
    'الاول': 1,
    'الأول': 1,
    'اول': 1,
    'أول': 1,
    'الاولى': 1,
    'الأولى': 1,
    'الاولي': 1,
    'اولي': 1,
    'أولى': 1,
    'الثاني': 2,
    'ثاني': 2,
    'الثانيه': 2,
    'الثانية': 2,
    'ثانيه': 2,
    'ثانية': 2,
    'الثالث': 3,
    'ثالث': 3,
    'الثالثه': 3,
    'الثالثة': 3,
    'الرابع': 4,
    'رابع': 4,
    'الرابعه': 4,
    'الرابعة': 4,
    'الخامس': 5,
    'خامس': 5,
    'الخامسه': 5,
    'الخامسة': 5,
    'الاخير': -1,
    'الأخير': -1,
    'الاخيره': -1,
    'الأخيرة': -1,
  };

  @override
  ExtractedEntities extract(String originalText, String normalizedText) {
    final tokens = normalizedText
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    int? index;
    for (final t in tokens) {
      for (final candidate in _ordinalTokenCandidates(t)) {
        final hit = _indexWords[candidate];
        if (hit != null) {
          index = hit;
          break;
        }
      }
      if (index != null) break;
    }
    if (index == null &&
        RegExp(r'(?:اخر|آخر)\s*واحد').hasMatch(normalizedText)) {
      index = -1;
    }
    if (index == null) {
      final numbered =
          RegExp(r'(?:^|\s)رقم\s*([123١٢٣])(?:\s|$)').firstMatch(normalizedText);
      if (numbered != null) {
        index = switch (numbered.group(1)) {
          '1' || '١' => 1,
          '2' || '٢' => 2,
          '3' || '٣' => 3,
          _ => null,
        };
      }
    }

    String? specialty;
    const specialtyHints = <String>[
      'اطفال',
      'اسنان',
      'نساء',
      'جلدية',
      'عظام',
      'قلبية',
      'باطنية',
      'جراحة',
      'عيون',
      'انف',
      'اذن',
      'اعصاب',
      'جملة',
    ];
    for (final hint in specialtyHints) {
      if (normalizedText.contains(hint)) {
        specialty = hint;
        break;
      }
    }

    final actionHint = _detectActionHint(normalizedText);
    final analysisTerms = _extractAnalysisTerms(originalText, normalizedText);
    final analysis = analysisTerms.length == 1
        ? analysisTerms.first
        : (analysisTerms.isEmpty
            ? _extractAnalysisNameCandidate(originalText, normalizedText)
            : analysisTerms.first);
    final packageName = _extractPackageNameCandidate(
      originalText,
      normalizedText,
    );
    final laboratory = (analysis != null ||
            analysisTerms.isNotEmpty ||
            packageName != null)
        ? null
        : _extractLaboratoryNameCandidate(
            originalText,
            normalizedText,
          );
    final doctorName =
        (laboratory != null || analysis != null || packageName != null)
            ? null
            : _extractDoctorNameCandidate(
                originalText,
                normalizedText,
                actionHint: actionHint,
              );

    return ExtractedEntities(
      doctorName: doctorName,
      specialty: specialty,
      laboratory: laboratory,
      packageName: packageName,
      analysis: analysis,
      analysisTerms: analysisTerms,
      resultIndex: index,
      actionHint: actionHint,
      rawTokens: tokens,
    );
  }

  /// يستخرج اسم باقة نظيف: «باقة الفحص الشامل» → «الفحص الشامل».
  static String? _extractPackageNameCandidate(
    String original,
    String normalized,
  ) {
    final hasPackageCue = RegExp(
      r'(?:ال)?(?:باقه|باقة)|(?:سعر\s+(?:ال)?(?:باقه|باقة))',
    ).hasMatch(normalized);
    if (!hasPackageCue) return null;

    // مرجع سياقي / عودة — ليست اسم باقة للبحث.
    if (RegExp(
      r'^(?:هذا|هاي|هذ|نفس)\s*(?:ال)?(?:باقه|باقة)\s*$|(?:ارجع|رجع).{0,12}(?:ال)?باق',
    ).hasMatch(normalized.trim())) {
      return null;
    }

    // قائمة عامة بدون اسم: «أريد باقات» / «شنو الباقات»
    if (RegExp(
      r'(?:ال)?(?:باقات|باقاته)\s*$|^(?:أريد|اريد|ابي|عرض|شنو|اكو|أكو).{0,12}(?:ال)?باقات',
    ).hasMatch(normalized.trim()) &&
        !RegExp(r'(?:ال)?(?:باقه|باقة)\s+\S+').hasMatch(normalized)) {
      return null;
    }

    var s = original.trim();
    s = s.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:ابحث(?:لي)?|دور(?:لي)?|عرض(?:لي)?|وريني|افتح|اعرض)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:شكد|بكم|سعر|اسعار|أسعار)\s*(?:ال)?',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:شنو\s+)?(?:تحاليل|التحاليل)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:وين|اين|أين)\s*(?:موجوده|موجودة|موجود)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:باي|بأي)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(r'^(?:ال)?(?:باقه|باقة)\s*', caseSensitive: false),
      '',
    );
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:بيها|بيه|فيها|سعرها|تحاليلها|موجوده|موجودة|موجود)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[؟?!.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (s.isEmpty || s.length <= 1) return null;
    if (RegExp(
      r'^(?:ال)?(?:باقات|باقاته|عروض|عرض|موجود|موجوده|موجودة)$',
    ).hasMatch(ArabicTextUtils.normalize(s))) {
      return null;
    }
    // لا تسرق «باقة بيها CBC» أو أسئلة سياقية كاسم باقة.
    if (RegExp(r'^(?:بيها|بيه|فيها)\b').hasMatch(ArabicTextUtils.normalize(s))) {
      return null;
    }
    return s;
  }

  /// يستخرج تحاليل متعددة صريحة: «بيها CBC وفيتامين D».
  static List<String> _extractAnalysisTerms(
    String original,
    String normalized,
  ) {
    // فقط عندما يطلب المستخدم باقة تحتوي تحاليل مسمّاة.
    if (!RegExp(
      r'(?:باق(?:ه|ة|ات).{0,24}(?:بيها|فيها|تحتوي))|(?:بيها|فيها)\s+\S+',
    ).hasMatch(normalized)) {
      // أيضاً: «CBC وفيتامين D» كزوج صريح بدون جملة كاملة إن وُجدت و.
      if (!RegExp(
        r'[A-Za-z]{2,}.{0,20}(?:و|and|&).{0,20}(?:فيتامين|[A-Za-z]{2,})',
        caseSensitive: false,
      ).hasMatch(original) &&
          !RegExp(
            r'(?:فيتامين|cbc|hba1c).{0,16}(?:و|and).{0,16}(?:فيتامين|cbc|hba1c|[A-Za-z]{2,})',
            caseSensitive: false,
          ).hasMatch(normalized)) {
        return const [];
      }
    }

    var chunk = original.trim();
    final m = RegExp(
      r'(?:بيها|فيها|تحتوي(?:\s+على)?)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (m != null) {
      chunk = m.group(1)!.trim();
    } else {
      // «الباقات اللي بيها» بدون أسماء تحاليل — ليست تقاطعاً متعددًا.
      if (RegExp(
        r'(?:بيها|فيها|تحتوي)\s*$',
      ).hasMatch(ArabicTextUtils.normalize(original.trim()))) {
        return const [];
      }
      // أزل غلاف الباقة إن وُجد.
      chunk = chunk
          .replaceFirst(
            RegExp(
              r'^(?:أريد|اريد|ابي)?\s*(?:ال)?(?:باقه|باقة|باقات)?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }

    chunk = chunk
        .replaceAll(RegExp(r'[؟?!.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (chunk.isEmpty) return const [];

    final parts = chunk
        .split(RegExp(r'\s*(?:و|,|and|&)\s*', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .map((e) {
          var t = e.replaceFirst(
            RegExp(r'^(?:ال)?(?:تحليل|تحاليل)\s*', caseSensitive: false),
            '',
          );
          return t.trim();
        })
        .where((e) => e.isNotEmpty)
        .where(
          (e) => !RegExp(
            r'^(?:باقه|باقة|باقات|بيها|فيها|عنده|موجود)$',
          ).hasMatch(ArabicTextUtils.normalize(e)),
        )
        .toList();

    if (parts.length < 2) {
      // تعبير واحد بعد «بيها X» — ليس تقاطعاً متعددًا هنا.
      if (parts.length == 1 &&
          RegExp(r'(?:بيها|فيها|تحتوي)').hasMatch(normalized)) {
        return [parts.first];
      }
      return const [];
    }
    return parts;
  }

  /// يستخرج تعبير التحليل النظيف (CBC / فيتامين د / …).
  static String? _extractAnalysisNameCandidate(
    String original,
    String normalized,
  ) {
    final hasAnalysisCue = RegExp(
          r'(?:ال)?تحليل(?:ات)?|(?:عندكم|عندك|اكو|أكو)\s+\S+|'
          r'(?:فيتامين|cbc|hba1c|tsh|vit\s*d)',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(r'\b[A-Za-z]{2,12}\b').hasMatch(original) &&
            RegExp(
              r'(?:تحليل|عندكم|عندك|ابحث|أريد|اريد|وين\s+موجود|باقه|باقة)',
            ).hasMatch(normalized);

    // اختصار لاتيني وحيد شائع كاستعلام تحليل.
    final latinOnly = RegExp(
      r'^[A-Za-z][A-Za-z0-9.\s\-]{1,20}$',
    ).hasMatch(original.trim());

    if (!hasAnalysisCue && !latinOnly) return null;

    // لا تسرق جمل كتالوج مختبر بدون اسم تحليل: «شنو التحاليل الموجودة»
    if (RegExp(
      r'^(?:شنو|ما|ماذا)?\s*(?:ال)?تحاليل\s*(?:الموجودة|الموجوده|بهذا|بيها)?\s*$',
    ).hasMatch(normalized.trim())) {
      return null;
    }

    var s = original.trim();
    s = s.replaceFirst(
      RegExp(
        r'^(?:هسه|هسة|الحين|الآن|الان|دحين)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:ابحث(?:لي)?|دور(?:لي)?|عندكم|عندك|اكو|أكو)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:وين|اين|أين)\s*(?:موجود|موجودة)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:بأي|شنو)?\s*(?:ال)?باق(?:ات|ة|ه)?\s*(?:اللي\s+)?(?:بيها|فيها|تحتوي)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(r'^(?:أي\s+)?(?:ال)?مختبر(?:ات)?\s*(?:عنده|فيها)?\s*', caseSensitive: false),
      '',
    );
    s = s.replaceFirst(
      RegExp(r'^(?:ال)?تحليل(?:ات)?\s*', caseSensitive: false),
      '',
    );
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:بيه|به|بيها|بها|هذا|هاي|هذي|هذه|هذاك|ذاك|موجود|موجودة|باقاته|باقات|مختبر|ضمن)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[؟?!.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (s.isEmpty) return null;
    final prepared = AnalysisNameMatcher().prepareQuery(s);
    if (prepared.isEmpty || prepared.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|هذا|هاي|هذي|هذه|هذاك|ذاك|الاول|الثاني|الموجوده|الموجودة|باقه|باقة)$',
    ).hasMatch(ArabicTextUtils.normalize(prepared))) {
      return null;
    }
    return s.trim();
  }

  /// يستخرج اسم المختبر النظيف — بدون كلمة «مختبر» وأفعال الإجراء.
  static String? _extractLaboratoryNameCandidate(
    String original,
    String normalized,
  ) {
    final hasLabWord = RegExp(r'(?:ال)?مختبر(?:ات)?').hasMatch(normalized);
    // لا تفعّل على «تحليل CBC» أو قائمة باقات عامة — فقط مختبر صريح أو باقات مختبر محدد.
    if (!hasLabWord &&
        !RegExp(
          r'(?:باقاته)|(?:تحاليل\s+(?:هذا|الموجودة|بهذا|بيها))',
        ).hasMatch(normalized)) {
      return null;
    }

    var s = original.trim();
    s = s.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        // «دك/دق» كلمة كاملة فقط — لا تقطع بادئة «دكتور».
        r'^(?:اتصل|اتصال|كلّم|كلم|(?:دق|دك)(?=\s|$)|راسل|أرسل|ارسل|دزله|دزّله|دزوله|دز\s+|افتح|اعرض|ابحث(?:لي)?|دور(?:لي)?|عرض(?:لي)?|وريني)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:رسالة\s+)?(?:واتساب|واتس\s*اب|واتس|whatsapp)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:ب|على|ل|في|مع|عن|إلى|الى)?\s*(?:رسالة\s*)?(?:واتساب|واتس\s*اب|واتس|whatsapp)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:وين|اين|أين)\s*(?:موقع|موقعه|مكان|مكانه|عنوان|عنوانه)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:شنو|ما|ماذا)?\s*(?:عنده\s+)?(?:باقاته|الباقات|باقات|تحاليله|التحاليل|تحاليل)\s*(?:الموجودة|الموجوده|موجودة|موجوده)?\s*(?:بيها|بهذا|في\s*هذا\s*المختبر|بهذا\s*المختبر)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(RegExp(r'^ل(?=مختبر)'), '').trim();
    s = s.replaceFirst(
      RegExp(r'^(?:ب)?(?:ال)?مختبر(?:ات)?\s*', caseSensitive: false),
      '',
    );
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|موقعه|مكانه|عنوانه|باقاته|تحاليله|دزله|دزّله|راسله|راسلها)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)[لب]?(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:مختبر|مختبرات)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (s.isEmpty) return null;
    final norm = ArabicTextUtils.normalize(s);
    if (norm.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|الثالث|الرابع|الخامس)$',
    ).hasMatch(norm)) {
      return null;
    }
    if (RegExp(r'^(?:ال)?(?:مختبر|مختبرات)$').hasMatch(norm)) return null;
    // بقايا جمل سياقية — ليست اسم مختبر.
    if (RegExp(
      r'^(?:الموجوده|الموجودة|موجوده|موجودة|بهذا|هذه|بيها|فيه|فيها|عنده|عندها)$',
    ).hasMatch(norm)) {
      return null;
    }
    return norm;
  }

  /// مرشّحات ترتيب من توكن قد يحمل حرف جر ملتصق: للثاني / بالاول.
  static Iterable<String> _ordinalTokenCandidates(String token) sync* {
    yield token;
    var s = token;
    if (s.startsWith('ل') || s.startsWith('ب')) {
      s = s.substring(1);
      yield s;
    }
    if (s.startsWith('ل') || s.startsWith('ب')) {
      s = s.substring(1);
      yield s;
    }
    if (s.startsWith('ال') && s.length > 2) {
      yield s.substring(2);
    } else if (s.isNotEmpty) {
      yield 'ال$s';
    }
  }

  static String? _detectActionHint(String n) {
    if (RegExp(
      r'(?:واتساب|واتس|whatsapp|دزله|دزّله|دزوله|راسل)',
    ).hasMatch(n)) {
      return 'whatsapp';
    }
    if (RegExp(r'(?:اتصل|اتصال|دق\b|دك\b|كلمه|كلّم)').hasMatch(n)) {
      return 'call';
    }
    if (RegExp(
      r'(?:شكد|بكم|سعرها|سعره|السعر|اسعار|أسعار)',
    ).hasMatch(n)) {
      return 'package_price';
    }
    if (RegExp(
      r'(?:ارخص|أرخص|اقل\s+سعر|أقل\s+سعر)',
    ).hasMatch(n)) {
      return 'cheapest';
    }
    if (RegExp(
      r'(?:عروض|عرض|تخفيض|مخفضه|مخفضة|خصم)',
    ).hasMatch(n) &&
        !RegExp(r'(?:عرض(?:لي)?\s*(?:ال)?باق)').hasMatch(n)) {
      return 'offers';
    }
    if (RegExp(
      r'(?:قارن|مقارن|الفرق\s+بين)',
    ).hasMatch(n)) {
      return 'compare_packages';
    }
    if (RegExp(
      r'(?:افضل|أفضل)\s+(?:باقه|باقة)',
    ).hasMatch(n)) {
      return 'best_unsupported';
    }
    if (RegExp(
      r'(?:وين|اين|أين).{0,24}(?:عياد|مكان|موقع|عنوان)|(?:عيادته|مكانه|موقعه|عنوانه)|(?:وين\s+(?:ال)?مختبر)|(?:وين\s+موجود)',
    ).hasMatch(n)) {
      return 'location';
    }
    if (RegExp(
      r'(?:تحاليلها|تحاليله)|(?:شنو\s+(?:ال)?تحاليل\s*(?:بيها|فيها|الباقه|الباقة)?)',
    ).hasMatch(n)) {
      return 'package_analyses';
    }
    if (RegExp(
      r'(?:اي\s+مختبر)|(?:أي\s+مختبر)|(?:المختبر\s+(?:حقها|تاعها|مالها))',
    ).hasMatch(n)) {
      return 'package_lab';
    }
    if (RegExp(
      r'(?:باقات|باقاته|الباقات)|(?:عرض(?:لي)?\s*باق)|(?:باي\s+باق)|(?:بأي\s+باق)',
    ).hasMatch(n)) {
      return 'packages';
    }
    if (RegExp(
      r'(?:تحاليل|التحاليل|تحاليله|تحليل)|(?:شنو\s+التحاليل)',
    ).hasMatch(n)) {
      return 'analyses';
    }
    if (RegExp(
      r'(?:افتح|اعرض).{0,24}(?:ملف|نبذه|نبذة|بطاقه|بطاقة|مختبر)|(?:ملفه|نبذته)|(?:افتح|اعرض)\s+(?:ال)?(?:دكتور|طبيب|مختبر)|(?:نبذة|معلومات)\s*(?:ال)?مختبر',
    ).hasMatch(n)) {
      return 'profile';
    }
    if (RegExp(
      r'(?:اختار|افتح|اريد|أريد).{0,8}(?:الاول|الأول|الثاني|الثالث|الاخير|الأخير)',
    ).hasMatch(n) ||
        _indexWords.keys.any((k) => RegExp('(?:^|\\s)$k(?:\\s|\$)').hasMatch(n))) {
      return 'select';
    }
    return null;
  }

  /// مرشّح اسم طبيب من الاستعلام — ليس مطابقة DB.
  static String? _extractDoctorNameCandidate(
    String original,
    String normalized, {
    String? actionHint,
  }) {
    var s = original.trim();
    if (s.isEmpty) return null;

    // انزع أفعال الإجراء والمفردات المحيطة ثم الألقاب.
    s = s.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        // «دك/دق» كلمة كاملة فقط — لا تقطع بادئة «دكتور».
        r'^(?:اتصل|اتصال|كلّم|كلم|(?:دق|دك)(?=\s|$)|راسل|أرسل|ارسل|دزله|دزّله|دزوله|دز\s+|افتح|اعرض|ابحث(?:لي)?|دور(?:لي)?)\s*',
        caseSensitive: false,
      ),
      '',
    );
    // «رسالة واتساب» / «واتساب» قبل الهدف.
    s = s.replaceFirst(
      RegExp(
        r'^(?:رسالة\s+)?(?:واتساب|واتس\s*اب|واتس|whatsapp)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:ب|على|ل|في|مع|عن|إلى|الى)?\s*(?:رسالة\s*)?(?:واتساب|واتس\s*اب|واتس|whatsapp)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    // بقايا «ل» من «للدكتور».
    s = s.replaceFirst(RegExp(r'^ل(?=دكتور|طبيب|دكتورة|طبيبة)'), '').trim();
    s = s.replaceFirst(
      RegExp(
        r'^(?:وين|اين|أين)\s*(?:عيادة|عيادته|مكان|مكانه|موقع|موقعه|عنوان|عنوانه)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    // انزع ملفه/نبذته كاملة قبل بادئة «ملف» حتى لا يبقى حرف «ه».
    s = s.replaceFirst(
      RegExp(
        r'^(?:ملفه|نبذته|عيادته|مكانه|موقعه|عنوانه)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:ملف|نبذة|بطاقة)\s*(?:ال)?(?:دكتور|طبيب)?\s*',
        caseSensitive: false,
      ),
      '',
    );

    s = ArabicTextUtils.stripHonorifics(s).trim();
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:بيه|به|بيها|بها|وياه|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|ملفه|نبذته|عيادته|مكانه|موقعه|عنوانه|دزله|دزّله|راسله|راسلها)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)[لب]?(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (s.isEmpty) return null;
    // إشارات سياقية / ألقاب مهنية فقط / ترتيب / بقايا أفعال — ليست اسماً.
    final norm = ArabicTextUtils.normalize(s);
    const refs = {
      'بيه',
      'به',
      'بيها',
      'بها',
      'يه',
      'وياه',
      'هذا',
      'هاي',
      'هذي',
      'هذه',
      'هذاك',
      'ذاك',
      'مالته',
      'مالتها',
      'بيهم',
      'عليهم',
      'الثاني',
      'الاول',
      'الأول',
      'الثالث',
      'الرابع',
      'الخامس',
      'الاخير',
      'الأخير',
      'دزله',
      'راسله',
      'ه',
      'دكتور',
      'دكتوره',
      'دكتورة',
      'طبيب',
      'طبيبه',
      'طبيبة',
      'الدكتور',
      'الدكتوره',
      'الدكتورة',
      'الطبيب',
      'الطبيبه',
      'الطبيبة',
    };
    if (refs.contains(norm) || norm.length <= 1) return null;
    if (RegExp(r'^(?:ال)?(?:دكتور|دكتوره|دكتورة|طبيب|طبيبه|طبيبة)$')
        .hasMatch(norm)) {
      return null;
    }
    if (RegExp(
      r'^(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?$',
    ).hasMatch(norm)) {
      return null;
    }

    final prepared = ArabicTextUtils.prepareDoctorNameQuery(s);
    if (prepared.isEmpty || prepared.trim().length <= 1) return null;
    final preparedNorm = ArabicTextUtils.normalize(prepared);
    if (RegExp(r'^(?:ال)?(?:دكتور|دكتوره|دكتورة|طبيب|طبيبه|طبيبة)$')
        .hasMatch(preparedNorm)) {
      return null;
    }
    return prepared;
  }
}
