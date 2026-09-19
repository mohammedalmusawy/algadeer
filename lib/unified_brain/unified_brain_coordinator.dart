import 'package:ghadeer_clinic/unified_brain/age_authority_resolver.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_arbitrator.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_turn_interpreter.dart';

/// منسّق طبقة PC-1.24 — تحكيم خفيف حول السلطات القائمة.
///
/// لا يستبدل منسّقي النطاق؛ يجمع المرشّحين ويبني خطة رد واحدة.
class UnifiedBrainCoordinator {
  UnifiedBrainCoordinator({
    UnifiedBrainTurnInterpreter? interpreter,
    UnifiedBrainArbitrator? arbitrator,
    AgeAuthorityResolver? ageResolver,
  })  : interpreter = interpreter ?? UnifiedBrainTurnInterpreter(),
        arbitrator = arbitrator ?? const UnifiedBrainArbitrator(),
        ageResolver = ageResolver ?? const AgeAuthorityResolver();

  final UnifiedBrainTurnInterpreter interpreter;
  final UnifiedBrainArbitrator arbitrator;
  final AgeAuthorityResolver ageResolver;

  UnifiedBrainTurnContext buildTurn(
    String query, {
    AgeResolution? age,
    bool subjectResolved = false,
    bool isAboutOtherPerson = false,
  }) {
    return interpreter.interpret(
      query,
      ageOverride: age,
      subjectResolved: subjectResolved,
      isAboutOtherPerson: isAboutOtherPerson,
    );
  }

  /// يختار السلطة الأساسية من مرشّحين مصنّفين.
  BrainAuthorityId selectPrimary(
    UnifiedBrainTurnContext turn,
    List<UnifiedBrainCandidate> candidates,
  ) {
    final plan = arbitrator.arbitrate(turn: turn, candidates: candidates);
    return plan.primaryAuthority;
  }

  UnifiedBrainResponsePlan planFromContributions({
    required UnifiedBrainTurnContext turn,
    required List<UnifiedBrainCandidate> candidates,
    BrainContribution? primary,
    List<BrainContribution> contextual = const [],
    bool safetyInvoked = false,
    bool mentalCrisisInvoked = false,
    bool fallbackUsed = false,
    bool serviceHandoff = false,
  }) {
    return arbitrator.arbitrate(
      turn: turn,
      candidates: candidates,
      primaryContribution: primary,
      contextualContributions: contextual,
      safetyInvoked: safetyInvoked,
      mentalCrisisInvoked: mentalCrisisInvoked,
      fallbackUsed: fallbackUsed,
      serviceHandoff: serviceHandoff,
    );
  }

  UnifiedBrainDiagnostics diagnosticsFromPlan({
    required UnifiedBrainTurnContext turn,
    required UnifiedBrainResponsePlan plan,
    required List<UnifiedBrainCandidate> candidates,
    bool clinicalSessionsClearedForForeignTurn = false,
  }) {
    final candidateIds = candidates
        .where((c) => c.role != BrainAuthorityRole.suppressed)
        .map((c) => c.authority.name)
        .toList();
    candidateIds.sort();
    final suppressionIds = candidates
        .where((c) => c.suppressionReason != null)
        .map((c) => c.suppressionReason!)
        .toSet()
        .toList();
    suppressionIds.sort();
    return UnifiedBrainDiagnostics(
      subjectResolved: turn.subjectResolved,
      primaryIntent: turn.primaryIntent,
      candidateAuthorityIds: candidateIds,
      selectedPrimaryAuthority: plan.primaryAuthority,
      contextualAuthorityIds:
          plan.contextualAuthorities.map((e) => e.name).toList(growable: false),
      safetyAuthorityInvoked: plan.safetyMode || plan.mentalCrisisMode,
      questionBudgetUsed: plan.questionBudgetUsed,
      serviceHandoff: plan.serviceHandoff,
      fallbackUsed: plan.fallbackUsed,
      suppressionReasonIds: suppressionIds,
      clinicalSessionsClearedForForeignTurn:
          clinicalSessionsClearedForForeignTurn,
      ageProvenance: turn.age.provenance,
    );
  }

  /// هل يجب مسح الجلسات السريرية اللاصقة قبل mayHandle؟
  bool shouldClearClinicalSessionsForForeignTurn(UnifiedBrainTurnContext turn) {
    return turn.isForeignToClinicalSessions;
  }
}
