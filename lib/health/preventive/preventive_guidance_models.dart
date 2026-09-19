/// PC-1.7 — توجيه وقائي قائم على قواعد مراجَعة، بلا تشخيص ولا وصفات.
library;

/// مستوى التخصيص — يحدد عمق النصحة.
enum PreventivePersonalizationLevel {
  general,
  contextual,
  healthContextual,
  clinicianRequired,
}

/// نوع التوجيه الوقائي.
enum PreventiveGuidanceType {
  physicalActivity,
  healthyDiet,
  saltReduction,
  sleepRoutine,
  screeningDiscussion,
  studentRoutine,
  movementBreak,
  tobaccoAvoidance,
  weightAwareness,
  hydration,
  examPeriodRoutine,
}

/// موضوع طلب المستخدم.
enum PreventiveGuidanceTopic {
  general,
  ageAppropriate,
  student,
  examPeriod,
  diet,
  walking,
  screening,
  salt,
  activity,
  employeeRoutine,
  selfEmployedRoutine,
}

/// نية وقائية — للتصحيح والتحليلات العامة فقط.
enum PreventiveIntent {
  none,
  requestedAdvice,
  moreAdvice,
  ageAppropriateAdvice,
  studentAdvice,
  examPeriodAdvice,
  dietAdvice,
  walkingAdvice,
  screeningDiscussion,
  generalPrevention,
}

/// جلسة توجيه وقائي — RAM فقط.
class PreventiveGuidanceSession {
  const PreventiveGuidanceSession({
    this.status = PreventiveGuidanceSessionStatus.inactive,
    this.lastTopic = PreventiveGuidanceTopic.general,
    this.deliveredRuleIds = const [],
    this.pendingMore = false,
    this.lastUpdatedTurnId = 0,
  });

  final PreventiveGuidanceSessionStatus status;
  final PreventiveGuidanceTopic lastTopic;
  final List<String> deliveredRuleIds;
  final bool pendingMore;
  final int lastUpdatedTurnId;

  static const inactive = PreventiveGuidanceSession();

  bool get isActive => status == PreventiveGuidanceSessionStatus.active;

  PreventiveGuidanceSession copyWith({
    PreventiveGuidanceSessionStatus? status,
    PreventiveGuidanceTopic? lastTopic,
    List<String>? deliveredRuleIds,
    bool? pendingMore,
    int? lastUpdatedTurnId,
  }) {
    return PreventiveGuidanceSession(
      status: status ?? this.status,
      lastTopic: lastTopic ?? this.lastTopic,
      deliveredRuleIds: deliveredRuleIds ?? this.deliveredRuleIds,
      pendingMore: pendingMore ?? this.pendingMore,
      lastUpdatedTurnId: lastUpdatedTurnId ?? this.lastUpdatedTurnId,
    );
  }

  Map<String, Object?> debugMap() => {
        'preventiveIntent': status.name,
        'guidanceTopic': lastTopic.name,
        'ruleCount': deliveredRuleIds.length,
        // بلا عمر/حالات.
      };
}

enum PreventiveGuidanceSessionStatus {
  inactive,
  active,
  completed,
}

/// نتيجة منسّق التوجيه الوقائي.
class PreventiveGuidanceTurnResult {
  const PreventiveGuidanceTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.deferToUrgentSafety = false,
    this.deferToMentalSafety = false,
    this.textFirstOnly = true,
    this.ruleIds = const [],
    this.personalizationLevel = PreventivePersonalizationLevel.general,
    this.intent = PreventiveIntent.none,
  });

  final bool handled;
  final String message;
  final PreventiveGuidanceSession session;
  final bool deferToUrgentSafety;
  final bool deferToMentalSafety;
  final bool textFirstOnly;
  final List<String> ruleIds;
  final PreventivePersonalizationLevel personalizationLevel;
  final PreventiveIntent intent;

  static PreventiveGuidanceTurnResult notHandled(
    PreventiveGuidanceSession session,
  ) =>
      PreventiveGuidanceTurnResult(
        handled: false,
        message: '',
        session: session,
      );

  Map<String, Object?> debugMap() => {
        'preventiveIntent': intent.name,
        'guidanceTopic': session.lastTopic.name,
        'personalizationLevel': personalizationLevel.name,
        'ruleCount': ruleIds.length,
        for (var i = 0; i < ruleIds.length; i++) 'ruleId_$i': ruleIds[i],
      };
}

/// خطة توجيه — قواعد مختارة للعرض.
class PreventiveGuidancePlan {
  const PreventiveGuidancePlan({
    required this.selectedRuleIds,
    required this.personalizationLevel,
    required this.topic,
    this.hasMore = false,
    this.intent = PreventiveIntent.requestedAdvice,
  });

  final List<String> selectedRuleIds;
  final PreventivePersonalizationLevel personalizationLevel;
  final PreventiveGuidanceTopic topic;
  final bool hasMore;
  final PreventiveIntent intent;

  static const empty = PreventiveGuidancePlan(
    selectedRuleIds: [],
    personalizationLevel: PreventivePersonalizationLevel.general,
    topic: PreventiveGuidanceTopic.general,
  );
}
