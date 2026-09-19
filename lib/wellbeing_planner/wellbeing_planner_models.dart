/// PC-1.16 — منسّق خطط عافية عملية قصيرة (جلسة)، بلا محرك صحي ثانٍ.
library;

enum WellbeingPlanScope {
  generalWellbeing,
  physicalHealth,
  mentalWellbeing,
  movement,
  sleepRest,
  studyBalance,
  workBalance,
  goalProgress,
  mixedWellbeing,
  unknown,
}

enum WellbeingPlanHorizon {
  now,
  today,
  tomorrow,
  fewDays,
  thisWeek,
  generalStart,
  unknown,
}

enum WellbeingActionCategory {
  rest,
  sleepRoutine,
  movement,
  walking,
  generalExercise,
  study,
  work,
  stressReduction,
  personalGoal,
  healthNextStep,
  preventiveHabit,
  organization,
  recovery,
  other,
}

enum WellbeingActionPriority {
  medicalSafety,
  mentalHealthSafety,
  immediateHealthNeed,
  sleepRestRecovery,
  explicitUserPriority,
  essentialObligation,
  manageableMovement,
  personalGoal,
  optionalOptimization,
}

enum WellbeingActionSource {
  dailyContext,
  wellness,
  preventive,
  goal,
  emotionalSupport,
  healthGuidance,
  userExplicitRequest,
  organization,
}

enum WellbeingEffortClass {
  veryLow,
  low,
  moderate,
  high,
}

enum WellbeingTimeCostClass {
  fewMinutes,
  short,
  moderate,
  long,
  unknown,
}

enum WellbeingSubjectKind {
  accountOwner,
  otherPerson,
  unknown,
}

/// طلب تخطيط — ليس سؤالاً عادياً.
class WellbeingPlanRequest {
  const WellbeingPlanRequest({
    required this.isPlanRequest,
    this.scope = WellbeingPlanScope.unknown,
    this.horizon = WellbeingPlanHorizon.unknown,
    this.isAboutOtherPerson = false,
    this.asksExplanation = false,
    this.asksReduce = false,
    this.asksIncrease = false,
    this.rejectsExercise = false,
    this.cannotWalkToday = false,
    this.looksLikeFollowUp = false,
    this.looksLikeEntityEscape = false,
    this.urgentMedicalHint = false,
    this.mentalSafetyHint = false,
    this.ordinaryBenefitsQuestion = false,
    this.symptomOnlyHealth = false,
    this.explicitPriorityCategory,
    this.userText = '',
  });

  final bool isPlanRequest;
  final WellbeingPlanScope scope;
  final WellbeingPlanHorizon horizon;
  final bool isAboutOtherPerson;
  final bool asksExplanation;
  final bool asksReduce;
  final bool asksIncrease;
  final bool rejectsExercise;
  final bool cannotWalkToday;
  final bool looksLikeFollowUp;
  final bool looksLikeEntityEscape;
  final bool urgentMedicalHint;
  final bool mentalSafetyHint;
  final bool ordinaryBenefitsQuestion;
  final bool symptomOnlyHealth;
  final WellbeingActionCategory? explicitPriorityCategory;
  final String userText;

  static const none = WellbeingPlanRequest(isPlanRequest: false);

  Map<String, Object?> debugMap() => {
        'isPlanRequest': isPlanRequest,
        'planScope': scope.name,
        'planHorizon': horizon.name,
        'subjectKind': isAboutOtherPerson
            ? WellbeingSubjectKind.otherPerson.name
            : WellbeingSubjectKind.accountOwner.name,
      };
}

/// مرشّح فعل — بلا تفكير حسّاس خام.
class WellbeingActionCandidate {
  const WellbeingActionCandidate({
    required this.id,
    required this.category,
    required this.source,
    required this.priority,
    required this.label,
    this.timeCost = WellbeingTimeCostClass.short,
    this.effort = WellbeingEffortClass.low,
    this.requiresHealthClearance = false,
    this.optional = false,
    this.reasonCode = '',
  });

  final String id;
  final WellbeingActionCategory category;
  final WellbeingActionSource source;
  final WellbeingActionPriority priority;
  final String label;
  final WellbeingTimeCostClass timeCost;
  final WellbeingEffortClass effort;
  final bool requiresHealthClearance;
  final bool optional;
  final String reasonCode;
}

/// فعل مختار في الخطة.
class WellbeingAction {
  const WellbeingAction({
    required this.id,
    required this.category,
    required this.source,
    required this.priority,
    required this.label,
    required this.slot,
    this.optional = false,
    this.reasonCode = '',
    this.effort = WellbeingEffortClass.low,
    this.timeCost = WellbeingTimeCostClass.short,
  });

  final String id;
  final WellbeingActionCategory category;
  final WellbeingActionSource source;
  final WellbeingActionPriority priority;
  final String label;
  /// now | next | optional
  final String slot;
  final bool optional;
  final String reasonCode;
  final WellbeingEffortClass effort;
  final WellbeingTimeCostClass timeCost;

  Map<String, Object?> debugMap() => {
        'category': category.name,
        'source': source.name,
        'slot': slot,
        'optional': optional,
        // بلا نص حسّاس خام
      };
}

/// خطة جلسة — بلا سجل دائم.
class WellbeingActionPlan {
  const WellbeingActionPlan({
    this.actions = const [],
    this.scope = WellbeingPlanScope.unknown,
    this.horizon = WellbeingPlanHorizon.unknown,
    this.oneNextStepMode = false,
    this.explanationCodes = const [],
    this.createdAt,
  });

  final List<WellbeingAction> actions;
  final WellbeingPlanScope scope;
  final WellbeingPlanHorizon horizon;
  final bool oneNextStepMode;
  final List<String> explanationCodes;
  final DateTime? createdAt;

  static const empty = WellbeingActionPlan();

  int get primaryCount =>
      actions.where((a) => a.slot != 'optional').length;

  Map<String, Object?> debugMap() => {
        'planActionCount': actions.length,
        'planPrimaryCount': primaryCount,
        'planScope': scope.name,
        'planHorizon': horizon.name,
        'oneNextStepMode': oneNextStepMode,
        'planCategories': [for (final a in actions) a.category.name],
        // بلا نقاط/streak/نسب إنجاز
      };
}

/// غلاف سياق أدنى مسموح.
class WellbeingPlanContextEnvelope {
  const WellbeingPlanContextEnvelope({
    this.resolvedSubjectKind = WellbeingSubjectKind.accountOwner,
    this.planScope = WellbeingPlanScope.unknown,
    this.planHorizon = WellbeingPlanHorizon.unknown,
    this.dailyPriority,
    this.hasHighDailyLoad = false,
    this.hasLowSleep = false,
    this.hasExamSoon = false,
    this.hasLowEnergy = false,
    this.hasStress = false,
    this.hasSedentaryWorkHint = false,
    this.eligibleWalkingGoal = false,
    this.eligibleWellnessContext = false,
    this.eligiblePreventiveContext = false,
    this.eligibleEmotionalContext = false,
    this.eligibleHealthContext = false,
    this.followUpEligibleButDefer = false,
    this.userExplicitPriority,
    this.rejectsExercise = false,
    this.cannotWalkToday = false,
    this.reduceBudget = false,
    this.increaseDetail = false,
  });

  final WellbeingSubjectKind resolvedSubjectKind;
  final WellbeingPlanScope planScope;
  final WellbeingPlanHorizon planHorizon;
  final String? dailyPriority;
  final bool hasHighDailyLoad;
  final bool hasLowSleep;
  final bool hasExamSoon;
  final bool hasLowEnergy;
  final bool hasStress;
  final bool hasSedentaryWorkHint;
  final bool eligibleWalkingGoal;
  final bool eligibleWellnessContext;
  final bool eligiblePreventiveContext;
  final bool eligibleEmotionalContext;
  final bool eligibleHealthContext;
  final bool followUpEligibleButDefer;
  final WellbeingActionCategory? userExplicitPriority;
  final bool rejectsExercise;
  final bool cannotWalkToday;
  final bool reduceBudget;
  final bool increaseDetail;

  Map<String, Object?> debugMap() => {
        'subjectKind': resolvedSubjectKind.name,
        'planScope': planScope.name,
        'planHorizon': planHorizon.name,
        'dailyPriority': dailyPriority,
        'hasHighLoad': hasHighDailyLoad,
        'eligibleWalkingGoal': eligibleWalkingGoal,
        'followUpDefer': followUpEligibleButDefer,
        // بلا عمر/تشخيص/اهتمامات غير ذات صلة
      };
}

/// جلسة المخطّط — RAM فقط.
class WellbeingPlannerSession {
  const WellbeingPlannerSession({
    this.lastPlan = WellbeingActionPlan.empty,
    this.rejectedCategories = const {},
    this.lastExplanation = '',
    this.active = false,
  });

  final WellbeingActionPlan lastPlan;
  final Set<WellbeingActionCategory> rejectedCategories;
  final String lastExplanation;
  final bool active;

  static const inactive = WellbeingPlannerSession();

  WellbeingPlannerSession copyWith({
    WellbeingActionPlan? lastPlan,
    Set<WellbeingActionCategory>? rejectedCategories,
    String? lastExplanation,
    bool? active,
  }) {
    return WellbeingPlannerSession(
      lastPlan: lastPlan ?? this.lastPlan,
      rejectedCategories: rejectedCategories ?? this.rejectedCategories,
      lastExplanation: lastExplanation ?? this.lastExplanation,
      active: active ?? this.active,
    );
  }

  Map<String, Object?> debugMap() => {
        'plannerActive': active,
        'rejectedCategoryCount': rejectedCategories.length,
        ...lastPlan.debugMap(),
      };
}

/// عقود مستقبلية — غير مفعّلة.
class PersistentWellbeingPlanContract {
  const PersistentWellbeingPlanContract();
  bool get isActive => false;
  bool get planCheckInEnabled => false;
  bool get planProgressEnabled => false;
  bool get planAdjustmentEnabled => false;
  bool get calendarIntegrationEnabled => false;
  bool get appleHealthIntegrationEnabled => false;
  bool get wearableIntegrationEnabled => false;
  bool get notificationsEnabled => false;
}

abstract class PersistentWellbeingPlan {
  String get planId;
}

abstract class PlanCheckIn {
  String get checkInId;
}

abstract class PlanProgress {
  String get progressId;
}
