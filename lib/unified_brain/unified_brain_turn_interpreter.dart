import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/unified_brain/age_authority_resolver.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_models.dart';

/// تفسير رخيص لدورات الدماغ — مرشّح قبل استدعاء الحزم الثقيلة.
class UnifiedBrainTurnInterpreter {
  UnifiedBrainTurnInterpreter({
    AgeAuthorityResolver? ageResolver,
  }) : _age = ageResolver ?? const AgeAuthorityResolver();

  final AgeAuthorityResolver _age;

  UnifiedBrainTurnContext interpret(
    String query, {
    AgeResolution? ageOverride,
    bool subjectResolved = false,
    bool isAboutOtherPerson = false,
  }) {
    final n = ArabicTextUtils.normalize(query.trim());
    final explicitAge = _age.parseExplicitAgeYears(n);
    final age = ageOverride ??
        _age.resolve(explicitAgeFromUtterance: explicitAge);

    final isGreeting = _isGreeting(n);
    final isCancel = _isCancel(n);
    final isService = _isServiceOrNavigation(n);
    final isFollowUp = _isExplicitFollowUp(n);
    final isEdu = _isEducational(n);
    final hasPregnancy = _hasPregnancy(n);
    final hasAdolescent = _hasAdolescent(n) ||
        (age.isKnown &&
            age.ageYears! >= 10 &&
            age.ageYears! <= 19 &&
            !_isPureClinicalWithoutLife(n));
    final hasDental = _hasDental(n);
    final hasMsk = _hasMsk(n);
    final hasResp = _hasRespiratory(n);
    final hasChronic = _hasChronic(n);
    final hasCorrection = _hasCorrection(n);
    final hasNegation = _hasNegation(n);
    final aboutOther = _isAboutOtherPerson(n);

    final intent = _primaryIntent(
      n: n,
      isGreeting: isGreeting,
      isCancel: isCancel,
      isService: isService,
      isFollowUp: isFollowUp,
      isEdu: isEdu,
      hasPregnancy: hasPregnancy,
      hasAdolescent: hasAdolescent,
      hasDental: hasDental,
      hasMsk: hasMsk,
      hasResp: hasResp,
      hasChronic: hasChronic,
    );

    return UnifiedBrainTurnContext(
      query: query,
      primaryIntent: intent,
      subjectResolved: subjectResolved,
      isAboutOtherPerson: isAboutOtherPerson || aboutOther,
      age: age,
      hasPregnancyCue: hasPregnancy,
      hasAdolescentCue: hasAdolescent,
      hasDentalCue: hasDental,
      hasMskCue: hasMsk,
      hasRespiratoryCue: hasResp,
      hasChronicCue: hasChronic,
      isServiceOrNavigationIntent: isService,
      isGreeting: isGreeting,
      isCancel: isCancel,
      isExplicitFollowUp: isFollowUp,
      isEducational: isEdu,
      hasCorrection: hasCorrection,
      hasNegation: hasNegation,
    );
  }

  BrainPrimaryIntent _primaryIntent({
    required String n,
    required bool isGreeting,
    required bool isCancel,
    required bool isService,
    required bool isFollowUp,
    required bool isEdu,
    required bool hasPregnancy,
    required bool hasAdolescent,
    required bool hasDental,
    required bool hasMsk,
    required bool hasResp,
    required bool hasChronic,
  }) {
    if (isCancel) return BrainPrimaryIntent.cancel;
    if (isGreeting) return BrainPrimaryIntent.greeting;
    if (isFollowUp) return BrainPrimaryIntent.followUpCommand;
    if (isService) {
      if (n.contains('مختبر') || n.contains('تحليل')) {
        return BrainPrimaryIntent.labQuestion;
      }
      if (n.contains('اشع') || n.contains('mri') || n.contains('رنين')) {
        return BrainPrimaryIntent.radiologyQuestion;
      }
      return BrainPrimaryIntent.providerQuestion;
    }
    if (isEdu) return BrainPrimaryIntent.education;
    if (RegExp(r'(اذ|اذي|انتحار|انتحر|اقتل)').hasMatch(n)) {
      return BrainPrimaryIntent.emotionalSupport;
    }
    if (hasDental) return BrainPrimaryIntent.dentalConcern;
    if (hasResp) return BrainPrimaryIntent.currentSymptom;
    if (hasMsk) return BrainPrimaryIntent.currentSymptom;
    if (hasChronic && (n.contains('قراء') || n.contains('ضغط') || n.contains('سكر'))) {
      return BrainPrimaryIntent.currentSymptom;
    }
    if (hasPregnancy && !hasDental && !hasMsk && !hasResp) {
      return BrainPrimaryIntent.pregnancyCare;
    }
    if (hasAdolescent &&
        (n.contains('امتحان') ||
            n.contains('دراس') ||
            n.contains('مدرس') ||
            n.contains('خايف') ||
            n.contains('قلق'))) {
      return BrainPrimaryIntent.adolescentLifeConcern;
    }
    if (n.contains('مشي') || n.contains('رياض') || n.contains('نشاط')) {
      return BrainPrimaryIntent.goal;
    }
    if (n.contains('خطه') || n.contains('يومي') || n.contains('جدول')) {
      return BrainPrimaryIntent.dailyPlanning;
    }
    return BrainPrimaryIntent.unknown;
  }

  bool _isGreeting(String n) =>
      RegExp(r'^(مرحبا|هلا|السلام|اهلا|صباح|مساء)\b').hasMatch(n) ||
      n == 'مرحبا' ||
      n == 'هلا';

  bool _isCancel(String n) =>
      RegExp(r'(خلاص|اترك الموضوع|ما اريد اكمل|وقف|الغ[يى])').hasMatch(n);

  bool _isServiceOrNavigation(String n) {
    if (RegExp(
          r'(وين|اين|موقع|عنوان|باق|باقات|عرض|حجز|تواصل|اتصال|واتساب)',
        ).hasMatch(n) &&
        RegExp(
          r'(مختبر|عياد|دكتور|طبيب|اشع|راديو|غدير|باق)',
        ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'(مختبر قريب|عياده قريب|دكتور قريب)').hasMatch(n)) {
      return true;
    }
    if (RegExp(r'(وين عيادته|شنو باقاته|شنو تحاليله)').hasMatch(n)) {
      return true;
    }
    return false;
  }

  bool _isExplicitFollowUp(String n) =>
      RegExp(r'(ذكرني|تابع وياي|بعد اسبوع|ذكّرني|ذكرني بعد)').hasMatch(n);

  bool _isEducational(String n) =>
      RegExp(r'^(شنو|ما هو|ماهي|ما هي|عرفني)\b').hasMatch(n) ||
      (n.contains('شنو') &&
          RegExp(r'(سكري|حمل|mri|رنين|تسوس|مراهق|مراهقين)').hasMatch(n) &&
          !RegExp(r'(عندي|يوجع|الم)').hasMatch(n));

  bool _hasPregnancy(String n) =>
      RegExp(r'(حامل|حمل|اسابيع? الحمل|ثلث)').hasMatch(n);

  bool _hasAdolescent(String n) =>
      RegExp(r'(مراهق|مراهقه|عمري\s*1[0-9]|عمر\s*1[0-9])').hasMatch(n);

  bool _hasDental(String n) {
    // «عمره 8 سنوات» ليست أسنان. «موضوع سنه» / «15 سنه يوجعه» قد تكون.
    final isAgeYearsUnit = RegExp(
      r'(?:عمر[يهاه]?\s*)?\d{1,2}\s*(?:سنه|سنة|سنوات|سنين)|'
      r'(?:سنوات|سنين)(?!\s*يوجع)',
    ).hasMatch(n);
    if (RegExp(
      // «سني» = ضرسي، لكن «سنين» وحدة عمر — نفس عائلة «سن» ⊂ «سنوات».
      r'(?:اسنان|أسنان|ضرس|لثه|فم|حكه\s*اسنان|تسوس|ضرس\s*العقل|سني(?!ن)|'
      r'سن[ةه]\s*يوجع|يوجع(?:ه|ها)?\s*(?:ال)?سن)',
    ).hasMatch(n)) {
      return true;
    }
    if (!isAgeYearsUnit && RegExp(r'سن[ةه]').hasMatch(n)) return true;
    return RegExp(r'سن(?![ةه]|ين|وات)').hasMatch(n);
  }

  bool _hasMsk(String n) => RegExp(
        r'(ظهر|رقبه|كتف|ركبه|مفصل|عضل|عظام|كسر|التواء)',
      ).hasMatch(n);

  bool _hasRespiratory(String n) => RegExp(
        r'(سعال|كحه|كحة|ضيق نفس|نفس|ربو|صدر|بلغم)',
      ).hasMatch(n);

  bool _hasChronic(String n) => RegExp(
        r'(سكر|ضغط|سكر حمل|سكري|ضغط الدم)',
      ).hasMatch(n);

  bool _hasCorrection(String n) =>
      RegExp(r'(مو\s+\d|مو اني|مو الي|لا مو|بالغلط)').hasMatch(n);

  bool _hasNegation(String n) =>
      RegExp(r'(ماكو|مو موجود|ليس لدي|ما عندي|لا ماكو)').hasMatch(n);

  bool _isAboutOtherPerson(String n) => RegExp(
        r'(زوجتي|زوجي|ابني|بنتي|ابنتي|ولدي|بنتي|امي|ابوي|اخوي|اختي|لابني|لزوجتي|مو اني)',
      ).hasMatch(n);

  bool _isPureClinicalWithoutLife(String n) =>
      _hasDental(n) || _hasMsk(n) || _hasRespiratory(n);
}
