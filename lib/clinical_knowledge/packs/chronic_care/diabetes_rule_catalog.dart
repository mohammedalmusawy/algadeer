import '../../clinical_knowledge_models.dart';
import 'chronic_care_models.dart';

/// قاعدة سكري — عتبات رقمية مركزية هنا فقط.
class DiabetesClinicalRule {
  const DiabetesClinicalRule({
    required this.ruleId,
    required this.careItem,
    required this.evidence,
    required this.reviewedAt,
    required this.freshness,
    required this.clinicalReviewRequired,
    required this.isActive,
    this.arabicGuidance = '',
    this.intervalMonthsStable,
    this.intervalMonthsUnstable,
    this.type1MinDurationYears,
    this.appliesToType1 = true,
    this.appliesToType2 = true,
    this.adultNonPregnantOnly = true,
    this.priority = 50,
  });

  final String ruleId;
  final DiabetesCareItem careItem;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final String arabicGuidance;
  final int? intervalMonthsStable;
  final int? intervalMonthsUnstable;
  final int? type1MinDurationYears;
  final bool appliesToType1;
  final bool appliesToType2;
  final bool adultNonPregnantOnly;
  final int priority;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

class DiabetesRuleCatalog {
  DiabetesRuleCatalog({List<DiabetesClinicalRule>? rules})
      : _rules = rules ?? activeRules;

  final List<DiabetesClinicalRule> _rules;
  static final DateTime _reviewed = DateTime(2026, 3, 1);

  /// عتبات ADA 2026 — ملكية الكتالوج لا المفسّر.
  static const int hba1cStableIntervalMonths = 6;
  static const int hba1cUnstableIntervalMonths = 3;
  static const int type1KidneyScreenMinYears = 5;
  static const int eyeScreenDefaultMonths = 12;
  static const int footScreenDefaultMonths = 12;
  static const double exampleA1cGeneralPercent = 7.0; // تعليمي عام فقط

  static final List<DiabetesClinicalRule> activeRules = [
    DiabetesClinicalRule(
      ruleId: 'dm_hba1c_assessment_interval_ada2026',
      careItem: DiabetesCareItem.glycemicAssessment,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Standards of Care in Diabetes — Glycemic Goals / Assessment',
        sourceReference: 'ADA Standards of Care in Diabetes — 2026',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 90,
      intervalMonthsStable: hba1cStableIntervalMonths,
      intervalMonthsUnstable: hba1cUnstableIntervalMonths,
      arabicGuidance:
          'تقييم سكر الدم (مثل التراكمي) يُراجع وفق الدليل على الأقل مرتين سنوياً '
          'عند الاستقرار، وأقرب عند عدم بلوغ الهدف أو تغيّر العلاج أو عدم الاستقرار — '
          'وليس هدفاً شخصياً موحّداً للجميع.',
    ),
    DiabetesClinicalRule(
      ruleId: 'dm_kidney_uacr_egfr_ada2026',
      careItem: DiabetesCareItem.kidneyAssessment,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'CKD and Risk Management — UACR and eGFR',
        sourceReference: 'ADA Standards of Care in Diabetes — 2026 CKD',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      type1MinDurationYears: type1KidneyScreenMinYears,
      arabicGuidance:
          'متابعة الكلى تشمل عادة نسبة الألبومين إلى الكرياتينين بالبول (UACR) '
          'وتقدير الترشيح الكبيبي (eGFR). '
          'لمرض النوع الثاني قد تبدأ من التشخيص؛ وللنوع الأول تعتمد على مدة المرض حسب الدليل. '
          'نتيجة واحدة غير طبيعية لا تشخّص اعتلال كلى سكري.',
    ),
    DiabetesClinicalRule(
      ruleId: 'dm_eye_screening_ada2026',
      careItem: DiabetesCareItem.eyeAssessment,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Retinopathy screening timing by diabetes type',
        sourceReference: 'ADA Standards of Care in Diabetes — 2026 Retinopathy',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 87,
      intervalMonthsStable: eyeScreenDefaultMonths,
      arabicGuidance:
          'فحص العين/الشبكية توقيته يعتمد على نوع السكري والنتائج السابقة — '
          'ليس قاعدة «كل سنة للأبد» بلا سياق. الوجهة دلالية: طب عيون.',
    ),
    DiabetesClinicalRule(
      ruleId: 'dm_foot_evaluation_ada2026',
      careItem: DiabetesCareItem.footAssessment,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Comprehensive foot evaluation',
        sourceReference: 'ADA Standards of Care in Diabetes — 2026 Foot Care',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 86,
      intervalMonthsStable: footScreenDefaultMonths,
      arabicGuidance:
          'تقييم القدم الشامل جزء من المتابعة. التنميل وحده لا يشخّص اعتلال أعصاب. '
          'جرح القدم يرفع أولوية المراجعة — بلا أشعة قدم تلقائية.',
    ),
    DiabetesClinicalRule(
      ruleId: 'dm_cv_lipid_lifestyle_ada2026',
      careItem: DiabetesCareItem.cardiovascularRiskAssessment,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'CVD and Risk Management',
        sourceReference: 'ADA Standards of Care in Diabetes — 2026 CVD',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 80,
      arabicGuidance:
          'رعاية السكري تشمل ضغط الدم والدهون والتدخين والنشاط — '
          'بلا حساب نسبة ASCVD/PREVENT مخترعة وبلا بدء ستاتين من الشات.',
    ),
    DiabetesClinicalRule(
      ruleId: 'dm_no_routine_chest_xray',
      careItem: DiabetesCareItem.generalClinicalReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'No routine chest imaging for diabetes alone',
        sourceReference: 'ADA comprehensive care — imaging not routine for DM alone',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 40,
      arabicGuidance: 'السكري وحده لا يستدعي صورة صدر روتينية.',
    ),
    DiabetesClinicalRule(
      ruleId: 'dm_incomplete_evidence_inactive',
      careItem: DiabetesCareItem.vaccinationReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'pending',
        sourceTitle: 'Incomplete vaccination engine placeholder',
        sourceReference: 'pending',
        sourceVersionOrDate: 'pending',
        evidenceType: ClinicalEvidenceType.other,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      clinicalReviewRequired: true,
      isActive: false,
      priority: 1,
      arabicGuidance: 'غير نشطة — بلا اختراع توفر لقاح محلي.',
    ),
  ];

  List<DiabetesClinicalRule> get all => List.unmodifiable(_rules);
  List<DiabetesClinicalRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  DiabetesClinicalRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }

  DiabetesClinicalRule? forCareItem(DiabetesCareItem item) {
    for (final r in active) {
      if (r.careItem == item) return r;
    }
    return null;
  }
}
