import 'respiratory_models.dart';

/// مرادفات عربية/عراقية للأعراض التنفسية.
class RespiratoryAliasCatalog {
  const RespiratoryAliasCatalog();

  bool looksLikeCough(String n) => RegExp(
        r'(?:سعال|كحه|كحّه|اسعل|اكح|كحيت|يسعل|يكح)',
      ).hasMatch(n);

  /// ضيق النفس بتركيب عراقي/عربي، بما فيه حرف الجر الملتصق.
  /// «ضيق نفس» · «ضيق بنفس» · «ضيق بالتنفس» · «ضيق تنفس».
  bool looksLikeBreathlessness(String n) =>
      _breathlessnessPresent.hasMatch(n);

  /// نفس المصدر لمسار triState حتى لا تتفرّق المرادفات.
  static const List<String> breathlessnessPresentPatterns = [
    r'(?:ضيق\s*(?:ب)?(?:ال)?ت?نفس|'
        r'نفسي\s*ضايق|'
        r'ما\s*اكدر\s*(?:اخذ\s*)?نفسي|'
        r'ما\s*اكدر\s*اتنفس|'
        r'اتنفس\s*بصعوبه|'
        r'اختناق)',
  ];

  static final RegExp _breathlessnessPresent =
      RegExp(breathlessnessPresentPatterns.first);

  RespiratoryCoughType? coughTypeFromNormalized(String n) {
    if (RegExp(r'(?:ناشف|جاف|كحه\s*ناشفه|سعال\s*ناشف|سعال\s*جاف)')
        .hasMatch(n)) {
      return RespiratoryCoughType.dry;
    }
    if (RegExp(r'(?:بلغم|مخاط|سعال\s*رطب|كحه\s*ببلغم|وياه\s*بلغم)')
        .hasMatch(n)) {
      return RespiratoryCoughType.productive;
    }
    return null;
  }

  RespiratoryDurationBucket? durationBucketFromNormalized(String n) {
    // تصحيح صريح: «مو شهرين… أسبوعين» → أسابيع
    if (RegExp(r'(?:مو\s*شهرين|لا\s*مو\s*شهرين).{0,40}(?:اسبوعين|أسبوعين)')
        .hasMatch(n)) {
      return RespiratoryDurationBucket.weeks;
    }
    if (RegExp(r'(?:ساعه|ساعات|من\s*شوي)').hasMatch(n)) {
      return RespiratoryDurationBucket.hours;
    }
    if (RegExp(r'(?:اسبوعين|أسبوعين|اسبوع|أسابيع)').hasMatch(n)) {
      return RespiratoryDurationBucket.weeks;
    }
    if (RegExp(r'(?:شهرين|شهر|اشهر|أشهر)').hasMatch(n)) {
      return RespiratoryDurationBucket.months;
    }
    if (RegExp(r'(?:يومين|ايام|أيام|من\s*يوم)').hasMatch(n)) {
      return RespiratoryDurationBucket.days;
    }
    // مدة مبهمة — لا نخترع قيمة
    if (RegExp(r'(?:صارله\s*فتره|من\s*فتره|من\s*زمان)').hasMatch(n)) {
      return null;
    }
    return null;
  }

  bool vagueDurationOnly(String n) =>
      RegExp(r'(?:صارله\s*فتره|من\s*فتره)').hasMatch(n) &&
      durationBucketFromNormalized(n) == null;

  RespiratoryTriState? triState({
    required String n,
    required List<String> presentPatterns,
    required List<String> absentPatterns,
  }) {
    for (final p in absentPatterns) {
      if (RegExp(p).hasMatch(n)) return RespiratoryTriState.absent;
    }
    for (final p in presentPatterns) {
      if (RegExp(p).hasMatch(n)) return RespiratoryTriState.present;
    }
    return null;
  }

  RespiratoryFunctionalImpact? functionalFromNormalized(String n) {
    if (RegExp(r'(?:ما\s*اكدر\s*اتكلم|صعوبه\s*الكلام\s*من\s*الضيق)')
        .hasMatch(n)) {
      return RespiratoryFunctionalImpact.difficultySpeakingDueToBreathlessness;
    }
    if (RegExp(r'(?:ما\s*اكدر\s*اشتغل|ما\s*اكدر\s*امارس|عاجز\s*عن\s*النشاط)')
        .hasMatch(n)) {
      return RespiratoryFunctionalImpact.unableNormalActivity;
    }
    if (RegExp(r'(?:ضيق\s*عند\s*المشي|ضيق\s*مع\s*الجهد|مع\s*الحركه)')
        .hasMatch(n)) {
      return RespiratoryFunctionalImpact.breathlessOnExertion;
    }
    if (RegExp(r'(?:يأثر\s*على\s*النوم|ما\s*انام\s*من\s*السعال)').hasMatch(n)) {
      return RespiratoryFunctionalImpact.difficultySleeping;
    }
    if (RegExp(r'(?:يحدد\s*نشاطي|يقلل\s*نشاطي)').hasMatch(n)) {
      return RespiratoryFunctionalImpact.reducedActivity;
    }
    return null;
  }

  RespiratorySmokingState? smokingFromNormalized(String n) {
    if (RegExp(r'(?:ما\s*ادخن|ما\s*أدخن|ماكو\s*تدخين|ما\s*ادخنت)')
        .hasMatch(n)) {
      return RespiratorySmokingState.neverReported;
    }
    if (RegExp(r'(?:كنت\s*ادخن|سابقا\s*ادخن|تركت\s*التدخين)').hasMatch(n)) {
      return RespiratorySmokingState.formerSmoking;
    }
    if (RegExp(r'(?:ادخن|أدخن|مدخن|تدخين)').hasMatch(n)) {
      return RespiratorySmokingState.currentSmoking;
    }
    return null;
  }
}
