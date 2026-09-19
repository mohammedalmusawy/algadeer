/// PC-1.24 — تنسيق الدماغ الموحّد (تحكيم؛ ليس محركاً طبياً شاملاً).
library;

/// مصدر حقيقة مستخدمة في التحكيم.
enum BrainFactSource {
  explicitCurrentTurn,
  explicitConversation,
  trustedProfile,
  sensitiveProfile,
  clinicalMeasurementStore,
  derivedFromBirthDate,
  derivedFromBirthYear,
  domainSession,
  unknown,
}

enum BrainAuthorityId {
  safety10E,
  mentalCrisis,
  followUp,
  pregnancy,
  dental,
  msk,
  respiratory,
  chronicClinical,
  adolescent,
  clinicalKnowledge,
  emotional,
  dailyContext,
  wellbeingPlanner,
  activity,
  goals,
  personalization,
  serviceEntity,
  fallback,
  none,
}

enum BrainAuthorityRole {
  primary,
  contextual,
  safety,
  emotional,
  planning,
  service,
  followUp,
  memory,
  suppressed,
  supportOnly,
  safetyOnly,
}

enum BrainPrimaryIntent {
  currentSymptom,
  healthQuestion,
  serviceSearch,
  followUpCommand,
  memoryCommand,
  dailyPlanning,
  goal,
  emotionalSupport,
  education,
  providerQuestion,
  labQuestion,
  radiologyQuestion,
  pregnancyCare,
  dentalConcern,
  adolescentLifeConcern,
  greeting,
  cancel,
  unknown,
}

enum AgeProvenance {
  exactBirthDateDerived,
  birthYearDerived,
  explicitCurrentAge,
  approximateAge,
  unknown,
}

class AgeResolution {
  const AgeResolution({
    this.ageYears,
    this.provenance = AgeProvenance.unknown,
  });

  final int? ageYears;
  final AgeProvenance provenance;

  static const unknown = AgeResolution();

  bool get isKnown => ageYears != null;
}

/// سياق دورة موحّد — حقائق دورة مقابل جلسة مقابل دائم.
class UnifiedBrainTurnContext {
  const UnifiedBrainTurnContext({
    required this.query,
    this.primaryIntent = BrainPrimaryIntent.unknown,
    this.subjectResolved = false,
    this.isAboutOtherPerson = false,
    this.age = AgeResolution.unknown,
    this.hasPregnancyCue = false,
    this.hasAdolescentCue = false,
    this.hasDentalCue = false,
    this.hasMskCue = false,
    this.hasRespiratoryCue = false,
    this.hasChronicCue = false,
    this.isServiceOrNavigationIntent = false,
    this.isGreeting = false,
    this.isCancel = false,
    this.isExplicitFollowUp = false,
    this.isEducational = false,
    this.hasCorrection = false,
    this.hasNegation = false,
  });

  final String query;
  final BrainPrimaryIntent primaryIntent;
  final bool subjectResolved;
  final bool isAboutOtherPerson;
  final AgeResolution age;
  final bool hasPregnancyCue;
  final bool hasAdolescentCue;
  final bool hasDentalCue;
  final bool hasMskCue;
  final bool hasRespiratoryCue;
  final bool hasChronicCue;
  final bool isServiceOrNavigationIntent;
  final bool isGreeting;
  final bool isCancel;
  final bool isExplicitFollowUp;
  final bool isEducational;
  final bool hasCorrection;
  final bool hasNegation;

  /// دورة أجنبية عن الشكاوى السريرية النشطة (بحث خدمة / تحية / إلغاء).
  bool get isForeignToClinicalSessions =>
      isServiceOrNavigationIntent || isGreeting || isCancel;
}

class UnifiedBrainCandidate {
  const UnifiedBrainCandidate({
    required this.authority,
    required this.role,
    required this.priority,
    this.mayHandleReason = 'explicitIntent',
    this.suppressionReason,
  });

  final BrainAuthorityId authority;
  final BrainAuthorityRole role;
  final int priority;
  final String mayHandleReason;
  final String? suppressionReason;
}

class BrainContribution {
  const BrainContribution({
    required this.authority,
    required this.role,
    required this.priority,
    this.message = '',
    this.safetyDeferred = false,
    this.mentalSafetyDeferred = false,
    this.clarificationQuestion,
    this.destinationHint,
    this.suppress = false,
    this.suppressionReason,
  });

  final BrainAuthorityId authority;
  final BrainAuthorityRole role;
  final int priority;
  final String message;
  final bool safetyDeferred;
  final bool mentalSafetyDeferred;
  final String? clarificationQuestion;
  final String? destinationHint;
  final bool suppress;
  final String? suppressionReason;
}

/// خطة رد واحدة قبل التصيير.
class UnifiedBrainResponsePlan {
  const UnifiedBrainResponsePlan({
    required this.primaryAuthority,
    this.contextualAuthorities = const [],
    this.suppressedAuthorities = const [],
    this.safetyMode = false,
    this.mentalCrisisMode = false,
    this.acknowledgement = '',
    this.coreAnswer = '',
    this.nextAction = '',
    this.clarificationQuestion,
    this.questionBudgetUsed = false,
    this.serviceHandoff = false,
    this.fallbackUsed = false,
    this.message = '',
  });

  final BrainAuthorityId primaryAuthority;
  final List<BrainAuthorityId> contextualAuthorities;
  final List<BrainAuthorityId> suppressedAuthorities;
  final bool safetyMode;
  final bool mentalCrisisMode;
  final String acknowledgement;
  final String coreAnswer;
  final String nextAction;
  final String? clarificationQuestion;
  final bool questionBudgetUsed;
  final bool serviceHandoff;
  final bool fallbackUsed;
  final String message;

  /// تشخيص آمن للاختبارات — بلا نص حسّاس خام.
  Map<String, Object?> debugMap() => {
        'primaryIntent': primaryAuthority.name,
        'selectedPrimaryAuthority': primaryAuthority.name,
        'contextualAuthorityIds':
            contextualAuthorities.map((e) => e.name).toList(growable: false),
        'suppressedAuthorityIds':
            suppressedAuthorities.map((e) => e.name).toList(growable: false),
        'safetyAuthorityInvoked': safetyMode || mentalCrisisMode,
        'questionBudgetUsed': questionBudgetUsed,
        'serviceHandoff': serviceHandoff,
        'fallbackUsed': fallbackUsed,
      };
}

/// تشخيص دورة آمن.
class UnifiedBrainDiagnostics {
  const UnifiedBrainDiagnostics({
    this.subjectResolved = false,
    this.primaryIntent = BrainPrimaryIntent.unknown,
    this.candidateAuthorityIds = const [],
    this.selectedPrimaryAuthority = BrainAuthorityId.none,
    this.contextualAuthorityIds = const [],
    this.safetyAuthorityInvoked = false,
    this.questionBudgetUsed = false,
    this.serviceHandoff = false,
    this.fallbackUsed = false,
    this.suppressionReasonIds = const [],
    this.clinicalSessionsClearedForForeignTurn = false,
    this.ageProvenance = AgeProvenance.unknown,
  });

  final bool subjectResolved;
  final BrainPrimaryIntent primaryIntent;
  final List<String> candidateAuthorityIds;
  final BrainAuthorityId selectedPrimaryAuthority;
  final List<String> contextualAuthorityIds;
  final bool safetyAuthorityInvoked;
  final bool questionBudgetUsed;
  final bool serviceHandoff;
  final bool fallbackUsed;
  final List<String> suppressionReasonIds;
  final bool clinicalSessionsClearedForForeignTurn;
  final AgeProvenance ageProvenance;

  static const empty = UnifiedBrainDiagnostics();

  Map<String, Object?> toDebugMap() => {
        'subjectResolved': subjectResolved,
        'primaryIntent': primaryIntent.name,
        'candidateAuthorityIds': candidateAuthorityIds,
        'selectedPrimaryAuthority': selectedPrimaryAuthority.name,
        'contextualAuthorityIds': contextualAuthorityIds,
        'safetyAuthorityInvoked': safetyAuthorityInvoked,
        'questionBudgetUsed': questionBudgetUsed,
        'serviceHandoff': serviceHandoff,
        'fallbackUsed': fallbackUsed,
        'suppressionReasonIds': suppressionReasonIds,
        'clinicalSessionsClearedForForeignTurn':
            clinicalSessionsClearedForForeignTurn,
        'ageProvenance': ageProvenance.name,
        // بلا personId / transcript / قيم طبية خام
      };
}
