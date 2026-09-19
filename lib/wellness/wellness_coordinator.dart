import '../companion/personal_companion_profile_service.dart';
import '../companion/personal_memory/personal_memory_models.dart';
import '../companion/personal_memory/personal_memory_service.dart';
import '../companion/personalization/personalization_models.dart';
import '../companion/personalization/personalization_relevance_policy.dart';
import '../health/emotional_support/mental_health_safety_gate.dart';
import '../health/preventive/preventive_guidance_context.dart';
import '../health/preventive/preventive_guidance_models.dart';
import '../health/sensitive_profile/sensitive_health_profile_service.dart';
import '../health/sensitive_profile/sensitive_health_retrieval_policy.dart';
import '../search/arabic_text_utils.dart';
import 'wellness_command_interpreter.dart';
import 'wellness_guidance_policy.dart';
import 'wellness_models.dart';
import 'wellness_response_builder.dart';
import 'wellness_safety_gate.dart';

class WellnessTurnResult {
  const WellnessTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.deferToUrgentSafety = false,
    this.deferToMentalSafety = false,
    this.deferToFollowUp = false,
    this.deferToPersonalMemory = false,
    this.textFirstOnly = true,
    this.success = true,
  });

  final bool handled;
  final String message;
  final WellnessSession session;
  final bool deferToUrgentSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToPersonalMemory;
  final bool textFirstOnly;
  final bool success;

  static WellnessTurnResult notHandled(WellnessSession session) =>
      WellnessTurnResult(
        handled: false,
        message: '',
        session: session,
      );

  Map<String, Object?> debugMap() => {
        'wellnessIntent': session.lastIntent.name,
        'wellnessTopic': session.lastTopic.name,
        'safetyDecision': session.lastSafety.name,
        'questionCount': session.pendingQuestionCount,
        'usedPreventiveRule': session.usedPreventiveRule,
        'usedPersonalization': session.usedPersonalization,
        'operationType': session.lastIntent.name,
        'operationSuccess': success,
      };
}

/// منسّق العافية — PC-1.14.
class WellnessCoordinator {
  WellnessCoordinator({
    WellnessCommandInterpreter? interpreter,
    WellnessSafetyGate? safety,
    WellnessQuestionPlanner? questions,
    WellnessGuidancePolicy? guidance,
    WellnessResponseBuilder? responses,
    PersonalMemoryService? personalMemory,
    PersonalCompanionProfileService? profiles,
    SensitiveHealthProfileService? health,
    SensitiveHealthRetrievalPolicy? healthRetrieval,
    MentalHealthSafetyGate? mentalSafety,
    PersonalizationRelevancePolicy? personalizationRelevance,
  })  : _interpreter = interpreter ?? const WellnessCommandInterpreter(),
        _safety = safety ?? const WellnessSafetyGate(),
        _questions = questions ?? const WellnessQuestionPlanner(),
        _guidance = guidance ?? WellnessGuidancePolicy(),
        _responses = responses ?? const WellnessResponseBuilder(),
        _personalMemory = personalMemory ?? PersonalMemoryService(),
        _profiles = profiles ?? PersonalCompanionProfileService(),
        _health = health ?? SensitiveHealthProfileService(),
        _healthRetrieval =
            healthRetrieval ?? const SensitiveHealthRetrievalPolicy(),
        _mentalSafety = mentalSafety ?? const MentalHealthSafetyGate(),
        _personalizationRelevance =
            personalizationRelevance ?? const PersonalizationRelevancePolicy();

  final WellnessCommandInterpreter _interpreter;
  final WellnessSafetyGate _safety;
  final WellnessQuestionPlanner _questions;
  final WellnessGuidancePolicy _guidance;
  final WellnessResponseBuilder _responses;
  final PersonalMemoryService _personalMemory;
  final PersonalCompanionProfileService _profiles;
  final SensitiveHealthProfileService _health;
  final SensitiveHealthRetrievalPolicy _healthRetrieval;
  final MentalHealthSafetyGate _mentalSafety;
  final PersonalizationRelevancePolicy _personalizationRelevance;

  WellnessCommandInterpreter get interpreter => _interpreter;
  ActivityTrackingContract get activityTrackingContract =>
      const ActivityTrackingContract();
  WellnessCoachingContract get coachingContract =>
      const WellnessCoachingContract();

  bool mayHandle({
    required String query,
    required WellnessSession session,
  }) {
    if (session.adviceDeclined &&
        !_interpreter.looksLikeWellnessCommand(query)) {
      return false;
    }
    if (session.isActive) return true;
    return _interpreter.looksLikeWellnessCommand(query);
  }

  Future<WellnessTurnResult> handle({
    required String text,
    required WellnessSession session,
  }) async {
    try {
      return await _handle(text: text, session: session);
    } catch (_) {
      return WellnessTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  Future<WellnessTurnResult> _handle({
    required String text,
    required WellnessSession session,
  }) async {
    if (_mentalSafety.triggersCrisis(text)) {
      return WellnessTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);
    if (!interp.isCommand && !session.isActive) {
      return WellnessTurnResult.notHandled(session);
    }

    // متابعة → سلطة PC-1.11
    if (interp.intent == WellnessIntent.followUpRequest) {
      return WellnessTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(
          lastIntent: interp.intent,
          lastTopic: interp.topic,
        ),
        deferToFollowUp: true,
      );
    }

    final safety = _safety.decide(text);
    if (safety == WellnessSafetyDecision.deferToMedicalSafety ||
        interp.intent == WellnessIntent.healthRelatedActivityQuestion) {
      return WellnessTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(
          lastSafety: WellnessSafetyDecision.deferToMedicalSafety,
          lastIntent: WellnessIntent.healthRelatedActivityQuestion,
          lastTopic: interp.topic,
        ),
        deferToUrgentSafety: true,
      );
    }

    var next = session.copyWith(
      active: true,
      lastIntent: interp.intent,
      lastTopic: interp.topic,
      lastSafety: safety,
      usedPreventiveRule: false,
      usedPersonalization: false,
    );

    if (interp.intent == WellnessIntent.declineWellnessAdvice) {
      return WellnessTurnResult(
        handled: true,
        message: _responses.declineAck(),
        session: next.copyWith(adviceDeclined: true, active: false),
      );
    }

    if (interp.intent == WellnessIntent.focusWalking) {
      return WellnessTurnResult(
        handled: true,
        message: _responses.focusWalkingAck(),
        session: next.copyWith(focusWalking: true),
      );
    }

    // عائلة / شخص آخر — معلومات عامة فقط
    if (interp.isAboutOtherPerson) {
      return WellnessTurnResult(
        handled: true,
        message: _responses.familyGeneralOnly(),
        session: next,
      );
    }

    switch (interp.intent) {
      case WellnessIntent.setGoal:
        return _setGoal(interp, next);
      case WellnessIntent.pauseGoal:
      case WellnessIntent.resumeGoal:
        return _goalLifecycle(interp, next);
      case WellnessIntent.reportActivity:
        return _report(interp, next);
      case WellnessIntent.askProgress:
        return _progress(interp, next);
      case WellnessIntent.reportBarrier:
        return _barrier(interp, next, safety);
      case WellnessIntent.askRoutine:
        return _routine(interp, next);
      case WellnessIntent.askGuidance:
      default:
        return _handleGuidance(interp, next, safety, text);
    }
  }

  Future<WellnessTurnResult> _setGoal(
    WellnessCommandInterpretation interp,
    WellnessSession session,
  ) async {
    final draft = interp.goalDraft ??
        const WellnessGoalDraft(
          canonicalKey: 'goal_walking',
          displayLabel: 'الالتزام بالمشي',
        );
    try {
      await _personalMemory.upsertCandidate(
        PersonalMemoryCandidate(
          memoryType: PersonalMemoryType.goal,
          canonicalKey: draft.canonicalKey,
          displayLabel: draft.displayLabel,
          category: PersonalGoalCategory.fitness.name,
          targetContext: draft.frequencyHint,
        ),
      );
      return WellnessTurnResult(
        handled: true,
        message: _responses.goalSaved(draft.displayLabel),
        session: session.copyWith(
          goalDraft: draft,
          clearGoalDraft: false,
        ),
      );
    } catch (_) {
      return WellnessTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أحفظ الهدف هسه. ما تم الحفظ.',
        session: session,
      );
    }
  }

  Future<WellnessTurnResult> _goalLifecycle(
    WellnessCommandInterpretation interp,
    WellnessSession session,
  ) async {
    final key = interp.goalDraft?.canonicalKey ?? 'goal_walking';
    final existing =
        await _personalMemory.findByCanonicalKey(key, type: PersonalMemoryType.goal);
    if (existing == null) {
      return WellnessTurnResult(
        handled: true,
        success: false,
        message: 'ما لقيت هدف مشي محفوظ.',
        session: session,
      );
    }
    final status = interp.intent == WellnessIntent.pauseGoal
        ? PersonalMemoryStatus.paused
        : PersonalMemoryStatus.active;
    await _personalMemory.updateStatus(existing.memoryId, status);
    return WellnessTurnResult(
      handled: true,
      message: status == PersonalMemoryStatus.paused
          ? 'تم إيقاف هدف المشي مؤقتاً (عبر ذاكرة الأهداف).'
          : 'رجّعت هدف المشي (عبر ذاكرة الأهداف).',
      session: session,
    );
  }

  Future<WellnessTurnResult> _report(
    WellnessCommandInterpretation interp,
    WellnessSession session,
  ) async {
    final report = interp.report!;
    final reports = [...session.sessionReports, report];
    return WellnessTurnResult(
      handled: true,
      message: _responses.activityReportAck(report),
      session: session.copyWith(sessionReports: reports),
    );
  }

  Future<WellnessTurnResult> _progress(
    WellnessCommandInterpretation interp,
    WellnessSession session,
  ) async {
    final goals = await _personalMemory.listByType(
      PersonalMemoryType.goal,
      activeOnly: true,
    );
    final hasGoal = goals.any((g) => g.canonicalKey.contains('walk'));
    return WellnessTurnResult(
      handled: true,
      message: _responses.progressHonest(
        hasSessionReports: session.sessionReports.isNotEmpty,
        hasGoal: hasGoal,
      ),
      session: session,
    );
  }

  Future<WellnessTurnResult> _barrier(
    WellnessCommandInterpretation interp,
    WellnessSession session,
    WellnessSafetyDecision safety,
  ) async {
    final qs = _questions.plan(
      interp: interp,
      safety: safety,
      overwhelmed: interp.overwhelmed,
    );
    final q = qs.isEmpty
        ? 'هل الألم خفيف ويسمح بمشي قصير، لو يمنعك تماماً؟'
        : qs.first;
    return WellnessTurnResult(
      handled: true,
      message: _responses.barrierClarification(q),
      session: session.copyWith(pendingQuestionCount: qs.length.clamp(0, 2)),
    );
  }

  Future<WellnessTurnResult> _routine(
    WellnessCommandInterpretation interp,
    WellnessSession session,
  ) async {
    final qs = _questions.plan(
      interp: interp,
      safety: WellnessSafetyDecision.safeGeneralGuidance,
      overwhelmed: interp.overwhelmed,
    );
    var msg = _responses.routineFramework(overwhelmed: interp.overwhelmed);
    if (qs.isNotEmpty && !interp.overwhelmed) {
      msg = '$msg\n\n${qs.first}';
    }
    if (_responses.containsForbiddenLanguage(msg)) {
      msg = _responses.routineFramework(overwhelmed: true);
    }
    return WellnessTurnResult(
      handled: true,
      message: msg,
      session: session.copyWith(pendingQuestionCount: qs.length.clamp(0, 2)),
    );
  }

  Future<WellnessTurnResult> _handleGuidance(
    WellnessCommandInterpretation interp,
    WellnessSession session,
    WellnessSafetyDecision safety,
    String text,
  ) async {
    if (interp.lowMotivation) {
      return WellnessTurnResult(
        handled: true,
        message: _responses.lowMotivation(),
        session: session,
      );
    }

    if (safety == WellnessSafetyDecision.clinicianDiscussionRecommended) {
      return WellnessTurnResult(
        handled: true,
        message: _responses.clinicianDiscussion(),
        session: session.copyWith(
          lastSafety: safety,
        ),
      );
    }

    // تخصيص أدنى — إشارة غرض فقط بلا حقن غير ذي صلة
    final purpose = _personalizationRelevance.purposeForQuery(text);
    final usedPers = purpose != PersonalizationPurpose.providerDiscovery &&
        purpose != PersonalizationPurpose.none &&
        purpose != PersonalizationPurpose.disabledByUser;

    // لا تجاوز سياسة الصحة: محتوى/حركة عامة → generalChat يفرّغ
    final healthPurpose = _healthRetrieval.purposeForQuery(text);
    if (healthPurpose != HealthRetrievalPurpose.generalChat &&
        healthPurpose != HealthRetrievalPurpose.unrelatedEntitySearch) {
      await _healthRetrieval.retrieveRelevant(
        service: _health,
        purpose: healthPurpose,
        queryHint: text,
      );
      // لا نعرض التشخيص في الرد
    }

    PersonalCompanionProfileService? profiles = _profiles;
    final profile = await profiles.loadProfile();
    final ctx = PreventiveGuidanceContext(
      computedAge: profile?.currentAge(),
      userContext: profile?.userContext,
      sexSelection: profile?.sexSelection,
      requestTopic: PreventiveGuidanceTopic.walking,
      catalogAvailable: true,
    );

    String? preventiveSnippet;
    var usedPrev = false;
    if (interp.asksPublicHealthTargets ||
        interp.topic == WellnessTopic.walking ||
        interp.topic == WellnessTopic.exercise ||
        interp.topic == WellnessTopic.generalMovement ||
        interp.topic == WellnessTopic.sedentaryTime) {
      final ev = await _guidance.buildEvidenceAwareAdvice(
        interp: interp,
        baseContext: ctx,
      );
      preventiveSnippet = ev.message;
      usedPrev = ev.usedPreventive;
    }

    String msg;
    if (interp.topic == WellnessTopic.restRecovery) {
      msg = _responses.restRecovery();
    } else if (interp.topic == WellnessTopic.sleepRoutine) {
      msg = _responses.sleepWellness();
    } else if (interp.topic == WellnessTopic.sedentaryTime) {
      msg = _responses.sedentary();
      if (preventiveSnippet != null && preventiveSnippet.isNotEmpty) {
        msg = '$msg\n\n$preventiveSnippet';
      }
    } else if (interp.topic == WellnessTopic.walking) {
      msg = _responses.walkingGuidance(preventiveSnippet: preventiveSnippet);
    } else if (interp.topic == WellnessTopic.generalMovement ||
        interp.topic == WellnessTopic.exercise) {
      if (RegExp(r'(?:ابدأ|أبدأ|ابدا|أريد\s*أبدأ|اريد\s*ابدأ)')
          .hasMatch(ArabicTextUtils.normalize(text))) {
        msg = _responses.startingActivity(overwhelmed: interp.overwhelmed);
      } else {
        msg =
            _responses.walkingGuidance(preventiveSnippet: preventiveSnippet);
      }
    } else {
      msg = _responses.startingActivity(overwhelmed: interp.overwhelmed);
    }

    if (_responses.containsForbiddenLanguage(msg)) {
      msg = _responses.startingActivity(overwhelmed: true);
    }

    final qs = _questions.plan(
      interp: interp,
      safety: safety,
      overwhelmed: interp.overwhelmed,
    );

    return WellnessTurnResult(
      handled: true,
      message: msg,
      session: session.copyWith(
        usedPreventiveRule: usedPrev,
        usedPersonalization: usedPers,
        pendingQuestionCount: qs.length.clamp(0, 2),
      ),
    );
  }
}
