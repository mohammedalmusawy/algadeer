import '../../clinical_knowledge_models.dart';
import 'respiratory_models.dart';
import 'respiratory_rule_catalog.dart';

/// سياسة تصوير تنفسي — قرار سريري أولاً؛ بلا تأثير تجاري.
class RespiratoryImagingPolicy {
  const RespiratoryImagingPolicy();

  RespiratoryClinicalRule? selectRule({
    required RespiratorySession session,
    required List<RespiratoryClinicalRule> activeRules,
    bool sponsorOverride = false,
    bool paidOverride = false,
    bool ownershipBias = false,
    bool packageRevenueBias = false,
    bool diabetesAlone = false,
    bool hypertensionAlone = false,
  }) {
    // تجاوزات تجارية/ملكية/مرض مزمن وحده لا تغيّر الأهلية
    // ignore: unnecessary_statements
    sponsorOverride;
    paidOverride;
    ownershipBias;
    packageRevenueBias;
    if (diabetesAlone || hypertensionAlone) {
      // لا أهلية تصوير من السكري/الضغط وحدهما
    }

    if (session.population == RespiratoryPopulation.child) {
      // قواعد البالغين تفشل مغلقة للطفل
      return null;
    }

    if (session.pregnancyContext) {
      // مسار قياسي قد يُقيَّد — نختار فقط قواعد غير محظورة أو نُرجع null للتوجيه الحذر
    }

    final candidates = <RespiratoryClinicalRule>[];
    for (final r in activeRules) {
      if (r.adultOnly && session.population == RespiratoryPopulation.child) {
        continue;
      }
      if (r.blocksPregnancyStandardPathway && session.pregnancyContext) {
        continue;
      }
      if (r.requiresHemoptysis &&
          session.hemoptysis != RespiratoryTriState.present) {
        continue;
      }
      if (r.requiresKnownCopd &&
          session.knownCondition != RespiratoryKnownCondition.copd) {
        continue;
      }
      if (r.requiresKnownAsthma &&
          session.knownCondition != RespiratoryKnownCondition.asthma) {
        continue;
      }
      if (r.requiresRecurrentInfection && !session.recurrentInfection) {
        continue;
      }
      if (r.requiresPostPneumoniaRisk) {
        final ok = session.knownCondition ==
                RespiratoryKnownCondition.pneumoniaEstablished &&
            (session.recentRespiratoryIllness ||
                session.durationBucket != RespiratoryDurationBucket.unknown ||
                session.breathlessness == RespiratoryTriState.present ||
                session.weightLoss == RespiratoryTriState.present);
        if (!ok) continue;
      }

      if (!_topicMatches(session, r)) continue;

      if (r.minDurationBucket != null &&
          !_durationAtLeast(session.durationBucket, r.minDurationBucket!)) {
        continue;
      }
      if (r.maxDurationBucket != null &&
          !_durationAtMost(session.durationBucket, r.maxDurationBucket!)) {
        // سماح إن المدة unknown للسعال الحاد فقط عند topic acute
        if (!(session.durationBucket == RespiratoryDurationBucket.unknown &&
            r.topic == RespiratoryTopic.acuteCough)) {
          continue;
        }
      }

      candidates.add(r);
    }
    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    return candidates.isEmpty ? null : candidates.first;
  }

  bool _topicMatches(RespiratorySession session, RespiratoryClinicalRule r) {
    if (r.topic == session.topic) return true;
    if (r.requiresKnownCopd &&
        session.knownCondition == RespiratoryKnownCondition.copd) {
      return true;
    }
    if (r.requiresKnownAsthma &&
        session.knownCondition == RespiratoryKnownCondition.asthma) {
      return true;
    }
    if (r.requiresHemoptysis &&
        session.hemoptysis == RespiratoryTriState.present) {
      return true;
    }
    if (r.requiresRecurrentInfection && session.recurrentInfection) {
      return true;
    }
    // اشتباه COPD: سعال مزمن + تدخين مصرّح + بلا تشخيص معروف
    if (r.ruleId == 'resp_suspected_copd_spirometry_discuss' &&
        session.durationClass == ClinicalCoughDurationClass.chronic &&
        session.smoking == RespiratorySmokingState.currentSmoking &&
        session.knownCondition == RespiratoryKnownCondition.none) {
      return true;
    }
    return false;
  }

  int _rank(RespiratoryDurationBucket b) {
    switch (b) {
      case RespiratoryDurationBucket.hours:
        return 1;
      case RespiratoryDurationBucket.days:
        return 2;
      case RespiratoryDurationBucket.weeks:
        return 3;
      case RespiratoryDurationBucket.months:
        return 4;
      case RespiratoryDurationBucket.unknown:
        return 0;
    }
  }

  bool _durationAtLeast(
    RespiratoryDurationBucket actual,
    RespiratoryDurationBucket min,
  ) =>
      _rank(actual) >= _rank(min) && actual != RespiratoryDurationBucket.unknown;

  bool _durationAtMost(
    RespiratoryDurationBucket actual,
    RespiratoryDurationBucket max,
  ) {
    if (actual == RespiratoryDurationBucket.unknown) return true;
    return _rank(actual) <= _rank(max);
  }

  bool commercialCanAlterIndication() => false;
  bool ownershipCanAlterIndication() => false;
  bool sponsorCanAlterIndication() => false;
  bool packageRevenueCanAlterIndication() => false;
  bool diabetesAloneTriggersCxr() => false;
  bool hypertensionAloneTriggersCxr() => false;
  bool severeCoughAloneRequiresCt() => false;
  bool longCoughAloneRequiresCt() => false;
}
