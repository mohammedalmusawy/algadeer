import 'arabic_answer_normalizer.dart';
import 'guided_answer_resolver.dart';
import 'guided_conversation_models.dart';
import 'guided_demo_flows.dart';
import 'guided_topic_change_detector.dart';
import '../intent/intent_result.dart';

/// محرّك تدفق موجَّه خفيف — لا يقرر أسئلة طبية ولا يعتمد على TTS.
class GuidedConversationEngine {
  GuidedConversationEngine({
    GuidedAnswerResolver? answerResolver,
    GuidedTopicChangeDetector? topicChangeDetector,
  })  : _answers = answerResolver ?? const GuidedAnswerResolver(),
        _topic = topicChangeDetector ?? const GuidedTopicChangeDetector();

  final GuidedAnswerResolver _answers;
  final GuidedTopicChangeDetector _topic;

  GuidedAnswerResolver get answerResolver => _answers;
  GuidedTopicChangeDetector get topicChangeDetector => _topic;

  /// يبدأ تدفقاً من تعريف جاهز.
  GuidedConversationResponse startFlow({
    required GuidedFlowDefinition definition,
    required GuidedConversationState Function() readState,
    required void Function(GuidedConversationState) writeState,
    required int turnId,
  }) {
    final first = definition.initialStep;
    if (first == null) {
      return const GuidedConversationResponse(
        message: 'ماكو خطوات بهاي المساعدة حالياً.',
        flowStatus: GuidedFlowStatus.inactive,
      );
    }

    final state = GuidedConversationState(
      flowId: definition.id,
      flowType: definition.type,
      status: GuidedFlowStatus.waitingForAnswer,
      currentStepId: first.id,
      pendingQuestion: first.question,
      collectedAnswers: const {},
      startedTurnId: turnId,
      lastUpdatedTurnId: turnId,
      definition: definition,
    );
    writeState(state);

    return GuidedConversationResponse(
      message: first.question.prompt,
      flowStatus: GuidedFlowStatus.waitingForAnswer,
      nextQuestion: first.question,
    );
  }

  /// اختصار لبدء تدفق العرض التجريبي غير الطبي.
  GuidedConversationResponse startServiceAssistanceDemo({
    required GuidedConversationState Function() readState,
    required void Function(GuidedConversationState) writeState,
    required int turnId,
  }) {
    return startFlow(
      definition: GuidedDemoFlows.serviceAssistanceDemo(),
      readState: readState,
      writeState: writeState,
      turnId: turnId,
    );
  }

  GuidedConversationResponse cancel({
    required void Function(GuidedConversationState) writeState,
    required int turnId,
    String message = 'تم إلغاء المساعدة الموجّهة.',
  }) {
    writeState(
      GuidedConversationState(
        status: GuidedFlowStatus.cancelled,
        lastUpdatedTurnId: turnId,
      ),
    );
    return GuidedConversationResponse(
      message: message,
      flowStatus: GuidedFlowStatus.cancelled,
      cancelled: true,
    );
  }

  GuidedConversationResponse reset({
    required void Function(GuidedConversationState) writeState,
  }) {
    writeState(GuidedConversationState.inactive);
    return const GuidedConversationResponse(
      message: '',
      flowStatus: GuidedFlowStatus.inactive,
    );
  }

  /// يعالج إدخال المستخدم عندما تكون الحالة waitingForAnswer.
  GuidedConversationResponse handleUserInput({
    required String query,
    required GuidedConversationState state,
    required void Function(GuidedConversationState) writeState,
    required int turnId,
    IntentResult? intentResult,
  }) {
    // تصحيح إجابة سابقة بعد الإكمال أو أثناء التدفق.
    if (ArabicAnswerNormalizer.looksLikeCorrection(query) &&
        state.collectedAnswers.isNotEmpty) {
      final corrected = _tryCorrectPrevious(
        query: query,
        state: state,
        writeState: writeState,
        turnId: turnId,
        intentResult: intentResult,
      );
      if (corrected != null) return corrected;
    }

    if (!state.isWaitingForAnswer || state.pendingQuestion == null) {
      return GuidedConversationResponse(
        message: '',
        flowStatus: state.status,
      );
    }

    final resolved = _answers.resolve(
      query: query,
      question: state.pendingQuestion!,
      intentResult: intentResult,
    );

    switch (resolved.status) {
      case GuidedAnswerResolveStatus.cancelled:
        return cancel(writeState: writeState, turnId: turnId);

      case GuidedAnswerResolveStatus.topicChanged:
        writeState(
          GuidedConversationState(
            status: GuidedFlowStatus.cancelled,
            lastUpdatedTurnId: turnId,
            collectedAnswers: state.collectedAnswers,
            flowId: state.flowId,
            flowType: state.flowType,
          ),
        );
        return GuidedConversationResponse(
          message: '',
          flowStatus: GuidedFlowStatus.cancelled,
          topicChanged: true,
          forwardQuery: resolved.forwardQuery ?? query,
        );

      case GuidedAnswerResolveStatus.needsClarification:
        writeState(
          state.copyWith(lastUpdatedTurnId: turnId),
        );
        return GuidedConversationResponse(
          message: resolved.message.isNotEmpty
              ? resolved.message
              : 'ما فهمت الجواب، كرر لو سمحت.',
          flowStatus: GuidedFlowStatus.waitingForAnswer,
          nextQuestion: state.pendingQuestion,
        );

      case GuidedAnswerResolveStatus.unresolved:
        return GuidedConversationResponse(
          message: '',
          flowStatus: state.status,
          // يُترك للمسار العادي إن لم يكن جواباً قصيراً متوافقاً.
        );

      case GuidedAnswerResolveStatus.resolved:
        return _acceptAnswer(
          answer: resolved.answer!,
          state: state,
          writeState: writeState,
          turnId: turnId,
        );
    }
  }

  GuidedConversationResponse _acceptAnswer({
    required GuidedAnswer answer,
    required GuidedConversationState state,
    required void Function(GuidedConversationState) writeState,
    required int turnId,
  }) {
    final nextAnswers = Map<String, GuidedAnswer>.from(state.collectedAnswers);
    nextAnswers[answer.questionId] = answer;

    final def = state.definition;
    final step = def?.stepById(state.currentStepId ?? '');
    final transitionKey = _transitionKey(answer);
    String? nextId = step?.nextStepByAnswer[transitionKey];
    nextId ??= step?.nextStepId;

    // NO على سؤال المساعدة → إكمال بدون خدمة.
    if (answer.answerType == GuidedAnswerType.yesNo &&
        answer.yesNo == false &&
        step?.nextStepByAnswer.containsKey('no') == true) {
      nextId = step!.nextStepByAnswer['no'];
    }
    if (answer.answerType == GuidedAnswerType.yesNo &&
        answer.yesNo == true &&
        step?.nextStepByAnswer.containsKey('yes') == true) {
      nextId = step!.nextStepByAnswer['yes'];
    }

    if (nextId == null || nextId == '__complete__') {
      final completed = GuidedConversationState(
        flowId: state.flowId,
        flowType: state.flowType,
        status: GuidedFlowStatus.completed,
        currentStepId: state.currentStepId,
        pendingQuestion: null,
        collectedAnswers: Map.unmodifiable(nextAnswers),
        startedTurnId: state.startedTurnId,
        lastUpdatedTurnId: turnId,
        definition: state.definition,
      );
      writeState(completed);
      return GuidedConversationResponse(
        message: 'تمام، خلصنا.',
        flowStatus: GuidedFlowStatus.completed,
        completedData: _completedData(nextAnswers),
      );
    }

    final nextStep = def?.stepById(nextId);
    if (nextStep == null) {
      final completed = GuidedConversationState(
        flowId: state.flowId,
        flowType: state.flowType,
        status: GuidedFlowStatus.completed,
        collectedAnswers: Map.unmodifiable(nextAnswers),
        startedTurnId: state.startedTurnId,
        lastUpdatedTurnId: turnId,
        definition: state.definition,
      );
      writeState(completed);
      return GuidedConversationResponse(
        message: 'تمام، خلصنا.',
        flowStatus: GuidedFlowStatus.completed,
        completedData: _completedData(nextAnswers),
      );
    }

    final waiting = GuidedConversationState(
      flowId: state.flowId,
      flowType: state.flowType,
      status: GuidedFlowStatus.waitingForAnswer,
      currentStepId: nextStep.id,
      pendingQuestion: nextStep.question,
      collectedAnswers: Map.unmodifiable(nextAnswers),
      startedTurnId: state.startedTurnId,
      lastUpdatedTurnId: turnId,
      definition: state.definition,
    );
    writeState(waiting);
    return GuidedConversationResponse(
      message: nextStep.question.prompt,
      flowStatus: GuidedFlowStatus.waitingForAnswer,
      nextQuestion: nextStep.question,
      completedData: _completedData(nextAnswers),
    );
  }

  String _transitionKey(GuidedAnswer answer) {
    if (answer.yesNo == true) return 'yes';
    if (answer.yesNo == false) return 'no';
    if (answer.optionIds.isNotEmpty) return answer.optionIds.first;
    final v = answer.normalizedValue;
    if (v is String) return v;
    return '';
  }

  Map<String, Object?> _completedData(Map<String, GuidedAnswer> answers) {
    final out = <String, Object?>{};
    for (final e in answers.entries) {
      final a = e.value;
      if (a.yesNo != null) {
        out[e.key] = a.yesNo;
      } else if (a.optionIds.isNotEmpty) {
        out[e.key] = a.optionIds.length == 1 ? a.optionIds.first : a.optionIds;
      } else if (a.numberValue != null) {
        out[e.key] = a.numberValue;
      } else if (a.durationValue != null) {
        out[e.key] = a.durationValue!.toDebugMap();
      } else {
        out[e.key] = a.normalizedValue;
      }
    }
    // مفتاح ودّي للعرض التجريبي.
    final service = answers['service_type'];
    if (service != null && service.optionIds.isNotEmpty) {
      out['serviceType'] = service.optionIds.first;
    }
    return out;
  }

  GuidedConversationResponse? _tryCorrectPrevious({
    required String query,
    required GuidedConversationState state,
    required void Function(GuidedConversationState) writeState,
    required int turnId,
    IntentResult? intentResult,
  }) {
    final def = state.definition;
    if (def == null) return null;

    // آخر إجابة مجموعة — نحاول إعادة حلها بنفس نوع السؤال.
    final lastId = state.collectedAnswers.keys.last;
    GuidedQuestion? question;
    for (final step in def.steps) {
      if (step.question.id == lastId) {
        question = step.question;
        break;
      }
    }
    question ??= state.pendingQuestion;
    if (question == null) return null;

    final resolved = _answers.resolve(
      query: query,
      question: question,
      intentResult: intentResult,
      allowTopicEscape: false,
    );
    if (resolved.status != GuidedAnswerResolveStatus.resolved ||
        resolved.answer == null) {
      return null;
    }

    final nextAnswers = Map<String, GuidedAnswer>.from(state.collectedAnswers);
    nextAnswers[question.id] = resolved.answer!;
    writeState(
      state.copyWith(
        collectedAnswers: Map.unmodifiable(nextAnswers),
        lastUpdatedTurnId: turnId,
      ),
    );
    return GuidedConversationResponse(
      message: 'تم تصحيح الإجابة.',
      flowStatus: state.status,
      nextQuestion: state.pendingQuestion,
      completedData: _completedData(nextAnswers),
    );
  }
}
