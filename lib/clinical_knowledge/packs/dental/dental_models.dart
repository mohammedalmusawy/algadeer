/// PC-1.22 — حزمة معرفة سريرية لأسنان وفم (ليست رفيق أسنان طولي).
library;

import '../../clinical_knowledge_models.dart';

enum DentalTopic {
  toothPain,
  toothSensitivity,
  gumPain,
  gumBleeding,
  gumSwelling,
  dentalSwelling,
  facialSwelling,
  suspectedDentalInfection,
  wisdomToothConcern,
  brokenTooth,
  crackedToothConcern,
  looseTooth,
  lostTooth,
  dentalTrauma,
  oralUlcer,
  oralLesion,
  jawPain,
  biteChewingPain,
  postDentalProcedureConcern,
  oralHygiene,
  cariesPrevention,
  childDentalConcern,
  pregnancyDentalConcern,
  dentalImagingQuestion,
  antibioticQuestion,
  painReliefQuestion,
  serviceNavigation,
  educationOnly,
  unknown,
}

enum DentalUrgency {
  selfCarePlusRoutineDental,
  dentalReview,
  promptDentalReview,
  urgentDentalReview,
  emergencySafety,
  unknown,
}

enum DentalToothType {
  primary,
  permanent,
  unknown,
}

enum DentalPainTrigger {
  cold,
  hot,
  sweet,
  biting,
  night,
  spontaneous,
  brushing,
  unknown,
}

enum DentalSwellingClass {
  none,
  localizedIntraoral,
  gum,
  facial,
  progressiveFacial,
  eyeArea,
  unknown,
}

enum DentalTraumaKind {
  none,
  chip,
  fracture,
  looseAfterTrauma,
  displaced,
  avulsion,
  facialTrauma,
  unknown,
}

class DentalInterpretation {
  const DentalInterpretation({
    this.isDentalTurn = false,
    this.topic = DentalTopic.unknown,
    this.severity = ClinicalSeverityClass.unknown,
    this.triggers = const [],
    this.swelling = DentalSwellingClass.unknown,
    this.trauma = DentalTraumaKind.none,
    this.toothType = DentalToothType.unknown,
    this.redFlagCandidate = false,
    this.hasFeverOrSystemic = false,
    this.difficultySwallowing = false,
    this.difficultyBreathing = false,
    this.difficultyOpeningMouth = false,
    this.bleeding = false,
    this.asksEducation = false,
    this.asksAntibiotic = false,
    this.asksAnalgesic = false,
    this.asksImaging = false,
    this.asksServiceWhere = false,
    this.asksBooking = false,
    this.isAboutOtherPerson = false,
    this.otherPersonLabel = '',
    this.pregnancyContextHint = false,
    this.diabetesContextHint = false,
    this.hypertensionContextHint = false,
    this.childContextHint = false,
    this.userReportedAbscess = false,
    this.explicitFollowUp = false,
    this.negatesSwelling = false,
    this.negatesFever = false,
    this.negatesBleeding = false,
    this.negatesTrauma = false,
    this.correctionSubject = false,
    this.correctionToothType = false,
    this.fearDentist = false,
    this.anticoagulantHint = false,
    this.prophylaxisRequest = false,
    this.namedAntibioticRequest = false,
  });

  final bool isDentalTurn;
  final DentalTopic topic;
  final ClinicalSeverityClass severity;
  final List<DentalPainTrigger> triggers;
  final DentalSwellingClass swelling;
  final DentalTraumaKind trauma;
  final DentalToothType toothType;
  final bool redFlagCandidate;
  final bool hasFeverOrSystemic;
  final bool difficultySwallowing;
  final bool difficultyBreathing;
  final bool difficultyOpeningMouth;
  final bool bleeding;
  final bool asksEducation;
  final bool asksAntibiotic;
  final bool asksAnalgesic;
  final bool asksImaging;
  final bool asksServiceWhere;
  final bool asksBooking;
  final bool isAboutOtherPerson;
  final String otherPersonLabel;
  final bool pregnancyContextHint;
  final bool diabetesContextHint;
  final bool hypertensionContextHint;
  final bool childContextHint;
  final bool userReportedAbscess;
  final bool explicitFollowUp;
  final bool negatesSwelling;
  final bool negatesFever;
  final bool negatesBleeding;
  final bool negatesTrauma;
  final bool correctionSubject;
  final bool correctionToothType;
  final bool fearDentist;
  final bool anticoagulantHint;
  final bool prophylaxisRequest;
  final bool namedAntibioticRequest;

  bool get hasTrauma =>
      trauma != DentalTraumaKind.none && trauma != DentalTraumaKind.unknown;

  static const none = DentalInterpretation();
}

/// جلسة أسنان — RAM فقط؛ بلا سجل أسنان دائم.
class DentalSession {
  const DentalSession({
    this.active = false,
    this.topic = DentalTopic.unknown,
    this.severity = ClinicalSeverityClass.unknown,
    this.triggers = const [],
    this.swelling = DentalSwellingClass.unknown,
    this.trauma = DentalTraumaKind.none,
    this.toothType = DentalToothType.unknown,
    this.urgency = DentalUrgency.unknown,
    this.isOtherPerson = false,
    this.otherPersonLabel = '',
    this.pregnancyContext = false,
    this.diabetesContext = false,
    this.childContext = false,
    this.userReportedAbscess = false,
    this.difficultyOpeningMouth = false,
    this.askedQuestionKeys = const [],
    this.lastQuestionKey,
    this.questionCount = 0,
    this.matchedRuleIds = const [],
    this.destinationType,
    this.imagingAppropriateness,
    this.imagingModality,
    this.imagingReasonCode = '',
    this.redFlagCandidate = false,
    this.lastGuidance = '',
  });

  final bool active;
  final DentalTopic topic;
  final ClinicalSeverityClass severity;
  final List<DentalPainTrigger> triggers;
  final DentalSwellingClass swelling;
  final DentalTraumaKind trauma;
  final DentalToothType toothType;
  final DentalUrgency urgency;
  final bool isOtherPerson;
  final String otherPersonLabel;
  final bool pregnancyContext;
  final bool diabetesContext;
  final bool childContext;
  final bool userReportedAbscess;
  final bool difficultyOpeningMouth;
  final List<String> askedQuestionKeys;
  final String? lastQuestionKey;
  final int questionCount;
  final List<String> matchedRuleIds;
  final ClinicalCareDestination? destinationType;
  final ClinicalImagingAppropriateness? imagingAppropriateness;
  final ClinicalImagingModality? imagingModality;
  final String imagingReasonCode;
  final bool redFlagCandidate;
  final String lastGuidance;

  static const inactive = DentalSession();

  DentalSession copyWith({
    bool? active,
    DentalTopic? topic,
    ClinicalSeverityClass? severity,
    List<DentalPainTrigger>? triggers,
    DentalSwellingClass? swelling,
    DentalTraumaKind? trauma,
    DentalToothType? toothType,
    DentalUrgency? urgency,
    bool? isOtherPerson,
    String? otherPersonLabel,
    bool? pregnancyContext,
    bool? diabetesContext,
    bool? childContext,
    bool? userReportedAbscess,
    bool? difficultyOpeningMouth,
    List<String>? askedQuestionKeys,
    String? lastQuestionKey,
    bool clearLastQuestion = false,
    int? questionCount,
    List<String>? matchedRuleIds,
    ClinicalCareDestination? destinationType,
    ClinicalImagingAppropriateness? imagingAppropriateness,
    ClinicalImagingModality? imagingModality,
    String? imagingReasonCode,
    bool? redFlagCandidate,
    String? lastGuidance,
  }) {
    return DentalSession(
      active: active ?? this.active,
      topic: topic ?? this.topic,
      severity: severity ?? this.severity,
      triggers: triggers ?? this.triggers,
      swelling: swelling ?? this.swelling,
      trauma: trauma ?? this.trauma,
      toothType: toothType ?? this.toothType,
      urgency: urgency ?? this.urgency,
      isOtherPerson: isOtherPerson ?? this.isOtherPerson,
      otherPersonLabel: otherPersonLabel ?? this.otherPersonLabel,
      pregnancyContext: pregnancyContext ?? this.pregnancyContext,
      diabetesContext: diabetesContext ?? this.diabetesContext,
      childContext: childContext ?? this.childContext,
      userReportedAbscess: userReportedAbscess ?? this.userReportedAbscess,
      difficultyOpeningMouth:
          difficultyOpeningMouth ?? this.difficultyOpeningMouth,
      askedQuestionKeys: askedQuestionKeys ?? this.askedQuestionKeys,
      lastQuestionKey: clearLastQuestion
          ? null
          : (lastQuestionKey ?? this.lastQuestionKey),
      questionCount: questionCount ?? this.questionCount,
      matchedRuleIds: matchedRuleIds ?? this.matchedRuleIds,
      destinationType: destinationType ?? this.destinationType,
      imagingAppropriateness:
          imagingAppropriateness ?? this.imagingAppropriateness,
      imagingModality: imagingModality ?? this.imagingModality,
      imagingReasonCode: imagingReasonCode ?? this.imagingReasonCode,
      redFlagCandidate: redFlagCandidate ?? this.redFlagCandidate,
      lastGuidance: lastGuidance ?? this.lastGuidance,
    );
  }

  Map<String, Object?> debugMap() => {
        'dentalIntent': topic != DentalTopic.unknown,
        'topic': topic.name,
        'safetyDeferred': redFlagCandidate,
        'matchedRuleId': matchedRuleIds.isEmpty ? null : matchedRuleIds.first,
        'urgency': urgency.name,
        'imagingAppropriate': imagingAppropriateness?.name,
        // بلا نص عرض خام / personId / أدوية مربوطة بشخص
      };
}

class DentalTurnResult {
  const DentalTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.deferToMedicalSafety = false,
    this.deferToMentalSafety = false,
    this.deferToFollowUp = false,
    this.deferToServiceNavigation = false,
    this.preserveDestinationContext = false,
    this.textFirstOnly = true,
    this.success = true,
  });

  final bool handled;
  final String message;
  final DentalSession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToServiceNavigation;
  final bool preserveDestinationContext;
  final bool textFirstOnly;
  final bool success;

  static DentalTurnResult notHandled(DentalSession s) =>
      DentalTurnResult(handled: false, message: '', session: s);
}
