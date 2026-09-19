import '../guidance/health_guidance_models.dart';
import '../understanding/symptom_models.dart';
import 'medical_safety_models.dart';

/// مقيّم قواعد السلامة — حتمي وبلا تشخيص.
class MedicalSafetyRuleEvaluator {
  const MedicalSafetyRuleEvaluator();

  MedicalSafetyRuleEvaluation evaluate(
    MedicalSafetyRule rule,
    HealthSessionFacts facts,
  ) {
    if (!rule.enabled || !rule.reviewed) {
      return MedicalSafetyRuleEvaluation(
        ruleId: rule.id,
        fullyMatched: false,
      );
    }

    for (final ex in rule.excludedSymptoms) {
      if (_satisfies(facts, ex, rule.allowUncertainRequired)) {
        return MedicalSafetyRuleEvaluation(
          ruleId: rule.id,
          fullyMatched: false,
          excludedByFacts: true,
        );
      }
    }

    final matched = <String>[];
    final missingSymptoms = <String>[];
    var blockedByNegative = false;

    for (final req in rule.requiredSymptoms) {
      if (_satisfies(facts, req, rule.allowUncertainRequired)) {
        matched.add(req.conceptId);
      } else {
        final status = facts.symptomStatuses[req.conceptId];
        // غياب صريح / uncertain صارم → لا تسأل عن هذا العرض كـ safety follow-up
        if (status == SymptomPolarity.absent ||
            (status == SymptomPolarity.uncertain &&
                !req.allowUncertain &&
                !rule.allowUncertainRequired)) {
          blockedByNegative = true;
        } else if (status == null) {
          missingSymptoms.add(req.conceptId);
        } else {
          missingSymptoms.add(req.conceptId);
        }
      }
    }

    if (blockedByNegative) {
      return MedicalSafetyRuleEvaluation(
        ruleId: rule.id,
        fullyMatched: false,
        partiallyMatched: false,
        matchedSymptomIds: matched,
      );
    }

    // لا تطابق جزئي إن لم يُطابق أي عرض مطلوب
    if (matched.isEmpty) {
      return MedicalSafetyRuleEvaluation(
        ruleId: rule.id,
        fullyMatched: false,
        matchedSymptomIds: matched,
        missingSymptomConceptIds: missingSymptoms,
      );
    }

    final missingFacts = <HealthMissingFact>[];

    if (rule.minSeverity != null) {
      final sev = _effectiveSeverity(facts, rule);
      if (!_severityAtLeast(sev, rule.minSeverity!)) {
        missingFacts.add(HealthMissingFact.severity);
      }
    }

    if (rule.requireOnset != null) {
      final onset = _effectiveOnset(facts, rule);
      if (onset == OnsetPattern.unknown) {
        missingFacts.add(HealthMissingFact.onset);
      } else if (onset != rule.requireOnset) {
        return MedicalSafetyRuleEvaluation(
          ruleId: rule.id,
          fullyMatched: false,
          partiallyMatched: false,
          matchedSymptomIds: matched,
        );
      }
    }

    if (rule.requireKnownLaterality || rule.requireLateralitySide != null) {
      final lat = _effectiveLaterality(facts, rule);
      if (lat == Laterality.unknown) {
        missingFacts.add(HealthMissingFact.laterality);
      } else if (rule.requireLateralitySide != null &&
          lat != rule.requireLateralitySide) {
        return MedicalSafetyRuleEvaluation(
          ruleId: rule.id,
          fullyMatched: false,
          partiallyMatched: false,
          matchedSymptomIds: matched,
        );
      } else if (rule.requireKnownLaterality &&
          lat != Laterality.right &&
          lat != Laterality.left) {
        missingFacts.add(HealthMissingFact.laterality);
      }
    }

    if (rule.requirePatientIsChild != null) {
      if (facts.patientIsChild != rule.requirePatientIsChild) {
        missingFacts.add(HealthMissingFact.patientIsChild);
      }
    }

    for (final m in rule.missingFactsIfIncomplete) {
      if (_isFactMissing(m, facts, rule) && !missingFacts.contains(m)) {
        missingFacts.add(m);
      }
    }

    // مناطق الجسم: إن حُددت، يكفي وجود واحدة منها أو البطن مع laterality محلولة
    if (rule.requiredBodyRegions.isNotEmpty) {
      final has = rule.requiredBodyRegions.any(facts.bodyRegions.contains);
      if (!has && !facts.abdominalLocationResolved) {
        // لا تفشل القاعدة إن كانت الأعراض كافية والجانبية محددة
        if (rule.requireLateralitySide == null && !rule.requireKnownLaterality) {
          missingFacts.add(HealthMissingFact.bodyRegion);
        }
      }
    }

    final specificity = matched.length * 10 +
        (rule.minSeverity != null ? 5 : 0) +
        (rule.requireOnset != null ? 4 : 0) +
        (rule.requireKnownLaterality || rule.requireLateralitySide != null
            ? 4
            : 0) +
        rule.optionalSymptoms
            .where((id) =>
                facts.symptomStatuses[id] == SymptomPolarity.present)
            .length;

    final fully = missingSymptoms.isEmpty && missingFacts.isEmpty;
    final partial = matched.isNotEmpty &&
        !fully &&
        (missingSymptoms.isNotEmpty || missingFacts.isNotEmpty);

    return MedicalSafetyRuleEvaluation(
      ruleId: rule.id,
      fullyMatched: fully,
      partiallyMatched: partial,
      matchedSymptomIds: List.unmodifiable(matched),
      missingFacts: List.unmodifiable(missingFacts),
      missingSymptomConceptIds: List.unmodifiable(missingSymptoms),
      specificity: specificity,
    );
  }

  /// شدة مرتبطة بالأعراض المطلوبة فقط — لا تسرّب من عرض آخر.
  UserStatedSeverity _effectiveSeverity(
    HealthSessionFacts facts,
    MedicalSafetyRule rule,
  ) {
    if (rule.severityConceptIds.isEmpty) {
      return facts.userSeverity;
    }

    var best = UserStatedSeverity.unknown;
    for (final id in rule.severityConceptIds) {
      final scoped = facts.symptomFacts[id]?.severity ?? UserStatedSeverity.unknown;
      if (_rank(scoped) > _rank(best)) best = scoped;
    }
    if (best != UserStatedSeverity.unknown) return best;

    // احتياطي: الشدة العامة فقط إذا كانت كل أعراض الشدة المطلوبة حاضرة
    // ولم تُضبط شدة عرض آخر وحدها على حساب هذه المجموعة.
    final allPresent = rule.severityConceptIds.every(
      (id) => facts.symptomStatuses[id] == SymptomPolarity.present,
    );
    if (allPresent) return facts.userSeverity;
    return UserStatedSeverity.unknown;
  }

  OnsetPattern _effectiveOnset(
    HealthSessionFacts facts,
    MedicalSafetyRule rule,
  ) {
    final id = rule.lateralityConceptId ??
        (rule.requiredSymptoms.isNotEmpty
            ? rule.requiredSymptoms.first.conceptId
            : null);
    if (id != null) {
      final scoped = facts.symptomFacts[id]?.onset;
      if (scoped != null && scoped != OnsetPattern.unknown) return scoped;
    }
    return facts.onset;
  }

  Laterality _effectiveLaterality(
    HealthSessionFacts facts,
    MedicalSafetyRule rule,
  ) {
    final id = rule.lateralityConceptId;
    if (id != null) {
      final scoped = facts.symptomFacts[id]?.laterality;
      if (scoped != null && scoped != Laterality.unknown) return scoped;
    }
    return facts.laterality;
  }

  bool _satisfies(
    HealthSessionFacts facts,
    SymptomRequirement req,
    bool allowUncertainDefault,
  ) {
    final status = facts.symptomStatuses[req.conceptId];
    if (status == null) return false;
    final allowUncertain = req.allowUncertain || allowUncertainDefault;
    if (req.polarity == SymptomPolarity.present) {
      if (status == SymptomPolarity.present) return true;
      if (allowUncertain && status == SymptomPolarity.uncertain) return true;
      return false;
    }
    if (req.polarity == SymptomPolarity.absent) {
      return status == SymptomPolarity.absent;
    }
    return status == req.polarity;
  }

  bool _severityAtLeast(UserStatedSeverity actual, UserStatedSeverity min) {
    return _rank(actual) >= _rank(min) && actual != UserStatedSeverity.unknown;
  }

  int _rank(UserStatedSeverity s) {
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

  bool _isFactMissing(
    HealthMissingFact fact,
    HealthSessionFacts facts,
    MedicalSafetyRule rule,
  ) {
    switch (fact) {
      case HealthMissingFact.duration:
        return facts.duration == null;
      case HealthMissingFact.bodyRegion:
        return facts.bodyRegions.isEmpty;
      case HealthMissingFact.laterality:
        final lat = _effectiveLaterality(facts, rule);
        if (rule.requireLateralitySide != null) {
          return lat != rule.requireLateralitySide;
        }
        return lat != Laterality.right && lat != Laterality.left;
      case HealthMissingFact.severity:
        final sev = _effectiveSeverity(facts, rule);
        return rule.minSeverity == null
            ? sev == UserStatedSeverity.unknown
            : !_severityAtLeast(sev, rule.minSeverity!);
      case HealthMissingFact.onset:
        return _effectiveOnset(facts, rule) == OnsetPattern.unknown;
      case HealthMissingFact.associatedFever:
        return !facts.symptomStatuses.containsKey('fever');
      case HealthMissingFact.patientIsChild:
        return facts.patientIsChild == null;
      case HealthMissingFact.abdominalLocationDetail:
        if (facts.abdominalLocationResolved) return false;
        final lat = _effectiveLaterality(facts, rule);
        return lat == Laterality.unknown;
    }
  }
}
