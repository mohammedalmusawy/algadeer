/// PC-1.14 — أساس العافية والنشاط البدني (جلسة / سياق).
///
/// ليس محرك وصف علاجي ولا تتبع دائم.
library;

enum WellnessTopic {
  walking,
  generalMovement,
  exercise,
  sedentaryTime,
  exerciseRoutine,
  restRecovery,
  sleepRoutine,
  activityGoal,
  activityProgress,
  exerciseBarrier,
  unknownWellness,
}

enum WellnessActivityType {
  walking,
  generalMovement,
  exercise,
  rest,
  unknown,
}

enum WellnessIntent {
  none,
  askGuidance,
  setGoal,
  reportActivity,
  reportBarrier,
  askProgress,
  askRoutine,
  pauseGoal,
  resumeGoal,
  followUpRequest,
  healthRelatedActivityQuestion,
  declineWellnessAdvice,
  focusWalking,
}

enum WellnessSafetyDecision {
  safeGeneralGuidance,
  needsClarification,
  deferToMedicalSafety,
  clinicianDiscussionRecommended,
}

enum WellnessSubjectKind {
  accountOwner,
  familyOrOther,
  unknown,
}

/// تقرير نشاط — جلسة فقط، بلا دفتر يومي دائم.
class WellnessUserReport {
  const WellnessUserReport({
    required this.activityType,
    this.durationMinutes,
    this.frequencyCount,
    this.period,
    this.userReportedIntensity,
    this.completed,
    this.source = 'userReported',
  });

  final WellnessActivityType activityType;
  final int? durationMinutes;
  final int? frequencyCount;
  final String? period;
  final String? userReportedIntensity;
  final bool? completed;
  final String source;

  Map<String, Object?> debugMap() => {
        'activityType': activityType.name,
        'hasDuration': durationMinutes != null,
        'hasFrequency': frequencyCount != null,
        // بلا قيم مدة/خطوات.
      };
}

/// مسودة هدف قبل التأكيد عبر PC-1.12.
class WellnessGoalDraft {
  const WellnessGoalDraft({
    required this.canonicalKey,
    required this.displayLabel,
    this.frequencyHint,
    this.durationHint,
  });

  final String canonicalKey;
  final String displayLabel;
  final String? frequencyHint;
  final String? durationHint;
}

/// جلسة عافية — RAM فقط.
class WellnessSession {
  const WellnessSession({
    this.active = false,
    this.lastTopic = WellnessTopic.unknownWellness,
    this.lastIntent = WellnessIntent.none,
    this.pendingQuestionCount = 0,
    this.sessionReports = const [],
    this.goalDraft,
    this.adviceDeclined = false,
    this.focusWalking = false,
    this.lastSafety = WellnessSafetyDecision.safeGeneralGuidance,
    this.usedPreventiveRule = false,
    this.usedPersonalization = false,
  });

  final bool active;
  final WellnessTopic lastTopic;
  final WellnessIntent lastIntent;
  final int pendingQuestionCount;
  final List<WellnessUserReport> sessionReports;
  final WellnessGoalDraft? goalDraft;
  final bool adviceDeclined;
  final bool focusWalking;
  final WellnessSafetyDecision lastSafety;
  final bool usedPreventiveRule;
  final bool usedPersonalization;

  static const inactive = WellnessSession();

  bool get isActive => active;

  WellnessSession copyWith({
    bool? active,
    WellnessTopic? lastTopic,
    WellnessIntent? lastIntent,
    int? pendingQuestionCount,
    List<WellnessUserReport>? sessionReports,
    WellnessGoalDraft? goalDraft,
    bool clearGoalDraft = false,
    bool? adviceDeclined,
    bool? focusWalking,
    WellnessSafetyDecision? lastSafety,
    bool? usedPreventiveRule,
    bool? usedPersonalization,
  }) {
    return WellnessSession(
      active: active ?? this.active,
      lastTopic: lastTopic ?? this.lastTopic,
      lastIntent: lastIntent ?? this.lastIntent,
      pendingQuestionCount:
          pendingQuestionCount ?? this.pendingQuestionCount,
      sessionReports: sessionReports ?? this.sessionReports,
      goalDraft: clearGoalDraft ? null : (goalDraft ?? this.goalDraft),
      adviceDeclined: adviceDeclined ?? this.adviceDeclined,
      focusWalking: focusWalking ?? this.focusWalking,
      lastSafety: lastSafety ?? this.lastSafety,
      usedPreventiveRule: usedPreventiveRule ?? this.usedPreventiveRule,
      usedPersonalization: usedPersonalization ?? this.usedPersonalization,
    );
  }

  Map<String, Object?> debugMap() => {
        'wellnessIntent': lastIntent.name,
        'wellnessTopic': lastTopic.name,
        'safetyDecision': lastSafety.name,
        'questionCount': pendingQuestionCount,
        'usedPreventiveRule': usedPreventiveRule,
        'usedPersonalization': usedPersonalization,
        'sessionReportCount': sessionReports.length,
        // بلا مدة/خطوات/أعراض.
      };
}

/// —— عقود مستقبلية (غير مفعّلة في PC-1.14) ——

/// مستقبل: سجل نشاط دائم — غير مُنفَّذ.
abstract class ActivityRecord {
  String get activityId;
  String get source; // userReported | AppleHealth | wearable | deviceSensors
}

/// مستقبل: مستودع تتبع — غير مُنفَّذ.
abstract class ActivityTrackingRepository {
  Future<void> save(ActivityRecord record);
  Future<List<ActivityRecord>> loadRecent();
}

/// مستقبل: مصدر wearable — غير مُنفَّذ.
abstract class WearableActivitySource {
  Future<List<ActivityRecord>> fetch();
}

/// مستقبل: خطة عافية — غير مُنفَّذة.
abstract class WellnessPlan {
  String get planId;
}

/// مستقبل: تقدم نشاط — غير مُنفَّذ.
abstract class ActivityProgress {
  String get progressId;
}

/// مستقبل: توجيه تكيّفي — غير مُنفَّذ.
abstract class AdaptiveActivityGuidance {
  String get guidanceId;
}

/// علامة صريحة: التتبع الدائم غير مفعّل.
class ActivityTrackingContract {
  const ActivityTrackingContract();
  bool get isActive => false;
  bool get wearableIntegrationEnabled => false;
  bool get appleHealthIntegrationEnabled => false;
}

class WellnessCoachingContract {
  const WellnessCoachingContract();
  bool get autonomousCoachingEnabled => false;
}
