/// PC-1.2 — حالة onboarding تدريجي لصاحب الحساب فقط.
///
/// ليس HealthSubjectContext. لا يكتب بيانات ابن/أم إلى الملف الشخصي.

enum CompanionOnboardingStatus {
  notStarted,
  active,
  waitingForAnswer,
  paused,
  completed,
}

/// خطوات الحقول — العرض أولاً ثم الحقول الناقصة.
enum CompanionOnboardingStep {
  offer,
  preferredName,
  birthYear,
  sexSelection,
  userContext,
  done,
}

/// تفضيل منتج محلي (ليس ذاكرة صحية).
enum CompanionOnboardingPreferenceKind {
  none,
  declined,
  completed,
}

class CompanionOnboardingState {
  const CompanionOnboardingState({
    this.status = CompanionOnboardingStatus.notStarted,
    this.currentStep = CompanionOnboardingStep.offer,
    this.answeredFields = const {},
    this.skippedFields = const {},
    this.startedThisSession = false,
    this.awaitingAgeYearConfirm = false,
    this.proposedBirthYear,
    this.invalidAttempts = 0,
  });

  final CompanionOnboardingStatus status;
  final CompanionOnboardingStep currentStep;
  final Set<String> answeredFields;
  final Set<String> skippedFields;
  final bool startedThisSession;

  /// بعد «عمري 35» ننتظر تأكيد سنة الميلاد.
  final bool awaitingAgeYearConfirm;
  final int? proposedBirthYear;
  final int invalidAttempts;

  static const inactive = CompanionOnboardingState();

  bool get isWaiting =>
      status == CompanionOnboardingStatus.waitingForAnswer;

  bool get isActiveLike =>
      status == CompanionOnboardingStatus.active ||
      status == CompanionOnboardingStatus.waitingForAnswer;

  CompanionOnboardingState copyWith({
    CompanionOnboardingStatus? status,
    CompanionOnboardingStep? currentStep,
    Set<String>? answeredFields,
    Set<String>? skippedFields,
    bool? startedThisSession,
    bool? awaitingAgeYearConfirm,
    int? proposedBirthYear,
    int? invalidAttempts,
    bool clearProposedBirthYear = false,
  }) {
    return CompanionOnboardingState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      answeredFields: answeredFields ?? this.answeredFields,
      skippedFields: skippedFields ?? this.skippedFields,
      startedThisSession: startedThisSession ?? this.startedThisSession,
      awaitingAgeYearConfirm:
          awaitingAgeYearConfirm ?? this.awaitingAgeYearConfirm,
      proposedBirthYear: clearProposedBirthYear
          ? null
          : (proposedBirthYear ?? this.proposedBirthYear),
      invalidAttempts: invalidAttempts ?? this.invalidAttempts,
    );
  }

  /// ميتاداتا آمنة — بلا إجابات.
  Map<String, Object?> debugMap() => {
        'onboardingStatus': status.name,
        'currentStep': currentStep.name,
        'completedFieldCount': answeredFields.length,
        'skippedFieldCount': skippedFields.length,
        'startedThisSession': startedThisSession,
        'awaitingAgeYearConfirm': awaitingAgeYearConfirm,
        'invalidAttempts': invalidAttempts,
      };
}

enum CompanionOnboardingInterpretKind {
  resolved,
  skip,
  pause,
  whyQuestion,
  correction,
  topicChanged,
  invalid,
  acceptOffer,
  declineOffer,
  laterOffer,
  ageNeedsConfirm,
}

class CompanionOnboardingInterpretation {
  const CompanionOnboardingInterpretation({
    required this.kind,
    this.preferredName,
    this.birthYear,
    this.birthDate,
    this.sexSelectionName,
    this.userContextName,
    this.proposedBirthYear,
    this.explanation,
    this.message,
  });

  final CompanionOnboardingInterpretKind kind;
  final String? preferredName;
  final int? birthYear;
  final DateTime? birthDate;
  final String? sexSelectionName;
  final String? userContextName;
  final int? proposedBirthYear;
  final String? explanation;
  final String? message;
}

class CompanionOnboardingTurnResult {
  const CompanionOnboardingTurnResult({
    required this.handled,
    required this.state,
    this.message = '',
    this.pauseAndForward = false,
    this.forwardQuery,
  });

  final bool handled;
  final CompanionOnboardingState state;
  final String message;
  final bool pauseAndForward;
  final String? forwardQuery;

  static CompanionOnboardingTurnResult notHandled(
    CompanionOnboardingState state,
  ) =>
      CompanionOnboardingTurnResult(handled: false, state: state);
}
