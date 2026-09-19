import '../../doctors/specialty_catalog.dart';
import '../../voice/guided_conversation/guided_conversation_models.dart';
import '../subject/health_subject_models.dart';
import '../understanding/symptom_models.dart';
import 'health_guidance_handoff.dart';

export 'health_guidance_handoff.dart'
    show
        HealthGuidanceHandoff,
        HealthGuidanceHandoffStatus,
        ProviderDiscoveryResult,
        ProviderDiscoveryStatus;

/// نوع قرار التوجيه الصحي — بلا تشخيص.
enum HealthGuidanceDecisionType {
  needMoreInformation,
  specialtyDirection,
  generalEvaluation,
  urgentEvaluation,
  emergencyEvaluation,
  unableToDetermine,
}

enum HealthGuidanceSessionStatus {
  inactive,
  active,
  waitingForAnswer,
  decided,
  cancelled,
  completed,
}

/// نوع وجهة التوجيه — قابل للتوسّع (أشعة/CT/MRI لاحقاً بدون تفعيل الآن).
enum GuidanceDestinationType {
  specialty,
  generalMedicalEvaluation,
  urgentEvaluation,

  /// وجهة مختبر صريحة فقط عند طلب مستقبلي مسيطر عليه — بلا اختراع من الأعراض.
  laboratory,

  /// خدمة تشخيصية عامة مستقبلية — بلا تفعيل في 10F.
  diagnosticService,

  /// محجوز للمستقبل — لا توصية تصوير في Step 10C/10F.
  radiologyReserved,
  ultrasoundReserved,
  ctReserved,
  mriReserved,
}

/// وجهة توجيه مستقرة — بدون أسماء أطباء.
class GuidanceDestination {
  const GuidanceDestination({
    required this.type,
    required this.key,
    required this.displayNameAr,
    this.specialtyCatalogId,
  });

  final GuidanceDestinationType type;
  final String key;
  final String displayNameAr;

  /// يطابق SpecialtyCatalog.id عند type=specialty.
  final String? specialtyCatalogId;

  static GuidanceDestination specialtyFromCatalog(String catalogId) {
    SpecialtyDefinition? def;
    for (final s in SpecialtyCatalog.all) {
      if (s.id == catalogId) {
        def = s;
        break;
      }
    }
    if (def == null) {
      return GuidanceDestination(
        type: GuidanceDestinationType.specialty,
        key: catalogId,
        displayNameAr: catalogId,
        specialtyCatalogId: catalogId,
      );
    }
    return GuidanceDestination(
      type: GuidanceDestinationType.specialty,
      key: def.id,
      displayNameAr: def.nameAr,
      specialtyCatalogId: def.id,
    );
  }

  static const general = GuidanceDestination(
    type: GuidanceDestinationType.generalMedicalEvaluation,
    key: 'general_medical_evaluation',
    displayNameAr: 'تقييم طبي عام',
  );

  static const urgent = GuidanceDestination(
    type: GuidanceDestinationType.urgentEvaluation,
    key: 'urgent_evaluation',
    displayNameAr: 'تقييم طبي عاجل',
  );

  static const emergency = GuidanceDestination(
    type: GuidanceDestinationType.urgentEvaluation,
    key: 'emergency_evaluation',
    displayNameAr: 'رعاية طبية طارئة',
  );
}

/// شرط عرض مطلوب/مستبعد.
class SymptomRequirement {
  const SymptomRequirement({
    required this.conceptId,
    this.polarity = SymptomPolarity.present,
    this.allowUncertain = false,
  });

  final String conceptId;
  final SymptomPolarity polarity;
  final bool allowUncertain;
}

/// حقل ناقص يطلب سؤالاً موجَّهاً.
enum HealthMissingFact {
  duration,
  bodyRegion,
  laterality,
  severity,
  onset,
  associatedFever,
  patientIsChild,
  abdominalLocationDetail,
}

/// قاعدة توجيه صحي قابلة للإدارة لاحقاً من Admin.
class HealthGuidanceRule {
  const HealthGuidanceRule({
    required this.id,
    required this.priority,
    required this.destination,
    this.enabled = true,
    this.requiredSymptoms = const [],
    this.optionalSymptoms = const [],
    this.excludedSymptoms = const [],
    this.bodyRegions = const [],
    this.requireLaterality,
    this.minSeverity,
    this.requireOnset,
    this.requirePatientIsChild = false,
    this.missingFactsIfIncomplete = const [],
    this.followUpQuestionBuilders = const {},
    this.rationaleCode = '',
    this.isUrgentSafety = false,
    this.minPresentSymptomCount = 1,
  });

  final String id;
  final bool enabled;
  final int priority;
  final List<SymptomRequirement> requiredSymptoms;
  final List<String> optionalSymptoms;
  final List<SymptomRequirement> excludedSymptoms;
  final List<BodyRegionId> bodyRegions;
  final Laterality? requireLaterality;
  final UserStatedSeverity? minSeverity;
  final OnsetPattern? requireOnset;
  final bool requirePatientIsChild;
  final List<HealthMissingFact> missingFactsIfIncomplete;
  final Map<HealthMissingFact, GuidedQuestion> followUpQuestionBuilders;
  final GuidanceDestination destination;
  final String rationaleCode;
  final bool isUrgentSafety;
  final int minPresentSymptomCount;
}

/// نتيجة تقييم قاعدة واحدة.
class HealthRuleEvaluation {
  const HealthRuleEvaluation({
    required this.ruleId,
    required this.eligible,
    this.matchedRequiredFacts = const [],
    this.missingRequiredFacts = const [],
    this.excludedByFacts = false,
    this.specificity = 0,
  });

  final String ruleId;
  final bool eligible;
  final List<String> matchedRequiredFacts;
  final List<HealthMissingFact> missingRequiredFacts;
  final bool excludedByFacts;
  final int specificity;
}

/// قرار توجيه نهائي للجلسة.
class HealthGuidanceDecision {
  const HealthGuidanceDecision({
    required this.type,
    this.destination,
    this.nextQuestion,
    this.missingFact,
    this.safetyMessage,
    this.userMessage = '',
    this.matchedRuleId,
    this.rationaleCode,
    this.allowCommercialOffers = true,
    this.suggestShowSpecialtyDoctors = false,
  });

  final HealthGuidanceDecisionType type;
  final GuidanceDestination? destination;
  final GuidedQuestion? nextQuestion;
  final HealthMissingFact? missingFact;
  final String? safetyMessage;
  final String userMessage;
  final String? matchedRuleId;
  final String? rationaleCode;

  /// false لمسار urgent — لا عروض/باقات.
  final bool allowCommercialOffers;
  final bool suggestShowSpecialtyDoctors;
}

/// حقائق مرتبطة بعرض محدد (منع تسرّب المدة بين الأعراض).
class SymptomScopedFacts {
  const SymptomScopedFacts({
    this.duration,
    this.severity = UserStatedSeverity.unknown,
    this.onset = OnsetPattern.unknown,
    this.temporalModifiers = const [],
    this.laterality = Laterality.unknown,
  });

  final DurationValue? duration;
  final UserStatedSeverity severity;
  final OnsetPattern onset;
  final List<String> temporalModifiers;
  final Laterality laterality;

  SymptomScopedFacts copyWith({
    DurationValue? duration,
    UserStatedSeverity? severity,
    OnsetPattern? onset,
    List<String>? temporalModifiers,
    Laterality? laterality,
    bool clearDuration = false,
  }) {
    return SymptomScopedFacts(
      duration: clearDuration ? null : (duration ?? this.duration),
      severity: severity ?? this.severity,
      onset: onset ?? this.onset,
      temporalModifiers: temporalModifiers ?? this.temporalModifiers,
      laterality: laterality ?? this.laterality,
    );
  }
}

/// حقائق مهيكلة متراكمة في الجلسة — بلا نص حر خام للتخزين.
///
/// PC-0.3: الحقائق تخص [subject] فقط.
/// SUBJECT HEALTH FACT ≠ ACCOUNT OWNER HEALTH FACT
/// SESSION SUBJECT ≠ PERSISTENT PERSON PROFILE
class HealthSessionFacts {
  const HealthSessionFacts({
    this.symptomStatuses = const {},
    this.bodyRegions = const {},
    this.laterality = Laterality.unknown,
    this.userSeverity = UserStatedSeverity.unknown,
    this.onset = OnsetPattern.unknown,
    this.duration,
    this.temporalModifiers = const [],
    this.patientIsChild,
    this.ageGroup,
    this.symptomFacts = const {},
    this.abdominalLocationResolved = false,
    this.subject = HealthSubjectContext.unknown,
  });

  /// conceptId → polarity
  final Map<String, SymptomPolarity> symptomStatuses;
  final Set<BodyRegionId> bodyRegions;
  final Laterality laterality;
  final UserStatedSeverity userSeverity;
  final OnsetPattern onset;
  final DurationValue? duration;
  final List<String> temporalModifiers;

  /// توافق مع قواعد الطفل/البالغ — يُشتق من [subject] عند الإمكان.
  final bool? patientIsChild;
  final String? ageGroup;

  /// حقائق لكل عرض — تمنع تسرّب المدة/الشدة بين الأعراض.
  final Map<String, SymptomScopedFacts> symptomFacts;
  final bool abdominalLocationResolved;

  /// الشخص الخاضع للنقاش الصحي (جلسة فقط).
  final HealthSubjectContext subject;

  HealthSessionFacts mergeUnderstanding(HealthUnderstandingResult u) {
    final statuses = Map<String, SymptomPolarity>.from(symptomStatuses);
    for (final s in u.symptoms) {
      statuses[s.conceptId] = s.status;
    }
    final regions = {...bodyRegions, ...u.bodyRegions};
    for (final s in u.symptoms) {
      if (s.bodyRegion != null) regions.add(s.bodyRegion!);
    }

    Laterality lat = laterality;
    if (u.laterality != Laterality.unknown) lat = u.laterality;
    for (final s in u.symptoms) {
      if (s.laterality != Laterality.unknown) lat = s.laterality;
    }

    UserStatedSeverity sev = userSeverity;
    if (u.userSeverity != UserStatedSeverity.unknown) sev = u.userSeverity;
    for (final s in u.symptoms) {
      if (s.userSeverity != UserStatedSeverity.unknown) {
        sev = s.userSeverity;
      }
    }

    OnsetPattern on = onset;
    if (u.onset != OnsetPattern.unknown) on = u.onset;

    final scoped = Map<String, SymptomScopedFacts>.from(symptomFacts);
    for (final s in u.symptoms) {
      final cur = scoped[s.conceptId] ?? const SymptomScopedFacts();
      scoped[s.conceptId] = cur.copyWith(
        duration: s.duration ?? cur.duration,
        severity: s.userSeverity != UserStatedSeverity.unknown
            ? s.userSeverity
            : cur.severity,
        onset: s.onset != OnsetPattern.unknown ? s.onset : cur.onset,
        laterality: s.laterality != Laterality.unknown
            ? s.laterality
            : cur.laterality,
        temporalModifiers: s.temporalModifiers.isNotEmpty
            ? s.temporalModifiers
            : cur.temporalModifiers,
      );
    }

    return HealthSessionFacts(
      symptomStatuses: Map.unmodifiable(statuses),
      bodyRegions: Set.unmodifiable(regions),
      laterality: lat,
      userSeverity: sev,
      onset: on,
      duration: u.duration ?? duration,
      temporalModifiers: u.temporalModifiers.isNotEmpty
          ? List.unmodifiable(u.temporalModifiers)
          : temporalModifiers,
      patientIsChild: patientIsChild,
      ageGroup: ageGroup,
      symptomFacts: Map.unmodifiable(scoped),
      abdominalLocationResolved: abdominalLocationResolved ||
          (lat != Laterality.unknown &&
              statuses['abdominal_pain'] == SymptomPolarity.present),
      subject: subject,
    );
  }

  HealthSessionFacts copyWith({
    Map<String, SymptomPolarity>? symptomStatuses,
    Set<BodyRegionId>? bodyRegions,
    Laterality? laterality,
    UserStatedSeverity? userSeverity,
    OnsetPattern? onset,
    DurationValue? duration,
    List<String>? temporalModifiers,
    bool? patientIsChild,
    String? ageGroup,
    Map<String, SymptomScopedFacts>? symptomFacts,
    bool? abdominalLocationResolved,
    HealthSubjectContext? subject,
    bool clearPatientIsChild = false,
    bool clearDuration = false,
  }) {
    return HealthSessionFacts(
      symptomStatuses: symptomStatuses ?? this.symptomStatuses,
      bodyRegions: bodyRegions ?? this.bodyRegions,
      laterality: laterality ?? this.laterality,
      userSeverity: userSeverity ?? this.userSeverity,
      onset: onset ?? this.onset,
      duration: clearDuration ? null : (duration ?? this.duration),
      temporalModifiers: temporalModifiers ?? this.temporalModifiers,
      patientIsChild:
          clearPatientIsChild ? null : (patientIsChild ?? this.patientIsChild),
      ageGroup: ageGroup ?? this.ageGroup,
      symptomFacts: symptomFacts ?? this.symptomFacts,
      abdominalLocationResolved:
          abdominalLocationResolved ?? this.abdominalLocationResolved,
      subject: subject ?? this.subject,
    );
  }

  /// يطبّق موضوعاً ويشتق patientIsChild/ageGroup دون مسح الأعراض.
  HealthSessionFacts withSubject(HealthSubjectContext next) {
    final child = next.isChild ??
        (next.type == HealthSubjectType.child ? true : null);
    if (child == null && next.type == HealthSubjectType.unknown) {
      return copyWith(subject: next);
    }
    return copyWith(
      subject: next,
      patientIsChild: child ?? patientIsChild,
      ageGroup: next.ageGroup ?? ageGroup,
    );
  }

  Map<String, Object?> debugMap() => {
        'symptomConceptIds': symptomStatuses.keys.toList(),
        'symptomPolarities': {
          for (final e in symptomStatuses.entries) e.key: e.value.name,
        },
        'bodyRegions': bodyRegions.map((e) => e.name).toList(),
        'laterality': laterality.name,
        'userSeverity': userSeverity.name,
        'onset': onset.name,
        'hasDuration': duration != null,
        'durationAmount': duration?.amount,
        'durationUnit': duration?.unit,
        'patientIsChild': patientIsChild,
        'ageGroup': ageGroup,
        'scopedSymptomIds': symptomFacts.keys.toList(),
        'abdominalLocationResolved': abdominalLocationResolved,
        ...subject.debugMap(),
      };
}

/// جلسة توجيه صحي — ذاكرة فقط.
class HealthGuidanceSession {
  const HealthGuidanceSession({
    this.id,
    this.status = HealthGuidanceSessionStatus.inactive,
    this.facts = const HealthSessionFacts(),
    this.askedQuestionIds = const [],
    this.answeredQuestionIds = const [],
    this.skippedQuestionIds = const [],
    this.currentDecision,
    this.startedTurnId = 0,
    this.updatedTurnId = 0,
    this.pendingMissingFact,
    this.pendingHealthFactKey,
    this.pendingSymptomConceptId,
    this.pendingQuestionId,
    this.questionsAskedCount = 0,
    this.maxQuestions = 4,
    this.lastSafetyStatus,
    this.matchedSafetyRuleId,
    this.safetyWarningDelivered = false,
    this.lastSafetyDeliveredTurnId,
    this.pendingSafetyQuestionId,
    this.handoff = HealthGuidanceHandoff.inactive,
    this.previousSubjectType,
  });

  final String? id;
  final HealthGuidanceSessionStatus status;
  final HealthSessionFacts facts;
  final List<String> askedQuestionIds;
  final List<String> answeredQuestionIds;
  final List<String> skippedQuestionIds;
  final HealthGuidanceDecision? currentDecision;
  final int startedTurnId;
  final int updatedTurnId;
  final HealthMissingFact? pendingMissingFact;
  final String? pendingHealthFactKey;
  final String? pendingSymptomConceptId;
  final String? pendingQuestionId;
  final int questionsAskedCount;
  final int maxQuestions;

  /// حالة سلامة Step 10E — جلسة فقط بلا نص خام.
  final String? lastSafetyStatus;
  final String? matchedSafetyRuleId;
  final bool safetyWarningDelivered;
  final int? lastSafetyDeliveredTurnId;
  final String? pendingSafetyQuestionId;

  /// تسليم مزوّدين حقيقيين (Step 10F) — جلسة فقط.
  final HealthGuidanceHandoff handoff;

  /// نوع الموضوع السابق بعد تبديل صريح — لاسترجاع النوع فقط بلا حقائق.
  final HealthSubjectType? previousSubjectType;

  bool get isActive =>
      status == HealthGuidanceSessionStatus.active ||
      status == HealthGuidanceSessionStatus.waitingForAnswer ||
      status == HealthGuidanceSessionStatus.decided;

  HealthSubjectContext get subject => facts.subject;

  static const inactive = HealthGuidanceSession();

  HealthGuidanceSession copyWith({
    String? id,
    HealthGuidanceSessionStatus? status,
    HealthSessionFacts? facts,
    List<String>? askedQuestionIds,
    List<String>? answeredQuestionIds,
    List<String>? skippedQuestionIds,
    HealthGuidanceDecision? currentDecision,
    int? startedTurnId,
    int? updatedTurnId,
    HealthMissingFact? pendingMissingFact,
    String? pendingHealthFactKey,
    String? pendingSymptomConceptId,
    String? pendingQuestionId,
    int? questionsAskedCount,
    int? maxQuestions,
    String? lastSafetyStatus,
    String? matchedSafetyRuleId,
    bool? safetyWarningDelivered,
    int? lastSafetyDeliveredTurnId,
    String? pendingSafetyQuestionId,
    HealthGuidanceHandoff? handoff,
    HealthSubjectType? previousSubjectType,
    bool clearPendingMissingFact = false,
    bool clearPendingMeta = false,
    bool clearDecision = false,
    bool clearSafetyPending = false,
    bool clearHandoff = false,
    bool clearPreviousSubject = false,
    bool clearSafetyState = false,
  }) {
    return HealthGuidanceSession(
      id: id ?? this.id,
      status: status ?? this.status,
      facts: facts ?? this.facts,
      askedQuestionIds: askedQuestionIds ?? this.askedQuestionIds,
      answeredQuestionIds: answeredQuestionIds ?? this.answeredQuestionIds,
      skippedQuestionIds: skippedQuestionIds ?? this.skippedQuestionIds,
      currentDecision:
          clearDecision ? null : (currentDecision ?? this.currentDecision),
      startedTurnId: startedTurnId ?? this.startedTurnId,
      updatedTurnId: updatedTurnId ?? this.updatedTurnId,
      pendingMissingFact: clearPendingMissingFact
          ? null
          : (pendingMissingFact ?? this.pendingMissingFact),
      pendingHealthFactKey: clearPendingMeta
          ? null
          : (pendingHealthFactKey ?? this.pendingHealthFactKey),
      pendingSymptomConceptId: clearPendingMeta
          ? null
          : (pendingSymptomConceptId ?? this.pendingSymptomConceptId),
      pendingQuestionId: clearPendingMeta
          ? null
          : (pendingQuestionId ?? this.pendingQuestionId),
      questionsAskedCount: questionsAskedCount ?? this.questionsAskedCount,
      maxQuestions: maxQuestions ?? this.maxQuestions,
      lastSafetyStatus: clearSafetyState
          ? null
          : (lastSafetyStatus ?? this.lastSafetyStatus),
      matchedSafetyRuleId: clearSafetyState
          ? null
          : (matchedSafetyRuleId ?? this.matchedSafetyRuleId),
      safetyWarningDelivered: clearSafetyState
          ? false
          : (safetyWarningDelivered ?? this.safetyWarningDelivered),
      lastSafetyDeliveredTurnId: clearSafetyState
          ? null
          : (lastSafetyDeliveredTurnId ?? this.lastSafetyDeliveredTurnId),
      pendingSafetyQuestionId: clearSafetyPending || clearSafetyState
          ? null
          : (pendingSafetyQuestionId ?? this.pendingSafetyQuestionId),
      handoff: clearHandoff
          ? HealthGuidanceHandoff.inactive
          : (handoff ?? this.handoff),
      previousSubjectType: clearPreviousSubject
          ? null
          : (previousSubjectType ?? this.previousSubjectType),
    );
  }

  Map<String, Object?> debugSnapshot() => {
        'healthSessionStatus': status.name,
        'healthSessionId': id,
        ...facts.debugMap(),
        'askedQuestionIds': askedQuestionIds,
        'answeredQuestionIds': answeredQuestionIds,
        'skippedQuestionIds': skippedQuestionIds,
        'questionCount': questionsAskedCount,
        'lastQuestionId': pendingQuestionId ??
            (askedQuestionIds.isNotEmpty ? askedQuestionIds.last : null),
        'pendingHealthFactKey': pendingHealthFactKey,
        'pendingMissingFact': pendingMissingFact?.name,
        'decisionType': currentDecision?.type.name,
        'matchedRuleId': currentDecision?.matchedRuleId,
        'destinationKey': currentDecision?.destination?.key,
        'safetyStatus': lastSafetyStatus,
        'matchedSafetyRuleId': matchedSafetyRuleId,
        'safetyQuestionId': pendingSafetyQuestionId,
        'safetyWarningDelivered': safetyWarningDelivered,
        'previousSubjectType': previousSubjectType?.name,
        ...handoff.debugMap(),
      };
}
