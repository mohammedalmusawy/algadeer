import 'daily_context_interpreter.dart';
import 'daily_context_models.dart';

/// يختار أولوية واحدة متماسكة — بلا تشخيص.
class DailyContextPriorityResolver {
  const DailyContextPriorityResolver();

  DailyContextPriority resolve({
    required DailyContextInterpretation interp,
    required DailyLifeContext context,
    bool urgentMedical = false,
    bool mentalSafety = false,
  }) {
    if (urgentMedical || interp.urgentMedicalHint) {
      return DailyContextPriority.urgentMedicalSafety;
    }
    if (mentalSafety || interp.mentalSafetyHint) {
      return DailyContextPriority.mentalHealthSafety;
    }

    final active = context.activeSignals();
    bool has(DailyContextCategory c) =>
        active.any((s) => s.category == c) ||
        interp.signals.any((s) => s.category == c);

    if (has(DailyContextCategory.healthConcern) &&
        (has(DailyContextCategory.sleep) ||
            interp.urgentMedicalHint == false)) {
      // اهتمام صحي غير عاجل
      if (has(DailyContextCategory.healthConcern)) {
        return DailyContextPriority.activeHealthConcern;
      }
    }

    if (interp.explicitFocusCategory != null ||
        context.explicitFocusCategory != null) {
      return DailyContextPriority.explicitUserGoal;
    }

    final veryLowSleep = active.any(
          (s) =>
              s.category == DailyContextCategory.sleep &&
              s.state.contains('VeryLow'),
        ) ||
        interp.signals.any((s) => s.state.contains('VeryLow'));

    if (veryLowSleep ||
        (has(DailyContextCategory.exam) && has(DailyContextCategory.sleep))) {
      return DailyContextPriority.restSleepNeed;
    }

    if (has(DailyContextCategory.exam) || has(DailyContextCategory.study)) {
      return DailyContextPriority.immediateFunctionalNeed;
    }

    if (has(DailyContextCategory.restNeed)) {
      return DailyContextPriority.restSleepNeed;
    }

    if (has(DailyContextCategory.emotionalState) ||
        has(DailyContextCategory.stressLoad)) {
      return DailyContextPriority.emotionalLoad;
    }

    if (has(DailyContextCategory.work) ||
        has(DailyContextCategory.scheduleLoad)) {
      return DailyContextPriority.immediateFunctionalNeed;
    }

    if (has(DailyContextCategory.activity) ||
        has(DailyContextCategory.energy)) {
      return DailyContextPriority.activityWellness;
    }

    return DailyContextPriority.lowerOptimization;
  }

  bool shouldDeferFollowUpSurfacing(DailyContextPriority p) {
    switch (p) {
      case DailyContextPriority.urgentMedicalSafety:
      case DailyContextPriority.mentalHealthSafety:
      case DailyContextPriority.activeHealthConcern:
      case DailyContextPriority.restSleepNeed:
      case DailyContextPriority.immediateFunctionalNeed:
      case DailyContextPriority.explicitUserGoal:
        return true;
      default:
        return false;
    }
  }

  bool shouldSuppressWellnessPressure(DailyContextPriority p) {
    return p == DailyContextPriority.restSleepNeed ||
        p == DailyContextPriority.immediateFunctionalNeed ||
        p == DailyContextPriority.urgentMedicalSafety ||
        p == DailyContextPriority.mentalHealthSafety ||
        p == DailyContextPriority.explicitUserGoal;
  }

  bool hasHighLoad(DailyLifeContext ctx, [DateTime? now]) {
    final cats =
        ctx.activeSignals(now ?? ctx.updatedAt).map((s) => s.category).toSet();
    var score = 0;
    if (cats.contains(DailyContextCategory.exam)) score++;
    if (cats.contains(DailyContextCategory.sleep)) score++;
    if (cats.contains(DailyContextCategory.stressLoad) ||
        cats.contains(DailyContextCategory.emotionalState)) {
      score++;
    }
    if (cats.contains(DailyContextCategory.work)) score++;
    if (cats.contains(DailyContextCategory.energy)) score++;
    return score >= 2;
  }
}

/// أسئلة قليلة عند الحاجة.
class DailyContextQuestionPlanner {
  const DailyContextQuestionPlanner({this.maxQuestions = 1});

  final int maxQuestions;

  List<String> plan(DailyContextPriority priority, {bool highLoad = false}) {
    if (highLoad || priority == DailyContextPriority.restSleepNeed) {
      return const [];
    }
    if (priority == DailyContextPriority.activeHealthConcern) {
      return ['هل تريد نركز على الراحة لو على العرض اللي ذكرته؟']
          .take(maxQuestions)
          .toList();
    }
    return const [];
  }
}
