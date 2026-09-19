import '../companion/personal_memory/personal_memory_models.dart';
import '../companion/personal_memory/personal_memory_service.dart';
import '../daily_context/daily_context_models.dart';
import '../follow_up/follow_up_service.dart';
import '../health/emotional_support/mental_health_safety_gate.dart';
import 'wellbeing_action_planner.dart';
import 'wellbeing_plan_request_interpreter.dart';
import 'wellbeing_plan_response_builder.dart';
import 'wellbeing_planner_models.dart';

class WellbeingPlannerTurnResult {
  const WellbeingPlannerTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.deferToUrgentSafety = false,
    this.deferToMentalSafety = false,
    this.deferToFollowUp = false,
    this.deferToEntityIntent = false,
    this.deferFollowUpSurfacing = false,
    this.textFirstOnly = true,
    this.success = true,
    this.plan = WellbeingActionPlan.empty,
  });

  final bool handled;
  final String message;
  final WellbeingPlannerSession session;
  final bool deferToUrgentSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToEntityIntent;
  final bool deferFollowUpSurfacing;
  final bool textFirstOnly;
  final bool success;
  final WellbeingActionPlan plan;

  static WellbeingPlannerTurnResult notHandled(WellbeingPlannerSession s) =>
      WellbeingPlannerTurnResult(
        handled: false,
        message: '',
        session: s,
      );

  Map<String, Object?> debugMap() => {
        ...session.debugMap(),
        'operationType': handled ? 'wellbeingPlanHandle' : 'wellbeingPlanSkip',
        'operationSuccess': success,
      };
}

/// منسّق خطط العافية — PC-1.16.
class WellbeingPlannerCoordinator {
  WellbeingPlannerCoordinator({
    WellbeingPlanRequestInterpreter? interpreter,
    WellbeingActionPlanner? planner,
    WellbeingPlanResponseBuilder? responses,
    MentalHealthSafetyGate? mentalSafety,
    PersonalMemoryService? personalMemory,
    FollowUpService? followUps,
  })  : _interpreter = interpreter ?? const WellbeingPlanRequestInterpreter(),
        _planner = planner ?? WellbeingActionPlanner(),
        _responses = responses ?? const WellbeingPlanResponseBuilder(),
        _mentalSafety = mentalSafety ?? const MentalHealthSafetyGate(),
        _personalMemory = personalMemory,
        _followUps = followUps;

  final WellbeingPlanRequestInterpreter _interpreter;
  final WellbeingActionPlanner _planner;
  final WellbeingPlanResponseBuilder _responses;
  final MentalHealthSafetyGate _mentalSafety;
  final PersonalMemoryService? _personalMemory;
  final FollowUpService? _followUps;

  WellbeingPlanRequestInterpreter get interpreter => _interpreter;
  WellbeingActionPlanner get actionPlanner => _planner;
  PersistentWellbeingPlanContract get futureContract =>
      const PersistentWellbeingPlanContract();

  bool mayHandle({
    required String query,
    required WellbeingPlannerSession session,
  }) {
    final req = _interpreter.interpret(query);
    if (req.looksLikeEntityEscape) return false;
    if (req.ordinaryBenefitsQuestion || req.symptomOnlyHealth) return false;
    if (req.asksExplanation && session.active) return true;
    if (req.asksReduce || req.asksIncrease || req.rejectsExercise ||
        req.cannotWalkToday) {
      return session.active || req.isPlanRequest;
    }
    if (RegExp(r'ما\s*سويت\s*الخطة').hasMatch(query) && session.active) {
      return true;
    }
    return req.isPlanRequest;
  }

  Future<WellbeingPlannerTurnResult> handle({
    required String text,
    required WellbeingPlannerSession session,
    DailyLifeContext? dailyContext,
  }) async {
    try {
      return await _handle(
        text: text,
        session: session,
        dailyContext: dailyContext ?? DailyLifeContext.empty,
      );
    } catch (_) {
      return WellbeingPlannerTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  Future<WellbeingPlannerTurnResult> _handle({
    required String text,
    required WellbeingPlannerSession session,
    required DailyLifeContext dailyContext,
  }) async {
    final req = _interpreter.interpret(text);

    if (req.looksLikeEntityEscape) {
      return WellbeingPlannerTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToEntityIntent: true,
      );
    }

    if (req.looksLikeFollowUp && !req.isPlanRequest) {
      return WellbeingPlannerTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToFollowUp: true,
      );
    }

    if (_mentalSafety.triggersCrisis(text) || req.mentalSafetyHint) {
      return WellbeingPlannerTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    if (req.urgentMedicalHint) {
      return WellbeingPlannerTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToUrgentSafety: true,
      );
    }

    if (req.isAboutOtherPerson) {
      return WellbeingPlannerTurnResult(
        handled: true,
        message: _responses.buildOtherPersonSafe(),
        session: session.copyWith(active: true),
        textFirstOnly: true,
      );
    }

    if (req.asksExplanation && session.active) {
      final env = _planner.buildEnvelope(
        request: req,
        daily: dailyContext,
      );
      final msg = _responses.buildExplanation(session.lastPlan, env);
      return WellbeingPlannerTurnResult(
        handled: true,
        message: msg,
        session: session.copyWith(lastExplanation: msg),
        plan: session.lastPlan,
      );
    }

    if (RegExp(r'ما\s*سويت').hasMatch(text) &&
        RegExp(r'خط').hasMatch(text) &&
        session.active) {
      return WellbeingPlannerTurnResult(
        handled: true,
        message: _responses.buildMissedNoGuilt(),
        session: session,
        plan: session.lastPlan,
      );
    }

    var rejected = {...session.rejectedCategories};
    if (req.rejectsExercise) {
      rejected.addAll({
        WellbeingActionCategory.walking,
        WellbeingActionCategory.generalExercise,
        WellbeingActionCategory.movement,
      });
    }

    final walkingGoal = await _hasWalkingGoal();
    final hasFu = await _hasActiveFollowUp();

    var env = _planner.buildEnvelope(
      request: req,
      daily: dailyContext,
      eligibleWalkingGoal: walkingGoal,
      eligiblePreventive: req.scope == WellbeingPlanScope.physicalHealth ||
          req.scope == WellbeingPlanScope.generalWellbeing ||
          req.scope == WellbeingPlanScope.mixedWellbeing,
      hasActiveFollowUp: hasFu,
    );

    if (req.asksReduce) {
      env = WellbeingPlanContextEnvelope(
        resolvedSubjectKind: env.resolvedSubjectKind,
        planScope: env.planScope,
        planHorizon: env.planHorizon,
        dailyPriority: env.dailyPriority,
        hasHighDailyLoad: env.hasHighDailyLoad,
        hasLowSleep: env.hasLowSleep,
        hasExamSoon: env.hasExamSoon,
        hasLowEnergy: env.hasLowEnergy,
        hasStress: env.hasStress,
        hasSedentaryWorkHint: env.hasSedentaryWorkHint,
        eligibleWalkingGoal: env.eligibleWalkingGoal,
        eligibleWellnessContext: env.eligibleWellnessContext,
        eligiblePreventiveContext: env.eligiblePreventiveContext,
        eligibleEmotionalContext: env.eligibleEmotionalContext,
        eligibleHealthContext: env.eligibleHealthContext,
        followUpEligibleButDefer: env.followUpEligibleButDefer,
        userExplicitPriority: env.userExplicitPriority,
        rejectsExercise: env.rejectsExercise,
        cannotWalkToday: env.cannotWalkToday,
        reduceBudget: true,
        increaseDetail: false,
      );
    }
    if (req.asksIncrease) {
      env = WellbeingPlanContextEnvelope(
        resolvedSubjectKind: env.resolvedSubjectKind,
        planScope: env.planScope,
        planHorizon: env.planHorizon,
        dailyPriority: env.dailyPriority,
        hasHighDailyLoad: env.hasHighDailyLoad,
        hasLowSleep: env.hasLowSleep,
        hasExamSoon: env.hasExamSoon,
        hasLowEnergy: env.hasLowEnergy,
        hasStress: env.hasStress,
        hasSedentaryWorkHint: env.hasSedentaryWorkHint,
        eligibleWalkingGoal: env.eligibleWalkingGoal,
        eligibleWellnessContext: env.eligibleWellnessContext,
        eligiblePreventiveContext: env.eligiblePreventiveContext,
        eligibleEmotionalContext: env.eligibleEmotionalContext,
        eligibleHealthContext: env.eligibleHealthContext,
        followUpEligibleButDefer: env.followUpEligibleButDefer,
        userExplicitPriority: env.userExplicitPriority,
        rejectsExercise: env.rejectsExercise,
        cannotWalkToday: env.cannotWalkToday,
        reduceBudget: false,
        increaseDetail: true,
      );
    }

    // إعادة توليد من سياق يومي مصحّح عند وجود جلسة/طلب
    if (!req.isPlanRequest &&
        (req.asksReduce ||
            req.asksIncrease ||
            req.rejectsExercise ||
            req.cannotWalkToday) &&
        session.active) {
      // استخدم نطاق آخر خطة
      env = WellbeingPlanContextEnvelope(
        resolvedSubjectKind: env.resolvedSubjectKind,
        planScope: session.lastPlan.scope != WellbeingPlanScope.unknown
            ? session.lastPlan.scope
            : env.planScope,
        planHorizon: session.lastPlan.horizon != WellbeingPlanHorizon.unknown
            ? session.lastPlan.horizon
            : env.planHorizon,
        dailyPriority: env.dailyPriority,
        hasHighDailyLoad: env.hasHighDailyLoad,
        hasLowSleep: env.hasLowSleep,
        hasExamSoon: env.hasExamSoon,
        hasLowEnergy: env.hasLowEnergy,
        hasStress: env.hasStress,
        hasSedentaryWorkHint: env.hasSedentaryWorkHint,
        eligibleWalkingGoal: env.eligibleWalkingGoal,
        eligibleWellnessContext: env.eligibleWellnessContext,
        eligiblePreventiveContext: env.eligiblePreventiveContext,
        eligibleEmotionalContext: env.eligibleEmotionalContext,
        eligibleHealthContext: env.eligibleHealthContext,
        followUpEligibleButDefer: env.followUpEligibleButDefer,
        userExplicitPriority: env.userExplicitPriority,
        rejectsExercise: env.rejectsExercise || rejected.isNotEmpty,
        cannotWalkToday: env.cannotWalkToday,
        reduceBudget: env.reduceBudget,
        increaseDetail: env.increaseDetail,
      );
    }

    if (!req.isPlanRequest &&
        !req.asksReduce &&
        !req.asksIncrease &&
        !req.rejectsExercise &&
        !req.cannotWalkToday &&
        !req.asksExplanation) {
      return WellbeingPlannerTurnResult.notHandled(session);
    }

    final plan = _planner.plan(envelope: env, rejected: rejected);
    var msg = _responses.buildPlan(plan, env);
    if (_responses.containsForbidden(msg)) {
      msg = 'خطة قصيرة بهدوء: ركّز على خطوة واحدة مناسبة الآن.';
    }

    // خطة + طلب متابعة صريح في نفس النص
    final deferFu = req.looksLikeFollowUp;

    final nextSession = session.copyWith(
      lastPlan: plan,
      rejectedCategories: rejected,
      active: true,
    );

    if (deferFu) {
      return WellbeingPlannerTurnResult(
        handled: true,
        message: '$msg\nإذا تحب المتابعة، أكمل طلب «تابع وياي» مع طبقة المتابعة.',
        session: nextSession,
        deferToFollowUp: true,
        deferFollowUpSurfacing: env.followUpEligibleButDefer,
        plan: plan,
      );
    }

    return WellbeingPlannerTurnResult(
      handled: true,
      message: msg,
      session: nextSession,
      deferFollowUpSurfacing: env.followUpEligibleButDefer,
      plan: plan,
    );
  }

  Future<bool> _hasWalkingGoal() async {
    final mem = _personalMemory;
    if (mem == null) return false;
    try {
      final goals = await mem.listByType(PersonalMemoryType.goal);
      return goals.any(
        (g) =>
            g.canonicalKey.contains('walk') ||
            g.displayLabel.contains('مشي'),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasActiveFollowUp() async {
    final fu = _followUps;
    if (fu == null) return false;
    try {
      return (await fu.listActive()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// حدود الخصوصية — لا ترقية صامتة.
  bool mayPersistPlanHistory() => false;
  bool mayTrackCompletion() => false;
  bool mayTrackActivity() => false;
  bool mayTrackMood() => false;
  bool mayTrackSleep() => false;
  bool mayCreateGoalFromPlan() => false;
  bool mayAuthorizeFollowUpFromPlanAlone() => false;
}
