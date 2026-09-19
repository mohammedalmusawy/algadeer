import '../../companion/personal_companion_profile.dart';
import '../../companion/personal_companion_profile_service.dart';
import '../../search/arabic_text_utils.dart';
import '../emotional_support/emotional_signal_detector.dart';
import '../emotional_support/mental_health_safety_gate.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';
import '../sensitive_profile/sensitive_health_retrieval_policy.dart';
import '../sensitive_profile/sensitive_health_profile_service.dart';
import 'preventive_guidance_catalog_source.dart';
import 'preventive_guidance_context.dart';
import 'preventive_guidance_interpreter.dart';
import 'preventive_guidance_models.dart';
import 'preventive_guidance_planner.dart';
import 'preventive_guidance_response_builder.dart';

/// منسّق التوجيه الوقائي PC-1.7 — requested-first، بلا تشخيص.
class PreventiveGuidanceCoordinator {
  PreventiveGuidanceCoordinator({
    PersonalCompanionProfileService? profiles,
    SensitiveHealthProfileService? healthProfiles,
    PreventiveGuidanceCatalogSource? catalog,
    PreventiveGuidancePlanner? planner,
    PreventiveGuidanceResponseBuilder? responses,
    PreventiveGuidanceInterpreter? interpreter,
    PreventiveGuidanceContextBuilder? contextBuilder,
    SensitiveHealthRetrievalPolicy? retrieval,
    EmotionalSignalDetector? emotionalDetector,
    MentalHealthSafetyGate? mentalSafety,
  })  : _profiles = profiles ?? PersonalCompanionProfileService(),
        _health = healthProfiles ?? SensitiveHealthProfileService(),
        _catalog = catalog ?? LocalPreventiveGuidanceCatalog(),
        _planner = planner ?? PreventiveGuidancePlanner(catalog: catalog),
        _responses = responses ??
            PreventiveGuidanceResponseBuilder(catalog: catalog),
        _interpreter = interpreter ?? const PreventiveGuidanceInterpreter(),
        _contextBuilder = contextBuilder ??
            const PreventiveGuidanceContextBuilder(),
        _retrieval = retrieval ?? const SensitiveHealthRetrievalPolicy(),
        _emotional = emotionalDetector ?? EmotionalSignalDetector(),
        _mentalSafety = mentalSafety ?? const MentalHealthSafetyGate();

  final PersonalCompanionProfileService _profiles;
  final SensitiveHealthProfileService _health;
  final PreventiveGuidanceCatalogSource _catalog;
  final PreventiveGuidancePlanner _planner;
  final PreventiveGuidanceResponseBuilder _responses;
  final PreventiveGuidanceInterpreter _interpreter;
  final PreventiveGuidanceContextBuilder _contextBuilder;
  final SensitiveHealthRetrievalPolicy _retrieval;
  final EmotionalSignalDetector _emotional;
  final MentalHealthSafetyGate _mentalSafety;

  PreventiveGuidancePlanner get planner => _planner;
  PreventiveGuidanceInterpreter get interpreter => _interpreter;
  PreventiveGuidanceResponseBuilder get responses => _responses;

  bool mayHandle({
    required String query,
    required PreventiveGuidanceSession session,
  }) {
    if (session.isActive || session.pendingMore) return true;
    if (isAboutAnotherPerson(query)) return false;
    return _interpreter.looksLikePreventiveRequest(query);
  }

  /// PC-1.8 — لا تخصيص وقائي بعمر/سياق صاحب الحساب لشخص آخر.
  bool isAboutAnotherPerson(String query) {
    final n = ArabicTextUtils.normalize(query);
    if (RegExp(r'(?:انا|عني|نفسي|مالتي|حقي)').hasMatch(n)) return false;
    return RegExp(
      r'(?:ابني|ابنتي|ولدي|بنتي|امي|أمي|ابوي|زوجتي|زوجي|زوج|طفلي|الولد|بنت)',
    ).hasMatch(n);
  }

  /// لا نتدخل إذا المستخدم يطلب طبيب/مختبر صراحة.
  bool shouldEscapeToProvider(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:زين\s*أريد\s*طبيب|اريد\s*طبيب|ابي\s*طبيب|'
      r'أريد\s*مختبر|اريد\s*مختبر|ابي\s*مختبر|'
      r'دور\s*لي\s*طبيب|دور\s*لي\s*مختبر)',
    ).hasMatch(n);
  }

  bool shouldYieldToUrgentSafety(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف|الم\s*صدر|ألم\s*صدر|شديد)',
    ).hasMatch(n);
  }

  Future<PreventiveGuidanceTurnResult> handle({
    required String text,
    required PreventiveGuidanceSession session,
    int turnId = 0,
  }) async {
    if (shouldEscapeToProvider(text)) {
      return PreventiveGuidanceTurnResult.notHandled(session);
    }

    if (_mentalSafety.triggersCrisis(text)) {
      return PreventiveGuidanceTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToMentalSafety: true,
      );
    }

    if (shouldYieldToUrgentSafety(text)) {
      return PreventiveGuidanceTurnResult(
        handled: false,
        message: '',
        session: session,
        deferToUrgentSafety: true,
      );
    }

    final interp = _interpreter.interpret(text);
    if (interp.kind == PreventiveIntent.none && !session.isActive) {
      return PreventiveGuidanceTurnResult.notHandled(session);
    }

    PersonalCompanionProfile? profile;
    var catalogAvailable = true;
    try {
      profile = await _profiles.loadProfile();
    } catch (_) {
      profile = null;
    }

    try {
      await _catalog.loadActiveRules();
    } catch (_) {
      catalogAvailable = false;
    }

    List<HealthConditionRecord> permitted = const [];
    try {
      permitted = await _retrieval.retrieveRelevant(
        service: _health,
        purpose: HealthRetrievalPurpose.healthConversation,
        queryHint: text,
      );
    } catch (_) {
      permitted = const [];
    }

    final emotional = _emotional.detect(text);
    final requestMore = interp.kind == PreventiveIntent.moreAdvice ||
        session.pendingMore;

    PreventiveGuidanceContext ctx;
    try {
      ctx = _contextBuilder.build(
        profile: profile,
        permittedConditions: permitted,
        emotionalCategory: emotional.category,
        requestTopic: interp.topic,
        intent: interp.kind == PreventiveIntent.none
            ? PreventiveIntent.moreAdvice
            : interp.kind,
        catalogAvailable: catalogAvailable,
      );
    } catch (_) {
      catalogAvailable = false;
      ctx = _contextBuilder.build(catalogAvailable: false);
    }

    PreventiveGuidancePlan plan;
    try {
      plan = await _planner.plan(
        context: ctx,
        session: session,
        requestMore: requestMore,
      );
    } catch (_) {
      final failMsg = await _responses.build(
        plan: PreventiveGuidancePlan.empty,
        context: ctx.copyWithCatalog(false),
      );
      return PreventiveGuidanceTurnResult(
        handled: true,
        message: failMsg,
        session: session,
        textFirstOnly: true,
        intent: interp.kind,
      );
    }

    final message = await _responses.build(plan: plan, context: ctx);
    if (message.trim().isEmpty) {
      return PreventiveGuidanceTurnResult.notHandled(session);
    }

    final newIds = [
      ...session.deliveredRuleIds,
      ...plan.selectedRuleIds,
    ];

    final nextSession = session.copyWith(
      status: PreventiveGuidanceSessionStatus.active,
      lastTopic: plan.topic,
      deliveredRuleIds: newIds,
      pendingMore: plan.hasMore,
      lastUpdatedTurnId: turnId,
    );

    return PreventiveGuidanceTurnResult(
      handled: true,
      message: message,
      session: nextSession,
      textFirstOnly: true,
      ruleIds: plan.selectedRuleIds,
      personalizationLevel: plan.personalizationLevel,
      intent: plan.intent,
    );
  }
}

extension on PreventiveGuidanceContext {
  PreventiveGuidanceContext copyWithCatalog(bool available) {
    return PreventiveGuidanceContext(
      computedAge: computedAge,
      sexSelection: sexSelection,
      userContext: userContext,
      permittedConditionKeys: permittedConditionKeys,
      emotionalCategory: emotionalCategory,
      emotionalOverload: emotionalOverload,
      requestTopic: requestTopic,
      intent: intent,
      catalogAvailable: available,
    );
  }
}
