import '../../clinical_knowledge_models.dart';
import 'pregnancy_models.dart';

/// قاعدة حمل — عتبات الأسابيع مركزية هنا فقط.
class PregnancyEvidenceRule {
  const PregnancyEvidenceRule({
    required this.ruleId,
    required this.careItem,
    required this.evidence,
    required this.reviewedAt,
    required this.freshness,
    required this.clinicalReviewRequired,
    required this.isActive,
    this.arabicGuidance = '',
    this.minGestationalWeek,
    this.maxGestationalWeek,
    this.priority = 50,
  });

  final String ruleId;
  final PregnancyCareItem careItem;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final String arabicGuidance;
  final int? minGestationalWeek;
  final int? maxGestationalWeek;
  final int priority;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

class PregnancyEvidenceCatalog {
  PregnancyEvidenceCatalog({List<PregnancyEvidenceRule>? rules})
      : _rules = rules ?? activeRules;

  final List<PregnancyEvidenceRule> _rules;
  static final DateTime _reviewed = DateTime(2026, 3, 1);

  /// عتبات مراحل — ملكية الكتالوج.
  static const int firstTrimesterEndExclusive = 14;
  static const int secondTrimesterEndExclusive = 28;
  static const int termStartWeek = 37;
  static const int anatomyWindowStartWeek = 18;
  static const int anatomyWindowEndWeek = 22;
  static const int gdmScreenStartWeek = 24;
  static const int gdmScreenEndWeek = 28;
  static const int ultrasoundBeforeWeek = 24;
  static const int fetalMovementConcernMinWeek = 24;

  static final List<PregnancyEvidenceRule> activeRules = [
    PregnancyEvidenceRule(
      ruleId: 'preg_who_anc_contacts_foundation',
      careItem: PregnancyCareItem.antenatalContact,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Antenatal care for a positive pregnancy experience',
        sourceReference: 'WHO ANC recommendations',
        sourceVersionOrDate: 'WHO ANC',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 90,
      arabicGuidance:
          'متابعة الحمل المنتظمة مهمة. التوقيت المحلي والتنفيذ يحددهما طبيبتك/النظام الصحي — '
          'الدليل الدولي لا يساوي موعداً تلقائياً في الغدير.',
    ),
    PregnancyEvidenceRule(
      ruleId: 'preg_ultrasound_before_24w_purpose',
      careItem: PregnancyCareItem.ultrasoundDating,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Ultrasound before 24 weeks — dating/anatomy purposes',
        sourceReference: 'WHO antenatal ultrasound recommendations',
        sourceVersionOrDate: 'WHO US',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      maxGestationalWeek: ultrasoundBeforeWeek,
      arabicGuidance:
          'السونار قبل حوالي 24 أسبوعاً قد يُدعم لأغراض تأريخ/تقييم وفق الدليل — '
          'ليس تبريراً لتكرار عشوائي، وليس لأن الخدمة متوفرة بالغدير.',
    ),
    PregnancyEvidenceRule(
      ruleId: 'preg_anatomy_assessment_window',
      careItem: PregnancyCareItem.fetalAnatomyAssessment,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Fetal anatomy assessment window',
        sourceReference: 'WHO/professional ANC ultrasound timing principles',
        sourceVersionOrDate: 'ANC US timing',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 86,
      minGestationalWeek: anatomyWindowStartWeek,
      maxGestationalWeek: anatomyWindowEndWeek,
      arabicGuidance:
          'تقييم التشريح الجنيني عادة ضمن نافذة مراجَعة — التنفيذ حسب خطة الطبيبة.',
    ),
    PregnancyEvidenceRule(
      ruleId: 'preg_gdm_screening_window_ada2026',
      careItem: PregnancyCareItem.gestationalDiabetesScreening,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Gestational diabetes screening in pregnancy',
        sourceReference: 'ADA Standards of Care in Diabetes — 2026 pregnancy',
        sourceVersionOrDate: '2026',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 87,
      minGestationalWeek: gdmScreenStartWeek,
      maxGestationalWeek: gdmScreenEndWeek,
      arabicGuidance:
          'فحص سكر الحمل له نافذة دليلية — قراءة سكر واحدة لا تشخّص سكر حمل. '
          'قواعد البالغين غير الحوامل من PC-1.20 لا تُطبَّق عمياء هنا.',
    ),
    PregnancyEvidenceRule(
      ruleId: 'preg_nutrition_who',
      careItem: PregnancyCareItem.nutritionReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Maternal nutrition in pregnancy',
        sourceReference: 'WHO maternal nutrition guidance',
        sourceVersionOrDate: 'WHO nutrition',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 70,
      arabicGuidance:
          'تغذية متنوعة وآمنة أفضل من قواعد صارمة أو تخسيس. المكملات حسب خطة الطبيبة — بلا أعشاب/جرعات عشوائية.',
    ),
    PregnancyEvidenceRule(
      ruleId: 'preg_activity_context',
      careItem: PregnancyCareItem.physicalActivityReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Physical activity in pregnancy — context aware',
        sourceReference: 'WHO activity / ANC wellbeing principles',
        sourceVersionOrDate: 'WHO activity',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 68,
      arabicGuidance:
          'المشي/نشاط مناسب قد يكون معقولاً إن لم تكن هناك قيود طبية أو علامات خطر — '
          'سلطة النشاط العامة تبقى PC-1.14.',
    ),
    PregnancyEvidenceRule(
      ruleId: 'preg_incomplete_inactive',
      careItem: PregnancyCareItem.vaccinationReview,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'pending',
        sourceTitle: 'Local vaccination schedule placeholder',
        sourceReference: 'pending',
        sourceVersionOrDate: 'pending',
        evidenceType: ClinicalEvidenceType.other,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      clinicalReviewRequired: true,
      isActive: false,
      priority: 1,
      arabicGuidance: 'غير نشطة — بلا اختراع جدول تطعيم عراقي.',
    ),
  ];

  List<PregnancyEvidenceRule> get all => List.unmodifiable(_rules);
  List<PregnancyEvidenceRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  PregnancyEvidenceRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }

  PregnancyEvidenceRule? forCareItem(PregnancyCareItem item) {
    for (final r in active) {
      if (r.careItem == item) return r;
    }
    return null;
  }
}
