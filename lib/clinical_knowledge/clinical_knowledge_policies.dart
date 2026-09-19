import 'clinical_knowledge_models.dart';
import 'local_clinical_knowledge_catalog.dart';

/// حداثة الأدلة — حتمية.
class ClinicalEvidenceFreshnessPolicy {
  const ClinicalEvidenceFreshnessPolicy({
    this.reviewDueAfterDays = 365 * 3,
  });

  final int reviewDueAfterDays;

  ClinicalEvidenceFreshness resolve(
    ClinicalKnowledgeRule rule, {
    DateTime? now,
  }) {
    if (rule.freshness == ClinicalEvidenceFreshness.superseded) {
      return ClinicalEvidenceFreshness.superseded;
    }
    if (rule.freshness == ClinicalEvidenceFreshness.reviewDue) {
      return ClinicalEvidenceFreshness.reviewDue;
    }
    final n = now ?? DateTime.now();
    final age = n.difference(rule.reviewedAt).inDays;
    if (age > reviewDueAfterDays) return ClinicalEvidenceFreshness.reviewDue;
    if (rule.freshness == ClinicalEvidenceFreshness.current) {
      return ClinicalEvidenceFreshness.current;
    }
    return ClinicalEvidenceFreshness.unknownFreshness;
  }
}

/// أهلية الاختيار — بلا تجاوز تجاري.
class ClinicalKnowledgeEligibilityPolicy {
  const ClinicalKnowledgeEligibilityPolicy();

  bool isEligible(ClinicalKnowledgeRule rule, ClinicalKnowledgeQuery query) {
    if (!rule.isActive) return false;
    if (!rule.hasEvidenceReference) return false;
    if (rule.freshness == ClinicalEvidenceFreshness.superseded) return false;

    // الحمل لا يُستنتج من العمر/الجنس
    if (query.inferPregnancyFromDemographics) return false;
    if (rule.domain == ClinicalDomain.pregnancy &&
        !query.contextTags.contains('explicit_pregnancy_confirmed')) {
      return false;
    }

    if (rule.requiredContext.isNotEmpty &&
        !rule.requiredContext.every(query.contextTags.contains)) {
      return false;
    }
    if (rule.excludedContext.any(query.contextTags.contains)) {
      return false;
    }

    if (rule.coughDurationClass != null &&
        query.coughDuration != null &&
        rule.coughDurationClass != query.coughDuration) {
      return false;
    }

    if (rule.knownDiagnosisKeys.isNotEmpty) {
      final hit = rule.knownDiagnosisKeys.any(query.knownDiagnosisKeys.contains);
      if (!hit) return false;
    }

    if (rule.symptomKeys.isNotEmpty) {
      final hit = rule.symptomKeys.any(query.symptomKeys.contains);
      // قواعد بتشخيص معروف فقط قد لا تحتاج عرضاً
      if (!hit && rule.knownDiagnosisKeys.isEmpty) return false;
    }

    if (query.topic != null &&
        rule.topic != query.topic &&
        rule.topic != ClinicalKnowledgeTopic.generalClinical &&
        rule.topic != ClinicalKnowledgeTopic.other) {
      // سماح بمطابقة الموضوع عند التحديد
      if (rule.requiredContext.isEmpty) {
        // إن وُجد موضوع استعلام مختلف وقاعدة مرتبطة بأعراض فقط — اسمح
        if (query.symptomKeys.isEmpty && query.knownDiagnosisKeys.isEmpty) {
          return false;
        }
      }
    }

    if (query.domain != null && rule.domain != query.domain) {
      if (rule.requiredContext.isEmpty &&
          query.symptomKeys.isEmpty &&
          query.knownDiagnosisKeys.isEmpty) {
        return false;
      }
    }

    return true;
  }

  /// الشدة وحدها لا تحدد العلاج.
  bool severityAloneDeterminesTreatment() => false;

  /// الراعي/الباقة المدفوعة لا يغيّران القرار السريري.
  bool commercialOverrideAllowed(ClinicalKnowledgeQuery query) =>
      !(query.sponsorOverrideRequested || query.paidPackageOverrideRequested)
          ? false
          : false;
}

/// مسترجع قواعد — data-driven.
class ClinicalKnowledgeRetriever {
  ClinicalKnowledgeRetriever({
    ClinicalKnowledgeCatalog? catalog,
    ClinicalKnowledgeEligibilityPolicy? eligibility,
    ClinicalEvidenceFreshnessPolicy? freshness,
  })  : _catalog = catalog ?? LocalClinicalKnowledgeCatalog(),
        _eligibility = eligibility ?? const ClinicalKnowledgeEligibilityPolicy(),
        _freshness = freshness ?? const ClinicalEvidenceFreshnessPolicy();

  final ClinicalKnowledgeCatalog _catalog;
  final ClinicalKnowledgeEligibilityPolicy _eligibility;
  final ClinicalEvidenceFreshnessPolicy _freshness;

  ClinicalKnowledgeCatalog get catalog => _catalog;
  ClinicalEvidenceFreshnessPolicy get freshnessPolicy => _freshness;

  Future<List<ClinicalKnowledgeRule>> retrieve(ClinicalKnowledgeQuery query) async {
    final all = await _catalog.loadRules(activeOnly: true);
    final matched = all.where((r) => _eligibility.isEligible(r, query)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return matched;
  }

  Future<ClinicalKnowledgeRule?> selectBest(ClinicalKnowledgeQuery query) async {
    final list = await retrieve(query);
    if (list.isEmpty) return null;
    return list.first;
  }
}

/// صياغة رد — معلومات عامة وليست علاجاً قطعياً.
class ClinicalKnowledgeResponsePolicy {
  const ClinicalKnowledgeResponsePolicy();

  String build(ClinicalKnowledgeMatch match) {
    final rule = match.rule;
    if (rule == null) {
      return 'ما عندي قاعدة سريرية مراجَعة مناسبة لهذا السياق حالياً. '
          'ما أخترع توجيهاً طبياً.';
    }

    final buf = StringBuffer();
    if (rule.arabicSummary.isNotEmpty) {
      buf.writeln(rule.arabicSummary);
    }

    final imaging = rule.imaging;
    if (imaging != null && imaging.arabicGuidance.isNotEmpty) {
      buf.writeln(imaging.arabicGuidance);
    }

    if (match.allowsRadiologyHandoff) {
      buf.writeln(
        'إذا قرر المختص أن التصوير مناسب، أكدر أدلّك على خدمة الأشعة المتوفرة في غدير.',
      );
    }

    buf.write('هذا توجيه عام مبني على دليل — مو تشخيص ولا وصفة علاج.');
    return buf.toString().trim();
  }

  bool claimsDiagnosis(String msg) => RegExp(
        r'(?:تشخيصك\s*هو|عندك\s*مرض|أنت\s*مصاب\s*ب)',
      ).hasMatch(msg);

  bool claimsFakeAvailability(String msg) => RegExp(
        r'(?:متوفر\s*هسه\s*موعد|الطبيب\s*متاح\s*الآن|أشعة\s*متوفرة\s*اليوم)',
      ).hasMatch(msg);
}
