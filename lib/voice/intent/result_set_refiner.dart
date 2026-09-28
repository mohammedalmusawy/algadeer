import '../../doctors/doctor_gender.dart';
import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';

/// قيود تصفية على نتائج الجلسة الحالية (ليست بحثاً جديداً).
class ResultSetConstraint {
  const ResultSetConstraint({
    this.requiresWhatsApp = false,
    this.requiresPhone = false,
    this.gender,
  });

  final bool requiresWhatsApp;
  final bool requiresPhone;

  /// [DoctorGender.female] / [DoctorGender.male] أو null.
  final String? gender;

  bool get isEmpty =>
      !requiresWhatsApp && !requiresPhone && (gender == null || gender!.isEmpty);

  bool get isNotEmpty => !isEmpty;
}

/// تصفية قائمة نتائج موجودة — بدون استعلام منصة جديد.
///
/// أمثلة عراقية: «اللي عنده واتساب»، «اللي بيه رقم»، «طبيبة فقط».
class ResultSetRefiner {
  ResultSetRefiner._();

  /// يحاول استخراج قيد تصفية من الاستعلام.
  ///
  /// يعيد null إن لم يكن الطلب تصفية واضحة (كي لا يخطف بحثاً جديداً).
  static ResultSetConstraint? parse(String query) {
    final n = ArabicTextUtils.normalize(query).trim();
    if (n.isEmpty) return null;

    // بحث جديد صريح بفعل طلب + كيان → ليس تصفية قائمة.
    if (_looksLikeFreshSearch(n)) return null;

    var requiresWhatsApp = false;
    var requiresPhone = false;
    String? gender;

    if (_whatsAppFilter.hasMatch(n)) {
      requiresWhatsApp = true;
    }
    if (_phoneFilter.hasMatch(n)) {
      requiresPhone = true;
    }
    if (_femaleOnly.hasMatch(n)) {
      gender = DoctorGender.female;
    } else if (_maleOnly.hasMatch(n)) {
      gender = DoctorGender.male;
    }

    final c = ResultSetConstraint(
      requiresWhatsApp: requiresWhatsApp,
      requiresPhone: requiresPhone,
      gender: gender,
    );
    return c.isEmpty ? null : c;
  }

  static List<SmartSearchResult> apply(
    List<SmartSearchResult> items,
    ResultSetConstraint constraint,
  ) {
    if (constraint.isEmpty || items.isEmpty) return items;
    return [
      for (final r in items)
        if (_matches(r, constraint)) r,
    ];
  }

  static bool _matches(SmartSearchResult r, ResultSetConstraint c) {
    if (c.requiresWhatsApp) {
      // تصفية «واتساب» = رقم واتساب صريح في بيانات المنصة، لا إسقاط من الهاتف.
      if ((r.whatsapp ?? '').trim().isEmpty) return false;
    }
    if (c.requiresPhone && !r.canCall) return false;
    if (c.gender != null && c.gender!.isNotEmpty) {
      // جنس فقط على الأطباء؛ كيانات بلا جنس تُستبعد عند طلب جنس.
      if (r.type != SmartSearchResultType.doctor) return false;
      if (DoctorGender.normalize(r.gender) != c.gender) return false;
    }
    return true;
  }

  /// جملة قصيرة للمستخدم من نتيجة التصفية الحقيقية فقط.
  static String messageFor({
    required ResultSetConstraint constraint,
    required int beforeCount,
    required int afterCount,
  }) {
    final label = _constraintLabelAr(constraint);
    if (afterCount == 0) {
      return 'من النتائج الحالية ($beforeCount) ما لكيت أحد يطابق: $label.';
    }
    if (afterCount == 1) {
      return 'من النتائج الحالية لقيت واحد يطابق: $label. تگدر تقول اتصل أو واتساب أو افتح.';
    }
    return 'من النتائج الحالية لقيت $afterCount يطابقون: $label. تگدر تقول الأول / الثاني.';
  }

  static String _constraintLabelAr(ResultSetConstraint c) {
    final parts = <String>[];
    if (c.requiresWhatsApp) parts.add('واتساب');
    if (c.requiresPhone) parts.add('اتصال');
    if (c.gender == DoctorGender.female) parts.add('طبيبة');
    if (c.gender == DoctorGender.male) parts.add('طبيب');
    return parts.isEmpty ? 'الشرط' : parts.join(' و');
  }

  static bool _looksLikeFreshSearch(String n) {
    return RegExp(
          r'(?:أريد|اريد|ابي|ابحث|دور|طل[عّ]|وريني|ورّيني).{0,20}'
          r'(?:طبيب|دكتور|مختبر|صيدلي|اشعه|اشعة|أشعة|باق|اختصاص)',
        ).hasMatch(n) ||
        RegExp(
          r'(?:مختبرات|صيدليات|مراكز\s*اشعه)',
        ).hasMatch(n);
  }

  /// واتساب كتصفية قائمة — ليس «دزله/ارسل واتساب» على كيان محدد.
  static final RegExp _whatsAppFilter = RegExp(
    r'(?:^|\s)(?:اللي\s+)?(?:عنده|عدها|عده|بيه|بيها|عندهم|عدهم|عندهن|عدهن)\s+'
    r'(?:واتساب|وتساب|واتس(?:\s*اب)?)(?:$|\s|[؟?!.,،])',
  );

  static final RegExp _phoneFilter = RegExp(
    r'(?:^|\s)(?:اللي\s+)?(?:عنده|عدها|عده|بيه|بيها|عندهم|عدهم)\s+'
    r'(?:اتصال|رقم|تلفون|تليفون|هاتف)(?:$|\s|[؟?!.,،])',
  );

  /// تصفية جنس قصيرة فقط — بعد normalize: ة→ه.
  static final RegExp _femaleOnly = RegExp(
    r'^(?:اللي\s+)?'
    r'(?:طبيبه|دكتوره|انثي|انثى)'
    r'(?:\s+فقط)?$'
    r'|'
    r'^(?:بس\s+)?(?:الطبيبات|الدكتورات)$'
    r'|'
    r'^(?:اللي\s+)?(?:انثي|انثى)$',
  );

  static final RegExp _maleOnly = RegExp(
    r'^(?:اللي\s+)?ذكر(?:\s+فقط)?$'
    r'|'
    r'^(?:طبيب|دكتور)\s+(?:فقط|بس)$'
    r'|'
    r'^(?:بس\s+)?(?:الاطباء|الأطباء|الدكاتره|الدكاترة)$',
  );
}
