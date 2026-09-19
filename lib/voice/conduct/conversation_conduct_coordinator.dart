import '../intent/smart_brain_planner.dart';
import '../../health/guidance/health_guidance_models.dart';
import 'conversation_conduct_detector.dart';
import 'conversation_conduct_models.dart';
import 'conversation_ethics_response_builder.dart';

/// نتيجة مراقبة السلوك قبل المسارات المفيدة.
class ConductObserveOutcome {
  const ConductObserveOutcome({
    required this.result,
    required this.state,
    required this.pipelineQuery,
  });

  final ConversationConductResult result;
  final ConversationConductSessionState state;

  /// استعلام للمسارات اللاحقة (بعد إزالة الإساءة الموجّهة إن لزم).
  final String pipelineQuery;
}

/// ينسّق كشف السلوك مع أولوية السلامة الطبية وعدم معاقبة المستخدم.
class ConversationConductCoordinator {
  ConversationConductCoordinator({
    ConversationConductDetector? detector,
    ConversationEthicsResponseBuilder? responses,
    this.decayAfterNormalTurns = 3,
  })  : _detector = detector ?? ConversationConductDetector(),
        _responses = responses ?? const ConversationEthicsResponseBuilder();

  final ConversationConductDetector _detector;
  final ConversationEthicsResponseBuilder _responses;
  final int decayAfterNormalTurns;

  ConversationConductDetector get detector => _detector;
  ConversationEthicsResponseBuilder get responseBuilder => _responses;

  /// يُستدعى مبكراً: metadata فقط + استعلام مسارات — لا يبتلع الإدخال قبل الصحة/السلامة.
  ConductObserveOutcome observe({
    required String query,
    required ConversationConductSessionState state,
  }) {
    final detected = _detector.detect(query);
    var next = state;

    if (detected.isQuotedOrThirdParty) {
      next = _maybeDecay(next);
      return ConductObserveOutcome(
        result: detected,
        state: next,
        pipelineQuery: query,
      );
    }

    if (detected.shouldRespond) {
      final count = state.recentAbuseCount + 1;
      final code = _responses.codeFor(
        level: detected.level,
        recentAbuseCount: count,
      );
      next = state.copyWith(
        recentAbuseCount: count,
        lastConductLevel: detected.level,
        normalTurnsSinceAbuse: 0,
        lastResponseCode: code,
      );
      final pipeline = detected.remainderQuery.trim().isNotEmpty
          ? detected.remainderQuery.trim()
          : query;
      return ConductObserveOutcome(
        result: ConversationConductResult(
          level: detected.level,
          target: detected.target,
          matchedCategory: detected.matchedCategory,
          shouldRespond: true,
          responseCode: code,
          remainderQuery: detected.remainderQuery,
          matchedEntryIds: detected.matchedEntryIds,
        ),
        state: next,
        pipelineQuery: pipeline,
      );
    }

    next = _maybeDecay(
      next.copyWith(
        lastConductLevel: ConversationConductLevel.normal,
        normalTurnsSinceAbuse: state.recentAbuseCount > 0
            ? state.normalTurnsSinceAbuse + 1
            : 0,
      ),
    );
    return ConductObserveOutcome(
      result: detected,
      state: next,
      pipelineQuery: query,
    );
  }

  ConversationConductSessionState _maybeDecay(
    ConversationConductSessionState state,
  ) {
    if (state.recentAbuseCount <= 0) return state;
    if (state.normalTurnsSinceAbuse < decayAfterNormalTurns) return state;
    return ConversationConductSessionState.empty;
  }

  /// يزيّن الخطة بعد المسارات المفيدة — السلامة الطبية تغلب الآداب.
  AssistantActionPlan decoratePlan({
    required AssistantActionPlan plan,
    required ConversationConductResult conduct,
    required ConversationConductSessionState state,
    required int turnId,
    required void Function(ConversationConductSessionState) writeState,
  }) {
    if (_isMedicalSafetyPriority(plan)) {
      writeState(state);
      return plan;
    }

    if (!conduct.shouldRespond) {
      writeState(state);
      return plan;
    }

    final ethicsText = _responses.build(conduct.responseCode);
    if (ethicsText == null || ethicsText.isEmpty) {
      writeState(state);
      return plan;
    }

    writeState(state.copyWith(lastConductResponseTurnId: turnId));

    final useful = plan.message.trim();
    final remainderEmpty = conduct.remainderQuery.trim().isEmpty;

    // إساءة فقط بلا مسار مفيد واضح
    if (remainderEmpty &&
        (plan.kind == AssistantActionKind.none ||
            (plan.kind == AssistantActionKind.showMessage && useful.isEmpty) ||
            useful.isEmpty && !plan.canExecute)) {
      return AssistantActionPlan(
        kind: AssistantActionKind.showMessage,
        intentResult: plan.intentResult,
        message: ethicsText,
        canExecute: false,
      );
    }

    // إساءة + محتوى مفيد → حد قصير ثم المحتوى (لا تضييع الهدف/الفعل)
    if (useful.isNotEmpty) {
      if (useful == ConversationEthicsResponseBuilder.gentle ||
          useful == ConversationEthicsResponseBuilder.repeated ||
          useful == ConversationEthicsResponseBuilder.severe) {
        return plan;
      }
      final combined = '$ethicsText\n$useful';
      return AssistantActionPlan(
        kind: plan.kind,
        intentResult: plan.intentResult,
        target: plan.target,
        candidates: plan.candidates,
        message: combined,
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
      );
    }

    // فعل قابل للتنفيذ بلا رسالة — أبقِ الفعل وأضف حداً قصيراً
    if (plan.canExecute ||
        plan.kind == AssistantActionKind.prepareCall ||
        plan.kind == AssistantActionKind.prepareWhatsApp ||
        plan.kind == AssistantActionKind.selectEntity ||
        plan.kind == AssistantActionKind.healthGuidance ||
        plan.kind == AssistantActionKind.guidedConversation) {
      return AssistantActionPlan(
        kind: plan.kind,
        intentResult: plan.intentResult,
        target: plan.target,
        candidates: plan.candidates,
        message: ethicsText,
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
      );
    }

    return AssistantActionPlan(
      kind: AssistantActionKind.showMessage,
      intentResult: plan.intentResult,
      message: ethicsText,
      canExecute: false,
    );
  }

  bool _isMedicalSafetyPriority(AssistantActionPlan plan) {
    final d = plan.healthDecision;
    if (d == null) return false;
    return d.type == HealthGuidanceDecisionType.urgentEvaluation ||
        d.type == HealthGuidanceDecisionType.emergencyEvaluation;
  }
}
