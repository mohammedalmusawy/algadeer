import '../guidance/health_guidance_models.dart';
import 'local_medical_safety_rules.dart';
import 'medical_safety_models.dart';
import 'medical_safety_response_builder.dart';
import 'medical_safety_rule_evaluator.dart';
import 'medical_safety_rule_source.dart';

/// محرك السلامة / الأعلام الحمراء — المرجع الوحيد للتصعيد العاجل.
///
/// لا تشخيص. لا اختيار طبيب/مختبر/باقة. لا أرقام طوارئ مخترعة.
///
/// [MedicalSafetyStatus.noRedFlagDetected] = لم تُطابق قاعدة مُعدَّة،
/// وليس معناه أن الحالة آمنة طبياً.
class MedicalSafetyEngine {
  MedicalSafetyEngine({
    SyncMedicalSafetyRuleSource? ruleSource,
    MedicalSafetyRuleEvaluator? evaluator,
    MedicalSafetyResponseBuilder? responseBuilder,
  })  : _rules = ruleSource ?? const LocalMedicalSafetyRuleSource(),
        _evaluator = evaluator ?? const MedicalSafetyRuleEvaluator(),
        _responses = responseBuilder ?? const MedicalSafetyResponseBuilder();

  final SyncMedicalSafetyRuleSource _rules;
  final MedicalSafetyRuleEvaluator _evaluator;
  final MedicalSafetyResponseBuilder _responses;

  MedicalSafetyDecision evaluate(HealthSessionFacts facts) {
    final rules = _rules.enabledRulesSync().where((r) => r.enabled).toList();
    final evals = <({MedicalSafetyRule rule, MedicalSafetyRuleEvaluation ev})>[];
    for (final rule in rules) {
      evals.add((rule: rule, ev: _evaluator.evaluate(rule, facts)));
    }

    final full = evals.where((e) => e.ev.fullyMatched).toList()
      ..sort(_compare);
    if (full.isNotEmpty) {
      final best = full.first;
      final status =
          best.rule.responseCategory ==
                  MedicalSafetyResponseCategory.emergencyEvaluation
              ? MedicalSafetyStatus.emergencyEvaluation
              : MedicalSafetyStatus.urgentEvaluation;
      return _responses.withMessage(
        MedicalSafetyDecision(
          status: status,
          matchedRuleId: best.rule.id,
          responseCode: best.rule.rationaleCode,
          suppressCommercialContent: true,
          interruptConversation: true,
          responseCategory: best.rule.responseCategory,
        ),
      );
    }

    // سؤال سلامة واحد عالي القيمة قبل التوجيه الروتيني
    final partial = evals
        .where(
          (e) =>
              e.ev.partiallyMatched &&
              !e.ev.excludedByFacts &&
              (e.ev.missingFacts.isNotEmpty ||
                  e.ev.missingSymptomConceptIds.isNotEmpty),
        )
        .toList()
      ..sort(_compare);

    if (partial.isNotEmpty) {
      final best = partial.first;
      // أولوية: عرض ناقص ثم حقيقة ناقصة
      if (best.ev.missingSymptomConceptIds.isNotEmpty) {
        final sym = best.ev.missingSymptomConceptIds.first;
        final q = best.rule.missingSymptomQuestions[sym];
        if (q != null) {
          return _responses.withMessage(
            MedicalSafetyDecision(
              status: MedicalSafetyStatus.needSafetyInformation,
              matchedRuleId: best.rule.id,
              responseCode: best.rule.rationaleCode,
              nextQuestion: q,
              suppressCommercialContent: true,
              interruptConversation: false,
              responseCategory: best.rule.responseCategory,
              userMessage: q.prompt,
            ),
          );
        }
      }
      if (best.ev.missingFacts.isNotEmpty) {
        final mf = best.ev.missingFacts.first;
        final q = best.rule.followUpQuestionBuilders[mf];
        if (q != null) {
          return _responses.withMessage(
            MedicalSafetyDecision(
              status: MedicalSafetyStatus.needSafetyInformation,
              matchedRuleId: best.rule.id,
              responseCode: best.rule.rationaleCode,
              nextQuestion: q,
              missingFact: mf,
              suppressCommercialContent: true,
              interruptConversation: false,
              responseCategory: best.rule.responseCategory,
              userMessage: q.prompt,
            ),
          );
        }
      }
    }

    // لا مطابقة — ليس «أنت بخير».
    return MedicalSafetyDecision.none;
  }

  int _compare(
    ({MedicalSafetyRule rule, MedicalSafetyRuleEvaluation ev}) a,
    ({MedicalSafetyRule rule, MedicalSafetyRuleEvaluation ev}) b,
  ) {
    final pr = b.rule.priority.compareTo(a.rule.priority);
    if (pr != 0) return pr;
    final sp = b.ev.specificity.compareTo(a.ev.specificity);
    if (sp != 0) return sp;
    return a.rule.id.compareTo(b.rule.id);
  }
}
