/// نماذج عامة لمحادثة موجَّهة — ليست طبية.
/// جلسة-محلية فقط؛ لا persistence.
library;

enum GuidedFlowStatus {
  inactive,
  active,
  waitingForAnswer,
  completed,
  cancelled,
}

enum GuidedQuestionType {
  freeText,
  yesNo,
  singleChoice,
  multipleChoice,
  duration,
  number,
  date,
  time,
}

enum GuidedAnswerType {
  freeText,
  yesNo,
  singleChoice,
  multipleChoice,
  duration,
  number,
  date,
  time,
  unknown,
}

enum GuidedFlowType {
  generic,
  serviceAssistanceDemo,
  searchClarification,
  confirmation,
  onboarding,
  /// محجوز للمستقبل — لا يُنفَّذ في Step 10A.
  healthGuidanceReserved,
}

/// خيار اختيار واحد/متعدد.
class GuidedChoiceOption {
  const GuidedChoiceOption({
    required this.id,
    required this.label,
    this.aliases = const [],
  });

  final String id;
  final String label;
  final List<String> aliases;
}

/// سؤال موجَّه ثابت المعرّف.
class GuidedQuestion {
  const GuidedQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.expectedAnswerType,
    this.options = const [],
    this.required = true,
    this.metadata = const {},
  });

  final String id;
  final GuidedQuestionType type;
  final String prompt;
  final GuidedAnswerType expectedAnswerType;
  final List<GuidedChoiceOption> options;
  final bool required;
  final Map<String, Object?> metadata;
}

/// مدة مهيكلة — بدون اختراع أرقام عند الغموض.
class DurationValue {
  const DurationValue({
    this.amount,
    this.unit,
    this.approximate = false,
    required this.rawText,
  });

  final int? amount;
  final String? unit; // day | week | month | year | relative_yesterday | relative_today | unknown
  final bool approximate;
  final String rawText;

  Map<String, Object?> toDebugMap() => {
        'amount': amount,
        'unit': unit,
        'approximate': approximate,
        // rawText عمداً غير مُدرَج في debugSnapshot العام
      };
}

/// إجابة محلولة على سؤال بمعرّف ثابت.
class GuidedAnswer {
  const GuidedAnswer({
    required this.questionId,
    required this.rawText,
    required this.normalizedValue,
    required this.answerType,
    this.resolved = true,
    this.optionIds = const [],
    this.yesNo,
    this.numberValue,
    this.durationValue,
  });

  final String questionId;
  final String rawText;
  final Object? normalizedValue;
  final GuidedAnswerType answerType;
  final bool resolved;
  final List<String> optionIds;
  final bool? yesNo;
  final num? numberValue;
  final DurationValue? durationValue;

  GuidedAnswer copyWith({
    String? rawText,
    Object? normalizedValue,
    bool? resolved,
    List<String>? optionIds,
    bool? yesNo,
    num? numberValue,
    DurationValue? durationValue,
  }) {
    return GuidedAnswer(
      questionId: questionId,
      rawText: rawText ?? this.rawText,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      answerType: answerType,
      resolved: resolved ?? this.resolved,
      optionIds: optionIds ?? this.optionIds,
      yesNo: yesNo ?? this.yesNo,
      numberValue: numberValue ?? this.numberValue,
      durationValue: durationValue ?? this.durationValue,
    );
  }
}

/// خطوة في تعريف تدفق.
class GuidedFlowStep {
  const GuidedFlowStep({
    required this.id,
    required this.question,
    this.nextStepId,
    this.nextStepByAnswer = const {},
  });

  final String id;
  final GuidedQuestion question;

  /// الانتقال الافتراضي بعد الإجابة.
  final String? nextStepId;

  /// انتقالات شرطية بسيطة: مفتاح = قيمة الإجابة المعيارية (مثلاً yes/no أو option id).
  final Map<String, String> nextStepByAnswer;
}

/// تعريف تدفق عام يزوّده المستدعي — المحرّك لا يخترع أسئلة طبية.
class GuidedFlowDefinition {
  const GuidedFlowDefinition({
    required this.id,
    required this.type,
    required this.steps,
    this.initialStepId,
  });

  final String id;
  final GuidedFlowType type;
  final List<GuidedFlowStep> steps;
  final String? initialStepId;

  GuidedFlowStep? stepById(String id) {
    for (final s in steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  GuidedFlowStep? get initialStep {
    if (initialStepId != null) return stepById(initialStepId!);
    return steps.isEmpty ? null : steps.first;
  }
}

/// حالة تدفق موجَّه — قابلة للقيمة/نسخ.
class GuidedConversationState {
  const GuidedConversationState({
    this.flowId,
    this.flowType = GuidedFlowType.generic,
    this.status = GuidedFlowStatus.inactive,
    this.currentStepId,
    this.pendingQuestion,
    this.collectedAnswers = const {},
    this.startedTurnId = 0,
    this.lastUpdatedTurnId = 0,
    this.definition,
  });

  final String? flowId;
  final GuidedFlowType flowType;
  final GuidedFlowStatus status;
  final String? currentStepId;
  final GuidedQuestion? pendingQuestion;
  final Map<String, GuidedAnswer> collectedAnswers;
  final int startedTurnId;
  final int lastUpdatedTurnId;

  /// التعريف النشط في الذاكرة فقط (لا يُصرَّف).
  final GuidedFlowDefinition? definition;

  bool get isWaitingForAnswer =>
      status == GuidedFlowStatus.waitingForAnswer && pendingQuestion != null;

  bool get isActive =>
      status == GuidedFlowStatus.active ||
      status == GuidedFlowStatus.waitingForAnswer;

  static const inactive = GuidedConversationState();

  GuidedConversationState copyWith({
    String? flowId,
    GuidedFlowType? flowType,
    GuidedFlowStatus? status,
    String? currentStepId,
    GuidedQuestion? pendingQuestion,
    Map<String, GuidedAnswer>? collectedAnswers,
    int? startedTurnId,
    int? lastUpdatedTurnId,
    GuidedFlowDefinition? definition,
    bool clearPendingQuestion = false,
    bool clearDefinition = false,
    bool clearFlowId = false,
  }) {
    return GuidedConversationState(
      flowId: clearFlowId ? null : (flowId ?? this.flowId),
      flowType: flowType ?? this.flowType,
      status: status ?? this.status,
      currentStepId: currentStepId ?? this.currentStepId,
      pendingQuestion: clearPendingQuestion
          ? null
          : (pendingQuestion ?? this.pendingQuestion),
      collectedAnswers: collectedAnswers ?? this.collectedAnswers,
      startedTurnId: startedTurnId ?? this.startedTurnId,
      lastUpdatedTurnId: lastUpdatedTurnId ?? this.lastUpdatedTurnId,
      definition: clearDefinition ? null : (definition ?? this.definition),
    );
  }

  /// لقطة مطوّر — بدون نصوص إجابات حرّة.
  Map<String, Object?> debugMap() => {
        'guidedFlowId': flowId,
        'guidedStatus': status.name,
        'pendingQuestionId': pendingQuestion?.id,
        'collectedAnswerCount': collectedAnswers.length,
        'currentStepId': currentStepId,
        'guidedFlowType': flowType.name,
      };
}

/// استجابة محادثة موجَّهة موحّدة للنص/الصوت/الأزرار لاحقاً.
class GuidedConversationResponse {
  const GuidedConversationResponse({
    required this.message,
    required this.flowStatus,
    this.nextQuestion,
    this.completedData = const {},
    this.cancelled = false,
    this.topicChanged = false,
    this.forwardQuery,
  });

  final String message;
  final GuidedFlowStatus flowStatus;
  final GuidedQuestion? nextQuestion;
  final Map<String, Object?> completedData;
  final bool cancelled;
  final bool topicChanged;

  /// عند تغيير الموضوع: النص المُعاد توجيهه لمسار Smart Brain العادي.
  final String? forwardQuery;
}
