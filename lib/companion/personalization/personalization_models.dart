/// PC-1.13 — تخصيص سياقي واستدعاء طبيعي للذاكرة.
///
/// لا مخزن ثانٍ — يستعلم المصادر السلطوية الموجودة فقط.
library;

enum PersonalizationSource {
  companionProfile,
  personalMemory,
  sensitiveHealth,
  familyPerson,
  familySensitiveHealth,
  chronicCare,
  followUp,
  conversationContext,
}

enum PersonalizationPurpose {
  answerCurrentQuestion,
  learningSupport,
  contentSupport,
  goalSupport,
  healthGuidance,
  chronicCare,
  preventiveGuidance,
  followUpContinuation,
  providerDiscovery,
  conversationContinuity,
  /// طلب صريح لعرض/استخدام الذاكرة.
  explicitMemoryQuery,
  /// تعطيل التخصيص لهذه الدورة.
  disabledByUser,
  none,
}

enum PersonalizationMentionMode {
  none,
  implicit,
  explicit,
}

enum PersonalizationDecisionState {
  notRelevant,
  relevant,
  relevantButSensitive,
  needsClarification,
  blockedByPrivacy,
  disabledByUser,
  failedSafe,
}

enum PersonalizationFreshnessState {
  fresh,
  possiblyStale,
  unknownFreshness,
}

enum PersonalizationSubjectKind {
  accountOwner,
  persistentFamilyPerson,
  temporaryOtherPerson,
  unknown,
  ambiguous,
}

/// مرشّح تخصيص معتمد — بدون نص مستودع خام في debug.
class PersonalizationCandidate {
  const PersonalizationCandidate({
    required this.opaqueKey,
    required this.source,
    required this.category,
    required this.displaySafeLabel,
    this.sensitive = false,
    this.freshness = PersonalizationFreshnessState.unknownFreshness,
    this.influenceOnly = true,
  });

  /// مفتاح جلسة فقط — ليس memoryId كاملاً في التحليلات.
  final String opaqueKey;
  final PersonalizationSource source;
  final String category;
  /// تسمية آمنة للعرض عند الذكر الصريح فقط.
  final String displaySafeLabel;
  final bool sensitive;
  final PersonalizationFreshnessState freshness;
  final bool influenceOnly;

  Map<String, Object?> debugMap() => {
        'source': source.name,
        'category': category,
        'sensitive': sensitive,
        'freshness': freshness.name,
        // بلا displaySafeLabel / محتوى.
      };
}

class PersonalizationBudget {
  const PersonalizationBudget({
    this.maxFacts = 2,
    this.maxSensitiveFacts = 1,
  });

  final int maxFacts;
  final int maxSensitiveFacts;

  static const standard = PersonalizationBudget();
  static const sensitivePreferMinimal =
      PersonalizationBudget(maxFacts: 1, maxSensitiveFacts: 1);
  static const zero = PersonalizationBudget(maxFacts: 0, maxSensitiveFacts: 0);
}

/// ظرف تخصيص أدنى — ما يُسمح بتعريضه للرد فقط.
class PersonalizationEnvelope {
  const PersonalizationEnvelope({
    required this.purpose,
    required this.subjectKind,
    required this.decisionState,
    this.selectedCandidates = const [],
    this.mentionMode = PersonalizationMentionMode.none,
    this.budgetUsed = 0,
    this.containsSensitiveContext = false,
    this.freshnessState = PersonalizationFreshnessState.unknownFreshness,
    this.clarificationHint = '',
    this.routeCorrectionToPersonalMemory = false,
    this.turnPreferenceOverride,
  });

  final PersonalizationPurpose purpose;
  final PersonalizationSubjectKind subjectKind;
  final PersonalizationDecisionState decisionState;
  final List<PersonalizationCandidate> selectedCandidates;
  final PersonalizationMentionMode mentionMode;
  final int budgetUsed;
  final bool containsSensitiveContext;
  final PersonalizationFreshnessState freshnessState;
  final String clarificationHint;
  final bool routeCorrectionToPersonalMemory;
  /// تفضيل مؤقت لهذه الدورة فقط (مثل الاختصار) — لا يحذف المخزّن.
  final String? turnPreferenceOverride;

  static const empty = PersonalizationEnvelope(
    purpose: PersonalizationPurpose.none,
    subjectKind: PersonalizationSubjectKind.unknown,
    decisionState: PersonalizationDecisionState.notRelevant,
  );

  bool get hasUsableContext =>
      selectedCandidates.isNotEmpty &&
      decisionState != PersonalizationDecisionState.blockedByPrivacy &&
      decisionState != PersonalizationDecisionState.disabledByUser &&
      decisionState != PersonalizationDecisionState.failedSafe;

  Map<String, Object?> debugMap() => {
        'personalizationPurpose': purpose.name,
        'candidateCount': selectedCandidates.length,
        'selectedCount': selectedCandidates.length,
        'mentionMode': mentionMode.name,
        'budgetUsed': budgetUsed,
        'containsSensitiveContext': containsSensitiveContext,
        'decisionState': decisionState.name,
        'freshnessState': freshnessState.name,
        'subjectKind': subjectKind.name,
        // بلا محتوى ذاكرة / أسماء / تشخيص.
      };
}

/// تتبع جلسة فقط — مفاتيح بلا قيم حسّاسة.
class PersonalizationSessionState {
  const PersonalizationSessionState({
    this.recentlyUsedMemoryKeys = const [],
    this.recentExplicitMentions = const [],
    this.lastPersonalizationPurpose,
    this.turnsSinceNameUsed = 99,
    this.lastEnvelopeDebug = const {},
  });

  final List<String> recentlyUsedMemoryKeys;
  final List<String> recentExplicitMentions;
  final PersonalizationPurpose? lastPersonalizationPurpose;
  final int turnsSinceNameUsed;
  final Map<String, Object?> lastEnvelopeDebug;

  static const empty = PersonalizationSessionState();

  PersonalizationSessionState copyWith({
    List<String>? recentlyUsedMemoryKeys,
    List<String>? recentExplicitMentions,
    PersonalizationPurpose? lastPersonalizationPurpose,
    int? turnsSinceNameUsed,
    Map<String, Object?>? lastEnvelopeDebug,
  }) {
    return PersonalizationSessionState(
      recentlyUsedMemoryKeys:
          recentlyUsedMemoryKeys ?? this.recentlyUsedMemoryKeys,
      recentExplicitMentions:
          recentExplicitMentions ?? this.recentExplicitMentions,
      lastPersonalizationPurpose:
          lastPersonalizationPurpose ?? this.lastPersonalizationPurpose,
      turnsSinceNameUsed: turnsSinceNameUsed ?? this.turnsSinceNameUsed,
      lastEnvelopeDebug: lastEnvelopeDebug ?? this.lastEnvelopeDebug,
    );
  }

  Map<String, Object?> debugMap() => {
        'recentPersonalizationKeyCount': recentlyUsedMemoryKeys.length,
        'recentExplicitMentionCount': recentExplicitMentions.length,
        'lastPersonalizationPurpose': lastPersonalizationPurpose?.name,
        'turnsSinceNameUsed': turnsSinceNameUsed,
        ...lastEnvelopeDebug,
      };
}

/// سياق إدخال منسّق التخصيص لدورة واحدة.
class PersonalizationTurnInput {
  const PersonalizationTurnInput({
    required this.query,
    required this.subjectKind,
    this.persistentPersonId,
    this.planKindName = '',
    this.intentName = '',
    this.urgentSafety = false,
    this.mentalSafety = false,
    this.emotionalDistress = false,
    this.userRequestsNoPersonalization = false,
    this.userRequestsUseMemory = false,
    this.session = PersonalizationSessionState.empty,
  });

  final String query;
  final PersonalizationSubjectKind subjectKind;
  final String? persistentPersonId;
  final String planKindName;
  final String intentName;
  final bool urgentSafety;
  final bool mentalSafety;
  final bool emotionalDistress;
  final bool userRequestsNoPersonalization;
  final bool userRequestsUseMemory;
  final PersonalizationSessionState session;
}
