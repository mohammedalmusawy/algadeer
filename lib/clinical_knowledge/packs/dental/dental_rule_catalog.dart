import '../../clinical_knowledge_models.dart';
import 'dental_models.dart';

class DentalClinicalRule {
  const DentalClinicalRule({
    required this.ruleId,
    required this.topic,
    required this.evidence,
    required this.reviewedAt,
    required this.freshness,
    required this.clinicalReviewRequired,
    required this.isActive,
    this.arabicGuidance = '',
    this.urgency = DentalUrgency.dentalReview,
    this.imaging,
    this.priority = 50,
    this.forTrauma = false,
    this.forAntibioticStewardship = false,
    this.forPrevention = false,
    this.primaryToothOnly = false,
    this.permanentToothOnly = false,
    this.minPersistenceDays,
  });

  final String ruleId;
  final DentalTopic topic;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final String arabicGuidance;
  final DentalUrgency urgency;
  final ClinicalImagingGuidance? imaging;
  final int priority;
  final bool forTrauma;
  final bool forAntibioticStewardship;
  final bool forPrevention;
  final bool primaryToothOnly;
  final bool permanentToothOnly;
  final int? minPersistenceDays;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

class DentalRuleCatalog {
  DentalRuleCatalog({List<DentalClinicalRule>? rules})
      : _rules = rules ?? activeRules;

  final List<DentalClinicalRule> _rules;
  static final DateTime _reviewed = DateTime(2026, 3, 1);

  /// عتبات مركزية — ملكية الكتالوج فقط.
  static const int oralLesionPersistenceDays = 14;
  static const int avulsionUrgentWindowMinutes = 60;
  static const int childAgeUnknownTreatConservatively = 1;

  static final List<DentalClinicalRule> activeRules = [
    DentalClinicalRule(
      ruleId: 'dental_ada_pain_definitive_care',
      topic: DentalTopic.toothPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Acute dental pain — definitive dental treatment',
        sourceReference: 'ADA dental pain / acute care guidance',
        sourceVersionOrDate: 'ADA',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 90,
      urgency: DentalUrgency.dentalReview,
      arabicGuidance:
          'ألم السن مو تشخيص بحد ذاته. غالباً يحتاج تقييم طبيب أسنان لتحديد السبب. '
          'ما نقرر من المحادثة إن العلاج حشو أو عصب أو خلع.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_ada_antibiotic_stewardship',
      topic: DentalTopic.antibioticQuestion,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Antibiotic stewardship in dentistry',
        sourceReference: 'ADA antibiotic stewardship / dental pain & swelling',
        sourceVersionOrDate: 'ADA stewardship',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 95,
      forAntibioticStewardship: true,
      urgency: DentalUrgency.dentalReview,
      arabicGuidance:
          'كثير من آلام الأسنان لا تتحسن بالمضاد وحده؛ العلاج السببي عند طبيب الأسنان هو الأساس. '
          'المضاد يقرره الطبيب عند وجود مبرر سريري — ما نبدأ أموكسيسيلين/مترونيدازول من هنا، '
          'وما ننصح ببقايا مضاد.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_facial_swelling_urgent_path',
      topic: DentalTopic.facialSwelling,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Dental infection with facial swelling — urgent assessment',
        sourceReference: 'ADA acute dental infection principles',
        sourceVersionOrDate: 'ADA',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 96,
      urgency: DentalUrgency.urgentDentalReview,
      arabicGuidance:
          'تورم الوجه المرتبط بالسن يحتاج تقييماً عاجلاً وليس انتظاراً مفتوحاً. '
          'ما نشخّص خراج/التهاب نسيج من الشات.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_iadt_avulsion_permanent',
      topic: DentalTopic.lostTooth,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'IADT',
        sourceTitle: 'Avulsed permanent tooth — urgent dental care',
        sourceReference: 'IADT dental trauma guidelines (endorsed pathway)',
        sourceVersionOrDate: 'IADT',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 98,
      forTrauma: true,
      permanentToothOnly: true,
      urgency: DentalUrgency.urgentDentalReview,
      arabicGuidance:
          'سن دائم مخلوع حالة حسّاسة زمنياً وتحتاج رعاية أسنان عاجلة حسب دليل الرضوض. '
          'التفاصيل الإجرائية عند المختص — وما نخلطها مع السن اللبني.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_aapd_avulsion_primary',
      topic: DentalTopic.lostTooth,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'AAPD',
        sourceTitle: 'Avulsed primary tooth — do not replant pathway',
        sourceReference: 'AAPD / IADT primary tooth trauma principles',
        sourceVersionOrDate: 'AAPD',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 97,
      forTrauma: true,
      primaryToothOnly: true,
      urgency: DentalUrgency.promptDentalReview,
      arabicGuidance:
          'السن اللبني المخلوع يُدار بخلاف الدائم؛ لا تُطبَّق تعليمات إعادة الزرع الخاصة بالدائم. '
          'راجعِ طبيب أسنان أطفال/أسنان عاجلاً حسب السياق.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_trauma_type_unknown_clarify',
      topic: DentalTopic.dentalTrauma,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'IADT',
        sourceTitle: 'Trauma management depends on primary vs permanent',
        sourceReference: 'IADT tooth type distinction',
        sourceVersionOrDate: 'IADT',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 94,
      forTrauma: true,
      urgency: DentalUrgency.promptDentalReview,
      arabicGuidance:
          'نوع السن (لبني/دائم) يغيّر المسار. إذا ما نعرف، نوضح بسؤال واحد ثم توجيه عاجل مناسب.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_imaging_not_routine_toothache',
      topic: DentalTopic.dentalImagingQuestion,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Dental imaging — clinical need first',
        sourceReference: 'ADA imaging appropriateness principles',
        sourceVersionOrDate: 'ADA imaging',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      urgency: DentalUrgency.dentalReview,
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'dentistDirectedIntraoral',
        allowsServiceHandoff: true,
      ),
      arabicGuidance:
          'أشعة الأسنان قرار سريري بعد تقييم؛ ألم السن وحده لا يفرض بانوراما تلقائياً. '
          'توفر خدمة الأشعة بالغدير لا يزيد الحاجة الطبية.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_cdc_pregnancy_dental_care',
      topic: DentalTopic.pregnancyDentalConcern,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'CDC',
        sourceTitle: 'Oral health care during pregnancy',
        sourceReference: 'CDC oral health / pregnancy resources',
        sourceVersionOrDate: 'CDC',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 92,
      urgency: DentalUrgency.dentalReview,
      arabicGuidance:
          'الحمل لا يبرر تأجيل علاج السن تلقائياً. الرعاية الروتينية والطارئة مهمة؛ '
          'الدواء/الأشعة تُناقش مع الطبيبة وطبيب الأسنان — بلا منع مبسّط لكل الأشعة.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_prevention_hygiene_fluoride',
      topic: DentalTopic.oralHygiene,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Caries prevention — hygiene and fluoride toothpaste',
        sourceReference: 'ADA preventive oral health',
        sourceVersionOrDate: 'ADA prevention',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 70,
      forPrevention: true,
      urgency: DentalUrgency.selfCarePlusRoutineDental,
      arabicGuidance:
          'تنظيف مرتين بمعجون فلورايد، وتنظيف بين الأسنان حسب التحمّل، وتقليل السكريات المتكررة '
          'مفيد عملياً. ما نختلق حالة فلورة مياه العراق ولا نوصي بمنتجات عالية التركيز.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_oral_lesion_persistence',
      topic: DentalTopic.oralLesion,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Persistent oral lesions need evaluation',
        sourceReference: 'ADA oral pathology referral principles',
        sourceVersionOrDate: 'ADA',
        evidenceType: ClinicalEvidenceType.professionalStandard,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 91,
      minPersistenceDays: oralLesionPersistenceDays,
      urgency: DentalUrgency.promptDentalReview,
      arabicGuidance:
          'آفة فموية مستمرة/غير مفسَّرة تستحق تقييماً مهنياً. '
          'ما نشخّص سرطاناً وما نطمْئن بطمأنة مطلقة.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_gum_bleeding_no_stop_brushing',
      topic: DentalTopic.gumBleeding,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Gingival bleeding — continue hygiene + dental review',
        sourceReference: 'ADA periodontal health principles',
        sourceVersionOrDate: 'ADA',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 80,
      urgency: DentalUrgency.dentalReview,
      arabicGuidance:
          'نزف اللثة مع التفريش شائع كملاحظة؛ لا يعني تشخيص التهاب لثة/نسج تلقائياً، '
          'وما نوقف التفريش بسبب النزف. راجعِ طبيب الأسنان إن استمر.',
    ),
    DentalClinicalRule(
      ruleId: 'dental_incomplete_inactive',
      topic: DentalTopic.unknown,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'pending',
        sourceTitle: 'placeholder',
        sourceReference: 'pending',
        sourceVersionOrDate: 'pending',
        evidenceType: ClinicalEvidenceType.other,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      clinicalReviewRequired: true,
      isActive: false,
      priority: 1,
      arabicGuidance: 'غير نشطة',
    ),
  ];

  List<DentalClinicalRule> get all => List.unmodifiable(_rules);
  List<DentalClinicalRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  DentalClinicalRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }

  DentalClinicalRule? bestFor(DentalSession session) {
    final c = <DentalClinicalRule>[];
    for (final r in active) {
      if (r.primaryToothOnly && session.toothType != DentalToothType.primary) {
        continue;
      }
      if (r.permanentToothOnly &&
          session.toothType != DentalToothType.permanent) {
        continue;
      }
      if (r.forTrauma &&
          session.trauma == DentalTraumaKind.none &&
          session.topic != DentalTopic.lostTooth &&
          session.topic != DentalTopic.dentalTrauma &&
          session.topic != DentalTopic.brokenTooth) {
        continue;
      }
      if (r.topic == session.topic ||
          (r.forAntibioticStewardship &&
              session.topic == DentalTopic.antibioticQuestion) ||
          (r.forPrevention &&
              (session.topic == DentalTopic.oralHygiene ||
                  session.topic == DentalTopic.educationOnly))) {
        c.add(r);
      }
    }
    c.sort((a, b) => b.priority.compareTo(a.priority));
    return c.isEmpty ? null : c.first;
  }
}
