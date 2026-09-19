import '../daily_context/daily_context_models.dart';
import 'wellbeing_action_policies.dart';
import 'wellbeing_planner_models.dart';

/// يبني الخطة من غلاف سياق أدنى — منسّق لا محرك جديد.
class WellbeingActionPlanner {
  WellbeingActionPlanner({
    WellbeingActionEligibilityPolicy? eligibility,
    WellbeingActionConflictResolver? conflicts,
    WellbeingActionPriorityResolver? priority,
    WellbeingActionSequencer? sequencer,
    WellbeingActionBudget? budget,
  })  : _eligibility = eligibility ?? const WellbeingActionEligibilityPolicy(),
        _conflicts = conflicts ?? const WellbeingActionConflictResolver(),
        _priority = priority ?? const WellbeingActionPriorityResolver(),
        _sequencer = sequencer ?? const WellbeingActionSequencer(),
        _budget = budget ?? const WellbeingActionBudget();

  final WellbeingActionEligibilityPolicy _eligibility;
  final WellbeingActionConflictResolver _conflicts;
  final WellbeingActionPriorityResolver _priority;
  final WellbeingActionSequencer _sequencer;
  final WellbeingActionBudget _budget;

  WellbeingActionPlan plan({
    required WellbeingPlanContextEnvelope envelope,
    Set<WellbeingActionCategory> rejected = const {},
  }) {
    final oneNext = envelope.hasHighDailyLoad ||
        envelope.hasLowEnergy ||
        (envelope.hasStress &&
            envelope.planHorizon == WellbeingPlanHorizon.now);

    final maxPrimary = _budget.maxPrimary(
      envelope: envelope,
      horizon: envelope.planHorizon,
      forceOneNext: oneNext && envelope.planHorizon != WellbeingPlanHorizon.thisWeek,
    );

    var candidates = _eligibility.buildCandidates(envelope);
    candidates = _conflicts.resolve(candidates, envelope, rejected);

    if (_budget.preferLowEffort(envelope)) {
      candidates = candidates
          .where(
            (c) =>
                c.effort == WellbeingEffortClass.veryLow ||
                c.effort == WellbeingEffortClass.low,
          )
          .toList();
      if (candidates.isEmpty) {
        candidates = _conflicts.resolve(
          _eligibility.buildCandidates(envelope),
          envelope,
          rejected,
        );
      }
    }

    final ranked = _priority.sort(candidates);
    return _sequencer.sequence(
      ranked: ranked,
      env: envelope,
      maxPrimary: maxPrimary,
      oneNextStep: oneNext &&
          envelope.planHorizon != WellbeingPlanHorizon.thisWeek &&
          !envelope.increaseDetail,
    );
  }

  /// يبني غلافاً من السياق اليومي + أعلام مسموحة فقط.
  WellbeingPlanContextEnvelope buildEnvelope({
    required WellbeingPlanRequest request,
    DailyLifeContext? daily,
    bool eligibleWalkingGoal = false,
    bool eligiblePreventive = false,
    bool hasActiveFollowUp = false,
  }) {
    final d = daily ?? DailyLifeContext.empty;
    final active = d.activeSignals(d.updatedAt);
    bool has(DailyContextCategory c) => active.any((s) => s.category == c);

    final lowSleep = has(DailyContextCategory.sleep);
    final exam = has(DailyContextCategory.exam);
    final energy = has(DailyContextCategory.energy);
    final stress = has(DailyContextCategory.stressLoad) ||
        has(DailyContextCategory.emotionalState);
    final work = has(DailyContextCategory.work) ||
        has(DailyContextCategory.scheduleLoad);

    return WellbeingPlanContextEnvelope(
      resolvedSubjectKind: request.isAboutOtherPerson
          ? WellbeingSubjectKind.otherPerson
          : WellbeingSubjectKind.accountOwner,
      planScope: request.scope,
      planHorizon: request.horizon,
      dailyPriority: d.lastPriority.name,
      hasHighDailyLoad: d.hasHighLoad || (exam && lowSleep),
      hasLowSleep: lowSleep,
      hasExamSoon: exam,
      hasLowEnergy: energy,
      hasStress: stress,
      hasSedentaryWorkHint: work &&
          (request.scope == WellbeingPlanScope.workBalance ||
              request.scope == WellbeingPlanScope.mixedWellbeing ||
              request.scope == WellbeingPlanScope.movement),
      eligibleWalkingGoal: eligibleWalkingGoal && !request.isAboutOtherPerson,
      eligibleWellnessContext: !request.isAboutOtherPerson &&
          (request.scope == WellbeingPlanScope.movement ||
              request.scope == WellbeingPlanScope.mixedWellbeing ||
              request.scope == WellbeingPlanScope.physicalHealth ||
              request.scope == WellbeingPlanScope.generalWellbeing ||
              request.scope == WellbeingPlanScope.workBalance),
      eligiblePreventiveContext:
          eligiblePreventive && !request.isAboutOtherPerson,
      eligibleEmotionalContext: !request.isAboutOtherPerson &&
          (request.scope == WellbeingPlanScope.mentalWellbeing ||
              request.scope == WellbeingPlanScope.mixedWellbeing ||
              stress),
      eligibleHealthContext: !request.isAboutOtherPerson &&
          has(DailyContextCategory.healthConcern),
      followUpEligibleButDefer:
          hasActiveFollowUp && (d.deferFollowUpSurfacing || d.hasHighLoad),
      userExplicitPriority: request.explicitPriorityCategory,
      rejectsExercise: request.rejectsExercise,
      cannotWalkToday: request.cannotWalkToday,
      reduceBudget: request.asksReduce,
      increaseDetail: request.asksIncrease,
    );
  }
}
