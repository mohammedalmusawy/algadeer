/// PC-1.17 — مكتبة معرفة سريرية مبنية على الأدلة (أساس معماري).
///
/// معرفة طبية منفصلة عن منطق المحادثة. ليست محرك تشخيص.
library;

/// نطاقات سريرية مستقبلية — لا تُملأ كلها في PC-1.17.
enum ClinicalDomain {
  musculoskeletal,
  respiratory,
  diabetes,
  hypertension,
  pregnancy,
  dental,
  mentalHealth,
  adolescentHealth,
  wellness,
  generalMedicine,
  other,
}

/// مواضيع مستقلة عن التشخيص — قابلة للتوسيع.
enum ClinicalKnowledgeTopic {
  lowBackPain,
  neckPain,
  kneePain,
  shoulderPain,
  hipPain,
  muscleStrain,
  radiatingLimbPain,
  knownDiscDisease,
  knownKneeOsteoarthritis,
  chronicCough,
  acuteCough,
  pregnancyRoutineCare,
  diabetesRoutineCare,
  hypertensionRoutineCare,
  dentalPain,
  activityWithRedFlags,
  generalClinical,
  other,
}

enum ClinicalEvidenceType {
  clinicalGuideline,
  appropriatenessCriteria,
  professionalStandard,
  consensusStatement,
  evidenceSummary,
  other,
}

enum ClinicalEvidenceFreshness {
  current,
  reviewDue,
  superseded,
  unknownFreshness,
}

enum ClinicalPopulation {
  generalAdult,
  child,
  adolescent,
  pregnant,
  postpartum,
  olderAdult,
  knownDiabetes,
  knownHypertension,
  athlete,
  other,
  unknown,
}

enum ClinicalSeverityClass {
  mild,
  moderate,
  severe,
  unknown,
}

enum ClinicalFunctionalImpact {
  normalFunction,
  limitedActivity,
  difficultyWalking,
  difficultySleeping,
  unableToPerformActivity,
  unknown,
}

enum ClinicalCareActionType {
  generalSelfCare,
  activityModification,
  restRecovery,
  relativeRest,
  continueActivityAsTolerated,
  exerciseGuidance,
  physiotherapyDiscussion,
  clinicianReview,
  specialistReview,
  dentalReview,
  mentalHealthSupport,
  investigationDiscussion,
  imagingDiscussion,
  urgentCare,
  emergencyCare,
  serviceNavigation,
}

enum ClinicalImagingAppropriateness {
  notRoutinelyIndicated,
  mayBeAppropriate,
  usuallyAppropriate,
  clinicianDecision,
  urgentImagingConsideration,
}

enum ClinicalImagingModality {
  xray,
  ultrasound,
  ct,
  mri,
  other,
  unspecified,
}

enum ClinicalCareDestination {
  selfCare,
  primaryCare,
  generalPractitioner,
  specialist,
  physiotherapy,
  radiology,
  laboratory,
  dentist,
  mentalHealthProfessional,
  obstetricsGynecology,
  emergency,
  other,
}

/// مصدر واحد لتسمية الوجهة بالعربية — ممنوع عرض اسم القيمة الإنجليزي للمستخدم.
extension ClinicalCareDestinationX on ClinicalCareDestination {
  String get arabicLabel {
    switch (this) {
      case ClinicalCareDestination.selfCare:
        return 'رعاية منزلية';
      case ClinicalCareDestination.primaryCare:
        return 'رعاية أولية';
      case ClinicalCareDestination.generalPractitioner:
        return 'طبيب عام';
      case ClinicalCareDestination.specialist:
        return 'طبيب اختصاص';
      case ClinicalCareDestination.physiotherapy:
        return 'علاج طبيعي';
      case ClinicalCareDestination.radiology:
        return 'أشعة';
      case ClinicalCareDestination.laboratory:
        return 'تحليل مختبري';
      case ClinicalCareDestination.dentist:
        return 'طبيب أسنان';
      case ClinicalCareDestination.mentalHealthProfessional:
        return 'اختصاصي صحة نفسية';
      case ClinicalCareDestination.obstetricsGynecology:
        return 'نسائية وتوليد';
      case ClinicalCareDestination.emergency:
        return 'طوارئ';
      case ClinicalCareDestination.other:
        return 'تقييم سريري عام';
    }
  }
}

enum ClinicalCoughDurationClass {
  acute,
  subacute,
  chronic,
  unknown,
}

/// مرجع دليل — إلزامي للقواعد النشطة.
class ClinicalEvidenceReference {
  const ClinicalEvidenceReference({
    required this.sourceOrganization,
    required this.sourceTitle,
    required this.sourceReference,
    required this.sourceVersionOrDate,
    required this.evidenceType,
  });

  final String sourceOrganization;
  final String sourceTitle;
  final String sourceReference;
  final String sourceVersionOrDate;
  final ClinicalEvidenceType evidenceType;

  Map<String, Object?> debugMap() => {
        'sourceOrganization': sourceOrganization,
        'sourceVersionOrDate': sourceVersionOrDate,
        'evidenceType': evidenceType.name,
      };
}

/// نمط أعراض — ليس تشخيصاً.
class ClinicalSymptomPattern {
  const ClinicalSymptomPattern({
    required this.symptomKey,
    this.location,
    this.durationHint,
    this.severity = ClinicalSeverityClass.unknown,
    this.functionalImpact = ClinicalFunctionalImpact.unknown,
    this.associatedFeatures = const [],
    this.onset,
    this.contextHints = const [],
    this.userReportedKnownDiagnosis,
  });

  final String symptomKey;
  final String? location;
  final String? durationHint;
  final ClinicalSeverityClass severity;
  final ClinicalFunctionalImpact functionalImpact;
  final List<String> associatedFeatures;
  final String? onset;
  final List<String> contextHints;

  /// تشخيص معلن من المستخدم — مميّز عن نمط العرض.
  final String? userReportedKnownDiagnosis;

  bool get isKnownDiagnosisContext =>
      userReportedKnownDiagnosis != null &&
      userReportedKnownDiagnosis!.trim().isNotEmpty;

  Map<String, Object?> debugMap() => {
        'symptomKey': symptomKey,
        'hasKnownDiagnosis': isKnownDiagnosisContext,
        'severity': severity.name,
        // بلا نص عرض خام
      };
}

class ClinicalQuestionDefinition {
  const ClinicalQuestionDefinition({
    required this.questionKey,
    required this.canonicalKey,
    this.arabicPrompt = '',
    this.iraqiAliases = const [],
    this.priority = 50,
  });

  final String questionKey;
  final String canonicalKey;
  final String arabicPrompt;
  final List<String> iraqiAliases;
  final int priority;
}

/// بيانات تصعيد نطاقية — ليست سلطة طوارئ ثانية.
class ClinicalRedFlagDefinition {
  const ClinicalRedFlagDefinition({
    required this.flagKey,
    required this.domain,
    this.defersToMedicalSafetyEngine = true,
    this.rationaleCode = '',
  });

  final String flagKey;
  final ClinicalDomain domain;
  final bool defersToMedicalSafetyEngine;
  final String rationaleCode;
}

class ClinicalGuidanceAction {
  const ClinicalGuidanceAction({
    required this.actionType,
    this.reasonCode = '',
    this.optional = false,
    this.arabicHint = '',
  });

  final ClinicalCareActionType actionType;
  final String reasonCode;
  final bool optional;
  final String arabicHint;
}

class ClinicalInvestigationGuidance {
  const ClinicalInvestigationGuidance({
    required this.investigationKey,
    this.reasonCode = '',
    this.requiresClinicianDiscussion = true,
  });

  final String investigationKey;
  final String reasonCode;
  final bool requiresClinicianDiscussion;
}

/// توجيه تصوير — قرار سريري أولاً.
class ClinicalImagingGuidance {
  const ClinicalImagingGuidance({
    required this.appropriateness,
    this.modality = ClinicalImagingModality.unspecified,
    this.reasonCode = '',
    this.allowsServiceHandoff = false,
    this.arabicGuidance = '',
  });

  final ClinicalImagingAppropriateness appropriateness;
  final ClinicalImagingModality modality;
  final String reasonCode;
  final bool allowsServiceHandoff;
  final String arabicGuidance;

  bool get isRoutinelyIndicated =>
      appropriateness == ClinicalImagingAppropriateness.usuallyAppropriate ||
      appropriateness ==
          ClinicalImagingAppropriateness.urgentImagingConsideration;

  Map<String, Object?> debugMap() => {
        'imagingGuidanceType': appropriateness.name,
        'modality': modality.name,
        'allowsServiceHandoff': allowsServiceHandoff,
        // بلا سبب نصّي حسّاس
      };
}

class ClinicalCareDestinationHint {
  const ClinicalCareDestinationHint({
    required this.destination,
    this.reasonCode = '',
    this.arabicHint = '',
  });

  final ClinicalCareDestination destination;
  final String reasonCode;
  final String arabicHint;
}

/// قاعدة معرفة سريرية — بلا قواعد مجهولة المصدر.
class ClinicalKnowledgeRule {
  const ClinicalKnowledgeRule({
    required this.ruleId,
    required this.domain,
    required this.topic,
    required this.population,
    required this.evidence,
    required this.reviewedAt,
    required this.schemaVersion,
    this.clinicalReviewRequired = true,
    this.isActive = false,
    this.freshness = ClinicalEvidenceFreshness.unknownFreshness,
    this.supersedesRuleId,
    this.symptomKeys = const [],
    this.knownDiagnosisKeys = const [],
    this.requiredContext = const {},
    this.excludedContext = const {},
    this.minimumQuestions = const [],
    this.redFlagKeys = const [],
    this.actions = const [],
    this.imaging,
    this.investigations = const [],
    this.destinations = const [],
    this.coughDurationClass,
    this.priority = 50,
    this.arabicSummary = '',
    this.englishCanonicalKey = '',
    this.iraqiAliases = const [],
  });

  final String ruleId;
  final ClinicalDomain domain;
  final ClinicalKnowledgeTopic topic;
  final ClinicalPopulation population;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final int schemaVersion;
  final bool clinicalReviewRequired;
  final bool isActive;
  final ClinicalEvidenceFreshness freshness;
  final String? supersedesRuleId;
  final List<String> symptomKeys;
  final List<String> knownDiagnosisKeys;
  final Set<String> requiredContext;
  final Set<String> excludedContext;
  final List<ClinicalQuestionDefinition> minimumQuestions;
  final List<String> redFlagKeys;
  final List<ClinicalGuidanceAction> actions;
  final ClinicalImagingGuidance? imaging;
  final List<ClinicalInvestigationGuidance> investigations;
  final List<ClinicalCareDestinationHint> destinations;
  final ClinicalCoughDurationClass? coughDurationClass;
  final int priority;
  final String arabicSummary;
  final String englishCanonicalKey;
  final List<String> iraqiAliases;

  bool get hasEvidenceReference =>
      evidence.sourceOrganization.trim().isNotEmpty &&
      evidence.sourceReference.trim().isNotEmpty;

  Map<String, Object?> debugMap() => {
        'selectedRuleId': ruleId,
        'clinicalDomain': domain.name,
        'topicKey': topic.name,
        'evidenceFreshness': freshness.name,
        'imagingGuidanceType': imaging?.appropriateness.name,
        'destinationType': destinations.isEmpty
            ? null
            : destinations.first.destination.name,
        'guidanceActionType':
            actions.isEmpty ? null : actions.first.actionType.name,
        // بلا أعراض خام / أسماء أشخاص
      };
}

/// نتيجة استعلام المعرفة.
class ClinicalKnowledgeMatch {
  const ClinicalKnowledgeMatch({
    this.rule,
    this.matchedRuleCount = 0,
    this.deferToMedicalSafety = false,
    this.allowsRadiologyHandoff = false,
    this.message = '',
    this.success = true,
  });

  final ClinicalKnowledgeRule? rule;
  final int matchedRuleCount;
  final bool deferToMedicalSafety;
  final bool allowsRadiologyHandoff;
  final String message;
  final bool success;

  static const empty = ClinicalKnowledgeMatch();

  Map<String, Object?> debugMap() => {
        'matchedRuleCount': matchedRuleCount,
        'selectedRuleId': rule?.ruleId,
        'clinicalDomain': rule?.domain.name,
        'topicKey': rule?.topic.name,
        'guidanceActionType': rule?.actions.isEmpty == false
            ? rule!.actions.first.actionType.name
            : null,
        'imagingGuidanceType': rule?.imaging?.appropriateness.name,
        'destinationType': rule?.destinations.isEmpty == false
            ? rule!.destinations.first.destination.name
            : null,
        'evidenceFreshness': rule?.freshness.name,
        'allowsRadiologyHandoff': allowsRadiologyHandoff,
        'deferToMedicalSafety': deferToMedicalSafety,
      };
}

/// جلسة استعلام — بلا سجل مريض.
class ClinicalKnowledgeSession {
  const ClinicalKnowledgeSession({
    this.lastMatch = ClinicalKnowledgeMatch.empty,
    this.active = false,
  });

  final ClinicalKnowledgeMatch lastMatch;
  final bool active;

  static const inactive = ClinicalKnowledgeSession();

  ClinicalKnowledgeSession copyWith({
    ClinicalKnowledgeMatch? lastMatch,
    bool? active,
  }) {
    return ClinicalKnowledgeSession(
      lastMatch: lastMatch ?? this.lastMatch,
      active: active ?? this.active,
    );
  }

  Map<String, Object?> debugMap() => {
        'clinicalKnowledgeActive': active,
        ...lastMatch.debugMap(),
      };
}

/// عقود مستقبلية — إدارة محتوى سريري / مراجعة.
class ClinicalKnowledgeAdminContract {
  const ClinicalKnowledgeAdminContract();
  bool get adminUiEnabled => false;
  bool get reviewerWorkflowEnabled => false;
  bool get pregnancyCompanionEnabled => false;
  bool get fullMskPackEnabled => false;
  bool get fullRespiratoryPackEnabled => false;
  bool get fullDiabetesPackEnabled => false;
  bool get fullDentalPackEnabled => false;
}

/// استعلام سياقي أدنى — بلا قياسات/حمل مستنتج.
class ClinicalKnowledgeQuery {
  const ClinicalKnowledgeQuery({
    this.topic,
    this.domain,
    this.symptomKeys = const [],
    this.knownDiagnosisKeys = const [],
    this.severity = ClinicalSeverityClass.unknown,
    this.functionalImpact = ClinicalFunctionalImpact.unknown,
    this.contextTags = const {},
    this.coughDuration,
    this.hasMedicalRedFlag = false,
    this.sponsorOverrideRequested = false,
    this.paidPackageOverrideRequested = false,
    this.inferPregnancyFromDemographics = false,
  });

  final ClinicalKnowledgeTopic? topic;
  final ClinicalDomain? domain;
  final List<String> symptomKeys;
  final List<String> knownDiagnosisKeys;
  final ClinicalSeverityClass severity;
  final ClinicalFunctionalImpact functionalImpact;
  final Set<String> contextTags;
  final ClinicalCoughDurationClass? coughDuration;
  final bool hasMedicalRedFlag;
  final bool sponsorOverrideRequested;
  final bool paidPackageOverrideRequested;

  /// يُرفض دائماً — الحمل لا يُستنتج من العمر/الجنس.
  final bool inferPregnancyFromDemographics;
}
