import '../../search/arabic_text_utils.dart';
import '../../voice/intent/assistant_intent.dart';
import '../../voice/intent/smart_brain_planner.dart';
import 'emotional_response_strategy.dart';
import 'emotional_signal_detector.dart';
import 'emotional_support_models.dart';
import 'emotional_support_policy.dart';
import 'mental_health_safety_gate.dart';

/// منسّق الدعم العاطفي — يزيّن المسار المفيد ولا يستبدله (إلا الأزمة).
class EmotionalSupportCoordinator {
  EmotionalSupportCoordinator({
    EmotionalSignalDetector? detector,
    EmotionalSupportPolicy? policy,
    EmotionalResponseStrategyBuilder? responses,
    MentalHealthSafetyGate? safetyGate,
  })  : _detector = detector ?? EmotionalSignalDetector(),
        _policy = policy ?? const EmotionalSupportPolicy(),
        _responses = responses ?? const EmotionalResponseStrategyBuilder(),
        _safety = safetyGate ?? const MentalHealthSafetyGate();

  final EmotionalSignalDetector _detector;
  final EmotionalSupportPolicy _policy;
  final EmotionalResponseStrategyBuilder _responses;
  final MentalHealthSafetyGate _safety;

  EmotionalSignalDetector get detector => _detector;
  MentalHealthSafetyGate get safetyGate => _safety;

  /// تقييم أولي قبل/حول المسار العادي.
  EmotionalSupportTurnResult evaluate({
    required String query,
    required AssistantIntent intent,
    bool studentContext = false,
  }) {
    if (_safety.triggersCrisis(query)) {
      return EmotionalSupportTurnResult(
        context: const EmotionalSupportContext(
          strategy: EmotionalSupportStrategy.crisisSafety,
          mentalSafetyTriggered: true,
        ),
        standaloneMessage: _safety.crisisMessage(),
        crisis: true,
        textFirstOnly: true,
      );
    }

    final hasTask = _hasClearTaskIntent(intent, query);
    final signal = _detector.detect(query, hasTaskIntent: hasTask);
    if (signal.category == EmotionalSignalCategory.neutral) {
      return EmotionalSupportTurnResult(
        context: EmotionalSupportContext.inactive,
      );
    }

    // لا نُحوّل عاطفة الغير إلى ذاكرة مالك
    final strategy = _policy.strategyFor(signal);
    final ask = _policy.shouldAskGentleClarification(
      signal: signal,
      hasClearTaskIntent: hasTask,
    );

    final text = _responses.build(
      strategy: strategy,
      signal: signal,
      studentContext: studentContext,
    );

    // هدف واضح → بادئة قصيرة فقط، بلا سؤال عاطفي
    if (hasTask) {
      return EmotionalSupportTurnResult(
        context: EmotionalSupportContext(
          signal: signal,
          strategy: strategy,
        ),
        prefixMessage: text,
        textFirstOnly: true,
      );
    }

    // لا هدف واضح → رسالة دعم (وربما توضيح لطيف مدمج)
    final standalone = ask
        ? (text.isEmpty
            ? 'معك. تحب تكلي شنو أكثر شي مقلقك؟'
            : text)
        : text;

    return EmotionalSupportTurnResult(
      context: EmotionalSupportContext(
        signal: signal,
        strategy: strategy,
      ),
      standaloneMessage: standalone,
      askGentleClarification: ask,
      textFirstOnly: true,
    );
  }

  /// يزيّن خطة مفيدة ببادئة عاطفية قصيرة — لا يغيّر السلامة/الحقائق.
  AssistantActionPlan decoratePlan({
    required AssistantActionPlan plan,
    required EmotionalSupportTurnResult support,
  }) {
    if (support.crisis) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: plan.intentResult,
        message: support.standaloneMessage,
        canExecute: false,
        textFirstOnly: true,
        healthDecision: plan.healthDecision,
      );
    }

    // سلامة طبية عاجلة: لا نعيد صياغة الحقائق؛ بادئة قصيرة فقط إن وُجدت
    if (plan.kind == AssistantActionKind.healthGuidance) {
      final prefix = support.prefixMessage.trim();
      final useful = plan.message.trim();
      if (prefix.isEmpty || useful.isEmpty) {
        return plan.copyWithTextFirst(true);
      }
      final combined = '$prefix\n$useful';
      if (_policy.containsForbiddenLanguage(combined)) {
        return plan.copyWithTextFirst(true);
      }
      return _clonePlan(plan, combined, textFirst: true);
    }

    final useful = plan.message.trim();
    final prefix = support.prefixMessage.trim();
    final standalone = support.standaloneMessage.trim();

    // لا مسار مفيد واضح + دعم عاطفي فقط
    if (useful.isEmpty &&
        !plan.canExecute &&
        (plan.kind == AssistantActionKind.none ||
            plan.kind == AssistantActionKind.showMessage)) {
      if (standalone.isNotEmpty) {
        return AssistantActionPlan(
          kind: AssistantActionKind.showMessage,
          intentResult: plan.intentResult,
          message: standalone,
          canExecute: false,
          textFirstOnly: true,
        );
      }
      return plan.copyWithTextFirst(true);
    }

    // هدف واضح: بادئة ثم المحتوى
    if (prefix.isNotEmpty && useful.isNotEmpty) {
      final combined = '$prefix\n$useful';
      if (_policy.containsForbiddenLanguage(combined)) {
        return plan.copyWithTextFirst(true);
      }
      return _clonePlan(plan, combined, textFirst: true);
    }

    if (prefix.isNotEmpty && useful.isEmpty && plan.canExecute) {
      // فعل قابل للتنفيذ بلا رسالة — أضف بادئة قصيرة كرسالة
      return _clonePlan(plan, prefix, textFirst: true);
    }

    return plan.copyWithTextFirst(plan.textFirstOnly || support.textFirstOnly);
  }

  bool _hasClearTaskIntent(AssistantIntent intent, String query) {
    switch (intent) {
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
      case AssistantIntent.specialtySearch:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.selectResult:
      case AssistantIntent.doctorSearch:
        return true;
      default:
        break;
    }
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:أريد|اريد|ابي|ابحث|دور).{0,20}(?:طبيب|دكتور|مختبر|تحليل|باقه|باقة)|'
      r'(?:وين\s*المختبر|ابي\s*مختبر)',
    ).hasMatch(n);
  }

  AssistantActionPlan _clonePlan(
    AssistantActionPlan plan,
    String message, {
    required bool textFirst,
  }) {
    return AssistantActionPlan(
      kind: plan.kind,
      intentResult: plan.intentResult,
      target: plan.target,
      candidates: plan.candidates,
      message: message,
      specialtyQuery: plan.specialtyQuery,
      doctorQuery: plan.doctorQuery,
      labQuery: plan.labQuery,
      analysisQuery: plan.analysisQuery,
      canExecute: plan.canExecute,
      contextResolution: plan.contextResolution,
      targetResolution: plan.targetResolution,
      labTargetResolution: plan.labTargetResolution,
      analysisTargetResolution: plan.analysisTargetResolution,
      packageTargetResolution: plan.packageTargetResolution,
      packages: plan.packages,
      analyses: plan.analyses,
      guidedResponse: plan.guidedResponse,
      healthDecision: plan.healthDecision,
      textFirstOnly: textFirst,
    );
  }
}

extension on AssistantActionPlan {
  AssistantActionPlan copyWithTextFirst(bool textFirst) {
    if (textFirstOnly == textFirst) return this;
    return AssistantActionPlan(
      kind: kind,
      intentResult: intentResult,
      target: target,
      candidates: candidates,
      message: message,
      specialtyQuery: specialtyQuery,
      doctorQuery: doctorQuery,
      labQuery: labQuery,
      analysisQuery: analysisQuery,
      canExecute: canExecute,
      contextResolution: contextResolution,
      targetResolution: targetResolution,
      labTargetResolution: labTargetResolution,
      analysisTargetResolution: analysisTargetResolution,
      packageTargetResolution: packageTargetResolution,
      packages: packages,
      analyses: analyses,
      guidedResponse: guidedResponse,
      healthDecision: healthDecision,
      textFirstOnly: textFirst,
    );
  }
}
