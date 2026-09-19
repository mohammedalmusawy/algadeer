import '../../follow_up/follow_up_due_policy.dart';
import '../../follow_up/follow_up_models.dart';
import '../../follow_up/follow_up_service.dart';
import '../../health/subject/health_subject_detector.dart';
import '../../health/subject/health_subject_models.dart';
import '../../search/arabic_text_utils.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';
import '../sensitive_profile/sensitive_health_profile_service.dart';
import 'chronic_care_answer_interpreter.dart';
import 'chronic_care_condition_registry.dart';
import 'chronic_care_models.dart';
import 'chronic_care_question_planner.dart';
import 'chronic_care_safety_policy.dart';
import 'local_chronic_care_repository.dart';

class ChronicCareTurnResult {
  const ChronicCareTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.success = true,
    this.deferToUrgentSafety = false,
    this.textFirstOnly = true,
    this.pauseForEntity = false,
  });

  final bool handled;
  final String message;
  final ChronicCareSession session;
  final bool success;
  final bool deferToUrgentSafety;
  final bool textFirstOnly;
  final bool pauseForEntity;

  static ChronicCareTurnResult notHandled(ChronicCareSession session) =>
      ChronicCareTurnResult(
        handled: false,
        message: '',
        session: session,
        textFirstOnly: true,
      );

  Map<String, Object?> debugMap() => {
        ...session.debugMap(),
        'operationSuccess': success,
        // بلا قياسات/أسماء.
      };
}

/// منسّق المتابعة المزمنة العام.
class ChronicCareCoordinator {
  ChronicCareCoordinator({
    SensitiveHealthProfileService? healthProfiles,
    ChronicCareRepository? repository,
    ChronicCareAnswerInterpreter? interpreter,
    ChronicCareQuestionPlanner? planner,
    ChronicCareConditionRegistry? registry,
    ChronicCareSafetyPolicy? safety,
    HealthSubjectDetector? subjects,
    FollowUpService? followUps,
  })  : _health = healthProfiles ?? SensitiveHealthProfileService(),
        _repo = repository ?? LocalChronicCareRepository(),
        _interpreter = interpreter ?? ChronicCareAnswerInterpreter(),
        _planner = planner ?? const ChronicCareQuestionPlanner(),
        _registry = registry ?? const ChronicCareConditionRegistry(),
        _safety = safety ?? const ChronicCareSafetyPolicy(),
        _subjects = subjects ?? const HealthSubjectDetector(),
        _followUps = followUps ?? FollowUpService();

  final SensitiveHealthProfileService _health;
  final ChronicCareRepository _repo;
  final ChronicCareAnswerInterpreter _interpreter;
  final ChronicCareQuestionPlanner _planner;
  final ChronicCareConditionRegistry _registry;
  final ChronicCareSafetyPolicy _safety;
  final HealthSubjectDetector _subjects;
  final FollowUpService _followUps;

  SensitiveHealthProfileService get healthProfiles => _health;
  ChronicCareRepository get repository => _repo;
  ChronicCareAnswerInterpreter get interpreter => _interpreter;
  FollowUpService get followUps => _followUps;

  bool mayHandle({
    required String query,
    required ChronicCareSession session,
  }) {
    if (session.isActive) return true;
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:تابع\s*وياي|وقف\s*متابعه|وقف\s*متابعة|لا\s*تابع|'
      r'ذكرني\s*اتابع|اريد\s*الغدير\s*يتابع|'
      r'ضغطي\s*\d|السكر\s*\d|السكر\s*مضبوط|السكر\s*مو|'
      r'لا\s*تسألني|شنو\s*اخر\s*شي\s*مسجل|امسح\s*(?:اخر\s*قياس|قياسات)|'
      r'هبا1c|hba1c)',
    ).hasMatch(n);
  }

  Future<ChronicCareTurnResult> handle({
    required String text,
    required ChronicCareSession session,
  }) async {
    if (_safety.shouldYieldToUrgentSafety(text)) {
      return ChronicCareTurnResult(
        handled: false,
        message: '',
        session: session.copyWith(status: ChronicCareFlowStatus.paused),
        deferToUrgentSafety: true,
      );
    }

    final subj = _subjects.detect(text);
    if (subj.type != HealthSubjectType.self &&
        subj.type != HealthSubjectType.unknown &&
        subj.evidence == HealthSubjectEvidence.explicitRelationship) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message:
            'هاي المعلومة تخص شخص ثاني. ما أسجّلها بجدول المتابعة حقك.',
        session: session,
      );
    }

    final interp = _interpreter.interpret(raw: text, session: session);
    if (interp.kind == ChronicCareInterpretKind.none && !session.isActive) {
      return ChronicCareTurnResult.notHandled(session);
    }

    try {
      return await _execute(interp, session);
    } catch (_) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message: 'ما كدرت أحفظ معلومة المتابعة هسه. ما تم الحفظ.',
        session: session,
      );
    }
  }

  Future<ChronicCareTurnResult> _execute(
    ChronicCareInterpretation interp,
    ChronicCareSession session,
  ) async {
    switch (interp.kind) {
      case ChronicCareInterpretKind.optInFollowUp:
        return _offerPermission(interp.conditionKey!, session);
      case ChronicCareInterpretKind.optOutFollowUp:
      case ChronicCareInterpretKind.stopAskingForever:
        final key = interp.conditionKey ?? session.activeConditionKey;
        if (key == null) {
          return ChronicCareTurnResult(
            handled: true,
            success: false,
            message: 'حدد السكري أو الضغط لإيقاف المتابعة.',
            session: session,
          );
        }
        return _setPermission(key, false, session,
            message: 'تمام، وقّفت المتابعة لهالحالة.');
      case ChronicCareInterpretKind.permissionYes:
        final key = session.pendingPermissionConditionKey;
        if (key == null) {
          return ChronicCareTurnResult.notHandled(session);
        }
        return _enableAndMaybeAsk(key, session);
      case ChronicCareInterpretKind.permissionNo:
      case ChronicCareInterpretKind.permissionLater:
        return ChronicCareTurnResult(
          handled: true,
          message: 'تمام، ما فعّلت المتابعة.',
          session: const ChronicCareSession(),
        );
      case ChronicCareInterpretKind.rejectMedicationAdvice:
      case ChronicCareInterpretKind.rejectSupplement:
        return ChronicCareTurnResult(
          handled: true,
          success: false,
          message: interp.message,
          session: session,
        );
      case ChronicCareInterpretKind.rejectNonOwner:
        return ChronicCareTurnResult(
          handled: true,
          success: false,
          message: interp.message,
          session: session,
        );
      case ChronicCareInterpretKind.needsGlucoseContext:
        return ChronicCareTurnResult(
          handled: true,
          message: _planner.promptFor(
            ChronicCareQuestionKind.measurementContextClarification,
            'السكر',
          ),
          session: session.copyWith(
            status: ChronicCareFlowStatus.waitingForAnswer,
            activeConditionKey: 'diabetes',
            pendingQuestion:
                ChronicCareQuestionKind.measurementContextClarification,
            awaitingMeasurementContext: true,
            draftGlucoseValue: interp.glucoseValue,
          ),
        );
      case ChronicCareInterpretKind.glucoseMeasurement:
        return _saveGlucose(interp, session);
      case ChronicCareInterpretKind.bpMeasurement:
        return _saveBp(interp, session);
      case ChronicCareInterpretKind.controlStatus:
        return _saveControl(interp, session);
      case ChronicCareInterpretKind.relativeTimingAnswer:
      case ChronicCareInterpretKind.doctorFollowUpMention:
      case ChronicCareInterpretKind.labFollowUpMention:
        return _saveTimelineMention(interp, session);
      case ChronicCareInterpretKind.skip:
        return _skip(session);
      case ChronicCareInterpretKind.showLastAbout:
        return _showLast(interp.conditionKey ?? session.activeConditionKey, session);
      case ChronicCareInterpretKind.deleteLastMeasurement:
        return _deleteLastMeasurement(session);
      case ChronicCareInterpretKind.deleteMeasurementsForCondition:
        return _deleteMeasurements(interp.conditionKey!, session);
      case ChronicCareInterpretKind.topicChangedUrgent:
      case ChronicCareInterpretKind.none:
        if (session.isActive && session.pendingQuestion != null) {
          // جواب غير مفهوم — أعد السؤال مرة واحدة دون حلقة لا نهائية
          final def = _registry.byKey(session.activeConditionKey ?? '');
          return ChronicCareTurnResult(
            handled: true,
            success: false,
            message: _planner.promptFor(
              session.pendingQuestion!,
              def?.displayNameAr ?? 'الحالة',
            ),
            session: session,
          );
        }
        return ChronicCareTurnResult.notHandled(session);
    }
  }

  Future<ChronicCareTurnResult> _offerPermission(
    String key,
    ChronicCareSession session,
  ) async {
    final cond = await _health.findCondition(key);
    if (cond == null || !cond.isPersistableEstablished) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message:
            'ما أكدر أفعّل متابعة مزمنة إلا لحالة مشخّصة/ثابتة محفوظة بموافقتك أولاً.',
        session: session,
      );
    }
    if (cond.followUpPermission) {
      return _askNext(key, session);
    }
    final def = _registry.byKey(key);
    return ChronicCareTurnResult(
      handled: true,
      message:
          'تحب الغدير يتابع وياك ${def?.displayNameAr ?? key} من وقت لوقت ويسألك عن القياسات والمتابعة؟',
      session: session.copyWith(
        status: ChronicCareFlowStatus.awaitingPermissionAnswer,
        pendingPermissionConditionKey: key,
      ),
    );
  }

  Future<ChronicCareTurnResult> _enableAndMaybeAsk(
    String key,
    ChronicCareSession session,
  ) async {
    await _health.setFollowUpPermission(
      canonicalConditionKey: key,
      enabled: true,
    );
    final def = _registry.byKey(key);
    await _followUps.syncChronicOptIn(
      conditionKey: key,
      displayTopic: 'متابعة ${def?.displayNameAr ?? key}',
    );
    var store = await _repo.load();
    final now = DateTime.now();
    final event = ChronicCareTimelineEvent(
      id: 'ev_${now.millisecondsSinceEpoch}',
      conditionKey: key,
      type: ChronicTimelineEventType.followUpPreferenceChanged,
      createdAt: now,
      categoryNote: 'follow_up_enabled',
    );
    store = store.copyWith(
      timeline: [...store.timeline, event],
    );
    await _repo.save(store);
    return _askNext(
      key,
      session.copyWith(
        clearPendingPermission: true,
        status: ChronicCareFlowStatus.activeFollowUp,
        activeConditionKey: key,
      ),
      prefix: 'تم تفعيل المتابعة.\n',
    );
  }

  Future<ChronicCareTurnResult> _setPermission(
    String key,
    bool enabled,
    ChronicCareSession session, {
    required String message,
  }) async {
    final cond = await _health.findCondition(key);
    if (cond != null) {
      await _health.setFollowUpPermission(
        canonicalConditionKey: key,
        enabled: enabled,
      );
    }
    if (enabled) {
      final def = _registry.byKey(key);
      await _followUps.syncChronicOptIn(
        conditionKey: key,
        displayTopic: 'متابعة ${def?.displayNameAr ?? key}',
      );
    } else {
      await _followUps.syncChronicOptOut(key);
    }
    var store = await _repo.load();
    final now = DateTime.now();
    store = store.copyWith(
      timeline: [
        ...store.timeline,
        ChronicCareTimelineEvent(
          id: 'ev_${now.millisecondsSinceEpoch}',
          conditionKey: key,
          type: ChronicTimelineEventType.followUpPreferenceChanged,
          createdAt: now,
          categoryNote: enabled ? 'follow_up_enabled' : 'follow_up_disabled',
        ),
      ],
    );
    await _repo.save(store);
    return ChronicCareTurnResult(
      handled: true,
      message: message,
      session: enabled
          ? session.copyWith(
              status: ChronicCareFlowStatus.activeFollowUp,
              activeConditionKey: key,
            )
          : const ChronicCareSession(),
    );
  }

  Future<ChronicCareTurnResult> _askNext(
    String key,
    ChronicCareSession session, {
    String prefix = '',
  }) async {
    // WHETHER — المحرك الموحّد؛ WHAT — المخطّط المزمن.
    final commitment = await _followUps.findByTopic(
      subject: FollowUpSubjectRef.accountOwner,
      domain: FollowUpDomain.chronicHealth,
      topicKey: key,
    );
    if (commitment != null) {
      final due = _followUps.maySurfaceReturn(
        commitment,
        FollowUpDueContext(
          now: DateTime.now(),
          currentSubject: FollowUpSubjectRef.accountOwner,
          conversationRelevant: true,
        ),
      );
      // بعد تخطّيات كافية: لا نعيد السؤال الروتيني.
      if (!due &&
          commitment.consecutiveSkips >= 2 &&
          prefix.isEmpty) {
        return ChronicCareTurnResult(
          handled: true,
          message: 'تمام، راح أخفف الأسئلة بهالخصوص حالياً.',
          session: session.copyWith(
            status: ChronicCareFlowStatus.reducedPressure,
            activeConditionKey: key,
            clearPendingQuestion: true,
          ),
        );
      }
    }

    final store = await _repo.load();
    final state = store.followUpByCondition[key] ??
        ChronicCareFollowUpState(conditionKey: key);
    final q = _planner.nextQuestion(
      conditionKey: key,
      state: state,
      store: store,
    );
    final def = _registry.byKey(key);
    if (q == null) {
      return ChronicCareTurnResult(
        handled: true,
        message: '${prefix}تمام، عندي الأساسيات لهاللحظة.',
        session: session.copyWith(
          status: ChronicCareFlowStatus.activeFollowUp,
          activeConditionKey: key,
          clearPendingQuestion: true,
        ),
      );
    }
    final now = DateTime.now();
    final nextState = state.copyWith(
      lastAskedAt: now,
      pendingQuestion: q,
    );
    final follow = Map<String, ChronicCareFollowUpState>.from(
      store.followUpByCondition,
    )..[key] = nextState;
    await _repo.save(store.copyWith(followUpByCondition: follow));
    if (commitment != null) {
      await _followUps.recordAsked(commitment.commitmentId);
    }
    return ChronicCareTurnResult(
      handled: true,
      message: '$prefix${_planner.promptFor(q, def?.displayNameAr ?? key)}',
      session: session.copyWith(
        status: ChronicCareFlowStatus.waitingForAnswer,
        activeConditionKey: key,
        pendingQuestion: q,
      ),
    );
  }

  Future<ChronicCareTurnResult> _saveGlucose(
    ChronicCareInterpretation interp,
    ChronicCareSession session,
  ) async {
    final key = 'diabetes';
    final gate = await _requireDiagnosed(key);
    if (gate != null) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message: gate,
        session: session,
      );
    }
    final now = DateTime.now();
    final m = ChronicCareMeasurement(
      id: 'm_${now.millisecondsSinceEpoch}',
      conditionKey: key,
      measurementType: interp.glucoseType ?? ChronicMeasurementType.bloodGlucose,
      numericValues: [interp.glucoseValue!],
      unit: interp.glucoseType == ChronicMeasurementType.hba1c ? '%' : 'mg/dL',
      measurementContext: interp.glucoseContext,
      reportedAt: now,
      createdAt: now,
    );
    await _appendMeasurement(m, session, answered: ChronicCareQuestionKind.lastMeasurement);
    return ChronicCareTurnResult(
      handled: true,
      message: 'سجّلت القياس كمعلومة مبلّغة منك (مو تشخيص جديد).',
      session: session.copyWith(
        status: ChronicCareFlowStatus.activeFollowUp,
        activeConditionKey: key,
        awaitingMeasurementContext: false,
        clearDraftGlucose: true,
        clearPendingQuestion: true,
      ),
    );
  }

  Future<ChronicCareTurnResult> _saveBp(
    ChronicCareInterpretation interp,
    ChronicCareSession session,
  ) async {
    const key = 'hypertension';
    final gate = await _requireDiagnosed(key);
    if (gate != null) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message: gate,
        session: session,
      );
    }
    final now = DateTime.now();
    final m = ChronicCareMeasurement(
      id: 'm_${now.millisecondsSinceEpoch}',
      conditionKey: key,
      measurementType: ChronicMeasurementType.bloodPressure,
      numericValues: [interp.systolic!, interp.diastolic!],
      unit: 'mmHg',
      reportedAt: now,
      createdAt: now,
    );
    await _appendMeasurement(m, session, answered: ChronicCareQuestionKind.lastMeasurement);
    return ChronicCareTurnResult(
      handled: true,
      message: 'سجّلت قياس الضغط (انقباضي/انبساطي) كمعلومة مبلّغة منك.',
      session: session.copyWith(
        status: ChronicCareFlowStatus.activeFollowUp,
        activeConditionKey: key,
        clearPendingQuestion: true,
      ),
    );
  }

  Future<void> _appendMeasurement(
    ChronicCareMeasurement m,
    ChronicCareSession session, {
    ChronicCareQuestionKind? answered,
  }) async {
    var store = await _repo.load();
    final now = DateTime.now();
    final event = ChronicCareTimelineEvent(
      id: 'ev_${now.millisecondsSinceEpoch}',
      conditionKey: m.conditionKey,
      type: ChronicTimelineEventType.measurement,
      createdAt: now,
      measurementId: m.id,
      occurredAt: m.measuredAt,
      relativeTiming: m.relativeTiming,
      categoryNote: m.measurementType.name,
    );
    var state = store.followUpByCondition[m.conditionKey] ??
        ChronicCareFollowUpState(conditionKey: m.conditionKey);
    if (answered != null) {
      state = state.copyWith(
        answeredQuestionKinds: {...state.answeredQuestionKinds, answered.name},
        lastAnsweredAt: now,
        consecutiveSkips: 0,
        clearPendingQuestion: true,
      );
    }
    final follow = Map<String, ChronicCareFollowUpState>.from(
      store.followUpByCondition,
    )..[m.conditionKey] = state;
    await _repo.save(
      store.copyWith(
        measurements: [...store.measurements, m],
        timeline: [...store.timeline, event],
        followUpByCondition: follow,
      ),
    );
  }

  Future<ChronicCareTurnResult> _saveControl(
    ChronicCareInterpretation interp,
    ChronicCareSession session,
  ) async {
    final key = interp.conditionKey!;
    final gate = await _requireDiagnosed(key);
    if (gate != null) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message: gate,
        session: session,
      );
    }
    var store = await _repo.load();
    final now = DateTime.now();
    var state = store.followUpByCondition[key] ??
        ChronicCareFollowUpState(conditionKey: key);
    state = state.copyWith(
      userControlStatus: interp.controlStatus,
      answeredQuestionKinds: {
        ...state.answeredQuestionKinds,
        ChronicCareQuestionKind.controlStatus.name,
        ChronicCareQuestionKind.recentStatus.name,
      },
      lastAnsweredAt: now,
      consecutiveSkips: 0,
      clearPendingQuestion: true,
    );
    final follow = Map<String, ChronicCareFollowUpState>.from(
      store.followUpByCondition,
    )..[key] = state;
    store = store.copyWith(
      followUpByCondition: follow,
      timeline: [
        ...store.timeline,
        ChronicCareTimelineEvent(
          id: 'ev_${now.millisecondsSinceEpoch}',
          conditionKey: key,
          type: ChronicTimelineEventType.userStatusUpdate,
          createdAt: now,
          controlStatus: interp.controlStatus,
          categoryNote: 'user_reported_control',
        ),
      ],
    );
    await _repo.save(store);
    return ChronicCareTurnResult(
      handled: true,
      message:
          'سجّلت تقييمك الشخصي للحالة (تقرير مستخدم، مو حكم سريري من الغدير).',
      session: session.copyWith(
        status: ChronicCareFlowStatus.activeFollowUp,
        activeConditionKey: key,
        clearPendingQuestion: true,
      ),
    );
  }

  Future<ChronicCareTurnResult> _saveTimelineMention(
    ChronicCareInterpretation interp,
    ChronicCareSession session,
  ) async {
    final key = interp.conditionKey ?? session.activeConditionKey;
    if (key == null) return ChronicCareTurnResult.notHandled(session);
    final gate = await _requireDiagnosed(key);
    if (gate != null) {
      return ChronicCareTurnResult(
        handled: true,
        success: false,
        message: gate,
        session: session,
      );
    }
    var store = await _repo.load();
    final now = DateTime.now();
    final type = interp.kind == ChronicCareInterpretKind.doctorFollowUpMention
        ? ChronicTimelineEventType.doctorFollowUp
        : (interp.kind == ChronicCareInterpretKind.labFollowUpMention
            ? ChronicTimelineEventType.labFollowUp
            : ChronicTimelineEventType.userStatusUpdate);
    var state = store.followUpByCondition[key] ??
        ChronicCareFollowUpState(conditionKey: key);
    final answered = {
      ...state.answeredQuestionKinds,
      if (session.pendingQuestion != null) session.pendingQuestion!.name,
      if (type == ChronicTimelineEventType.doctorFollowUp)
        ChronicCareQuestionKind.doctorFollowUp.name,
      if (type == ChronicTimelineEventType.labFollowUp)
        ChronicCareQuestionKind.lastFollowUp.name,
      ChronicCareQuestionKind.lastMeasurement.name,
    };
    state = state.copyWith(
      answeredQuestionKinds: answered,
      lastAnsweredAt: now,
      consecutiveSkips: 0,
      clearPendingQuestion: true,
    );
    final follow = Map<String, ChronicCareFollowUpState>.from(
      store.followUpByCondition,
    )..[key] = state;
    await _repo.save(
      store.copyWith(
        followUpByCondition: follow,
        timeline: [
          ...store.timeline,
          ChronicCareTimelineEvent(
            id: 'ev_${now.millisecondsSinceEpoch}',
            conditionKey: key,
            type: type,
            createdAt: now,
            relativeTiming: interp.relativeTiming,
            occurredAt: interp.exactDate,
            categoryNote: type.name,
          ),
        ],
      ),
    );
    return ChronicCareTurnResult(
      handled: true,
      message: 'سجّلت معلومة المتابعة بشكل منظم.',
      session: session.copyWith(
        status: ChronicCareFlowStatus.activeFollowUp,
        activeConditionKey: key,
        clearPendingQuestion: true,
      ),
    );
  }

  Future<ChronicCareTurnResult> _skip(ChronicCareSession session) async {
    final key = session.activeConditionKey;
    if (key == null) return ChronicCareTurnResult.notHandled(session);
    var store = await _repo.load();
    var state = store.followUpByCondition[key] ??
        ChronicCareFollowUpState(conditionKey: key);
    final skips = state.consecutiveSkips + 1;
    state = state.copyWith(
      consecutiveSkips: skips,
      lastSkippedAt: DateTime.now(),
      reducedPressure: skips >= 2,
      clearPendingQuestion: true,
    );
    final follow = Map<String, ChronicCareFollowUpState>.from(
      store.followUpByCondition,
    )..[key] = state;
    await _repo.save(store.copyWith(followUpByCondition: follow));
    final commitment = await _followUps.findByTopic(
      subject: FollowUpSubjectRef.accountOwner,
      domain: FollowUpDomain.chronicHealth,
      topicKey: key,
    );
    if (commitment != null) {
      await _followUps.recordSkipped(commitment.commitmentId);
    }
    return ChronicCareTurnResult(
      handled: true,
      message: skips >= 2
          ? 'تمام، راح أخفف الأسئلة بهالخصوص.'
          : 'تمام، نكمّل لاحقاً إذا تحب.',
      session: session.copyWith(
        status: skips >= 2
            ? ChronicCareFlowStatus.reducedPressure
            : ChronicCareFlowStatus.paused,
        clearPendingQuestion: true,
      ),
    );
  }

  Future<ChronicCareTurnResult> _showLast(
    String? key,
    ChronicCareSession session,
  ) async {
    if (key == null) {
      return ChronicCareTurnResult(
        handled: true,
        message: 'حدد السكري أو الضغط.',
        session: session,
      );
    }
    final store = await _repo.load();
    final ms = store.measurements.where((m) => m.conditionKey == key).toList();
    final state = store.followUpByCondition[key];
    if (ms.isEmpty && state == null) {
      return ChronicCareTurnResult(
        handled: true,
        message: 'ما عندي قياسات أو متابعة مسجّلة لهالحالة حالياً.',
        session: session,
      );
    }
    final lines = <String>['آخر ما مسجّل (ملخص منظم):'];
    if (ms.isNotEmpty) {
      lines.add('- يوجد قياس مبلّغ مؤخراً.');
    }
    if (state?.userControlStatus != null &&
        state!.userControlStatus != ChronicUserControlStatus.unknown) {
      lines.add('- تقييمك الشخصي مسجّل.');
    }
    final events =
        store.timeline.where((e) => e.conditionKey == key).toList();
    if (events.isNotEmpty) {
      lines.add('- أحداث متابعة: ${events.length}');
    }
    return ChronicCareTurnResult(
      handled: true,
      message: lines.join('\n'),
      session: session,
    );
  }

  Future<ChronicCareTurnResult> _deleteLastMeasurement(
    ChronicCareSession session,
  ) async {
    var store = await _repo.load();
    if (store.measurements.isEmpty) {
      return ChronicCareTurnResult(
        handled: true,
        message: 'ما أكو قياس للحذف.',
        session: session,
      );
    }
    final last = store.measurements.last;
    final nextM = store.measurements.sublist(0, store.measurements.length - 1);
    final nextT = store.timeline
        .where((e) => e.measurementId != last.id)
        .toList(growable: false);
    await _repo.save(store.copyWith(measurements: nextM, timeline: nextT));
    // لا يحذف التشخيص ولا يغيّر followUpPermission
    return ChronicCareTurnResult(
      handled: true,
      message: 'مسحت آخر قياس فقط. التشخيص وصلاحية المتابعة ما تغيّروا.',
      session: session,
    );
  }

  Future<ChronicCareTurnResult> _deleteMeasurements(
    String key,
    ChronicCareSession session,
  ) async {
    var store = await _repo.load();
    final nextM =
        store.measurements.where((m) => m.conditionKey != key).toList();
    final removedIds = store.measurements
        .where((m) => m.conditionKey == key)
        .map((m) => m.id)
        .toSet();
    final nextT = store.timeline
        .where((e) =>
            e.conditionKey != key ||
            e.type != ChronicTimelineEventType.measurement ||
            (e.measurementId != null && !removedIds.contains(e.measurementId)))
        .where((e) => !(e.conditionKey == key &&
            e.type == ChronicTimelineEventType.measurement))
        .toList();
    await _repo.save(store.copyWith(measurements: nextM, timeline: nextT));
    final cond = await _health.findCondition(key);
    return ChronicCareTurnResult(
      handled: true,
      message:
          'مسحت قياسات هالحالة فقط. التشخيص${cond?.followUpPermission == true ? " وصلاحية المتابعة" : ""} ما انمسحوا.',
      session: session,
    );
  }

  Future<String?> _requireDiagnosed(String key) async {
    final cond = await _health.findCondition(key);
    if (cond == null || !cond.isPersistableEstablished) {
      return 'ما أكدر أسجّل متابعة/قياس مزمن إلا لحالة مشخّصة محفوظة بموافقة.';
    }
    return null;
  }
}
