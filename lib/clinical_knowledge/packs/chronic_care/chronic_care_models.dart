/// PC-1.20 — حزمة معرفة سريرية لرعاية السكري والضغط (فوق سلطة PC-1.5).
library;

import '../../clinical_knowledge_models.dart';

enum ChronicConditionKind {
  diabetes,
  hypertension,
  both,
  none,
}

enum ChronicConditionStatus {
  established,
  suspected,
  singleAbnormalMeasurement,
  screeningQuestion,
  familyHistoryOnly,
  unknown,
}

enum DiabetesTypeContext {
  type1,
  type2,
  gestational,
  otherKnownType,
  unspecifiedKnownDiabetes,
  unknown,
}

enum ChronicMeasurementKind {
  bloodGlucose,
  fastingGlucose,
  postMealGlucose,
  randomGlucose,
  hba1c,
  systolicBloodPressure,
  diastolicBloodPressure,
  unknown,
}

enum DiabetesCareItem {
  glycemicAssessment,
  bloodPressureAssessment,
  kidneyAssessment,
  eyeAssessment,
  footAssessment,
  cardiovascularRiskAssessment,
  lipidAssessment,
  lifestyleReview,
  smokingStatusReview,
  vaccinationReview,
  dentalReview,
  medicationReviewByClinician,
  hypoglycemiaReview,
  generalClinicalReview,
}

enum HypertensionCareItem {
  measurementQuality,
  homeMonitoring,
  clinicalConfirmation,
  bloodPressureGoalDiscussion,
  lifestyleReview,
  cardiovascularRiskReview,
  kidneyRiskReview,
  medicationReviewByClinician,
  followUpReview,
}

enum CareItemStatus {
  notApplicable,
  unknown,
  notYetDue,
  due,
  overdue,
  recentlyCompleted,
  needsClinicianReview,
}

enum ChronicClinicalTopic {
  diabetesEstablished,
  hypertensionEstablished,
  combinedCare,
  singleGlucoseReading,
  singleBpReading,
  homeBpTechnique,
  careChecklist,
  whatsLeft,
  education,
  serviceNavigation,
  followUpRequest,
  unknown,
}

/// عنصر رعاية مُجمَّع للرد.
class AssembledCarePriority {
  const AssembledCarePriority({
    required this.id,
    required this.status,
    required this.arabicLabel,
    this.reasonCode = '',
    this.matchedRuleId,
  });

  final String id;
  final CareItemStatus status;
  final String arabicLabel;
  final String reasonCode;
  final String? matchedRuleId;
}

class ChronicClinicalInterpretation {
  const ChronicClinicalInterpretation({
    this.isChronicClinicalTurn = false,
    this.topic = ChronicClinicalTopic.unknown,
    this.conditionKind = ChronicConditionKind.none,
    this.diabetesStatus = ChronicConditionStatus.unknown,
    this.hypertensionStatus = ChronicConditionStatus.unknown,
    this.diabetesType = DiabetesTypeContext.unknown,
    this.measurementKind = ChronicMeasurementKind.unknown,
    this.systolic,
    this.diastolic,
    this.glucoseValue,
    this.hba1cValue,
    this.unitExplicit = false,
    this.unitLabel = '',
    this.measurementContextUnknown = true,
    this.isFasting = false,
    this.isPostMeal = false,
    this.careItemHint,
    this.careCompletedHint,
    this.approximateTimingLabel = '',
    this.asksWhatsLeft = false,
    this.asksFullChecklist = false,
    this.asksEducation = false,
    this.asksWhyCareItem = false,
    this.asksBpTechnique = false,
    this.asksServiceWhere = false,
    this.asksBooking = false,
    this.cufflessDevice = false,
    this.redFlagCandidate = false,
    this.metabolicDangerHint = false,
    this.bpConcerningSymptoms = false,
    this.isAboutOtherPerson = false,
    this.pregnancyContextHint = false,
    this.explicitFollowUp = false,
    this.selfSuspectsDiabetes = false,
    this.selfSuspectsHypertension = false,
    this.insulinMentioned = false,
    this.correctionMeasurement = false,
    this.correctionDiabetesType = false,
    this.correctionSubject = false,
    this.footWoundHint = false,
    this.numbnessHint = false,
    this.knownRetinopathyHint = false,
  });

  final bool isChronicClinicalTurn;
  final ChronicClinicalTopic topic;
  final ChronicConditionKind conditionKind;
  final ChronicConditionStatus diabetesStatus;
  final ChronicConditionStatus hypertensionStatus;
  final DiabetesTypeContext diabetesType;
  final ChronicMeasurementKind measurementKind;
  final double? systolic;
  final double? diastolic;
  final double? glucoseValue;
  final double? hba1cValue;
  final bool unitExplicit;
  final String unitLabel;
  final bool measurementContextUnknown;
  final bool isFasting;
  final bool isPostMeal;
  final String? careItemHint;
  final String? careCompletedHint;
  final String approximateTimingLabel;
  final bool asksWhatsLeft;
  final bool asksFullChecklist;
  final bool asksEducation;
  final bool asksWhyCareItem;
  final bool asksBpTechnique;
  final bool asksServiceWhere;
  final bool asksBooking;
  final bool cufflessDevice;
  final bool redFlagCandidate;
  final bool metabolicDangerHint;
  final bool bpConcerningSymptoms;
  final bool isAboutOtherPerson;
  final bool pregnancyContextHint;
  final bool explicitFollowUp;
  final bool selfSuspectsDiabetes;
  final bool selfSuspectsHypertension;
  final bool insulinMentioned;
  final bool correctionMeasurement;
  final bool correctionDiabetesType;
  final bool correctionSubject;
  final bool footWoundHint;
  final bool numbnessHint;
  final bool knownRetinopathyHint;

  static const none = ChronicClinicalInterpretation();
}

/// جلسة محادثة للحزمة السريرية — ليست السجل المزمن (PC-1.5).
class ChronicClinicalSession {
  const ChronicClinicalSession({
    this.active = false,
    this.topic = ChronicClinicalTopic.unknown,
    this.conditionKind = ChronicConditionKind.none,
    this.diabetesStatus = ChronicConditionStatus.unknown,
    this.hypertensionStatus = ChronicConditionStatus.unknown,
    this.diabetesType = DiabetesTypeContext.unknown,
    this.lastSystolic,
    this.lastDiastolic,
    this.lastGlucose,
    this.lastHba1c,
    this.measurementContextUnknown = true,
    this.isFasting = false,
    this.isPostMeal = false,
    this.unitLabel = '',
    this.completedCareItems = const [],
    this.unknownCareItems = const [],
    this.dueCareItems = const [],
    this.askedQuestionKeys = const [],
    this.lastQuestionKey,
    this.questionCount = 0,
    this.matchedRuleIds = const [],
    this.destinationType,
    this.redFlagCandidate = false,
    this.pregnancyContext = false,
    this.isOtherPerson = false,
    this.cufflessWarned = false,
    this.lastGuidance = '',
    this.assembledPriorities = const [],
  });

  final bool active;
  final ChronicClinicalTopic topic;
  final ChronicConditionKind conditionKind;
  final ChronicConditionStatus diabetesStatus;
  final ChronicConditionStatus hypertensionStatus;
  final DiabetesTypeContext diabetesType;
  final double? lastSystolic;
  final double? lastDiastolic;
  final double? lastGlucose;
  final double? lastHba1c;
  final bool measurementContextUnknown;
  final bool isFasting;
  final bool isPostMeal;
  final String unitLabel;
  final List<String> completedCareItems;
  final List<String> unknownCareItems;
  final List<String> dueCareItems;
  final List<String> askedQuestionKeys;
  final String? lastQuestionKey;
  final int questionCount;
  final List<String> matchedRuleIds;
  final ClinicalCareDestination? destinationType;
  final bool redFlagCandidate;
  final bool pregnancyContext;
  final bool isOtherPerson;
  final bool cufflessWarned;
  final String lastGuidance;
  final List<AssembledCarePriority> assembledPriorities;

  static const inactive = ChronicClinicalSession();

  bool get hasEstablishedDiabetes =>
      diabetesStatus == ChronicConditionStatus.established;
  bool get hasEstablishedHypertension =>
      hypertensionStatus == ChronicConditionStatus.established;

  ChronicClinicalSession copyWith({
    bool? active,
    ChronicClinicalTopic? topic,
    ChronicConditionKind? conditionKind,
    ChronicConditionStatus? diabetesStatus,
    ChronicConditionStatus? hypertensionStatus,
    DiabetesTypeContext? diabetesType,
    double? lastSystolic,
    double? lastDiastolic,
    double? lastGlucose,
    double? lastHba1c,
    bool clearBp = false,
    bool clearGlucose = false,
    bool clearHba1c = false,
    bool? measurementContextUnknown,
    bool? isFasting,
    bool? isPostMeal,
    String? unitLabel,
    List<String>? completedCareItems,
    List<String>? unknownCareItems,
    List<String>? dueCareItems,
    List<String>? askedQuestionKeys,
    String? lastQuestionKey,
    bool clearLastQuestion = false,
    int? questionCount,
    List<String>? matchedRuleIds,
    ClinicalCareDestination? destinationType,
    bool? redFlagCandidate,
    bool? pregnancyContext,
    bool? isOtherPerson,
    bool? cufflessWarned,
    String? lastGuidance,
    List<AssembledCarePriority>? assembledPriorities,
  }) {
    return ChronicClinicalSession(
      active: active ?? this.active,
      topic: topic ?? this.topic,
      conditionKind: conditionKind ?? this.conditionKind,
      diabetesStatus: diabetesStatus ?? this.diabetesStatus,
      hypertensionStatus: hypertensionStatus ?? this.hypertensionStatus,
      diabetesType: diabetesType ?? this.diabetesType,
      lastSystolic: clearBp ? null : (lastSystolic ?? this.lastSystolic),
      lastDiastolic: clearBp ? null : (lastDiastolic ?? this.lastDiastolic),
      lastGlucose: clearGlucose ? null : (lastGlucose ?? this.lastGlucose),
      lastHba1c: clearHba1c ? null : (lastHba1c ?? this.lastHba1c),
      measurementContextUnknown:
          measurementContextUnknown ?? this.measurementContextUnknown,
      isFasting: isFasting ?? this.isFasting,
      isPostMeal: isPostMeal ?? this.isPostMeal,
      unitLabel: unitLabel ?? this.unitLabel,
      completedCareItems: completedCareItems ?? this.completedCareItems,
      unknownCareItems: unknownCareItems ?? this.unknownCareItems,
      dueCareItems: dueCareItems ?? this.dueCareItems,
      askedQuestionKeys: askedQuestionKeys ?? this.askedQuestionKeys,
      lastQuestionKey: clearLastQuestion
          ? null
          : (lastQuestionKey ?? this.lastQuestionKey),
      questionCount: questionCount ?? this.questionCount,
      matchedRuleIds: matchedRuleIds ?? this.matchedRuleIds,
      destinationType: destinationType ?? this.destinationType,
      redFlagCandidate: redFlagCandidate ?? this.redFlagCandidate,
      pregnancyContext: pregnancyContext ?? this.pregnancyContext,
      isOtherPerson: isOtherPerson ?? this.isOtherPerson,
      cufflessWarned: cufflessWarned ?? this.cufflessWarned,
      lastGuidance: lastGuidance ?? this.lastGuidance,
      assembledPriorities: assembledPriorities ?? this.assembledPriorities,
    );
  }

  Map<String, Object?> debugMap() => {
        'chronicDomain': conditionKind.name,
        'conditionStatus':
            '${diabetesStatus.name}/${hypertensionStatus.name}',
        'careItemType': dueCareItems.isEmpty ? null : dueCareItems.first,
        'careItemStatus': unknownCareItems.isNotEmpty ? 'unknown' : null,
        'matchedRuleId': matchedRuleIds.isEmpty ? null : matchedRuleIds.first,
        'measurementType': lastGlucose != null
            ? 'glucose'
            : (lastSystolic != null ? 'bp' : (lastHba1c != null ? 'hba1c' : null)),
        'measurementPresent':
            lastGlucose != null || lastSystolic != null || lastHba1c != null,
        'safetyDeferred': redFlagCandidate,
        'destinationType': destinationType?.name,
        'questionCount': questionCount,
        // بلا قيم خام / personId / تشخيص نصّي
      };
}

class ChronicClinicalTurnResult {
  const ChronicClinicalTurnResult({
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
  final ChronicClinicalSession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToServiceNavigation;
  final bool preserveDestinationContext;
  final bool textFirstOnly;
  final bool success;

  static ChronicClinicalTurnResult notHandled(ChronicClinicalSession s) =>
      ChronicClinicalTurnResult(handled: false, message: '', session: s);
}
