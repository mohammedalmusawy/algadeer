import '../../health/guidance/health_guidance_models.dart';
import '../../health/understanding/health_understanding_engine.dart';
import '../conversation_context.dart';
import '../guided_conversation/guided_conversation_models.dart';
import 'assistant_intent.dart';
import 'smart_brain_planner.dart';

/// قرار حتمي لمسار ما بعد المخطِّط — بلا عبارات مبعثرة في الواجهة.
class SmartBrainFallbackDecision {
  const SmartBrainFallbackDecision({
    required this.allowGeneralSearch,
    required this.allowLegacyOrchestrator,
    required this.blockLegacyMedicalNavigation,
    required this.reasonCode,
    this.controlledMessage,
    this.brainOwned = false,
  });

  /// بحث بيانات عبر SmartSearchService فقط.
  final bool allowGeneralSearch;

  /// استدعاء AssistantOrchestrator.processQuery — يجب أن يبقى false لملكية الدماغ.
  final bool allowLegacyOrchestrator;

  /// منع MedicalNavigationService كتفسير طبي منافس.
  final bool blockLegacyMedicalNavigation;

  final String reasonCode;

  /// رد آمن من الدماغ عند ملكية صحية بلا سقوط للـ legacy.
  final String? controlledMessage;

  /// الاستعلام ضمن سلطة Smart Brain (صحة/موجَّه/كيان/فعل).
  final bool brainOwned;

  static const String defaultHealthNeedMore =
      'أحتاج معلومات أكثر حتى أقدر أوجّهك بصورة مناسبة.';
}

/// سياسة سقوط موحّدة: الدماغ يقرر؛ الـ legacy لا يعيد تفسير الصحة/الكيانات.
class SmartBrainFallbackPolicy {
  SmartBrainFallbackPolicy({
    HealthUnderstandingEngine? understanding,
  }) : _understanding = understanding ?? HealthUnderstandingEngine();

  final HealthUnderstandingEngine _understanding;

  /// نص آمن عندما يملك الدماغ استعلاماً صحياً دون اتجاه كافٍ.
  static const controlledUnknownHealthMessage =
      SmartBrainFallbackDecision.defaultHealthNeedMore;

  SmartBrainFallbackDecision decide({
    required String query,
    required AssistantActionPlan plan,
    required ConversationContext context,
  }) {
    final intent = plan.intentResult.intent;
    final healthLang = _understanding.looksLikeHealthLanguage(query);
    final guidedWaiting = context.guidedConversation.isWaitingForAnswer;
    final healthWaiting = context.healthGuidanceSession.status ==
        HealthGuidanceSessionStatus.waitingForAnswer;
    final healthActive = context.healthGuidanceSession.isActive;
    final handoffAwaiting =
        context.healthGuidanceSession.handoff.isAwaitingAcceptance;
    final pendingClarification = context.pendingClarification != null;
    final hasEntitySelection = context.selectedDoctor != null ||
        context.selectedLaboratory != null ||
        context.selectedAnalysis != null ||
        context.selectedPackage != null;
    final hasResultContext = context.currentResultContext?.isNotEmpty == true;

    // —— صحة / سلامة / تسليم ——
    if (plan.kind == AssistantActionKind.healthGuidance ||
        plan.healthDecision != null) {
      return const SmartBrainFallbackDecision(
        allowGeneralSearch: false,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'health_plan_authoritative',
        brainOwned: true,
      );
    }

    if (healthWaiting ||
        handoffAwaiting ||
        (healthActive &&
            context.healthGuidanceSession.status ==
                HealthGuidanceSessionStatus.waitingForAnswer)) {
      return SmartBrainFallbackDecision(
        allowGeneralSearch: false,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'health_pending_authoritative',
        controlledMessage: controlledUnknownHealthMessage,
        brainOwned: true,
      );
    }

    if (healthLang) {
      return SmartBrainFallbackDecision(
        allowGeneralSearch: false,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'health_language_firewall',
        controlledMessage: plan.message.trim().isNotEmpty
            ? plan.message
            : controlledUnknownHealthMessage,
        brainOwned: true,
      );
    }

    // —— Guided ——
    if (plan.kind == AssistantActionKind.guidedConversation || guidedWaiting) {
      return SmartBrainFallbackDecision(
        allowGeneralSearch: false,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'guided_pending_authoritative',
        controlledMessage: plan.message.trim().isNotEmpty
            ? plan.message
            : 'أحتاج جواب أوضح على السؤال الحالي.',
        brainOwned: true,
      );
    }

    // —— توضيح معلّق ——
    if (pendingClarification ||
        plan.kind == AssistantActionKind.showClarification) {
      return const SmartBrainFallbackDecision(
        allowGeneralSearch: false,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'clarification_authoritative',
        brainOwned: true,
      );
    }

    // —— أفعال كيان / اتصال / موقع ——
    if (_isEntityActionIntent(intent) ||
        _isEntityActionKind(plan.kind) ||
        (hasEntitySelection && _looksLikeActionFollowUp(intent))) {
      return const SmartBrainFallbackDecision(
        allowGeneralSearch: false,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'entity_action_authoritative',
        brainOwned: true,
      );
    }

    // —— بحث كيان / عروض / اختصاص ——
    if (_isEntitySearchIntent(intent) ||
        _isEntitySearchKind(plan.kind) ||
        hasResultContext && intent == AssistantIntent.selectResult) {
      return const SmartBrainFallbackDecision(
        allowGeneralSearch: true,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'entity_search_data_only',
        brainOwned: true,
      );
    }

    // —— خطط بحث صريحة من المخطِّط: بيانات فقط ——
    if (plan.kind == AssistantActionKind.runDoctorSearch ||
        plan.kind == AssistantActionKind.runLabSearch ||
        plan.kind == AssistantActionKind.runAnalysisSearch ||
        plan.kind == AssistantActionKind.runPackageSearch ||
        plan.kind == AssistantActionKind.runSpecialtySearch) {
      return const SmartBrainFallbackDecision(
        allowGeneralSearch: true,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'planner_search_data_only',
        brainOwned: true,
      );
    }

    // بحث عام من المخطِّط — بيانات فقط، بلا ملكية صحية/كيان
    if (plan.kind == AssistantActionKind.runGeneralSearch ||
        plan.kind == AssistantActionKind.none) {
      return const SmartBrainFallbackDecision(
        allowGeneralSearch: true,
        allowLegacyOrchestrator: false,
        blockLegacyMedicalNavigation: true,
        reasonCode: 'safe_general_search_no_legacy_orchestrator',
        brainOwned: false,
      );
    }

    // —— عام غير طبي: بحث بيانات مسموح؛ Orchestrator معطّل في SmartSearch ——
    return const SmartBrainFallbackDecision(
      allowGeneralSearch: true,
      allowLegacyOrchestrator: false,
      blockLegacyMedicalNavigation: true,
      reasonCode: 'safe_general_search_no_legacy_orchestrator',
      brainOwned: false,
    );
  }

  bool _isEntityActionIntent(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.selectResult:
        return true;
      default:
        return false;
    }
  }

  bool _isEntitySearchIntent(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.doctorSearch:
      case AssistantIntent.specialtySearch:
      case AssistantIntent.findLab:
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
        return true;
      default:
        return false;
    }
  }

  bool _isEntityActionKind(AssistantActionKind kind) {
    switch (kind) {
      case AssistantActionKind.prepareCall:
      case AssistantActionKind.prepareWhatsApp:
      case AssistantActionKind.showLocation:
      case AssistantActionKind.openProfile:
      case AssistantActionKind.selectEntity:
        return true;
      default:
        return false;
    }
  }

  bool _isEntitySearchKind(AssistantActionKind kind) {
    switch (kind) {
      case AssistantActionKind.showOffers:
      case AssistantActionKind.showLabPackages:
      case AssistantActionKind.showLabAnalyses:
      case AssistantActionKind.showPackagesContainingAnalysis:
      case AssistantActionKind.showLabsViaAnalysisPackages:
      case AssistantActionKind.showPackagePrice:
      case AssistantActionKind.showPackageAnalyses:
      case AssistantActionKind.showPackageComparison:
        return true;
      default:
        return false;
    }
  }

  bool _looksLikeActionFollowUp(AssistantIntent intent) {
    return intent == AssistantIntent.callDoctor ||
        intent == AssistantIntent.messageDoctor ||
        intent == AssistantIntent.callLab ||
        intent == AssistantIntent.messageLab ||
        intent == AssistantIntent.showLocation ||
        intent == AssistantIntent.showProfile ||
        intent == AssistantIntent.selectResult ||
        intent == AssistantIntent.unknown;
  }
}

/// نتيجة تنفيذ سقوط آمن — للاختبارات والمراقبة.
class SmartBrainSafeFallbackOutcome {
  const SmartBrainSafeFallbackOutcome({
    required this.decision,
    required this.usedLegacyOrchestrator,
    required this.usedMedicalNavigation,
    required this.sentRawQueryToLegacyAi,
    this.searchRan = false,
    this.message,
  });

  final SmartBrainFallbackDecision decision;
  final bool usedLegacyOrchestrator;
  final bool usedMedicalNavigation;
  final bool sentRawQueryToLegacyAi;
  final bool searchRan;
  final String? message;
}
