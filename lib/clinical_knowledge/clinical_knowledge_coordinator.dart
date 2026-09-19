import '../health/emotional_support/mental_health_safety_gate.dart';
import '../search/arabic_text_utils.dart';
import 'clinical_knowledge_models.dart';
import 'clinical_knowledge_policies.dart';
import 'local_clinical_knowledge_catalog.dart';

class ClinicalKnowledgeTurnResult {
  const ClinicalKnowledgeTurnResult({
    required this.handled,
    required this.message,
    required this.session,
    this.deferToMedicalSafety = false,
    this.deferToMentalSafety = false,
    this.textFirstOnly = true,
    this.success = true,
    this.match = ClinicalKnowledgeMatch.empty,
  });

  final bool handled;
  final String message;
  final ClinicalKnowledgeSession session;
  final bool deferToMedicalSafety;
  final bool deferToMentalSafety;
  final bool textFirstOnly;
  final bool success;
  final ClinicalKnowledgeMatch match;

  static ClinicalKnowledgeTurnResult notHandled(ClinicalKnowledgeSession s) =>
      ClinicalKnowledgeTurnResult(
        handled: false,
        message: '',
        session: s,
      );
}

/// منسّق المعرفة السريرية — يستعلم الكتalog؛ لا يستبدل 10E/10C/PC-1.5/1.6.
class ClinicalKnowledgeCoordinator {
  ClinicalKnowledgeCoordinator({
    ClinicalKnowledgeRetriever? retriever,
    ClinicalKnowledgeResponsePolicy? responses,
    MentalHealthSafetyGate? mentalSafety,
  })  : _retriever = retriever ?? ClinicalKnowledgeRetriever(),
        _responses = responses ?? const ClinicalKnowledgeResponsePolicy(),
        _mentalSafety = mentalSafety ?? const MentalHealthSafetyGate();

  final ClinicalKnowledgeRetriever _retriever;
  final ClinicalKnowledgeResponsePolicy _responses;
  final MentalHealthSafetyGate _mentalSafety;

  ClinicalKnowledgeRetriever get retriever => _retriever;
  ClinicalKnowledgeCatalog get catalog => _retriever.catalog;
  ClinicalKnowledgeAdminContract get futureAdmin =>
      const ClinicalKnowledgeAdminContract();
  ClinicalKnowledgeEligibilityPolicy get eligibility =>
      const ClinicalKnowledgeEligibilityPolicy();

  /// هل يبدو الطلب مناسباً لاستعلام المعرفة (وليس اختطاف كل الصحة)؟
  bool mayHandle({
    required String query,
    required ClinicalKnowledgeSession session,
  }) {
    final n = ArabicTextUtils.normalize(query);
    if (n.isEmpty) return false;
    // أسئلة تصوير / دليل عام — لا تحل محل 10C لكل عرض
    return RegExp(
      r'(?:احتاج\s*اشعه|أحتاج\s*أشعة|اسوي\s*اشعه|أسوي\s*أشعة|'
      r'لازم\s*اشعه|لازم\s*أشعة|تصوير\s*اشعه|صورة\s*اشعه|'
      r'اشعه\s*للظهر|أشعة\s*للظهر|اشعه\s*صدر|أشعة\s*صدر|'
      r'حسب\s*الدليل|شنو\s*يقول\s*الدليل)',
    ).hasMatch(n);
  }

  Future<ClinicalKnowledgeMatch> query(ClinicalKnowledgeQuery q) async {
    try {
      if (q.hasMedicalRedFlag) {
        return const ClinicalKnowledgeMatch(
          deferToMedicalSafety: true,
          matchedRuleCount: 0,
        );
      }
      // تجاوز تجاري مرفوض — لا يغيّر القرار
      final effective = ClinicalKnowledgeQuery(
        topic: q.topic,
        domain: q.domain,
        symptomKeys: q.symptomKeys,
        knownDiagnosisKeys: q.knownDiagnosisKeys,
        severity: q.severity,
        functionalImpact: q.functionalImpact,
        contextTags: q.contextTags,
        coughDuration: q.coughDuration,
        hasMedicalRedFlag: q.hasMedicalRedFlag,
        sponsorOverrideRequested: false,
        paidPackageOverrideRequested: false,
        inferPregnancyFromDemographics: q.inferPregnancyFromDemographics,
      );

      if (effective.inferPregnancyFromDemographics) {
        return const ClinicalKnowledgeMatch(matchedRuleCount: 0);
      }

      final list = await _retriever.retrieve(effective);
      if (list.isEmpty) return ClinicalKnowledgeMatch(matchedRuleCount: 0);

      final best = list.first;
      final imaging = best.imaging;
      final handoff = imaging != null &&
          imaging.allowsServiceHandoff &&
          (imaging.appropriateness ==
                  ClinicalImagingAppropriateness.usuallyAppropriate ||
              imaging.appropriateness ==
                  ClinicalImagingAppropriateness.mayBeAppropriate);

      final match = ClinicalKnowledgeMatch(
        rule: best,
        matchedRuleCount: list.length,
        allowsRadiologyHandoff: handoff,
      );
      return ClinicalKnowledgeMatch(
        rule: match.rule,
        matchedRuleCount: match.matchedRuleCount,
        allowsRadiologyHandoff: match.allowsRadiologyHandoff,
        message: _responses.build(match),
      );
    } catch (_) {
      return const ClinicalKnowledgeMatch(success: false);
    }
  }

  /// تقييم تصوير لموضوع — للاختبارات والمسارات الآمنة.
  Future<ClinicalImagingGuidance?> evaluateImaging({
    required ClinicalKnowledgeTopic topic,
    Set<String> contextTags = const {},
    List<String> symptomKeys = const [],
    List<String> knownDiagnosisKeys = const [],
    ClinicalCoughDurationClass? coughDuration,
    bool hasMedicalRedFlag = false,
    bool sponsorOverride = false,
    bool paidPackageOverride = false,
  }) async {
    // الراعي لا يغيّر النتيجة: نتجاهل طلب التجاوز ونقيّم سريرياً
    final match = await query(
      ClinicalKnowledgeQuery(
        topic: topic,
        symptomKeys: symptomKeys,
        knownDiagnosisKeys: knownDiagnosisKeys,
        contextTags: contextTags,
        coughDuration: coughDuration,
        hasMedicalRedFlag: hasMedicalRedFlag,
        sponsorOverrideRequested: sponsorOverride,
        paidPackageOverrideRequested: paidPackageOverride,
      ),
    );
    if (match.deferToMedicalSafety) return null;
    return match.rule?.imaging;
  }

  Future<ClinicalKnowledgeTurnResult> handle({
    required String text,
    required ClinicalKnowledgeSession session,
    bool urgentMedicalHint = false,
  }) async {
    try {
      if (_mentalSafety.triggersCrisis(text)) {
        return ClinicalKnowledgeTurnResult(
          handled: false,
          message: '',
          session: session,
          deferToMentalSafety: true,
        );
      }
      if (urgentMedicalHint) {
        return ClinicalKnowledgeTurnResult(
          handled: false,
          message: '',
          session: session,
          deferToMedicalSafety: true,
        );
      }

      final q = _interpretQuery(text);
      final match = await query(q);
      if (match.deferToMedicalSafety) {
        return ClinicalKnowledgeTurnResult(
          handled: false,
          message: '',
          session: session.copyWith(lastMatch: match, active: true),
          deferToMedicalSafety: true,
          match: match,
        );
      }
      if (match.rule == null) {
        return ClinicalKnowledgeTurnResult.notHandled(session);
      }

      var msg = match.message;
      if (_responses.claimsDiagnosis(msg) ||
          _responses.claimsFakeAvailability(msg)) {
        msg = 'توجيه عام مختصر حسب قاعدة مراجَعة — ناقش مع مختص عند الحاجة.';
      }

      return ClinicalKnowledgeTurnResult(
        handled: true,
        message: msg,
        session: session.copyWith(lastMatch: match, active: true),
        match: match,
        textFirstOnly: true,
      );
    } catch (_) {
      return ClinicalKnowledgeTurnResult(
        handled: false,
        message: '',
        session: session,
        success: false,
      );
    }
  }

  ClinicalKnowledgeQuery _interpretQuery(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    final tags = <String>{};
    var topic = ClinicalKnowledgeTopic.generalClinical;
    final symptoms = <String>[];
    final diagnoses = <String>[];
    ClinicalCoughDurationClass? coughDur;

    if (RegExp(r'(?:ظهر|ضهر|اسفل\s*الظهر)').hasMatch(n)) {
      topic = ClinicalKnowledgeTopic.lowBackPain;
      symptoms.add('low_back_pain');
    }
    if (RegExp(r'(?:رقبه|رقبة|عنق)').hasMatch(n)) {
      topic = ClinicalKnowledgeTopic.neckPain;
      symptoms.add('neck_pain');
    }
    if (RegExp(r'ركبه|ركبة').hasMatch(n)) {
      topic = ClinicalKnowledgeTopic.kneePain;
      symptoms.add('knee_pain');
    }
    if (RegExp(r'(?:كحه|كحة|سعال)').hasMatch(n)) {
      if (RegExp(r'(?:مزمن|مستمر|هواي\s*ايام|اسابيع|أسابيع)').hasMatch(n)) {
        topic = ClinicalKnowledgeTopic.chronicCough;
        coughDur = ClinicalCoughDurationClass.chronic;
        tags.add('duration_chronic');
        symptoms.add('chronic_cough');
      } else {
        topic = ClinicalKnowledgeTopic.acuteCough;
        coughDur = ClinicalCoughDurationClass.acute;
        symptoms.add('cough');
      }
    }
    if (RegExp(r'سكري').hasMatch(n)) {
      topic = ClinicalKnowledgeTopic.diabetesRoutineCare;
      diagnoses.add('diabetes');
    }
    if (RegExp(r'(?:حمل|حامل)').hasMatch(n) &&
        RegExp(r'(?:انا|إني|اني)\s*(?:حامل|بي\s*حمل)|اكد|أكد|مثبت')
            .hasMatch(n)) {
      tags.add('explicit_pregnancy_confirmed');
      topic = ClinicalKnowledgeTopic.pregnancyRoutineCare;
    }

    return ClinicalKnowledgeQuery(
      topic: topic,
      symptomKeys: symptoms,
      knownDiagnosisKeys: diagnoses,
      contextTags: tags,
      coughDuration: coughDur,
    );
  }

  /// حدود ثابتة للاختبارات.
  bool createsSecondEmergencyEngine() => false;
  bool replacesMentalHealthAuthority() => false;
  bool replacesChronicCareAuthority() => false;
  bool autoCreatesFollowUp() => false;
  bool storesPatientRecordsInCatalog() => false;
  bool mayInferPregnancyFromAgeOrSex() => false;
  bool wellbeingPlannerMayReinterpretRules() => false;
  bool dailyContextMayAlterEvidence() => false;
}
