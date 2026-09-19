import '../health/emotional_support/mental_health_safety_gate.dart';
import 'daily_context_expiry_policy.dart';
import 'daily_context_interpreter.dart';
import 'daily_context_models.dart';
import 'daily_context_priority_resolver.dart';
import 'daily_context_response_strategy.dart';

class DailyContextTurnResult {
  const DailyContextTurnResult({
    required this.handled,
    required this.message,
    required this.context,
    this.deferToUrgentSafety = false,
    this.deferToMentalSafety = false,
    this.deferToFollowUp = false,
    this.deferToPersonalMemory = false,
    this.deferToEntityIntent = false,
    this.suppressWellnessPressure = false,
    this.textFirstOnly = true,
    this.success = true,
  });

  final bool handled;
  final String message;
  final DailyLifeContext context;
  final bool deferToUrgentSafety;
  final bool deferToMentalSafety;
  final bool deferToFollowUp;
  final bool deferToPersonalMemory;
  final bool deferToEntityIntent;
  final bool suppressWellnessPressure;
  final bool textFirstOnly;
  final bool success;

  static DailyContextTurnResult notHandled(DailyLifeContext ctx) =>
      DailyContextTurnResult(
        handled: false,
        message: '',
        context: ctx,
      );

  Map<String, Object?> debugMap() => {
        ...context.debugMap(),
        'operationType': handled ? 'dailyContextHandle' : 'dailyContextSkip',
        'operationSuccess': success,
      };
}

/// منسّق السياق اليومي — PC-1.15.
class DailyContextCoordinator {
  DailyContextCoordinator({
    DailyContextInterpreter? interpreter,
    DailyContextExpiryPolicy? expiry,
    DailyContextPrivacyPolicy? privacy,
    DailyContextPriorityResolver? priority,
    DailyContextQuestionPlanner? questions,
    DailyContextResponseStrategy? responses,
    MentalHealthSafetyGate? mentalSafety,
  })  : _interpreter = interpreter ?? const DailyContextInterpreter(),
        _expiry = expiry ?? const DailyContextExpiryPolicy(),
        _privacy = privacy ?? const DailyContextPrivacyPolicy(),
        _priority = priority ?? const DailyContextPriorityResolver(),
        _questions = questions ?? const DailyContextQuestionPlanner(),
        _responses = responses ?? const DailyContextResponseStrategy(),
        _mentalSafety = mentalSafety ?? const MentalHealthSafetyGate();

  final DailyContextInterpreter _interpreter;
  final DailyContextExpiryPolicy _expiry;
  final DailyContextPrivacyPolicy _privacy;
  final DailyContextPriorityResolver _priority;
  final DailyContextQuestionPlanner _questions;
  final DailyContextResponseStrategy _responses;
  final MentalHealthSafetyGate _mentalSafety;

  DailyContextInterpreter get interpreter => _interpreter;
  DailyContextPriorityResolver get priorityResolver => _priority;
  DailyContextPrivacyPolicy get privacy => _privacy;
  DailyContextExpiryPolicy get expiry => _expiry;
  DailyCompanionContract get futureContract => const DailyCompanionContract();

  bool mayHandle({
    required String query,
    required DailyLifeContext context,
  }) {
    final interp = _interpreter.interpret(query);
    if (interp.looksLikeEntityEscape) return false;
    if (interp.looksLikeLongTermRemember) return false;
    if (interp.looksLikeFollowUpRequest) return false;
    if (interp.asksSummary || interp.asksDailyPlan) return true;
    if (interp.signals.length >= 2) return true;
    if (interp.hasSignals &&
        (interp.signals.any((s) =>
                s.category == DailyContextCategory.exam ||
                s.category == DailyContextCategory.sleep ||
                s.category == DailyContextCategory.work ||
                s.category == DailyContextCategory.energy ||
                s.category == DailyContextCategory.emotionalState) ||
            context.hasHighLoad)) {
      return true;
    }
    // تحديث صامت ممكن عبر observe دون handle
    return interp.isCorrection && interp.hasSignals;
  }

  /// يحدّث السياق دون بالضرورة الرد.
  DailyLifeContext observe({
    required String text,
    required DailyLifeContext context,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final interp = _interpreter.interpret(text, now: n);
    var merged = _merge(context, interp, n);
    final forPriority = interp.isAboutOtherPerson
        ? merged.copyWith(
            signals: otherSignals(merged, n),
          )
        : merged.copyWith(
            signals: ownerSignals(merged, n),
          );
    final p = _priority.resolve(
      interp: interp,
      context: forPriority,
      urgentMedical: interp.urgentMedicalHint,
      mentalSafety: interp.mentalSafetyHint || _mentalSafety.triggersCrisis(text),
    );
    final high = _priority.hasHighLoad(forPriority, n);
    return merged.copyWith(
      lastPriority: p,
      hasHighLoad: high,
      deferFollowUpSurfacing: _priority.shouldDeferFollowUpSurfacing(p),
      explicitFocusCategory: interp.explicitFocusCategory,
      updatedAt: n,
    );
  }

  Future<DailyContextTurnResult> handle({
    required String text,
    required DailyLifeContext context,
    DateTime? now,
  }) async {
    try {
      return _handle(text: text, context: context, now: now);
    } catch (_) {
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: context,
        success: false,
      );
    }
  }

  DailyContextTurnResult _handle({
    required String text,
    required DailyLifeContext context,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final interp = _interpreter.interpret(text, now: n);

    if (interp.looksLikeEntityEscape) {
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: context,
        deferToEntityIntent: true,
      );
    }
    if (interp.looksLikeLongTermRemember) {
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: context,
        deferToPersonalMemory: true,
      );
    }
    if (interp.looksLikeFollowUpRequest) {
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: context,
        deferToFollowUp: true,
      );
    }

    if (_mentalSafety.triggersCrisis(text) || interp.mentalSafetyHint) {
      final updated = observe(text: text, context: context, now: n);
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: updated,
        deferToMentalSafety: true,
      );
    }

    if (interp.urgentMedicalHint) {
      final updated = observe(text: text, context: context, now: n);
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: updated,
        deferToUrgentSafety: true,
      );
    }

    if (!interp.isDailyContextTurn && !mayHandle(query: text, context: context)) {
      return DailyContextTurnResult.notHandled(context);
    }

    final updated = observe(text: text, context: context, now: n);
    final priority = updated.lastPriority;
    final high = updated.hasHighLoad;

    // لا نرد على إشارة نشاط وحيدة ضعيفة إن لم تُطلب خطة/ملخص — اترك للعافية
    if (!interp.asksDailyPlan &&
        !interp.asksSummary &&
        interp.signals.length == 1 &&
        interp.signals.first.category == DailyContextCategory.activity &&
        !high) {
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: updated,
        suppressWellnessPressure: false,
      );
    }

    var msg = _responses.build(
      priority: priority,
      context: updated,
      highLoad: high,
      asksPlan: interp.asksDailyPlan,
      asksSummary: interp.asksSummary,
      aboutOther: interp.isAboutOtherPerson,
    );

    final qs = _questions.plan(priority, highLoad: high);
    if (qs.isNotEmpty && !high) {
      msg = '$msg\n${qs.first}';
    }

    if (msg.trim().isEmpty) {
      return DailyContextTurnResult(
        handled: false,
        message: '',
        context: updated,
        suppressWellnessPressure:
            _priority.shouldSuppressWellnessPressure(priority),
      );
    }

    if (_responses.containsForbidden(msg)) {
      msg = 'فهمت وضعك الحالي بشكل مختصر. شنو تحب نعمل الآن؟';
    }

    // صدق القدرة
    assert(!msg.contains('أراقب يومك'));

    return DailyContextTurnResult(
      handled: true,
      message: msg,
      context: updated,
      suppressWellnessPressure:
          _priority.shouldSuppressWellnessPressure(priority),
      textFirstOnly: true,
    );
  }

  DailyLifeContext _merge(
    DailyLifeContext context,
    DailyContextInterpretation interp,
    DateTime now,
  ) {
    var list = _expiry.pruneExpired(context.signals, now);

    // تصحيح: إزالة الطاقة عند «مو تعبان بس نعسان»
    if (interp.isCorrection &&
        interp.signals.any((d) => d.state == 'userReportsSleepyNotFatigued')) {
      final subject = interp.signals.first.subject;
      list = list
          .where(
            (s) => !(s.category == DailyContextCategory.energy &&
                s.subject == subject),
          )
          .toList();
    }

    for (final d in interp.signals) {
      // استبدال نفس الفئة+الموضوع فقط — لا تسريب بين المالك وغيره.
      list = list
          .where((s) => !(s.category == d.category && s.subject == d.subject))
          .toList();
      list = [
        ...list,
        DailyContextSignal(
          category: d.category,
          state: d.state,
          timing: d.timing,
          subject: d.subject,
          createdAt: now,
          expiresAt: _expiry.expiresAt(timing: d.timing, now: now),
        ),
      ];
    }
    return context.copyWith(signals: list, updatedAt: now);
  }

  /// إشارات المالك النشطة فقط.
  List<DailyContextSignal> ownerSignals(DailyLifeContext ctx, [DateTime? now]) =>
      ctx
          .activeSignals(now)
          .where((s) => s.subject == DailyContextSubjectKind.accountOwner)
          .toList(growable: false);

  List<DailyContextSignal> otherSignals(DailyLifeContext ctx, [DateTime? now]) =>
      ctx
          .activeSignals(now)
          .where((s) => s.subject == DailyContextSubjectKind.otherPerson)
          .toList(growable: false);

  /// للاختبارات: هل يُرقّى للذاكرة؟ دائماً لا من هذه الطبقة.
  bool wouldSilentlyPersist(String domain) {
    switch (domain) {
      case 'personalMemory':
        return _privacy.mayPersistToPersonalMemory();
      case 'sensitiveHealth':
        return _privacy.mayPersistToSensitiveHealth();
      case 'followUp':
        return _privacy.mayCreateFollowUp();
      case 'activityRecord':
        return _privacy.mayCreateActivityRecord();
      case 'moodHistory':
        return _privacy.mayCreateMoodHistory();
      default:
        return false;
    }
  }
}
