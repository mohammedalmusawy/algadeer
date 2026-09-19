import '../understanding/symptom_models.dart';
import 'health_follow_up_models.dart';
import 'health_follow_up_question_catalog.dart';
import 'health_guidance_models.dart';
import 'health_guidance_rule_source.dart';
import 'health_rule_evaluator.dart';
import 'local_health_guidance_rules.dart';

/// يختار سؤالاً واحداً مفيداً — أو لا سؤال — بحتمية وميزانية محدودة.
class HealthFollowUpQuestionPlanner {
  HealthFollowUpQuestionPlanner({
    SyncHealthGuidanceRuleSource? ruleSource,
    HealthRuleEvaluator? evaluator,
    this.maxQuestions = 4,
  })  : _rules = ruleSource ?? const LocalHealthGuidanceRuleSource(),
        _evaluator = evaluator ?? const HealthRuleEvaluator();

  final SyncHealthGuidanceRuleSource _rules;
  final HealthRuleEvaluator _evaluator;
  final int maxQuestions;

  FollowUpQuestionPlan plan({
    required HealthSessionFacts facts,
    required List<String> askedQuestionIds,
    required List<String> answeredQuestionIds,
    required List<String> skippedQuestionIds,
    required int questionsAskedCount,
    int? maxQuestionsOverride,
  }) {
    final budget = maxQuestionsOverride ?? maxQuestions;
    if (questionsAskedCount >= budget) {
      return const FollowUpQuestionPlan(
        noQuestionNeeded: true,
        budgetExhausted: true,
      );
    }

    final rules = _rules.enabledRulesSync().where((r) => r.enabled).toList();
    final candidates =
        <({HealthGuidanceRule rule, HealthRuleEvaluation ev, int score})>[];

    for (final rule in rules) {
      final ev = _evaluator.evaluate(rule, facts);
      if (ev.excludedByFacts) continue;
      if (ev.matchedRequiredFacts.isEmpty &&
          rule.requiredSymptoms.isNotEmpty) {
        // لا نسأل عن قاعدة لم تبدأ أعراضها
        continue;
      }
      if (ev.eligible) continue; // لا حاجة لسؤال
      if (ev.missingRequiredFacts.isEmpty) continue;

      var score = rule.priority + ev.specificity;
      if (rule.isUrgentSafety) score += 1000;
      candidates.add((rule: rule, ev: ev, score: score));
    }

    candidates.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return a.rule.id.compareTo(b.rule.id);
    });

    for (final c in candidates) {
      for (final missing in c.ev.missingRequiredFacts) {
        if (_factAlreadyKnown(facts, missing, c.rule)) continue;

        final symptomId = _primarySymptom(c.rule, facts);
        final question = HealthFollowUpQuestionCatalog.forMissingFact(
              missing,
              symptomConceptId: symptomId,
            ) ??
            c.rule.followUpQuestionBuilders[missing];
        if (question == null) continue;

        if (askedQuestionIds.contains(question.id) &&
            !answeredQuestionIds.contains(question.id) &&
            skippedQuestionIds.contains(question.id)) {
          continue; // لا تكرار فوري بعد تخطي
        }
        if (answeredQuestionIds.contains(question.id)) continue;
        if (skippedQuestionIds.contains(question.id)) continue;

        // لا تسأل مدة عامة إن وُجدت مدة عامة أو للعرض المرتبط
        if (missing == HealthMissingFact.duration &&
            _durationKnown(facts, symptomId)) {
          continue;
        }
        if (missing == HealthMissingFact.severity &&
            _severityKnown(facts, symptomId)) {
          continue;
        }
        if ((missing == HealthMissingFact.abdominalLocationDetail ||
                missing == HealthMissingFact.laterality ||
                missing == HealthMissingFact.bodyRegion) &&
            _locationKnown(facts)) {
          continue;
        }

        final meta = HealthQuestionMeta.fromQuestion(question);
        return FollowUpQuestionPlan(
          question: question,
          missingFact: missing,
          factKey: meta?.factKey,
          symptomConceptId: meta?.symptomConceptId ?? symptomId,
          purpose: meta?.purpose,
        );
      }
    }

    return FollowUpQuestionPlan.none;
  }

  bool _factAlreadyKnown(
    HealthSessionFacts facts,
    HealthMissingFact missing,
    HealthGuidanceRule rule,
  ) {
    switch (missing) {
      case HealthMissingFact.duration:
        return _durationKnown(facts, _primarySymptom(rule, facts));
      case HealthMissingFact.severity:
        return _severityKnown(facts, _primarySymptom(rule, facts));
      case HealthMissingFact.onset:
        return facts.onset != OnsetPattern.unknown;
      case HealthMissingFact.laterality:
      case HealthMissingFact.bodyRegion:
      case HealthMissingFact.abdominalLocationDetail:
        return _locationKnown(facts);
      case HealthMissingFact.associatedFever:
        return facts.symptomStatuses.containsKey('fever');
      case HealthMissingFact.patientIsChild:
        return facts.patientIsChild != null;
    }
  }

  bool _durationKnown(HealthSessionFacts facts, String? symptomId) {
    if (facts.duration != null) return true;
    if (symptomId != null) {
      final scoped = facts.symptomFacts[symptomId];
      if (scoped?.duration != null) return true;
    }
    return false;
  }

  bool _severityKnown(HealthSessionFacts facts, String? symptomId) {
    if (facts.userSeverity != UserStatedSeverity.unknown) return true;
    if (symptomId != null) {
      final scoped = facts.symptomFacts[symptomId];
      if (scoped != null &&
          scoped.severity != UserStatedSeverity.unknown) {
        return true;
      }
    }
    return false;
  }

  bool _locationKnown(HealthSessionFacts facts) {
    return facts.laterality != Laterality.unknown ||
        facts.bodyRegions.contains(BodyRegionId.lowerBack) ||
        facts.abdominalLocationResolved;
  }

  String? _primarySymptom(HealthGuidanceRule rule, HealthSessionFacts facts) {
    for (final req in rule.requiredSymptoms) {
      if (facts.symptomStatuses[req.conceptId] == SymptomPolarity.present) {
        return req.conceptId;
      }
    }
    if (rule.requiredSymptoms.isNotEmpty) {
      return rule.requiredSymptoms.first.conceptId;
    }
    return null;
  }
}
