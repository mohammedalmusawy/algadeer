import 'wellbeing_planner_models.dart';

/// ميزانية أفعال — مبدأ: أكثر سياق ≠ أكثر نصائح.
class WellbeingActionBudget {
  const WellbeingActionBudget();

  int maxPrimary({
    required WellbeingPlanContextEnvelope envelope,
    required WellbeingPlanHorizon horizon,
    bool forceOneNext = false,
  }) {
    if (forceOneNext || envelope.hasHighDailyLoad || envelope.hasLowEnergy) {
      if (horizon == WellbeingPlanHorizon.thisWeek && !envelope.reduceBudget) {
        return envelope.reduceBudget ? 1 : 2;
      }
      return envelope.reduceBudget ? 1 : 2;
    }
    if (envelope.reduceBudget) return 2;
    if (horizon == WellbeingPlanHorizon.thisWeek) {
      return envelope.increaseDetail ? 5 : 5;
    }
    if (envelope.increaseDetail) return 4;
    return 3;
  }

  bool preferLowEffort(WellbeingPlanContextEnvelope envelope) =>
      envelope.hasHighDailyLoad ||
      envelope.hasLowEnergy ||
      envelope.hasLowSleep ||
      envelope.hasStress;
}

/// أهلية مرشّحين من السلطات القائمة — بلا محركات جديدة.
class WellbeingActionEligibilityPolicy {
  const WellbeingActionEligibilityPolicy();

  List<WellbeingActionCandidate> buildCandidates(
    WellbeingPlanContextEnvelope env,
  ) {
    final out = <WellbeingActionCandidate>[];

    if (env.eligibleHealthContext) {
      out.add(
        const WellbeingActionCandidate(
          id: 'health_next',
          category: WellbeingActionCategory.healthNextStep,
          source: WellbeingActionSource.healthGuidance,
          priority: WellbeingActionPriority.immediateHealthNeed,
          label: 'وضّح العرض أو ناقش مع مختص إذا استمر — بدون اجتهاد طبي مني',
          effort: WellbeingEffortClass.low,
          timeCost: WellbeingTimeCostClass.short,
          reasonCode: 'healthContext',
        ),
      );
    }

    if (env.hasLowSleep ||
        env.planScope == WellbeingPlanScope.sleepRest ||
        env.userExplicitPriority == WellbeingActionCategory.rest) {
      out.add(
        const WellbeingActionCandidate(
          id: 'rest_sleep',
          category: WellbeingActionCategory.rest,
          source: WellbeingActionSource.dailyContext,
          priority: WellbeingActionPriority.sleepRestRecovery,
          label: 'راحة / ترتيب نوم خفيف حسب وضعك الحالي',
          effort: WellbeingEffortClass.veryLow,
          timeCost: WellbeingTimeCostClass.short,
          reasonCode: 'restNeed',
        ),
      );
    }

    if (env.userExplicitPriority == WellbeingActionCategory.study ||
        env.hasExamSoon ||
        env.planScope == WellbeingPlanScope.studyBalance) {
      out.add(
        const WellbeingActionCandidate(
          id: 'study_block',
          category: WellbeingActionCategory.study,
          source: WellbeingActionSource.userExplicitRequest,
          priority: WellbeingActionPriority.essentialObligation,
          label: 'كتلة دراسة قصيرة للأهم فقط',
          effort: WellbeingEffortClass.low,
          timeCost: WellbeingTimeCostClass.moderate,
          reasonCode: 'studyObligation',
        ),
      );
    }

    if (env.planScope == WellbeingPlanScope.workBalance ||
        env.hasSedentaryWorkHint ||
        env.dailyPriority == 'immediateFunctionalNeed') {
      out.add(
        const WellbeingActionCandidate(
          id: 'work_break',
          category: WellbeingActionCategory.work,
          source: WellbeingActionSource.dailyContext,
          priority: WellbeingActionPriority.essentialObligation,
          label: 'استراحة قصيرة من دوام طويل إن قدرت',
          effort: WellbeingEffortClass.veryLow,
          timeCost: WellbeingTimeCostClass.fewMinutes,
          reasonCode: 'workLoad',
        ),
      );
    }

    final allowMove = !env.rejectsExercise &&
        !env.cannotWalkToday &&
        !(env.hasLowSleep && env.hasExamSoon);
    if (allowMove &&
        (env.eligibleWellnessContext ||
            env.eligibleWalkingGoal ||
            env.planScope == WellbeingPlanScope.movement ||
            env.planScope == WellbeingPlanScope.mixedWellbeing ||
            env.hasSedentaryWorkHint ||
            env.planScope == WellbeingPlanScope.physicalHealth ||
            env.planScope == WellbeingPlanScope.generalWellbeing)) {
      out.add(
        WellbeingActionCandidate(
          id: 'walk_light',
          category: WellbeingActionCategory.walking,
          source: env.eligibleWalkingGoal
              ? WellbeingActionSource.goal
              : WellbeingActionSource.wellness,
          priority: WellbeingActionPriority.manageableMovement,
          label: env.hasSedentaryWorkHint
              ? 'حركة خفيفة قصيرة لكسر الجلوس'
              : 'مشي خفيف اختياري إن ناسبك',
          effort: WellbeingEffortClass.low,
          timeCost: WellbeingTimeCostClass.short,
          optional: env.hasHighDailyLoad || env.hasExamSoon,
          reasonCode: 'wellnessMovement',
        ),
      );
    }

    if (env.eligibleEmotionalContext ||
        env.planScope == WellbeingPlanScope.mentalWellbeing ||
        (env.hasStress &&
            env.planScope != WellbeingPlanScope.movement)) {
      // لا تمارين تلقائية لكل توتر
      out.add(
        const WellbeingActionCandidate(
          id: 'stress_space',
          category: WellbeingActionCategory.stressReduction,
          source: WellbeingActionSource.emotionalSupport,
          priority: WellbeingActionPriority.optionalOptimization,
          label: 'مساحة تهدئة قصيرة بدون بروتوكول علاج',
          effort: WellbeingEffortClass.veryLow,
          timeCost: WellbeingTimeCostClass.fewMinutes,
          optional: true,
          reasonCode: 'emotionalSupport',
        ),
      );
    }

    if (env.eligiblePreventiveContext &&
        (env.planScope == WellbeingPlanScope.physicalHealth ||
            env.planScope == WellbeingPlanScope.generalWellbeing ||
            env.planScope == WellbeingPlanScope.mixedWellbeing)) {
      out.add(
        const WellbeingActionCandidate(
          id: 'preventive_habit',
          category: WellbeingActionCategory.preventiveHabit,
          source: WellbeingActionSource.preventive,
          priority: WellbeingActionPriority.optionalOptimization,
          label: 'عادة وقائية عامة بسيطة (مرجع الأدلة من الطبقة الوقائية)',
          effort: WellbeingEffortClass.low,
          timeCost: WellbeingTimeCostClass.short,
          optional: true,
          reasonCode: 'preventive',
        ),
      );
    }

    if (env.planScope == WellbeingPlanScope.generalWellbeing ||
        env.planScope == WellbeingPlanScope.mixedWellbeing ||
        env.planScope == WellbeingPlanScope.workBalance ||
        env.planHorizon == WellbeingPlanHorizon.thisWeek) {
      out.add(
        const WellbeingActionCandidate(
          id: 'org_block',
          category: WellbeingActionCategory.organization,
          source: WellbeingActionSource.organization,
          priority: WellbeingActionPriority.optionalOptimization,
          label: 'ترتيب أولوية واحدة لليوم/الأسبوع',
          effort: WellbeingEffortClass.low,
          timeCost: WellbeingTimeCostClass.short,
          reasonCode: 'organization',
        ),
      );
    }

    if (env.eligibleWalkingGoal && allowMove) {
      out.add(
        const WellbeingActionCandidate(
          id: 'goal_walk',
          category: WellbeingActionCategory.personalGoal,
          source: WellbeingActionSource.goal,
          priority: WellbeingActionPriority.personalGoal,
          label: 'خطوة صغيرة مرتبطة بهدف المشي إن ناسب اليوم',
          effort: WellbeingEffortClass.low,
          timeCost: WellbeingTimeCostClass.short,
          optional: true,
          reasonCode: 'existingGoal',
        ),
      );
    }

    return out;
  }
}

class WellbeingActionConflictResolver {
  const WellbeingActionConflictResolver();

  List<WellbeingActionCandidate> resolve(
    List<WellbeingActionCandidate> candidates,
    WellbeingPlanContextEnvelope env,
    Set<WellbeingActionCategory> rejected,
  ) {
    var list = candidates
        .where((c) => !rejected.contains(c.category))
        .toList();

    if (env.rejectsExercise || env.cannotWalkToday) {
      list = list
          .where(
            (c) =>
                c.category != WellbeingActionCategory.walking &&
                c.category != WellbeingActionCategory.generalExercise &&
                c.category != WellbeingActionCategory.movement,
          )
          .toList();
    }

    // نوم ضعيف + امتحان → لا يسيطر المشي
    if (env.hasLowSleep && env.hasExamSoon) {
      list = list
          .where(
            (c) =>
                c.category != WellbeingActionCategory.walking &&
                c.category != WellbeingActionCategory.personalGoal,
          )
          .toList();
    }

    if (env.userExplicitPriority == WellbeingActionCategory.rest) {
      list = list
          .where(
            (c) =>
                c.category == WellbeingActionCategory.rest ||
                c.category == WellbeingActionCategory.sleepRoutine ||
                c.priority.index <=
                    WellbeingActionPriority.sleepRestRecovery.index,
          )
          .toList();
      if (list.isEmpty) {
        list = candidates
            .where((c) => c.category == WellbeingActionCategory.rest)
            .toList();
      }
    }

    return list;
  }
}

class WellbeingActionPriorityResolver {
  const WellbeingActionPriorityResolver();

  List<WellbeingActionCandidate> sort(List<WellbeingActionCandidate> list) {
    final copy = [...list];
    copy.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return copy;
  }
}

class WellbeingActionSequencer {
  const WellbeingActionSequencer();

  WellbeingActionPlan sequence({
    required List<WellbeingActionCandidate> ranked,
    required WellbeingPlanContextEnvelope env,
    required int maxPrimary,
    required bool oneNextStep,
  }) {
    final selected = <WellbeingAction>[];
    final codes = <String>[];

    if (oneNextStep && ranked.isNotEmpty) {
      final c = ranked.first;
      selected.add(_toAction(c, 'now'));
      codes.add(c.reasonCode);
      return WellbeingActionPlan(
        actions: selected,
        scope: env.planScope,
        horizon: env.planHorizon,
        oneNextStepMode: true,
        explanationCodes: codes,
        createdAt: DateTime.now(),
      );
    }

    var primary = 0;
    for (final c in ranked) {
      if (c.optional && primary >= maxPrimary) {
        if (selected.length < maxPrimary + 1) {
          selected.add(_toAction(c, 'optional'));
          codes.add(c.reasonCode);
        }
        continue;
      }
      if (primary >= maxPrimary) break;
      final slot = primary == 0
          ? 'now'
          : (primary == 1 ? 'next' : 'optional');
      selected.add(_toAction(c, slot == 'optional' && !c.optional ? 'next' : slot));
      codes.add(c.reasonCode);
      primary++;
    }

    // أسبوع: إطار خفيف بدون جدول بالدقيقة
    if (env.planHorizon == WellbeingPlanHorizon.thisWeek &&
        selected.length < maxPrimary) {
      selected.add(
        const WellbeingAction(
          id: 'week_frame',
          category: WellbeingActionCategory.organization,
          source: WellbeingActionSource.organization,
          priority: WellbeingActionPriority.optionalOptimization,
          label: 'إطار أسبوعي بسيط: يوم راحة + يوم حركة خفيفة + يوم أولوية شخصية',
          slot: 'next',
          reasonCode: 'weeklyFramework',
        ),
      );
    }

    return WellbeingActionPlan(
      actions: selected.take(maxPrimary + 1).toList(),
      scope: env.planScope,
      horizon: env.planHorizon,
      oneNextStepMode: false,
      explanationCodes: codes.toSet().toList(),
      createdAt: DateTime.now(),
    );
  }

  WellbeingAction _toAction(WellbeingActionCandidate c, String slot) {
    return WellbeingAction(
      id: c.id,
      category: c.category,
      source: c.source,
      priority: c.priority,
      label: c.label,
      slot: slot,
      optional: c.optional || slot == 'optional',
      reasonCode: c.reasonCode,
      effort: c.effort,
      timeCost: c.timeCost,
    );
  }
}
