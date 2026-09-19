import '../understanding/symptom_models.dart';
import 'health_guidance_models.dart';

/// مقيّم قواعد حتمي — بلا احتمالات مرضية.
class HealthRuleEvaluator {
  const HealthRuleEvaluator();

  HealthRuleEvaluation evaluate(
    HealthGuidanceRule rule,
    HealthSessionFacts facts,
  ) {
    if (!rule.enabled) {
      return HealthRuleEvaluation(ruleId: rule.id, eligible: false);
    }

    // استبعاد
    for (final ex in rule.excludedSymptoms) {
      if (_satisfies(facts, ex)) {
        return HealthRuleEvaluation(
          ruleId: rule.id,
          eligible: false,
          excludedByFacts: true,
        );
      }
    }

    final matched = <String>[];
    final missing = <HealthMissingFact>[];

    for (final req in rule.requiredSymptoms) {
      if (_satisfies(facts, req)) {
        matched.add(req.conceptId);
      } else {
        // عرض مطلوب غير موجود → غير مؤهل للتوجيه النهائي
        // لكن قد نطلب معلومات إن كان العرض الأساسي موجوداً جزئياً
        return HealthRuleEvaluation(
          ruleId: rule.id,
          eligible: false,
          matchedRequiredFacts: matched,
        );
      }
    }

    if (matched.length < rule.minPresentSymptomCount) {
      return HealthRuleEvaluation(
        ruleId: rule.id,
        eligible: false,
        matchedRequiredFacts: matched,
      );
    }

    if (rule.bodyRegions.isNotEmpty) {
      final hasRegion = rule.bodyRegions.any(facts.bodyRegions.contains) ||
          matched.any((id) {
            // مفاهيم تحمل منطقة ضمنياً
            return true;
          });
      // إن حُددت مناطق في القاعدة وتوجد أعراض مطابقة بمناطق الكتالوج — نكتفي بالأعراض
      if (!hasRegion && facts.bodyRegions.isEmpty) {
        // لا تفشل دائماً — بعض القواعد تعتمد على concept فقط
      }
    }

    if (rule.requireLaterality != null &&
        facts.laterality != rule.requireLaterality) {
      missing.add(HealthMissingFact.laterality);
    }

    if (rule.minSeverity != null) {
      if (!_severityAtLeast(facts.userSeverity, rule.minSeverity!)) {
        missing.add(HealthMissingFact.severity);
      }
    }

    if (rule.requireOnset != null && facts.onset != rule.requireOnset) {
      missing.add(HealthMissingFact.onset);
    }

    if (rule.requirePatientIsChild) {
      if (facts.patientIsChild != true) {
        missing.add(HealthMissingFact.patientIsChild);
      }
    }

    for (final m in rule.missingFactsIfIncomplete) {
      if (_isFactMissing(m, facts, rule)) {
        if (!missing.contains(m)) missing.add(m);
      }
    }

    final specificity = matched.length * 10 +
        (rule.bodyRegions.isNotEmpty ? 3 : 0) +
        (rule.isUrgentSafety ? 50 : 0) +
        rule.optionalSymptoms
            .where((id) =>
                facts.symptomStatuses[id] == SymptomPolarity.present)
            .length;

    final eligible = missing.isEmpty;
    return HealthRuleEvaluation(
      ruleId: rule.id,
      eligible: eligible,
      matchedRequiredFacts: matched,
      missingRequiredFacts: List.unmodifiable(missing),
      specificity: specificity,
    );
  }

  bool _satisfies(HealthSessionFacts facts, SymptomRequirement req) {
    final status = facts.symptomStatuses[req.conceptId];
    if (status == null) return false;
    if (req.polarity == SymptomPolarity.present) {
      if (status == SymptomPolarity.present) return true;
      if (req.allowUncertain && status == SymptomPolarity.uncertain) {
        return true;
      }
      return false;
    }
    if (req.polarity == SymptomPolarity.absent) {
      return status == SymptomPolarity.absent;
    }
    if (req.polarity == SymptomPolarity.uncertain) {
      return status == SymptomPolarity.uncertain;
    }
    return false;
  }

  bool _severityAtLeast(UserStatedSeverity actual, UserStatedSeverity min) {
    int rank(UserStatedSeverity s) {
      switch (s) {
        case UserStatedSeverity.unknown:
          return 0;
        case UserStatedSeverity.mild:
          return 1;
        case UserStatedSeverity.moderate:
          return 2;
        case UserStatedSeverity.severe:
          return 3;
      }
    }

    return rank(actual) >= rank(min) && actual != UserStatedSeverity.unknown;
  }

  bool _isFactMissing(
    HealthMissingFact fact,
    HealthSessionFacts facts,
    HealthGuidanceRule rule,
  ) {
    switch (fact) {
      case HealthMissingFact.duration:
        if (facts.duration != null) return false;
        for (final req in rule.requiredSymptoms) {
          if (facts.symptomFacts[req.conceptId]?.duration != null) {
            return false;
          }
        }
        return true;
      case HealthMissingFact.bodyRegion:
        return facts.bodyRegions.isEmpty;
      case HealthMissingFact.laterality:
        return facts.laterality == Laterality.unknown;
      case HealthMissingFact.severity:
        if (facts.userSeverity != UserStatedSeverity.unknown) return false;
        for (final req in rule.requiredSymptoms) {
          final scoped = facts.symptomFacts[req.conceptId];
          if (scoped != null &&
              scoped.severity != UserStatedSeverity.unknown) {
            return false;
          }
        }
        return true;
      case HealthMissingFact.onset:
        return facts.onset == OnsetPattern.unknown;
      case HealthMissingFact.associatedFever:
        return !facts.symptomStatuses.containsKey('fever');
      case HealthMissingFact.patientIsChild:
        return facts.patientIsChild == null;
      case HealthMissingFact.abdominalLocationDetail:
        if (facts.abdominalLocationResolved) return false;
        return facts.laterality == Laterality.unknown &&
            !facts.bodyRegions.contains(BodyRegionId.lowerBack);
    }
  }
}
