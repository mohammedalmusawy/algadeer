/// PC-1.18 — حزمة جهاز عضلي هيكلي (MSK) فوق أساس المعرفة السريرية.
library;

import '../../clinical_knowledge_models.dart';

enum MskBodyRegion {
  cervicalSpine,
  thoracicSpine,
  lumbarSpine,
  shoulder,
  upperArm,
  elbow,
  forearm,
  wristHand,
  hip,
  thigh,
  knee,
  lowerLeg,
  ankleFoot,
  multiple,
  unknown,
}

enum MskSymptomType {
  pain,
  stiffness,
  swelling,
  weakness,
  numbness,
  tingling,
  spasm,
  cramp,
  reducedMovement,
  radiatingPain,
  bruising,
  difficultyWeightBearing,
  locking,
  givingWay,
  other,
}

enum MskDurationClass {
  hours,
  days,
  weeks,
  months,
  acute,
  persistent,
  chronic,
  unknown,
}

enum MskTraumaMechanism {
  fall,
  twist,
  directBlow,
  sportsInjury,
  liftingInjury,
  collision,
  unknownTrauma,
  noneReported,
}

enum MskKnownDiagnosisKind {
  none,
  discDisease,
  kneeOsteoarthritis,
  other,
}

enum MskTopic {
  lowBackPain,
  neckPain,
  kneePain,
  shoulderPain,
  hipPain,
  muscleStrain,
  thighMuscleInjury,
  spasm,
  radiatingLimbPain,
  knownDiscDisease,
  knownKneeOsteoarthritis,
  jointPainGeneral,
  educationQuery,
  serviceNavigation,
  unknown,
}

/// تفسير دورة MSK — جلسة فقط.
class MskInterpretation {
  const MskInterpretation({
    this.isMskTurn = false,
    this.topic = MskTopic.unknown,
    this.region = MskBodyRegion.unknown,
    this.symptoms = const [],
    this.severity = ClinicalSeverityClass.unknown,
    this.functionalImpact = ClinicalFunctionalImpact.unknown,
    this.duration = MskDurationClass.unknown,
    this.trauma = MskTraumaMechanism.noneReported,
    this.knownDiagnosis = MskKnownDiagnosisKind.none,
    this.knownDiagnosisLabel = '',
    this.redFlagCandidate = false,
    this.asksEducation = false,
    this.asksServiceWhere = false,
    this.asksBooking = false,
    this.asksImagingWhere = false,
    this.selfSuspectsOa = false,
    this.isAboutOtherPerson = false,
    this.pregnancyContextHint = false,
    this.looksLikeFollowUp = false,
    this.explicitFollowUp = false,
  });

  final bool isMskTurn;
  final MskTopic topic;
  final MskBodyRegion region;
  final List<MskSymptomType> symptoms;
  final ClinicalSeverityClass severity;
  final ClinicalFunctionalImpact functionalImpact;
  final MskDurationClass duration;
  final MskTraumaMechanism trauma;
  final MskKnownDiagnosisKind knownDiagnosis;
  final String knownDiagnosisLabel;
  final bool redFlagCandidate;
  final bool asksEducation;
  final bool asksServiceWhere;
  final bool asksBooking;
  final bool asksImagingWhere;
  final bool selfSuspectsOa;
  final bool isAboutOtherPerson;
  final bool pregnancyContextHint;
  final bool looksLikeFollowUp;
  final bool explicitFollowUp;

  bool get hasTrauma =>
      trauma != MskTraumaMechanism.noneReported &&
      trauma != MskTraumaMechanism.unknownTrauma;

  bool get unableToBearWeight =>
      symptoms.contains(MskSymptomType.difficultyWeightBearing) ||
      functionalImpact == ClinicalFunctionalImpact.unableToPerformActivity ||
      functionalImpact == ClinicalFunctionalImpact.difficultyWalking;

  static const none = MskInterpretation();
}

/// جلسة MSK — RAM فقط، بلا دفتر ألم دائم.
class MskSession {
  const MskSession({
    this.active = false,
    this.topic = MskTopic.unknown,
    this.region = MskBodyRegion.unknown,
    this.symptoms = const [],
    this.severity = ClinicalSeverityClass.unknown,
    this.functionalImpact = ClinicalFunctionalImpact.unknown,
    this.duration = MskDurationClass.unknown,
    this.trauma = MskTraumaMechanism.noneReported,
    this.knownDiagnosis = MskKnownDiagnosisKind.none,
    this.questionCount = 0,
    this.lastQuestionKey,
    this.lastRuleId,
    this.imagingAppropriateness,
    this.imagingModality,
    this.imagingReasonCode,
    this.destinationType,
    this.pendingDestination,
    this.redFlagCandidate = false,
    this.lastGuidance = '',
  });

  final bool active;
  final MskTopic topic;
  final MskBodyRegion region;
  final List<MskSymptomType> symptoms;
  final ClinicalSeverityClass severity;
  final ClinicalFunctionalImpact functionalImpact;
  final MskDurationClass duration;
  final MskTraumaMechanism trauma;
  final MskKnownDiagnosisKind knownDiagnosis;
  final int questionCount;
  final String? lastQuestionKey;
  final String? lastRuleId;
  final ClinicalImagingAppropriateness? imagingAppropriateness;
  final ClinicalImagingModality? imagingModality;
  final String? imagingReasonCode;
  final ClinicalCareDestination? destinationType;
  final ClinicalCareDestination? pendingDestination;
  final bool redFlagCandidate;
  final String lastGuidance;

  static const inactive = MskSession();

  MskSession copyWith({
    bool? active,
    MskTopic? topic,
    MskBodyRegion? region,
    List<MskSymptomType>? symptoms,
    ClinicalSeverityClass? severity,
    ClinicalFunctionalImpact? functionalImpact,
    MskDurationClass? duration,
    MskTraumaMechanism? trauma,
    MskKnownDiagnosisKind? knownDiagnosis,
    int? questionCount,
    String? lastQuestionKey,
    bool clearLastQuestion = false,
    String? lastRuleId,
    ClinicalImagingAppropriateness? imagingAppropriateness,
    ClinicalImagingModality? imagingModality,
    String? imagingReasonCode,
    ClinicalCareDestination? destinationType,
    ClinicalCareDestination? pendingDestination,
    bool? redFlagCandidate,
    String? lastGuidance,
  }) {
    return MskSession(
      active: active ?? this.active,
      topic: topic ?? this.topic,
      region: region ?? this.region,
      symptoms: symptoms ?? this.symptoms,
      severity: severity ?? this.severity,
      functionalImpact: functionalImpact ?? this.functionalImpact,
      duration: duration ?? this.duration,
      trauma: trauma ?? this.trauma,
      knownDiagnosis: knownDiagnosis ?? this.knownDiagnosis,
      questionCount: questionCount ?? this.questionCount,
      lastQuestionKey:
          clearLastQuestion ? null : (lastQuestionKey ?? this.lastQuestionKey),
      lastRuleId: lastRuleId ?? this.lastRuleId,
      imagingAppropriateness:
          imagingAppropriateness ?? this.imagingAppropriateness,
      imagingModality: imagingModality ?? this.imagingModality,
      imagingReasonCode: imagingReasonCode ?? this.imagingReasonCode,
      destinationType: destinationType ?? this.destinationType,
      pendingDestination: pendingDestination ?? this.pendingDestination,
      redFlagCandidate: redFlagCandidate ?? this.redFlagCandidate,
      lastGuidance: lastGuidance ?? this.lastGuidance,
    );
  }

  Map<String, Object?> debugMap() => {
        'mskTopic': topic.name,
        'bodyRegion': region.name,
        'severityClass': severity.name,
        'functionalImpactClass': functionalImpact.name,
        'traumaPresent': trauma != MskTraumaMechanism.noneReported,
        'redFlagCandidate': redFlagCandidate,
        'questionCount': questionCount,
        'clinicalRuleId': lastRuleId,
        'imagingAppropriateness': imagingAppropriateness?.name,
        'imagingModality': imagingModality?.name,
        'destinationType': destinationType?.name,
        // بلا نص أعراض خام / تشخيص حسّاس / personId
      };
}

class MskTurnResult {
  const MskTurnResult({
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
  final MskSession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToServiceNavigation;
  final bool preserveDestinationContext;
  final bool textFirstOnly;
  final bool success;

  static MskTurnResult notHandled(MskSession s) => MskTurnResult(
        handled: false,
        message: '',
        session: s,
      );
}
