import '../search/arabic_text_utils.dart';
import 'wellbeing_planner_models.dart';

/// يميّز طلب تخطيط صريح عن سؤال عادي.
class WellbeingPlanRequestInterpreter {
  const WellbeingPlanRequestInterpreter();

  WellbeingPlanRequest interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return WellbeingPlanRequest.none;

    final urgent = RegExp(
      r'(?:الم.{0,12}صدر|ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف)',
    ).hasMatch(n);
    final mental = RegExp(
      r'(?:اقتل\s*نفسي|انتحار|اذي\s*نفسي|أذي\s*نفسي|اؤذي\s*نفسي)',
    ).hasMatch(n);

    if (RegExp(
      r'(?:أريد|اريد|ابي|دور)\s*(?:رقم\s*)?(?:طبيب|دكتور|مختبر)|'
      r'(?:رقم\s*(?:مختبر|الطبيب))',
    ).hasMatch(n)) {
      return WellbeingPlanRequest(
        isPlanRequest: false,
        looksLikeEntityEscape: true,
        urgentMedicalHint: urgent,
        mentalSafetyHint: mental,
        userText: raw,
      );
    }

    if (RegExp(r'تابع\s*وياي').hasMatch(n)) {
      return WellbeingPlanRequest(
        isPlanRequest: RegExp(
          r'(?:خطه|خطة|رتب|مشي|رياضه|رياضة)',
        ).hasMatch(n),
        looksLikeFollowUp: true,
        urgentMedicalHint: urgent,
        mentalSafetyHint: mental,
        userText: raw,
      );
    }

    final other = _otherPerson(n);

    // أسئلة فوائد عادية — ليست خطة (تطبيع: فوائد → فوايد)
    if (RegExp(r'(?:فوائد|فوايد|فايده|فائدة)').hasMatch(n) &&
        !RegExp(r'(?:خطه|خطة|رتب|خطوة\s*خطوة|شنو\s*اسوي|اهتم)')
            .hasMatch(n)) {
      return WellbeingPlanRequest(
        isPlanRequest: false,
        ordinaryBenefitsQuestion: true,
        userText: raw,
      );
    }

    // عرض صحي فقط
    if (RegExp(r'(?:عندي\s*صداع|صداع|الم\s*بطن|حراره)').hasMatch(n) &&
        !RegExp(r'(?:خطه|خطة|رتب|اهتم|أرتب|شنو\s*اسوي|ساعدني)')
            .hasMatch(n)) {
      return WellbeingPlanRequest(
        isPlanRequest: false,
        symptomOnlyHealth: true,
        urgentMedicalHint: urgent,
        mentalSafetyHint: mental,
        userText: raw,
      );
    }

    final asksExplanation = RegExp(
      r'(?:ليش\s*رتبتها|ليش\s*هيج|ليش\s*الخطة|لماذا\s*رتبت)',
    ).hasMatch(n);
    final asksReduce = RegExp(r'(?:هذا\s*هواي|قللها|اختصر|كثير\s*هواي)')
        .hasMatch(n);
    final asksIncrease = RegExp(r'(?:اقوي\s*شوي|أقوى\s*شوي|زيد\s*التفاصيل)')
        .hasMatch(n);
    final rejectsExercise = RegExp(
      r'(?:ما\s*اريد\s*تمارين|ما\s*أريد\s*تمارين|بلا\s*رياضه|بلا\s*رياضة)',
    ).hasMatch(n);
    final cannotWalk = RegExp(
      r'(?:ما\s*اقدر\s*امشي|ما\s*أقدر\s*أمشي|ما\s*اقدر\s*أمشي)',
    ).hasMatch(n);

    final planCue = RegExp(
      r'(?:رتبلي|رتب\s*لي|اريد\s*خطه|أريد\s*خطة|سويلي\s*خطه|سويلي\s*خطة|'
      r'خطه\s*بسيطه|خطة\s*بسيطة|اهتم\s*بصحتي|أهتم\s*بصحتي|'
      r'اهتم\s*بنفسيتي|أهتم\s*بنفسيتي|ارجع\s*للرياضه|أرجع\s*للرياضة|'
      r'خطوه\s*خطوه|خطوة\s*خطوة|شنو\s*اسوي|شنو\s*أسوي|'
      r'ساعدني\s*(?:ابدأ|أبدأ|ابدا)|'
      r'ارتب\s*حياتي|أرتب\s*حياتي|اريد\s*ارتب|أريد\s*أرتب|نظم\s*حياتي|'
      r'خطه\s*لهذا\s*الاسبوع|خطة\s*لهذا\s*الأسبوع|رتبلي\s*اسبوع|رتبلي\s*أسبوع|'
      r'اريد\s*ابق[ىي]\s*اتحرك|أريد\s*أبق[ىي]\s*أتحرك|ابق[ىي]\s*اتحرك|'
      r'ما\s*سويت\s*الخطة|ما\s*سويت\s*خطه|'
      r'اهتم\s*بصحتي\s*ونفسيتي|صحتي\s*ونفسيتي)',
    ).hasMatch(n);

    // «رتبلي يومي» يبقى لـ PC-1.15 — ليس اختطافاً هنا إلا ضمن سياق أوسع
    final pureDailyOnly = RegExp(r'رتبلي\s*يومي').hasMatch(n) &&
        !RegExp(r'(?:صحه|صحة|نفسي|رياض|مشي|حياتي|اسبوع|أسبوع)')
            .hasMatch(n);

    final isPlan = (planCue && !pureDailyOnly) ||
        asksExplanation ||
        asksReduce ||
        asksIncrease ||
        rejectsExercise ||
        cannotWalk ||
        RegExp(r'ما\s*سويت\s*الخطة').hasMatch(n);

    if (!isPlan && !asksExplanation) {
      return WellbeingPlanRequest(
        isPlanRequest: false,
        urgentMedicalHint: urgent,
        mentalSafetyHint: mental,
        isAboutOtherPerson: other,
        userText: raw,
      );
    }

    return WellbeingPlanRequest(
      isPlanRequest: isPlan || asksExplanation,
      scope: _scope(n),
      horizon: _horizon(n),
      isAboutOtherPerson: other,
      asksExplanation: asksExplanation,
      asksReduce: asksReduce,
      asksIncrease: asksIncrease,
      rejectsExercise: rejectsExercise,
      cannotWalkToday: cannotWalk,
      looksLikeFollowUp: false,
      urgentMedicalHint: urgent,
      mentalSafetyHint: mental,
      explicitPriorityCategory: _explicitPriority(n),
      userText: raw,
    );
  }

  WellbeingPlanScope _scope(String n) {
    final mental = RegExp(r'(?:نفسيتي|نفسي|توتر|ضغط\s*نفسي)').hasMatch(n);
    final physical = RegExp(r'(?:صحتي|صحه|صحة)').hasMatch(n);
    final move = RegExp(r'(?:رياضه|رياضة|مشي|اتحرك|أتحرك|تمارين)').hasMatch(n);
    final sleep = RegExp(r'(?:نوم|راحه|راحة|ارتاح)').hasMatch(n);
    final study = RegExp(r'(?:امتحان|دراسه|دراسة)').hasMatch(n);
    final work = RegExp(r'(?:دوام|شغل|عمل)').hasMatch(n);
    final goal = RegExp(r'(?:هدفي|هدفي\s*المشي)').hasMatch(n);

    final hits = [
      if (mental) 1,
      if (physical) 1,
      if (move) 1,
      if (sleep) 1,
      if (study) 1,
      if (work) 1,
    ].length;

    if (hits >= 2) return WellbeingPlanScope.mixedWellbeing;
    if (mental) return WellbeingPlanScope.mentalWellbeing;
    if (physical && !move) return WellbeingPlanScope.physicalHealth;
    if (move) return WellbeingPlanScope.movement;
    if (sleep) return WellbeingPlanScope.sleepRest;
    if (study) return WellbeingPlanScope.studyBalance;
    if (work) return WellbeingPlanScope.workBalance;
    if (goal) return WellbeingPlanScope.goalProgress;
    if (RegExp(r'(?:حياتي|عافيه|عافية|عام)').hasMatch(n)) {
      return WellbeingPlanScope.generalWellbeing;
    }
    return WellbeingPlanScope.generalWellbeing;
  }

  WellbeingPlanHorizon _horizon(String n) {
    if (RegExp(r'(?:هسه|الآن|الحين|شنو\s*اسوي)').hasMatch(n)) {
      return WellbeingPlanHorizon.now;
    }
    if (RegExp(r'(?:لهذا\s*الاسبوع|لهذا\s*الأسبوع|رتبلي\s*اسبوع|اسبوع\s*بسيط)')
        .hasMatch(n)) {
      return WellbeingPlanHorizon.thisWeek;
    }
    if (RegExp(r'(?:باچر|باجر|غدا)').hasMatch(n)) {
      return WellbeingPlanHorizon.tomorrow;
    }
    if (RegExp(r'(?:اليوم|ليوم)').hasMatch(n)) {
      return WellbeingPlanHorizon.today;
    }
    if (RegExp(r'(?:ايام|أيام|كم\s*يوم)').hasMatch(n)) {
      return WellbeingPlanHorizon.fewDays;
    }
    if (RegExp(r'(?:خطوة\s*خطوة|ابدأ|أبدأ|ارجع)').hasMatch(n)) {
      return WellbeingPlanHorizon.generalStart;
    }
    return WellbeingPlanHorizon.unknown;
  }

  WellbeingActionCategory? _explicitPriority(String n) {
    if (RegExp(r'(?:هسه\s*اريد\s*انام|هسه\s*أريد\s*أنام|أريد\s*أنام)')
        .hasMatch(n)) {
      return WellbeingActionCategory.rest;
    }
    if (RegExp(r'(?:ركز\s*على\s*الدراسه|نركز\s*علي\s*الدراسه|نركز\s*على\s*الدراسة)')
        .hasMatch(n)) {
      return WellbeingActionCategory.study;
    }
    return null;
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:انا|اني|أني)(?:\s|$)').hasMatch(n)) return false;
    // تجنّب تطابق «امي» داخل «دوامي»
    return RegExp(
      r'(?:^|\s)(?:امي|أبي|ابوي|ابني|ابنتي|زوجتي|زوجي)(?:\s|$)|'
      r'(?:خطه|خطة)\s*(?:لامي|لأمي|لامى)|رتبلي\s*خطه\s*لامي|لأمي|لامي\b',
    ).hasMatch(n);
  }
}
