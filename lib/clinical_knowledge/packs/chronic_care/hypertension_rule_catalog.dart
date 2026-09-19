import '../../clinical_knowledge_models.dart';
import 'chronic_care_models.dart';

/// قاعدة ضغط — عتبات رقمية مركزية هنا فقط.
class HypertensionClinicalRule {
  const HypertensionClinicalRule({
    required this.ruleId,
    required this.careItem,
    required this.evidence,
    required this.reviewedAt,
    required this.freshness,
    required this.clinicalReviewRequired,
    required this.isActive,
    this.arabicGuidance = '',
    this.systolicElevatedThreshold,
    this.diastolicElevatedThreshold,
    this.systolicSevereThreshold,
    this.priority = 50,
  });

  final String ruleId;
  final HypertensionCareItem careItem;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final String arabicGuidance;
  final int? systolicElevatedThreshold;
  final int? diastolicElevatedThreshold;
  final int? systolicSevereThreshold;
  final int priority;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

class HypertensionRuleCatalog {
  HypertensionRuleCatalog({List<HypertensionClinicalRule>? rules})
      : _rules = rules ?? activeRules;

  final List<HypertensionClinicalRule> _rules;
  static final DateTime _reviewed = DateTime(2026, 3, 1);

  /// عتبات 2025 AHA/ACC — في الكتالوج فقط.
  static const int systolicElevated = 130;
  static const int diastolicElevated = 80;
  static const int systolicStage2 = 140;
  static const int diastolicStage2 = 90;
  static const int systolicSevereConcern = 180;

  static final List<HypertensionClinicalRule> activeRules = [
    HypertensionClinicalRule(
      ruleId: 'htn_classification_aha_acc_2025',
      careItem: HypertensionCareItem.clinicalConfirmation,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'AHA/ACC',
        sourceTitle: '2025 Guideline for High Blood Pressure in Adults',
        sourceReference: '2025 AHA/ACC High Blood Pressure Guideline',
        sourceVersionOrDate: '2025',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 90,
      systolicElevatedThreshold: systolicElevated,
      diastolicElevatedThreshold: diastolicElevated,
      systolicSevereThreshold: systolicSevereConcern,
      arabicGuidance:
          'تصنيف ضغط الدم وتعريفه المزمن يعتمدان على الدليل والمقاييس المتكررة — '
          'قراءة منزلية واحدة لا تكفي عادةً لتأكيد ضغط مزمن. '
          'الهدف الشخصي ليس موحّداً للجميع.',
    ),
    HypertensionClinicalRule(
      ruleId: 'htn_home_measurement_technique',
      careItem: HypertensionCareItem.measurementQuality,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'AHA/ACC',
        sourceTitle: 'Home BP measurement quality',
        sourceReference: '2025 AHA/ACC — out-of-office measurement principles',
        sourceVersionOrDate: '2025',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 85,
      arabicGuidance:
          'قياس منزلي أفضل بجهاز عضد آلي موثّق وكفة مناسبة، بعد راحة قصيرة، '
          'جلسة مستقيمة، قدمين على الأرض، ذراع مدعوم، بدون كلام أثناء القياس، '
          'مع تكرار القراءات حسب البروتوكول المراجَع وتسجيلها لمناقشة الطبيب. '
          'قياس الساعة الذكية/بدون كفة لا يُعامل كمكافئ لكفة موثّقة.',
    ),
    HypertensionClinicalRule(
      ruleId: 'htn_single_high_recheck',
      careItem: HypertensionCareItem.homeMonitoring,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'AHA/ACC',
        sourceTitle: 'Unexpected high home reading — recheck / quality',
        sourceReference: '2025 AHA/ACC measurement and confirmation principles',
        sourceVersionOrDate: '2025',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      systolicElevatedThreshold: systolicStage2,
      diastolicElevatedThreshold: diastolicStage2,
      arabicGuidance:
          'قراءة مرتفعة مرة واحدة تستحق إعادة قياس بهدوء وجودة — '
          'بلا ذعر تلقائي وبلا طمأنة زائفة للقراءات المقلقة مع أعراض.',
    ),
    HypertensionClinicalRule(
      ruleId: 'htn_no_routine_chest_xray',
      careItem: HypertensionCareItem.followUpReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'AHA/ACC',
        sourceTitle: 'No routine chest X-ray for hypertension alone',
        sourceReference: 'HTN care — imaging not routine for HTN alone',
        sourceVersionOrDate: '2025',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 40,
      arabicGuidance: 'الضغط وحده لا يستدعي صورة صدر روتينية.',
    ),
    HypertensionClinicalRule(
      ruleId: 'htn_incomplete_evidence_inactive',
      careItem: HypertensionCareItem.followUpReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'pending',
        sourceTitle: 'Incomplete HTN placeholder',
        sourceReference: 'pending',
        sourceVersionOrDate: 'pending',
        evidenceType: ClinicalEvidenceType.other,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      clinicalReviewRequired: true,
      isActive: false,
      priority: 1,
      arabicGuidance: 'غير نشطة.',
    ),
  ];

  List<HypertensionClinicalRule> get all => List.unmodifiable(_rules);
  List<HypertensionClinicalRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  HypertensionClinicalRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }
}
