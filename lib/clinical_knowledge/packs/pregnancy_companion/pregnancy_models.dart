/// PC-1.21 — رفيق الحمل المبني على الأدلة (تنسيق سياق؛ ليس محرك ولادة).
library;

import '../../clinical_knowledge_models.dart';

enum PregnancyStatus {
  confirmed,
  possible,
  tryingToConceive,
  postpartum,
  pregnancyLossReported,
  notPregnant,
  unknown,
}

enum GestationalDatingSource {
  explicitWeek,
  explicitDueDate,
  explicitLmp,
  clinicianEstimate,
  ultrasoundEstimate,
  trimesterOnly,
  monthColloquial,
  unknown,
}

enum PregnancyStage {
  earlyPregnancy,
  firstTrimester,
  secondTrimester,
  thirdTrimester,
  latePregnancy,
  termContext,
  unknown,
}

enum PregnancyCareItem {
  pregnancyConfirmation,
  gestationalDating,
  antenatalContact,
  bloodPressureAssessment,
  routineBloodTesting,
  gestationalDiabetesScreening,
  ultrasoundDating,
  fetalAnatomyAssessment,
  fetalGrowthAssessment,
  fetalMovementEducation,
  nutritionReview,
  physicalActivityReview,
  vaccinationReview,
  medicationReviewByClinician,
  birthPreparedness,
  mentalWellbeingReview,
  generalObstetricReview,
}

enum PregnancyCareItemStatus {
  notApplicable,
  unknown,
  notYetDue,
  due,
  overdue,
  recentlyCompleted,
  needsClinicianReview,
}

enum PregnancyCompanionIntent {
  pregnancyGeneralQuestion,
  gestationalAgeQuestion,
  whatToExpect,
  whatIsDue,
  careChecklist,
  currentSymptom,
  nutritionQuestion,
  activityQuestion,
  ultrasoundQuestion,
  labQuestion,
  fetalSexQuestion,
  birthPreparation,
  emotionalSupport,
  clinicianPlanQuestion,
  serviceContinuation,
  educationOnly,
  safetyConcern,
  unknown,
}

enum PregnancySymptomClass {
  commonPossible,
  selfCareEligible,
  needsClarification,
  needsClinicianReview,
  safetyConcern,
  deferTo10E,
  unknown,
}

class PregnancyCarePriority {
  const PregnancyCarePriority({
    required this.id,
    required this.status,
    required this.arabicLabel,
    this.matchedRuleId,
  });

  final String id;
  final PregnancyCareItemStatus status;
  final String arabicLabel;
  final String? matchedRuleId;
}

class PregnancyInterpretation {
  const PregnancyInterpretation({
    this.isPregnancyTurn = false,
    this.intent = PregnancyCompanionIntent.unknown,
    this.status = PregnancyStatus.unknown,
    this.datingSource = GestationalDatingSource.unknown,
    this.gestationalWeeks,
    this.gestationalDaysExtra,
    this.trimesterHint,
    this.monthColloquial,
    this.stage = PregnancyStage.unknown,
    this.isAboutOtherPerson = false,
    this.otherPersonLabel = '',
    this.asksWhatsLeft = false,
    this.asksFullChecklist = false,
    this.asksEducation = false,
    this.asksUltrasound = false,
    this.asksFetalSex = false,
    this.asksActivity = false,
    this.asksNutrition = false,
    this.asksServiceWhere = false,
    this.asksBooking = false,
    this.explicitFollowUp = false,
    this.careCompletedHint,
    this.clinicianSaid = '',
    this.fetalSexFromClinician = '',
    this.symptomKey = '',
    this.symptomClass = PregnancySymptomClass.unknown,
    this.redFlagCandidate = false,
    this.bleedingHint = false,
    this.reducedMovementHint = false,
    this.gdmEstablished = false,
    this.preexistingDiabetes = false,
    this.highBpHint = false,
    this.correctionSubject = false,
    this.correctionWeek = false,
    this.pregnancyLossHint = false,
    this.tryingToConceive = false,
    this.possibleOnly = false,
  });

  final bool isPregnancyTurn;
  final PregnancyCompanionIntent intent;
  final PregnancyStatus status;
  final GestationalDatingSource datingSource;
  final int? gestationalWeeks;
  final int? gestationalDaysExtra;
  final int? trimesterHint;
  final int? monthColloquial;
  final PregnancyStage stage;
  final bool isAboutOtherPerson;
  final String otherPersonLabel;
  final bool asksWhatsLeft;
  final bool asksFullChecklist;
  final bool asksEducation;
  final bool asksUltrasound;
  final bool asksFetalSex;
  final bool asksActivity;
  final bool asksNutrition;
  final bool asksServiceWhere;
  final bool asksBooking;
  final bool explicitFollowUp;
  final String? careCompletedHint;
  final String clinicianSaid;
  final String fetalSexFromClinician;
  final String symptomKey;
  final PregnancySymptomClass symptomClass;
  final bool redFlagCandidate;
  final bool bleedingHint;
  final bool reducedMovementHint;
  final bool gdmEstablished;
  final bool preexistingDiabetes;
  final bool highBpHint;
  final bool correctionSubject;
  final bool correctionWeek;
  final bool pregnancyLossHint;
  final bool tryingToConceive;
  final bool possibleOnly;

  static const none = PregnancyInterpretation();
}

/// جلسة رفيق الحمل — RAM فقط؛ ليست سجلاً طبياً دائماً.
class PregnancyCompanionSession {
  const PregnancyCompanionSession({
    this.active = false,
    this.status = PregnancyStatus.unknown,
    this.datingSource = GestationalDatingSource.unknown,
    this.gestationalWeeks,
    this.gestationalDaysExtra,
    this.stage = PregnancyStage.unknown,
    this.isOtherPerson = false,
    this.otherPersonLabel = '',
    this.completedCareItems = const [],
    this.unknownCareItems = const [],
    this.askedQuestionKeys = const [],
    this.lastQuestionKey,
    this.questionCount = 0,
    this.matchedRuleIds = const [],
    this.destinationType,
    this.intent = PregnancyCompanionIntent.unknown,
    this.clinicianPlanHint = '',
    this.fetalSexFromClinician = '',
    this.redFlagCandidate = false,
    this.priorities = const [],
    this.lastGuidance = '',
  });

  final bool active;
  final PregnancyStatus status;
  final GestationalDatingSource datingSource;
  final int? gestationalWeeks;
  final int? gestationalDaysExtra;
  final PregnancyStage stage;
  final bool isOtherPerson;
  final String otherPersonLabel;
  final List<String> completedCareItems;
  final List<String> unknownCareItems;
  final List<String> askedQuestionKeys;
  final String? lastQuestionKey;
  final int questionCount;
  final List<String> matchedRuleIds;
  final ClinicalCareDestination? destinationType;
  final PregnancyCompanionIntent intent;
  final String clinicianPlanHint;
  final String fetalSexFromClinician;
  final bool redFlagCandidate;
  final List<PregnancyCarePriority> priorities;
  final String lastGuidance;

  static const inactive = PregnancyCompanionSession();

  bool get isConfirmedOwnerPregnancy =>
      active &&
      status == PregnancyStatus.confirmed &&
      !isOtherPerson;

  PregnancyCompanionSession copyWith({
    bool? active,
    PregnancyStatus? status,
    GestationalDatingSource? datingSource,
    int? gestationalWeeks,
    int? gestationalDaysExtra,
    bool clearGestation = false,
    PregnancyStage? stage,
    bool? isOtherPerson,
    String? otherPersonLabel,
    List<String>? completedCareItems,
    List<String>? unknownCareItems,
    List<String>? askedQuestionKeys,
    String? lastQuestionKey,
    bool clearLastQuestion = false,
    int? questionCount,
    List<String>? matchedRuleIds,
    ClinicalCareDestination? destinationType,
    PregnancyCompanionIntent? intent,
    String? clinicianPlanHint,
    String? fetalSexFromClinician,
    bool? redFlagCandidate,
    List<PregnancyCarePriority>? priorities,
    String? lastGuidance,
  }) {
    return PregnancyCompanionSession(
      active: active ?? this.active,
      status: status ?? this.status,
      datingSource: datingSource ?? this.datingSource,
      gestationalWeeks:
          clearGestation ? null : (gestationalWeeks ?? this.gestationalWeeks),
      gestationalDaysExtra: clearGestation
          ? null
          : (gestationalDaysExtra ?? this.gestationalDaysExtra),
      stage: stage ?? this.stage,
      isOtherPerson: isOtherPerson ?? this.isOtherPerson,
      otherPersonLabel: otherPersonLabel ?? this.otherPersonLabel,
      completedCareItems: completedCareItems ?? this.completedCareItems,
      unknownCareItems: unknownCareItems ?? this.unknownCareItems,
      askedQuestionKeys: askedQuestionKeys ?? this.askedQuestionKeys,
      lastQuestionKey: clearLastQuestion
          ? null
          : (lastQuestionKey ?? this.lastQuestionKey),
      questionCount: questionCount ?? this.questionCount,
      matchedRuleIds: matchedRuleIds ?? this.matchedRuleIds,
      destinationType: destinationType ?? this.destinationType,
      intent: intent ?? this.intent,
      clinicianPlanHint: clinicianPlanHint ?? this.clinicianPlanHint,
      fetalSexFromClinician:
          fetalSexFromClinician ?? this.fetalSexFromClinician,
      redFlagCandidate: redFlagCandidate ?? this.redFlagCandidate,
      priorities: priorities ?? this.priorities,
      lastGuidance: lastGuidance ?? this.lastGuidance,
    );
  }

  Map<String, Object?> debugMap() => {
        'pregnancyIntent': intent != PregnancyCompanionIntent.unknown,
        'gestationalContextKnown': gestationalWeeks != null ||
            stage != PregnancyStage.unknown,
        'matchedRuleId': matchedRuleIds.isEmpty ? null : matchedRuleIds.first,
        'safetyDeferred': redFlagCandidate,
        'careItemType':
            priorities.isEmpty ? null : priorities.first.id,
        // بلا أسبوع خام مربوط بشخص / EDD / جنس / personId
      };
}

class PregnancyCompanionTurnResult {
  const PregnancyCompanionTurnResult({
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
  final PregnancyCompanionSession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToServiceNavigation;
  final bool preserveDestinationContext;
  final bool textFirstOnly;
  final bool success;

  static PregnancyCompanionTurnResult notHandled(PregnancyCompanionSession s) =>
      PregnancyCompanionTurnResult(handled: false, message: '', session: s);
}
