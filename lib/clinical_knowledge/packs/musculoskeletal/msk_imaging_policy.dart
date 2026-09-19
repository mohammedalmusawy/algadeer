import '../../clinical_knowledge_models.dart';
import 'msk_models.dart';
import 'msk_rule_catalog.dart';

/// سياسة تصوير MSK — قرار سريري أولاً؛ بلا تأثير تجاري.
class MskImagingPolicy {
  const MskImagingPolicy();

  MskClinicalRule? selectRule({
    required MskSession session,
    required List<MskClinicalRule> activeRules,
    bool sponsorOverride = false,
    bool paidOverride = false,
    bool ownershipBias = false,
  }) {
    // تجاوزات تجارية/ملكية لا تغيّر الأهلية
    // ignore: unnecessary_statements
    sponsorOverride;
    paidOverride;
    ownershipBias;

    final candidates = <MskClinicalRule>[];
    for (final r in activeRules) {
      if (!_topicMatches(session, r)) continue;
      if (r.requiresKnownOa &&
          session.knownDiagnosis != MskKnownDiagnosisKind.kneeOsteoarthritis) {
        continue;
      }
      if (r.requiresKnownDisc &&
          session.knownDiagnosis != MskKnownDiagnosisKind.discDisease) {
        continue;
      }
      if (r.requiresTrauma &&
          session.trauma == MskTraumaMechanism.noneReported) {
        continue;
      }
      if (r.requiresUnableToBearWeight && !_unableBear(session)) {
        continue;
      }
      candidates.add(r);
    }
    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    return candidates.isEmpty ? null : candidates.first;
  }

  bool _topicMatches(MskSession session, MskClinicalRule r) {
    if (r.topic == session.topic) return true;
    if (r.requiresKnownOa &&
        session.knownDiagnosis == MskKnownDiagnosisKind.kneeOsteoarthritis) {
      return true;
    }
    if (r.requiresKnownDisc &&
        session.knownDiagnosis == MskKnownDiagnosisKind.discDisease) {
      return true;
    }
    if (session.topic == MskTopic.thighMuscleInjury &&
        r.topic == MskTopic.muscleStrain) {
      return true;
    }
    return false;
  }

  bool _unableBear(MskSession session) =>
      session.symptoms.contains(MskSymptomType.difficultyWeightBearing) ||
      session.functionalImpact == ClinicalFunctionalImpact.difficultyWalking ||
      session.functionalImpact == ClinicalFunctionalImpact.unableToPerformActivity;

  bool severeAloneRequiresMri(ClinicalSeverityClass s) => false;
  bool commercialCanAlterIndication() => false;
  bool ownershipCanAlterIndication() => false;
}
