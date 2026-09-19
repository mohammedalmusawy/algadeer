import '../../voice/guided_conversation/arabic_answer_normalizer.dart';
import '../../voice/guided_conversation/guided_answer_resolver.dart';
import '../../voice/guided_conversation/guided_conversation_models.dart';
import '../subject/health_subject_coordinator.dart';
import '../subject/health_subject_models.dart';
import '../understanding/health_understanding_engine.dart';
import '../understanding/symptom_models.dart';
import '../safety/medical_safety_engine.dart';
import '../safety/medical_safety_models.dart';
import 'health_follow_up_answer_interpreter.dart';
import 'health_follow_up_models.dart';
import 'health_follow_up_question_planner.dart';
import 'health_guidance_engine.dart';
import 'health_guidance_models.dart';
import 'health_guidance_response_builder.dart';

/// نتيجة خطوة منسّق التوجيه الصحي للـ planner.
class HealthGuidanceCoordinatorResult {
  const HealthGuidanceCoordinatorResult({
    required this.handled,
    this.session = HealthGuidanceSession.inactive,
    this.decision,
    this.message = '',
    this.startGuidedFlow,
    this.cancelAndForward = false,
    this.forwardQuery,
    this.keepPendingQuestion = false,
    this.turnResult,
    this.safetyDecision,
    this.runProviderDiscovery = false,
  });

  final bool handled;
  final HealthGuidanceSession session;
  final HealthGuidanceDecision? decision;
  final String message;
  final GuidedFlowDefinition? startGuidedFlow;
  final bool cancelAndForward;
  final String? forwardQuery;
  final bool keepPendingQuestion;
  final HealthConversationTurnResult? turnResult;
  final MedicalSafetyDecision? safetyDecision;

  /// بعد قبول المستخدم — ينفّذ المخطِّط اكتشاف المزوّدين الحقيقيين.
  final bool runProviderDiscovery;

  static const notHandled = HealthGuidanceCoordinatorResult(handled: false);
}

/// ينسّق 10B فهم + 10E سلامة + 10C قواعد + 10D أسئلة + 10A GuidedQuestion.
class HealthGuidanceCoordinator {
  HealthGuidanceCoordinator({
    HealthUnderstandingEngine? understanding,
    HealthGuidanceEngine? guidance,
    HealthFollowUpQuestionPlanner? followUpPlanner,
    HealthFollowUpAnswerInterpreter? answerInterpreter,
    HealthGuidanceResponseBuilder? responses,
    MedicalSafetyEngine? safetyEngine,
    HealthSubjectCoordinator? subjectCoordinator,
    this.defaultMaxQuestions = 4,
  })  : _understanding = understanding ?? HealthUnderstandingEngine(),
        _guidance = guidance ?? HealthGuidanceEngine(),
        _planner = followUpPlanner ?? HealthFollowUpQuestionPlanner(),
        _interpreter = answerInterpreter ?? HealthFollowUpAnswerInterpreter(),
        _responses = responses ?? const HealthGuidanceResponseBuilder(),
        _safety = safetyEngine ?? MedicalSafetyEngine(),
        _subjects = subjectCoordinator ?? HealthSubjectCoordinator();

  final HealthUnderstandingEngine _understanding;
  final HealthGuidanceEngine _guidance;
  final HealthFollowUpQuestionPlanner _planner;
  final HealthFollowUpAnswerInterpreter _interpreter;
  final HealthGuidanceResponseBuilder _responses;
  final MedicalSafetyEngine _safety;
  final HealthSubjectCoordinator _subjects;
  final int defaultMaxQuestions;

  HealthUnderstandingEngine get understanding => _understanding;
  HealthFollowUpQuestionPlanner get followUpPlanner => _planner;
  HealthFollowUpAnswerInterpreter get answerInterpreter => _interpreter;
  MedicalSafetyEngine get safetyEngine => _safety;
  HealthSubjectCoordinator get subjectCoordinator => _subjects;

  bool shouldConsiderHealthFlow(String query) {
    if (_subjects.detector.detect(query).returnToPrevious) return true;
    if (!_understanding.looksLikeHealthLanguage(query)) return false;
    return true;
  }

  HealthGuidanceCoordinatorResult startFromUserText({
    required String query,
    required HealthGuidanceSession current,
    required int turnId,
    HealthSubjectContext? enrichedSubject,
  }) {
    final understood = _understanding.understand(query);
    final earlyDet = _subjects.detector.detect(query);
    final hasHealth =
        understood.containsHealthLanguage || understood.hasPresentSymptoms;
    if (!hasHealth &&
        !earlyDet.returnToPrevious &&
        !earlyDet.isExplicitSwitchSignal) {
      return HealthGuidanceCoordinatorResult.notHandled;
    }
    // تصحيح موضوع بلا أعراض (مثل «لا مو إلي، لابني») أثناء جلسة نشطة فقط.
    if (!hasHealth &&
        earlyDet.isExplicitSwitchSignal &&
        !earlyDet.returnToPrevious &&
        !current.isActive) {
      return HealthGuidanceCoordinatorResult.notHandled;
    }

    final subjectResolution = _subjects.resolve(
      current: current.isActive ? current.facts.subject : null,
      text: query,
      previousType: current.previousSubjectType,
    );
    final effectiveSubject = _effectiveSubject(
      subjectResolution: subjectResolution,
      enrichedSubject: enrichedSubject,
    );
    // «نرجع لـ…» بلا حقائق محفوظة → إعادة موضوع فقط، بلا اختلاق أعراض.
    if (subjectResolution.returnRequested) {
      final fresh = HealthSessionFacts(subject: effectiveSubject)
          .withSubject(effectiveSubject);
      final session = HealthGuidanceSession(
        id: 'hs_${turnId}_${DateTime.now().millisecondsSinceEpoch}',
        status: HealthGuidanceSessionStatus.active,
        facts: fresh,
        maxQuestions: current.maxQuestions > 0
            ? current.maxQuestions
            : defaultMaxQuestions,
        startedTurnId: turnId,
        updatedTurnId: turnId,
        previousSubjectType: subjectResolution.previousType,
      );
      // إن وُجدت أعراض في نفس الجملة تُدمج بعد الاستبدال فقط.
      final withU = understood.containsHealthLanguage ||
              understood.hasPresentSymptoms
          ? fresh.mergeUnderstanding(understood).withSubject(effectiveSubject)
          : fresh;
      return _decide(
        session.copyWith(facts: withU),
        turnId: turnId,
      );
    }

    final replace = current.isActive &&
        _subjects.shouldReplaceHealthState(subjectResolution);

    HealthSessionFacts facts;
    HealthGuidanceSession baseSession;
    if (replace) {
      // تبديل موضوع: لا دمج أعراض/مدة/شدة/سلامة بين الأشخاص.
      facts = const HealthSessionFacts()
          .mergeUnderstanding(understood)
          .withSubject(effectiveSubject);
      baseSession = HealthGuidanceSession(
        id: 'hs_${turnId}_${DateTime.now().millisecondsSinceEpoch}',
        status: HealthGuidanceSessionStatus.active,
        facts: facts,
        maxQuestions: defaultMaxQuestions,
        startedTurnId: turnId,
        updatedTurnId: turnId,
        previousSubjectType: subjectResolution.previousType ??
            (current.facts.subject.isKnown
                ? current.facts.subject.type
                : current.previousSubjectType),
      );
    } else {
      final seed = current.isActive
          ? current.facts
          : HealthSessionFacts(subject: effectiveSubject);
      facts = seed
          .mergeUnderstanding(understood)
          .withSubject(
            effectiveSubject.type == HealthSubjectType.unknown &&
                    seed.subject.isKnown
                ? seed.subject.copyWith(
                    evidence: HealthSubjectEvidence.contextualContinuation,
                    linkedPersonId: effectiveSubject.linkedPersonId,
                  )
                : effectiveSubject,
          );
      // توافق قديم: تلميحات طفل عامة بلا علاقة صريحة
      facts = _syncCompatChildFlags(facts);
      baseSession = HealthGuidanceSession(
        id: current.id ??
            'hs_${turnId}_${DateTime.now().millisecondsSinceEpoch}',
        status: HealthGuidanceSessionStatus.active,
        facts: facts,
        askedQuestionIds: current.isActive ? current.askedQuestionIds : const [],
        answeredQuestionIds:
            current.isActive ? current.answeredQuestionIds : const [],
        skippedQuestionIds:
            current.isActive ? current.skippedQuestionIds : const [],
        questionsAskedCount:
            current.isActive ? current.questionsAskedCount : 0,
        maxQuestions: current.maxQuestions > 0
            ? current.maxQuestions
            : defaultMaxQuestions,
        startedTurnId: current.isActive ? current.startedTurnId : turnId,
        updatedTurnId: turnId,
        lastSafetyStatus: current.isActive ? current.lastSafetyStatus : null,
        matchedSafetyRuleId:
            current.isActive ? current.matchedSafetyRuleId : null,
        safetyWarningDelivered:
            current.isActive ? current.safetyWarningDelivered : false,
        lastSafetyDeliveredTurnId:
            current.isActive ? current.lastSafetyDeliveredTurnId : null,
        pendingSafetyQuestionId:
            current.isActive ? current.pendingSafetyQuestionId : null,
        handoff: current.handoff.destination != null &&
                current.handoff.status != HealthGuidanceHandoffStatus.inactive
            ? current.handoff
            : HealthGuidanceHandoff.inactive,
        previousSubjectType: current.previousSubjectType,
      );
    }

    return _decide(baseSession, turnId: turnId);
  }

  HealthGuidanceCoordinatorResult continueAfterAnswer({
    required String answerText,
    required HealthGuidanceSession session,
    required int turnId,
    GuidedAnswer? guidedAnswer,
    GuidedQuestion? pendingQuestion,
  }) {
    // تبديل موضوع صريح أثناء سؤال معلّق → لا تُستهلك الإجابة للموضوع القديم.
    final subjectResolution = _subjects.resolve(
      current: session.facts.subject,
      text: answerText,
      previousType: session.previousSubjectType,
    );
    if (_subjects.shouldReplaceHealthState(subjectResolution)) {
      return startFromUserText(
        query: answerText,
        current: session,
        turnId: turnId,
      );
    }

    final question =
        pendingQuestion ?? session.currentDecision?.nextQuestion;
    if (question == null) {
      var facts = session.facts
          .mergeUnderstanding(_understanding.understand(answerText))
          .withSubject(subjectResolution.subject);
      facts = _syncCompatChildFlags(facts);
      return _decide(
        session.copyWith(
          facts: facts,
          status: HealthGuidanceSessionStatus.active,
          updatedTurnId: turnId,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
        ),
        turnId: turnId,
      );
    }

    // —— Step 10F: تأكيد اكتشاف المزوّدين (إعادة استخدام نعم/لا من 10A) ——
    if (_isProviderDiscoveryConfirmation(question)) {
      return _handleProviderDiscoveryAnswer(
        answerText: answerText,
        session: session,
        turnId: turnId,
        guidedAnswer: guidedAnswer,
        question: question,
      );
    }

    final interp = _interpreter.interpret(
      rawAnswer: answerText,
      question: question,
      facts: session.facts,
      guidedAnswer: guidedAnswer,
    );

    if (interp.cancelFlow) {
      return cancel(session: session, turnId: turnId);
    }

    if (interp.keepPendingQuestion) {
      return HealthGuidanceCoordinatorResult(
        handled: true,
        session: session.copyWith(
          facts: (interp.updatedFacts ?? session.facts)
              .withSubject(subjectResolution.subject),
          status: HealthGuidanceSessionStatus.waitingForAnswer,
          updatedTurnId: turnId,
        ),
        decision: session.currentDecision,
        message: interp.explanation ?? question.prompt,
        keepPendingQuestion: true,
        turnResult: HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.waitingForAnswer,
          question: question,
          explanation: interp.explanation,
          awaitingAnswer: true,
        ),
      );
    }

    if (interp.skipCurrentQuestion || interp.refuseAnswerOnly) {
      final skipped = [...session.skippedQuestionIds, question.id];
      return _decide(
        session.copyWith(
          status: HealthGuidanceSessionStatus.active,
          skippedQuestionIds: List.unmodifiable(skipped.toSet()),
          updatedTurnId: turnId,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
          clearSafetyPending: true,
        ),
        turnId: turnId,
      );
    }

    var facts = interp.updatedFacts ?? session.facts;
    if (interp.kind == HealthFollowUpInterpretKind.unresolved) {
      facts = session.facts.mergeUnderstanding(
        _understanding.understand(answerText),
      );
      facts =
          _applyGuidedAnswer(facts, session.pendingMissingFact, guidedAnswer);
    }
    facts = facts.withSubject(subjectResolution.subject);
    facts = _syncCompatChildFlags(facts);

    final answered = [...session.answeredQuestionIds, question.id];
    return _decide(
      session.copyWith(
        facts: facts,
        status: HealthGuidanceSessionStatus.active,
        answeredQuestionIds: List.unmodifiable(answered.toSet()),
        updatedTurnId: turnId,
        clearPendingMissingFact: true,
        clearPendingMeta: true,
        clearSafetyPending: true,
      ),
      turnId: turnId,
    );
  }

  HealthGuidanceCoordinatorResult cancel({
    required HealthGuidanceSession session,
    required int turnId,
    String? forwardQuery,
  }) {
    return HealthGuidanceCoordinatorResult(
      handled: true,
      session: session.copyWith(
        status: HealthGuidanceSessionStatus.cancelled,
        updatedTurnId: turnId,
        clearDecision: true,
        clearPendingMissingFact: true,
        clearPendingMeta: true,
        clearSafetyPending: true,
      ),
      message: forwardQuery == null ? 'تم إيقاف المساعدة الصحية.' : '',
      cancelAndForward: forwardQuery != null,
      forwardQuery: forwardQuery,
      turnResult: const HealthConversationTurnResult(
        status: HealthGuidanceSessionStatus.cancelled,
      ),
    );
  }

  HealthGuidanceCoordinatorResult _decide(
    HealthGuidanceSession session, {
    required int turnId,
  }) {
    // —— Step 10E أولاً ——
    final safety = _safety.evaluate(session.facts);

    if (safety.isEscalation) {
      final already = session.safetyWarningDelivered &&
          session.matchedSafetyRuleId == safety.matchedRuleId;
      final isEmergency =
          safety.status == MedicalSafetyStatus.emergencyEvaluation;
      final decision = _responses.withMessage(
        HealthGuidanceDecision(
          type: isEmergency
              ? HealthGuidanceDecisionType.emergencyEvaluation
              : HealthGuidanceDecisionType.urgentEvaluation,
          destination: isEmergency
              ? GuidanceDestination.emergency
              : GuidanceDestination.urgent,
          matchedRuleId: safety.matchedRuleId,
          rationaleCode: safety.responseCode ?? '',
          allowCommercialOffers: false,
          safetyMessage: safety.userMessage,
          userMessage: already ? '' : safety.userMessage,
        ),
      );
      return HealthGuidanceCoordinatorResult(
        handled: true,
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.decided,
          currentDecision: decision,
          updatedTurnId: turnId,
          lastSafetyStatus: safety.status.name,
          matchedSafetyRuleId: safety.matchedRuleId,
          safetyWarningDelivered: true,
          lastSafetyDeliveredTurnId:
              already ? session.lastSafetyDeliveredTurnId : turnId,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
          clearSafetyPending: true,
          // جدار: لا تسليم مزوّدين تجاري من العاجل/الطوارئ
          clearHandoff: true,
        ),
        decision: decision,
        message: already ? '' : decision.userMessage,
        safetyDecision: safety,
        turnResult: HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.decided,
          guidanceDecision: decision,
        ),
      );
    }

    if (safety.needsQuestion) {
      return _askQuestion(
        session: session,
        turnId: turnId,
        question: safety.nextQuestion!,
        missingFact: safety.missingFact,
        matchedRuleId: safety.matchedRuleId,
        rationaleCode: safety.responseCode ?? 'safety_need_info',
        allowCommercial: false,
        safetyStatus: safety.status.name,
        safetyRuleId: safety.matchedRuleId,
        isSafetyQuestion: true,
      );
    }

    // —— Step 10C (+ 10E مضمّن داخله كشبكة أمان) ——
    final decision = _guidance.evaluate(session.facts);

    if (decision.type == HealthGuidanceDecisionType.urgentEvaluation ||
        decision.type == HealthGuidanceDecisionType.emergencyEvaluation) {
      return HealthGuidanceCoordinatorResult(
        handled: true,
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.decided,
          currentDecision: decision,
          updatedTurnId: turnId,
          lastSafetyStatus: decision.type.name,
          matchedSafetyRuleId: decision.matchedRuleId,
          safetyWarningDelivered: true,
          lastSafetyDeliveredTurnId: turnId,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
          clearSafetyPending: true,
          clearHandoff: true,
        ),
        decision: decision,
        message: decision.userMessage,
        turnResult: HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.decided,
          guidanceDecision: decision,
        ),
      );
    }

    // —— Step 10F: بوابة قبول قبل اكتشاف الأطباء الحقيقيين ——
    if (decision.type == HealthGuidanceDecisionType.specialtyDirection &&
        decision.suggestShowSpecialtyDoctors &&
        decision.destination != null &&
        !session.handoff.blocksFurtherHealthQuestions) {
      return _offerProviderDiscovery(
        session: session,
        turnId: turnId,
        decision: decision,
      );
    }

    if (decision.type != HealthGuidanceDecisionType.needMoreInformation) {
      return HealthGuidanceCoordinatorResult(
        handled: true,
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.decided,
          currentDecision: decision,
          updatedTurnId: turnId,
          lastSafetyStatus: MedicalSafetyStatus.noRedFlagDetected.name,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
          clearSafetyPending: true,
        ),
        decision: decision,
        message: decision.userMessage,
        safetyDecision: MedicalSafetyDecision.none,
        turnResult: HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.decided,
          guidanceDecision: decision,
        ),
      );
    }

    // سؤال سلامة قادم من طبقة 10E عبر 10C
    if (decision.nextQuestion != null &&
        (decision.nextQuestion!.id.startsWith('safety_') ||
            decision.matchedRuleId?.startsWith('safety_') == true)) {
      return _askQuestion(
        session: session,
        turnId: turnId,
        question: decision.nextQuestion!,
        missingFact: decision.missingFact,
        matchedRuleId: decision.matchedRuleId,
        rationaleCode: decision.rationaleCode,
        allowCommercial: false,
        safetyStatus: MedicalSafetyStatus.needSafetyInformation.name,
        safetyRuleId: decision.matchedRuleId,
        isSafetyQuestion: true,
      );
    }

    final plan = _planner.plan(
      facts: session.facts,
      askedQuestionIds: session.askedQuestionIds,
      answeredQuestionIds: session.answeredQuestionIds,
      skippedQuestionIds: session.skippedQuestionIds,
      questionsAskedCount: session.questionsAskedCount,
      maxQuestionsOverride: session.maxQuestions,
    );

    if (plan.budgetExhausted ||
        (plan.noQuestionNeeded && plan.question == null)) {
      final chosen = plan.budgetExhausted
          ? _responses.withMessage(
              const HealthGuidanceDecision(
                type: HealthGuidanceDecisionType.generalEvaluation,
                destination: GuidanceDestination.general,
                rationaleCode: 'question_budget_exhausted',
                allowCommercialOffers: true,
              ),
            )
          : _responses.withMessage(
              HealthGuidanceDecision(
                type: HealthGuidanceDecisionType.unableToDetermine,
                matchedRuleId: decision.matchedRuleId,
                rationaleCode: (decision.rationaleCode ?? '').isNotEmpty
                    ? decision.rationaleCode
                    : 'no_useful_question',
              ),
            );
      return HealthGuidanceCoordinatorResult(
        handled: true,
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.decided,
          currentDecision: chosen,
          updatedTurnId: turnId,
          lastSafetyStatus: MedicalSafetyStatus.noRedFlagDetected.name,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
        ),
        decision: chosen,
        message: chosen.userMessage,
        turnResult: HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.decided,
          guidanceDecision: chosen,
        ),
      );
    }

    return _askQuestion(
      session: session,
      turnId: turnId,
      question: plan.question!,
      missingFact: plan.missingFact ?? decision.missingFact,
      matchedRuleId: decision.matchedRuleId,
      rationaleCode: decision.rationaleCode,
      allowCommercial: true,
      safetyStatus: MedicalSafetyStatus.noRedFlagDetected.name,
      isSafetyQuestion: false,
    );
  }

  HealthGuidanceCoordinatorResult _askQuestion({
    required HealthGuidanceSession session,
    required int turnId,
    required GuidedQuestion question,
    HealthMissingFact? missingFact,
    String? matchedRuleId,
    String? rationaleCode,
    required bool allowCommercial,
    required String safetyStatus,
    String? safetyRuleId,
    required bool isSafetyQuestion,
  }) {
    final asked = [...session.askedQuestionIds, question.id];
    final count = session.questionsAskedCount + 1;
    final meta = HealthQuestionMeta.fromQuestion(question);
    final askedDecision = HealthGuidanceDecision(
      type: HealthGuidanceDecisionType.needMoreInformation,
      nextQuestion: question,
      missingFact: missingFact,
      matchedRuleId: matchedRuleId,
      rationaleCode: rationaleCode,
      userMessage: question.prompt,
      allowCommercialOffers: allowCommercial,
    );
    final flow = GuidedFlowDefinition(
      id: isSafetyQuestion
          ? 'safety_followup_${question.id}'
          : 'health_followup_${question.id}',
      type: GuidedFlowType.healthGuidanceReserved,
      initialStepId: 'q1',
      steps: [
        GuidedFlowStep(
          id: 'q1',
          question: question,
          nextStepId: '__complete__',
        ),
      ],
    );
    return HealthGuidanceCoordinatorResult(
      handled: true,
      session: session.copyWith(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
        currentDecision: askedDecision,
        askedQuestionIds: List.unmodifiable(asked.toSet()),
        pendingMissingFact: missingFact,
        pendingHealthFactKey: meta?.factKey.name,
        pendingSymptomConceptId: meta?.symptomConceptId,
        pendingQuestionId: question.id,
        pendingSafetyQuestionId: isSafetyQuestion ? question.id : null,
        questionsAskedCount: count,
        lastSafetyStatus: safetyStatus,
        matchedSafetyRuleId: safetyRuleId ?? session.matchedSafetyRuleId,
        updatedTurnId: turnId,
        clearSafetyPending: !isSafetyQuestion,
      ),
      decision: askedDecision,
      message: question.prompt,
      startGuidedFlow: flow,
      turnResult: HealthConversationTurnResult(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
        question: question,
        guidanceDecision: askedDecision,
        awaitingAnswer: true,
      ),
    );
  }

  HealthSessionFacts _applyGuidedAnswer(
    HealthSessionFacts facts,
    HealthMissingFact? missing,
    GuidedAnswer? answer,
  ) {
    if (missing == null || answer == null) return facts;
    switch (missing) {
      case HealthMissingFact.duration:
        if (answer.durationValue != null) {
          return facts.copyWith(duration: answer.durationValue);
        }
        return facts;
      case HealthMissingFact.associatedFever:
        if (answer.yesNo == true) {
          final m = Map<String, SymptomPolarity>.from(facts.symptomStatuses);
          m['fever'] = SymptomPolarity.present;
          return facts.copyWith(symptomStatuses: Map.unmodifiable(m));
        }
        if (answer.yesNo == false) {
          final m = Map<String, SymptomPolarity>.from(facts.symptomStatuses);
          m['fever'] = SymptomPolarity.absent;
          return facts.copyWith(symptomStatuses: Map.unmodifiable(m));
        }
        return facts;
      case HealthMissingFact.patientIsChild:
        return facts.copyWith(patientIsChild: answer.yesNo == true);
      case HealthMissingFact.severity:
        final id = answer.optionIds.isNotEmpty
            ? answer.optionIds.first
            : '${answer.normalizedValue}';
        final sev = switch (id) {
          'mild' || 'خفيف' || 'بسيط' => UserStatedSeverity.mild,
          'moderate' || 'متوسط' => UserStatedSeverity.moderate,
          'severe' || 'شديد' || 'قوي' => UserStatedSeverity.severe,
          _ => facts.userSeverity,
        };
        return facts.copyWith(userSeverity: sev);
      case HealthMissingFact.abdominalLocationDetail:
        final id = answer.optionIds.isNotEmpty
            ? answer.optionIds.first
            : '${answer.normalizedValue}';
        final regions = {...facts.bodyRegions, BodyRegionId.abdomen};
        var lat = facts.laterality;
        final blob = '$id ${answer.rawText} ${answer.normalizedValue}';
        if (RegExp(r'يمين|right').hasMatch(blob)) lat = Laterality.right;
        if (RegExp(r'يسار|left').hasMatch(blob)) lat = Laterality.left;
        if (RegExp(r'أسفل|اسفل|lower').hasMatch(blob)) {
          regions.add(BodyRegionId.lowerBack);
        }
        return facts.copyWith(
          bodyRegions: Set.unmodifiable(regions),
          laterality: lat,
          abdominalLocationResolved: lat != Laterality.unknown ||
              regions.contains(BodyRegionId.lowerBack),
        );
      case HealthMissingFact.bodyRegion:
      case HealthMissingFact.laterality:
      case HealthMissingFact.onset:
        return facts;
    }
  }

  HealthSubjectContext _effectiveSubject({
    required HealthSubjectResolution subjectResolution,
    HealthSubjectContext? enrichedSubject,
  }) {
    if (enrichedSubject == null) return subjectResolution.subject;
    if (subjectResolution.switched || subjectResolution.returnRequested) {
      return enrichedSubject;
    }
    return enrichedSubject.copyWith(
      evidence: subjectResolution.subject.evidence,
      ageYears:
          subjectResolution.subject.ageYears ?? enrichedSubject.ageYears,
      isChild: subjectResolution.subject.isChild ?? enrichedSubject.isChild,
      ageGroup: subjectResolution.subject.ageGroup ?? enrichedSubject.ageGroup,
    );
  }

  HealthSessionFacts _syncCompatChildFlags(HealthSessionFacts facts) {
    final s = facts.subject;
    if (s.type == HealthSubjectType.child || s.isChild == true) {
      return facts.copyWith(patientIsChild: true, ageGroup: 'child');
    }
    if (s.type == HealthSubjectType.self ||
        s.type == HealthSubjectType.mother ||
        s.type == HealthSubjectType.father ||
        s.type == HealthSubjectType.spouse) {
      if (s.isChild == false || s.ageGroup == 'adult') {
        return facts.copyWith(
          patientIsChild: false,
          ageGroup: s.ageGroup ?? 'adult',
        );
      }
      if (facts.patientIsChild == null && s.type != HealthSubjectType.self) {
        return facts.copyWith(patientIsChild: false, ageGroup: 'adult');
      }
    }
    return facts;
  }

  bool _isProviderDiscoveryConfirmation(GuidedQuestion question) {
    final purpose = question.metadata['purpose']?.toString();
    return purpose ==
            HealthQuestionPurpose.providerDiscoveryConfirmation.name ||
        purpose == 'providerDiscoveryConfirmation';
  }

  static GuidedQuestion buildProviderDiscoveryConfirmation(
    GuidanceDestination destination,
  ) {
    final isLab = destination.type == GuidanceDestinationType.laboratory;
    return GuidedQuestion(
      id: 'health_provider_discovery_confirm',
      type: GuidedQuestionType.yesNo,
      prompt: isLab
          ? 'تريد أعرض لك المختبرات ضمن بيانات الغدير؟'
          : 'تريد أعرض لك الأطباء بهذا الاختصاص؟',
      expectedAnswerType: GuidedAnswerType.yesNo,
      metadata: {
        'purpose': HealthQuestionPurpose.providerDiscoveryConfirmation.name,
        'destinationType': destination.type.name,
        'destinationKey': destination.key,
        if (destination.specialtyCatalogId != null)
          'specialtyCatalogId': destination.specialtyCatalogId,
      },
    );
  }

  HealthGuidanceCoordinatorResult _offerProviderDiscovery({
    required HealthGuidanceSession session,
    required int turnId,
    required HealthGuidanceDecision decision,
  }) {
    final dest = decision.destination!;
    final question = buildProviderDiscoveryConfirmation(dest);
    final guidanceText = decision.userMessage.trim();
    final ask = question.prompt;
    final combined = guidanceText.isEmpty
        ? ask
        : (guidanceText.contains(ask) ? guidanceText : '$guidanceText\n$ask');

    final decided = HealthGuidanceDecision(
      type: decision.type,
      destination: dest,
      matchedRuleId: decision.matchedRuleId,
      rationaleCode: decision.rationaleCode,
      nextQuestion: question,
      userMessage: combined,
      allowCommercialOffers: decision.allowCommercialOffers,
      suggestShowSpecialtyDoctors: true,
    );

    final flow = GuidedFlowDefinition(
      id: 'health_provider_discovery_${dest.key}',
      type: GuidedFlowType.healthGuidanceReserved,
      initialStepId: 'confirm',
      steps: [
        GuidedFlowStep(
          id: 'confirm',
          question: question,
          nextStepId: '__complete__',
        ),
      ],
    );

    return HealthGuidanceCoordinatorResult(
      handled: true,
      session: session.copyWith(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
        currentDecision: decided,
        pendingQuestionId: question.id,
        updatedTurnId: turnId,
        lastSafetyStatus: MedicalSafetyStatus.noRedFlagDetected.name,
        clearPendingMissingFact: true,
        clearSafetyPending: true,
        handoff: HealthGuidanceHandoff(
          status: HealthGuidanceHandoffStatus.awaitingAcceptance,
          destination: dest,
          subjectTypeName: session.facts.subject.type.name,
        ),
      ),
      decision: decided,
      message: combined,
      startGuidedFlow: flow,
      turnResult: HealthConversationTurnResult(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
        question: question,
        guidanceDecision: decided,
        awaitingAnswer: true,
      ),
    );
  }

  HealthGuidanceCoordinatorResult _handleProviderDiscoveryAnswer({
    required String answerText,
    required HealthGuidanceSession session,
    required int turnId,
    required GuidedQuestion question,
    GuidedAnswer? guidedAnswer,
  }) {
    // إعادة استخدام مُطبِّع/محلّل نعم-لا من 10A — بلا parser جديد.
    bool? yn = guidedAnswer?.yesNo;
    if (yn == null) {
      final resolved = const GuidedAnswerResolver().resolve(
        query: answerText,
        question: question,
        allowTopicEscape: false,
      );
      yn = resolved.answer?.yesNo ?? ArabicAnswerNormalizer.tryYesNo(answerText);
    }

    final dest = session.handoff.destination ??
        session.currentDecision?.destination;

    if (yn == true) {
      return HealthGuidanceCoordinatorResult(
        handled: true,
        runProviderDiscovery: true,
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.completed,
          updatedTurnId: turnId,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
          clearSafetyPending: true,
          handoff: HealthGuidanceHandoff(
            status: HealthGuidanceHandoffStatus.accepted,
            destination: dest,
            subjectTypeName: session.facts.subject.type.name,
          ),
          currentDecision: session.currentDecision,
        ),
        decision: session.currentDecision,
        message: '',
        turnResult: const HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.completed,
        ),
      );
    }

    if (yn == false) {
      return HealthGuidanceCoordinatorResult(
        handled: true,
        session: session.copyWith(
          status: HealthGuidanceSessionStatus.completed,
          updatedTurnId: turnId,
          clearPendingMissingFact: true,
          clearPendingMeta: true,
          clearSafetyPending: true,
          handoff: HealthGuidanceHandoff(
            status: HealthGuidanceHandoffStatus.declined,
            destination: dest,
            subjectTypeName: session.facts.subject.type.name,
          ),
          currentDecision: session.currentDecision,
        ),
        decision: session.currentDecision,
        message:
            'تمام. إذا حابب لاحقاً تگولي وأعرض لك الأطباء بهذا الاختصاص.',
        turnResult: const HealthConversationTurnResult(
          status: HealthGuidanceSessionStatus.completed,
        ),
      );
    }

    return HealthGuidanceCoordinatorResult(
      handled: true,
      session: session.copyWith(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
        updatedTurnId: turnId,
      ),
      decision: session.currentDecision,
      message: question.prompt,
      keepPendingQuestion: true,
      turnResult: HealthConversationTurnResult(
        status: HealthGuidanceSessionStatus.waitingForAnswer,
        question: question,
        guidanceDecision: session.currentDecision,
        awaitingAnswer: true,
      ),
    );
  }

  /// إعادة عرض سؤال التسليم إن بقيت الوجهة في الجلسة.
  HealthGuidanceCoordinatorResult? tryReturnToGuidance({
    required HealthGuidanceSession session,
    required int turnId,
  }) {
    final dest = session.handoff.destination ??
        session.currentDecision?.destination;
    if (dest == null) return null;
    if (dest.type == GuidanceDestinationType.urgentEvaluation) return null;
    if (dest.type != GuidanceDestinationType.specialty &&
        dest.type != GuidanceDestinationType.laboratory &&
        dest.type != GuidanceDestinationType.generalMedicalEvaluation) {
      return null;
    }
    final decision = _responses.withMessage(
      HealthGuidanceDecision(
        type: dest.type == GuidanceDestinationType.specialty
            ? HealthGuidanceDecisionType.specialtyDirection
            : HealthGuidanceDecisionType.generalEvaluation,
        destination: dest,
        rationaleCode: 'return_to_guidance',
        suggestShowSpecialtyDoctors:
            dest.type == GuidanceDestinationType.specialty,
        allowCommercialOffers: true,
      ),
    );
    return _offerProviderDiscovery(
      session: session.copyWith(
        status: HealthGuidanceSessionStatus.active,
        updatedTurnId: turnId,
      ),
      turnId: turnId,
      decision: decision,
    );
  }
}
