/// PC-1.23 — رفيق رفاهية وحياة المراهق (سياق نمائي؛ ليس محرك تشخيص نفسي).
library;

enum AdolescentDevelopmentState {
  confirmedAdolescent,
  possibleAgeRelevant,
  adult,
  youngerChild,
  unknown,
}

enum AdolescentTopic {
  studyDifficulty,
  examStress,
  concentrationDifficulty,
  motivationDifficulty,
  timeManagement,
  schoolRoutine,
  sleepRoutine,
  lateSleep,
  fatigue,
  physicalActivity,
  sedentaryBehavior,
  dailyRoutine,
  selfConfidence,
  bodyImageConcern,
  friendship,
  peerPressure,
  bullying,
  cyberbullying,
  familyTension,
  communicationDifficulty,
  anger,
  sadness,
  worry,
  stress,
  loneliness,
  goalSetting,
  habitBuilding,
  helpSeeking,
  generalPubertyEducation,
  generalAdolescentHealth,
  educationOnly,
  unknown,
}

enum AdolescentFunctionalImpact {
  studyAffected,
  sleepAffected,
  dailyActivitiesAffected,
  relationshipsAffected,
  schoolAttendanceAffected,
  unknown,
}

enum AdolescentSupportDestination {
  trustedAdult,
  parentGuardianWhenSafe,
  schoolSupport,
  primaryCare,
  mentalHealthProfessional,
  emergency,
  none,
}

class AdolescentInterpretation {
  const AdolescentInterpretation({
    this.isAdolescentTurn = false,
    this.topic = AdolescentTopic.unknown,
    this.statedAgeYears,
    this.developmentState = AdolescentDevelopmentState.unknown,
    this.functionalImpacts = const [],
    this.isAboutOtherPerson = false,
    this.otherPersonLabel = '',
    this.parentAskingAboutTeen = false,
    this.correctionSubject = false,
    this.correctionAge = false,
    this.asksEducation = false,
    this.asksPlan = false,
    this.asksActivity = false,
    this.asksSleep = false,
    this.asksStudyHelp = false,
    this.explicitFollowUp = false,
    this.bullyingHint = false,
    this.cyberbullyingHint = false,
    this.threatHint = false,
    this.bodyImageHint = false,
    this.weightLossRequest = false,
    this.dietPillRequest = false,
    this.extremeDietHint = false,
    this.pubertyEducation = false,
    this.dependencyLanguageProbe = false,
    this.secrecyPromiseProbe = false,
    this.medicalForeignDomain = false,
  });

  final bool isAdolescentTurn;
  final AdolescentTopic topic;
  final int? statedAgeYears;
  final AdolescentDevelopmentState developmentState;
  final List<AdolescentFunctionalImpact> functionalImpacts;
  final bool isAboutOtherPerson;
  final String otherPersonLabel;
  final bool parentAskingAboutTeen;
  final bool correctionSubject;
  final bool correctionAge;
  final bool asksEducation;
  final bool asksPlan;
  final bool asksActivity;
  final bool asksSleep;
  final bool asksStudyHelp;
  final bool explicitFollowUp;
  final bool bullyingHint;
  final bool cyberbullyingHint;
  final bool threatHint;
  final bool bodyImageHint;
  final bool weightLossRequest;
  final bool dietPillRequest;
  final bool extremeDietHint;
  final bool pubertyEducation;
  final bool dependencyLanguageProbe;
  final bool secrecyPromiseProbe;
  final bool medicalForeignDomain;

  static const none = AdolescentInterpretation();
}

/// جلسة رفيق المراهق — RAM فقط؛ بلا يوميات/مراقبة/تشخيص.
class AdolescentCompanionSession {
  const AdolescentCompanionSession({
    this.active = false,
    this.statedAgeYears,
    this.developmentState = AdolescentDevelopmentState.unknown,
    this.topic = AdolescentTopic.unknown,
    this.isOtherPerson = false,
    this.otherPersonLabel = '',
    this.parentAskingAboutTeen = false,
    this.functionalImpacts = const [],
    this.askedQuestionKeys = const [],
    this.lastQuestionKey,
    this.questionCount = 0,
    this.matchedRuleIds = const [],
    this.supportDestination = AdolescentSupportDestination.none,
    this.bullyingContext = false,
    this.bodyImageContext = false,
    this.lastGuidance = '',
  });

  final bool active;
  final int? statedAgeYears;
  final AdolescentDevelopmentState developmentState;
  final AdolescentTopic topic;
  final bool isOtherPerson;
  final String otherPersonLabel;
  final bool parentAskingAboutTeen;
  final List<AdolescentFunctionalImpact> functionalImpacts;
  final List<String> askedQuestionKeys;
  final String? lastQuestionKey;
  final int questionCount;
  final List<String> matchedRuleIds;
  final AdolescentSupportDestination supportDestination;
  final bool bullyingContext;
  final bool bodyImageContext;
  final String lastGuidance;

  static const inactive = AdolescentCompanionSession();

  bool get isConfirmedAdolescent =>
      developmentState == AdolescentDevelopmentState.confirmedAdolescent;

  AdolescentCompanionSession copyWith({
    bool? active,
    int? statedAgeYears,
    bool clearAge = false,
    AdolescentDevelopmentState? developmentState,
    AdolescentTopic? topic,
    bool? isOtherPerson,
    String? otherPersonLabel,
    bool? parentAskingAboutTeen,
    List<AdolescentFunctionalImpact>? functionalImpacts,
    List<String>? askedQuestionKeys,
    String? lastQuestionKey,
    bool clearLastQuestion = false,
    int? questionCount,
    List<String>? matchedRuleIds,
    AdolescentSupportDestination? supportDestination,
    bool? bullyingContext,
    bool? bodyImageContext,
    String? lastGuidance,
  }) {
    return AdolescentCompanionSession(
      active: active ?? this.active,
      statedAgeYears: clearAge ? null : (statedAgeYears ?? this.statedAgeYears),
      developmentState: developmentState ?? this.developmentState,
      topic: topic ?? this.topic,
      isOtherPerson: isOtherPerson ?? this.isOtherPerson,
      otherPersonLabel: otherPersonLabel ?? this.otherPersonLabel,
      parentAskingAboutTeen:
          parentAskingAboutTeen ?? this.parentAskingAboutTeen,
      functionalImpacts: functionalImpacts ?? this.functionalImpacts,
      askedQuestionKeys: askedQuestionKeys ?? this.askedQuestionKeys,
      lastQuestionKey: clearLastQuestion
          ? null
          : (lastQuestionKey ?? this.lastQuestionKey),
      questionCount: questionCount ?? this.questionCount,
      matchedRuleIds: matchedRuleIds ?? this.matchedRuleIds,
      supportDestination: supportDestination ?? this.supportDestination,
      bullyingContext: bullyingContext ?? this.bullyingContext,
      bodyImageContext: bodyImageContext ?? this.bodyImageContext,
      lastGuidance: lastGuidance ?? this.lastGuidance,
    );
  }

  Map<String, Object?> debugMap() => {
        'adolescentContext':
            developmentState == AdolescentDevelopmentState.confirmedAdolescent,
        'topic': topic.name,
        'safetyDeferred': false,
        'functionalImpactKnown': functionalImpacts.isNotEmpty,
        'matchedRuleId': matchedRuleIds.isEmpty ? null : matchedRuleIds.first,
        // بلا عمر خام مربوط بهوية / تنمر / personId / نص حسّاس
      };
}

class AdolescentCompanionTurnResult {
  const AdolescentCompanionTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.deferToMedicalSafety = false,
    this.deferToMentalSafety = false,
    this.deferToFollowUp = false,
    this.deferToClinicalPack = false,
    this.deferToEmotionalSupport = false,
    this.deferToDailyContext = false,
    this.deferToActivity = false,
    this.deferToPlanner = false,
    this.textFirstOnly = true,
    this.success = true,
  });

  final bool handled;
  final String message;
  final AdolescentCompanionSession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToClinicalPack;
  final bool deferToEmotionalSupport;
  final bool deferToDailyContext;
  final bool deferToActivity;
  final bool deferToPlanner;
  final bool textFirstOnly;
  final bool success;

  static AdolescentCompanionTurnResult notHandled(
    AdolescentCompanionSession s,
  ) =>
      AdolescentCompanionTurnResult(handled: false, message: '', session: s);
}
