import '../safety/medical_safety_engine.dart';
import '../safety/medical_safety_models.dart';
import '../understanding/symptom_models.dart';
import 'health_guidance_models.dart';
import 'health_guidance_response_builder.dart';
import 'health_guidance_rule_source.dart';
import 'health_rule_evaluator.dart';
import 'local_health_guidance_rules.dart';

/// محرك قواعد التوجيه الصحي — قرار مسيطر عليه بلا تشخيص.
///
/// التصعيد العاجل/الطوارئ يمر عبر [MedicalSafetyEngine] (Step 10E)
/// كمرجع وحيد — لا مقيّم عاجل منافس داخل 10C.
class HealthGuidanceEngine {
  HealthGuidanceEngine({
    SyncHealthGuidanceRuleSource? ruleSource,
    HealthRuleEvaluator? evaluator,
    HealthGuidanceResponseBuilder? responseBuilder,
    MedicalSafetyEngine? safetyEngine,
  })  : _rules = ruleSource ?? const LocalHealthGuidanceRuleSource(),
        _evaluator = evaluator ?? const HealthRuleEvaluator(),
        _responses = responseBuilder ?? const HealthGuidanceResponseBuilder(),
        _safety = safetyEngine ?? MedicalSafetyEngine();

  final SyncHealthGuidanceRuleSource _rules;
  final HealthRuleEvaluator _evaluator;
  final HealthGuidanceResponseBuilder _responses;
  final MedicalSafetyEngine _safety;

  MedicalSafetyEngine get safetyEngine => _safety;

  HealthGuidanceDecision evaluate(HealthSessionFacts facts) {
    // —— Step 10E أولاً ——
    final safety = _safety.evaluate(facts);
    if (safety.isEscalation) {
      final isEmergency =
          safety.status == MedicalSafetyStatus.emergencyEvaluation;
      return _responses.withMessage(
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
          userMessage: safety.userMessage,
        ),
      );
    }
    if (safety.needsQuestion) {
      return _responses.withMessage(
        HealthGuidanceDecision(
          type: HealthGuidanceDecisionType.needMoreInformation,
          nextQuestion: safety.nextQuestion,
          missingFact: safety.missingFact,
          matchedRuleId: safety.matchedRuleId,
          rationaleCode: safety.responseCode ?? 'safety_need_info',
          allowCommercialOffers: false,
          userMessage: safety.userMessage,
        ),
      );
    }

    final rules = _rules.enabledRulesSync().where((r) => r.enabled).toList();

    final evals = <({HealthGuidanceRule rule, HealthRuleEvaluation ev})>[];
    for (final rule in rules) {
      // تجاهل أي قواعد isUrgentSafety متبقية — 10E هو المرجع
      if (rule.isUrgentSafety) continue;
      final ev = _evaluator.evaluate(rule, facts);
      evals.add((rule: rule, ev: ev));
    }

    // قواعد مكتملة (غير عاجلة)
    final ready =
        evals.where((e) => e.ev.eligible && !e.rule.isUrgentSafety).toList()
          ..sort(_compare);
    if (ready.isNotEmpty) {
      final best = ready.first;
      final dest = best.rule.destination;
      final type = switch (dest.type) {
        GuidanceDestinationType.specialty =>
          HealthGuidanceDecisionType.specialtyDirection,
        GuidanceDestinationType.generalMedicalEvaluation =>
          HealthGuidanceDecisionType.generalEvaluation,
        GuidanceDestinationType.urgentEvaluation =>
          HealthGuidanceDecisionType.urgentEvaluation,
        _ => HealthGuidanceDecisionType.generalEvaluation,
      };
      return _responses.withMessage(
        HealthGuidanceDecision(
          type: type,
          destination: dest,
          matchedRuleId: best.rule.id,
          rationaleCode: best.rule.rationaleCode,
          allowCommercialOffers:
              dest.type != GuidanceDestinationType.urgentEvaluation,
          suggestShowSpecialtyDoctors:
              dest.type == GuidanceDestinationType.specialty,
        ),
      );
    }

    // قواعد تحتاج معلومة واحدة — اختر الأعلى أولوية/تخصصاً مع سؤال
    final needing = evals
        .where(
          (e) =>
              e.ev.matchedRequiredFacts.isNotEmpty &&
              e.ev.missingRequiredFacts.isNotEmpty &&
              !e.ev.excludedByFacts,
        )
        .toList()
      ..sort(_compare);

    if (needing.isNotEmpty) {
      final best = needing.first;
      final missing = best.ev.missingRequiredFacts.first;
      final question = best.rule.followUpQuestionBuilders[missing];
      return _responses.withMessage(
        HealthGuidanceDecision(
          type: HealthGuidanceDecisionType.needMoreInformation,
          nextQuestion: question,
          missingFact: missing,
          matchedRuleId: best.rule.id,
          rationaleCode: best.rule.rationaleCode,
          allowCommercialOffers: true,
        ),
      );
    }

    // أعراض ضعيفة/غامضة
    final hasAnyPresent = facts.symptomStatuses.values
        .any((p) => p == SymptomPolarity.present);
    if (hasAnyPresent) {
      return _responses.withMessage(
        const HealthGuidanceDecision(
          type: HealthGuidanceDecisionType.needMoreInformation,
          rationaleCode: 'insufficient_specific_rule',
        ),
      );
    }

    return _responses.withMessage(
      const HealthGuidanceDecision(
        type: HealthGuidanceDecisionType.unableToDetermine,
        rationaleCode: 'unable',
      ),
    );
  }

  int _compare(
    ({HealthGuidanceRule rule, HealthRuleEvaluation ev}) a,
    ({HealthGuidanceRule rule, HealthRuleEvaluation ev}) b,
  ) {
    final sp = b.ev.specificity.compareTo(a.ev.specificity);
    if (sp != 0) return sp;
    final pr = b.rule.priority.compareTo(a.rule.priority);
    if (pr != 0) return pr;
    return a.rule.id.compareTo(b.rule.id);
  }
}
