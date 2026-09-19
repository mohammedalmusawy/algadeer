/// PC-1.19 — حزمة الجهاز التنفسي والصدر فوق أساس المعرفة السريرية.
library;

import '../../clinical_knowledge_models.dart';

enum RespiratoryTopic {
  acuteCough,
  persistentCough,
  chronicCough,
  breathlessness,
  wheeze,
  sputum,
  hemoptysis,
  respiratoryChestPain,
  recurrentChestInfection,
  knownAsthma,
  knownCopd,
  postRespiratoryIllness,
  generalRespiratory,
  educationQuery,
  serviceNavigation,
  unknownRespiratory,
}

enum RespiratoryCoughType {
  dry,
  productive,
  unknown,
}

enum RespiratoryTriState {
  present,
  absent,
  unknown,
}

enum RespiratoryDurationBucket {
  hours,
  days,
  weeks,
  months,
  unknown,
}

enum RespiratoryFunctionalImpact {
  normalActivity,
  reducedActivity,
  breathlessOnExertion,
  difficultySleeping,
  difficultySpeakingDueToBreathlessness,
  unableNormalActivity,
  unknown,
}

enum RespiratoryKnownCondition {
  none,
  asthma,
  copd,
  chronicRespiratoryDisease,
  pneumoniaEstablished,
  chestInfectionSelfLabel,
  other,
}

enum RespiratorySmokingState {
  currentSmoking,
  formerSmoking,
  neverReported,
  unknown,
}

enum RespiratoryPopulation {
  adult,
  child,
  unknown,
}

enum RespiratoryInvestigationType {
  none,
  chestXray,
  ctChest,
  spirometry,
  clinicianDirected,
}

/// تفسير دورة تنفسية — جلسة فقط.
class RespiratoryInterpretation {
  const RespiratoryInterpretation({
    this.isRespiratoryTurn = false,
    this.topic = RespiratoryTopic.unknownRespiratory,
    this.durationBucket = RespiratoryDurationBucket.unknown,
    this.coughType = RespiratoryCoughType.unknown,
    this.sputum = RespiratoryTriState.unknown,
    this.breathlessness = RespiratoryTriState.unknown,
    this.wheeze = RespiratoryTriState.unknown,
    this.chestPain = RespiratoryTriState.unknown,
    this.fever = RespiratoryTriState.unknown,
    this.hemoptysis = RespiratoryTriState.unknown,
    this.weightLoss = RespiratoryTriState.unknown,
    this.functionalImpact = RespiratoryFunctionalImpact.unknown,
    this.knownCondition = RespiratoryKnownCondition.none,
    this.smoking = RespiratorySmokingState.unknown,
    this.recurrentInfection = false,
    this.recentRespiratoryIllness = false,
    this.redFlagCandidate = false,
    this.chestPainSafetyFirst = false,
    this.severeDistress = false,
    this.asksEducation = false,
    this.asksServiceWhere = false,
    this.asksBooking = false,
    this.asksImagingWhere = false,
    this.asksDirectChestXray = false,
    this.selfSuspectsInfection = false,
    this.isAboutOtherPerson = false,
    this.pregnancyContextHint = false,
    this.population = RespiratoryPopulation.unknown,
    this.explicitFollowUp = false,
    this.correctionDuration = false,
    this.correctionCoughType = false,
    this.symptomKeys = const [],
  });

  final bool isRespiratoryTurn;
  final RespiratoryTopic topic;
  final RespiratoryDurationBucket durationBucket;
  final RespiratoryCoughType coughType;
  final RespiratoryTriState sputum;
  final RespiratoryTriState breathlessness;
  final RespiratoryTriState wheeze;
  final RespiratoryTriState chestPain;
  final RespiratoryTriState fever;
  final RespiratoryTriState hemoptysis;
  final RespiratoryTriState weightLoss;
  final RespiratoryFunctionalImpact functionalImpact;
  final RespiratoryKnownCondition knownCondition;
  final RespiratorySmokingState smoking;
  final bool recurrentInfection;
  final bool recentRespiratoryIllness;
  final bool redFlagCandidate;
  final bool chestPainSafetyFirst;
  final bool severeDistress;
  final bool asksEducation;
  final bool asksServiceWhere;
  final bool asksBooking;
  final bool asksImagingWhere;
  final bool asksDirectChestXray;
  final bool selfSuspectsInfection;
  final bool isAboutOtherPerson;
  final bool pregnancyContextHint;
  final RespiratoryPopulation population;
  final bool explicitFollowUp;
  final bool correctionDuration;
  final bool correctionCoughType;
  final List<String> symptomKeys;

  static const none = RespiratoryInterpretation();
}

/// جلسة تنفسية — RAM فقط، بلا دفتر سعال دائم.
class RespiratorySession {
  const RespiratorySession({
    this.active = false,
    this.topic = RespiratoryTopic.unknownRespiratory,
    this.durationBucket = RespiratoryDurationBucket.unknown,
    this.durationClass = ClinicalCoughDurationClass.unknown,
    this.coughType = RespiratoryCoughType.unknown,
    this.sputum = RespiratoryTriState.unknown,
    this.breathlessness = RespiratoryTriState.unknown,
    this.wheeze = RespiratoryTriState.unknown,
    this.chestPain = RespiratoryTriState.unknown,
    this.fever = RespiratoryTriState.unknown,
    this.hemoptysis = RespiratoryTriState.unknown,
    this.weightLoss = RespiratoryTriState.unknown,
    this.functionalImpact = RespiratoryFunctionalImpact.unknown,
    this.knownCondition = RespiratoryKnownCondition.none,
    this.smoking = RespiratorySmokingState.unknown,
    this.recurrentInfection = false,
    this.recentRespiratoryIllness = false,
    this.redFlagCandidate = false,
    this.population = RespiratoryPopulation.unknown,
    this.pregnancyContext = false,
    this.questionCount = 0,
    this.askedQuestionKeys = const [],
    this.lastQuestionKey,
    this.lastRuleId,
    this.imagingAppropriateness,
    this.imagingModality,
    this.imagingReasonCode,
    this.investigationType = RespiratoryInvestigationType.none,
    this.destinationType,
    this.pendingDestination,
    this.lastGuidance = '',
    this.symptomKeys = const [],
  });

  final bool active;
  final RespiratoryTopic topic;
  final RespiratoryDurationBucket durationBucket;
  final ClinicalCoughDurationClass durationClass;
  final RespiratoryCoughType coughType;
  final RespiratoryTriState sputum;
  final RespiratoryTriState breathlessness;
  final RespiratoryTriState wheeze;
  final RespiratoryTriState chestPain;
  final RespiratoryTriState fever;
  final RespiratoryTriState hemoptysis;
  final RespiratoryTriState weightLoss;
  final RespiratoryFunctionalImpact functionalImpact;
  final RespiratoryKnownCondition knownCondition;
  final RespiratorySmokingState smoking;
  final bool recurrentInfection;
  final bool recentRespiratoryIllness;
  final bool redFlagCandidate;
  final RespiratoryPopulation population;
  final bool pregnancyContext;
  final int questionCount;
  final List<String> askedQuestionKeys;
  final String? lastQuestionKey;
  final String? lastRuleId;
  final ClinicalImagingAppropriateness? imagingAppropriateness;
  final ClinicalImagingModality? imagingModality;
  final String? imagingReasonCode;
  final RespiratoryInvestigationType investigationType;
  final ClinicalCareDestination? destinationType;
  final ClinicalCareDestination? pendingDestination;
  final String lastGuidance;
  final List<String> symptomKeys;

  static const inactive = RespiratorySession();

  bool get hasCoughContext =>
      topic == RespiratoryTopic.acuteCough ||
      topic == RespiratoryTopic.persistentCough ||
      topic == RespiratoryTopic.chronicCough ||
      coughType != RespiratoryCoughType.unknown ||
      symptomKeys.contains('cough');

  RespiratorySession copyWith({
    bool? active,
    RespiratoryTopic? topic,
    RespiratoryDurationBucket? durationBucket,
    ClinicalCoughDurationClass? durationClass,
    RespiratoryCoughType? coughType,
    RespiratoryTriState? sputum,
    RespiratoryTriState? breathlessness,
    RespiratoryTriState? wheeze,
    RespiratoryTriState? chestPain,
    RespiratoryTriState? fever,
    RespiratoryTriState? hemoptysis,
    RespiratoryTriState? weightLoss,
    RespiratoryFunctionalImpact? functionalImpact,
    RespiratoryKnownCondition? knownCondition,
    RespiratorySmokingState? smoking,
    bool? recurrentInfection,
    bool? recentRespiratoryIllness,
    bool? redFlagCandidate,
    RespiratoryPopulation? population,
    bool? pregnancyContext,
    int? questionCount,
    List<String>? askedQuestionKeys,
    String? lastQuestionKey,
    bool clearLastQuestion = false,
    String? lastRuleId,
    ClinicalImagingAppropriateness? imagingAppropriateness,
    ClinicalImagingModality? imagingModality,
    String? imagingReasonCode,
    RespiratoryInvestigationType? investigationType,
    ClinicalCareDestination? destinationType,
    ClinicalCareDestination? pendingDestination,
    String? lastGuidance,
    List<String>? symptomKeys,
  }) {
    return RespiratorySession(
      active: active ?? this.active,
      topic: topic ?? this.topic,
      durationBucket: durationBucket ?? this.durationBucket,
      durationClass: durationClass ?? this.durationClass,
      coughType: coughType ?? this.coughType,
      sputum: sputum ?? this.sputum,
      breathlessness: breathlessness ?? this.breathlessness,
      wheeze: wheeze ?? this.wheeze,
      chestPain: chestPain ?? this.chestPain,
      fever: fever ?? this.fever,
      hemoptysis: hemoptysis ?? this.hemoptysis,
      weightLoss: weightLoss ?? this.weightLoss,
      functionalImpact: functionalImpact ?? this.functionalImpact,
      knownCondition: knownCondition ?? this.knownCondition,
      smoking: smoking ?? this.smoking,
      recurrentInfection: recurrentInfection ?? this.recurrentInfection,
      recentRespiratoryIllness:
          recentRespiratoryIllness ?? this.recentRespiratoryIllness,
      redFlagCandidate: redFlagCandidate ?? this.redFlagCandidate,
      population: population ?? this.population,
      pregnancyContext: pregnancyContext ?? this.pregnancyContext,
      questionCount: questionCount ?? this.questionCount,
      askedQuestionKeys: askedQuestionKeys ?? this.askedQuestionKeys,
      lastQuestionKey: clearLastQuestion
          ? null
          : (lastQuestionKey ?? this.lastQuestionKey),
      lastRuleId: lastRuleId ?? this.lastRuleId,
      imagingAppropriateness:
          imagingAppropriateness ?? this.imagingAppropriateness,
      imagingModality: imagingModality ?? this.imagingModality,
      imagingReasonCode: imagingReasonCode ?? this.imagingReasonCode,
      investigationType: investigationType ?? this.investigationType,
      destinationType: destinationType ?? this.destinationType,
      pendingDestination: pendingDestination ?? this.pendingDestination,
      lastGuidance: lastGuidance ?? this.lastGuidance,
      symptomKeys: symptomKeys ?? this.symptomKeys,
    );
  }

  Map<String, Object?> debugMap() => {
        'respiratoryTopic': topic.name,
        'durationClass': durationClass.name,
        'symptomCount': symptomKeys.length,
        'hasBreathlessness': breathlessness == RespiratoryTriState.present,
        'hasRedFlagCandidate': redFlagCandidate,
        'functionalImpactClass': functionalImpact.name,
        'questionCount': questionCount,
        'matchedRuleId': lastRuleId,
        'investigationType': investigationType.name,
        'imagingAppropriateness': imagingAppropriateness?.name,
        'destinationType': destinationType?.name,
        // بلا نص أعراض خام / مدة دقيقة / تدخين / بلغم / تشخيص / personId
      };
}

class RespiratoryTurnResult {
  const RespiratoryTurnResult({
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
  final RespiratorySession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToServiceNavigation;
  final bool preserveDestinationContext;
  final bool textFirstOnly;
  final bool success;

  static RespiratoryTurnResult notHandled(RespiratorySession s) =>
      RespiratoryTurnResult(
        handled: false,
        message: '',
        session: s,
      );
}
