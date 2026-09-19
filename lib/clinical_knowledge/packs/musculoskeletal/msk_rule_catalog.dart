import '../../clinical_knowledge_models.dart';
import 'msk_models.dart';

/// قاعدة MSK منظّمة — فوق نموذج PC-1.17.
class MskClinicalRule {
  const MskClinicalRule({
    required this.ruleId,
    required this.topic,
    required this.evidence,
    required this.reviewedAt,
    required this.freshness,
    required this.clinicalReviewRequired,
    required this.isActive,
    this.imaging,
    this.actions = const [],
    this.destinations = const [],
    this.arabicGuidance = '',
    this.requiresTrauma = false,
    this.requiresKnownOa = false,
    this.requiresKnownDisc = false,
    this.requiresUnableToBearWeight = false,
    this.forEducationOnly = false,
    this.priority = 50,
  });

  final String ruleId;
  final MskTopic topic;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final ClinicalImagingGuidance? imaging;
  final List<ClinicalGuidanceAction> actions;
  final List<ClinicalCareDestinationHint> destinations;
  final String arabicGuidance;
  final bool requiresTrauma;
  final bool requiresKnownOa;
  final bool requiresKnownDisc;
  final bool requiresUnableToBearWeight;
  final bool forEducationOnly;
  final int priority;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

/// كتalog قواعد MSK مراجَعة — data-driven.
class MskRuleCatalog {
  MskRuleCatalog({List<MskClinicalRule>? rules}) : _rules = rules ?? activeRules;

  final List<MskClinicalRule> _rules;

  static final DateTime _reviewed = DateTime(2026, 3, 1);

  static final List<MskClinicalRule> activeRules = [
    MskClinicalRule(
      ruleId: 'msk_lbp_nonspecific_no_routine_xray',
      topic: MskTopic.lowBackPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Low back pain and sciatica — imaging not routine',
        sourceReference: 'NICE NG59 / imaging principles',
        sourceVersionOrDate: '2020',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 90,
      arabicGuidance:
          'لألم أسفل الظهر غير المعقّد بدون علامات خطر: '
          'الأنسب غالباً تعديل النشاط والحركة حسب التحمّل، '
          'مو راحة سريرية طويلة، والتصوير الشعاعي مو روتيني تلقائي.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'nonspecificLbpNoRoutineXray',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'activityMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.continueActivityAsTolerated,
          reasonCode: 'activityAsTolerated',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.relativeRest,
          reasonCode: 'relativeRestNotBedRest',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.physiotherapyDiscussion,
          reasonCode: 'physioIfPersistent',
          optional: true,
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifPersistentOrLimiting',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.selfCare,
          reasonCode: 'initial',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.physiotherapy,
          reasonCode: 'physioOptional',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gpIfNeeded',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_radiating_no_auto_disc_dx',
      topic: MskTopic.radiatingLimbPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Sciatica symptoms — assessment before labelling',
        sourceReference: 'NICE NG59 sciatica pathway principles',
        sourceVersionOrDate: '2020',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      arabicGuidance:
          'امتداد الألم للرجل عرض يحتاج توضيحاً، '
          'وما يعني تلقائياً تشخيص انزلاق غضروفي أو عرق نسا بدون تقييم سريري.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.mri,
        reasonCode: 'radiatingNeedsClinicalContext',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'neuroContext',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_known_disc_current_symptoms',
      topic: MskTopic.knownDiscDisease,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Known disc disease — current symptom reassessment',
        sourceReference: 'NICE NG59 known pathology principles',
        sourceVersionOrDate: '2020',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      requiresKnownDisc: true,
      priority: 85,
      arabicGuidance:
          'فهمت إن عندك تشخيص انزلاق غضروفي مذكور مسبقاً. '
          'الأعراض الحالية ما زالت تحتاج تقييماً سياقياً، '
          'وما نفترض إن كل ألم ظهر لاحق سببه نفس التشخيص، '
          'وما نغيّر أدويتك أو نصف معالجة يدوية للعمود.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.mri,
        reasonCode: 'knownDiscNeedsCurrentAssessment',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'reassess',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'modActivity',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_neck_nonspecific_no_auto_xray',
      topic: MskTopic.neckPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Cervical pain — imaging not automatic',
        sourceReference: 'ACR AC Cervical Neck Pain',
        sourceVersionOrDate: '2021',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 80,
      arabicGuidance:
          'ألم الرقبة غير الرضّي غير المعقّد: التصوير مو تلقائي. '
          'تعديل النشاط ومراجعة سريرية عند استمرار الألم أو وجود أعراض عصبية.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'nonspecificNeckNoRoutineXray',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'neckMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifNeuroOrPersistent',
          optional: true,
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_neck_trauma_pathway',
      topic: MskTopic.neckPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Traumatic cervical pain — clinical assessment first',
        sourceReference: 'ACR AC Cervical trauma principles',
        sourceVersionOrDate: '2021',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      requiresTrauma: true,
      priority: 92,
      arabicGuidance:
          'ألم رقبة بعد إصابة يحتاج تقييماً سريرياً أدق من ألم غير رضّي. '
          'قرار التصوير سياقي ومراجَع — مو مجرد «أشعة لأن في ألم».',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'neckTraumaClinicianDecision',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'traumaNeck',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.emergency,
          reasonCode: 'urgentIfNeeded',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_knee_nonspecific_no_auto_xray',
      topic: MskTopic.kneePain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Knee pain — no automatic X-ray',
        sourceReference: 'ACR AC Knee Pain',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 78,
      arabicGuidance:
          'ألم الركبة العام مو تشخيص سوفان، والتصوير مو تلقائي بدون سياق.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'nonspecificKneeNoRoutineXray',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'kneeMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifLimiting',
          optional: true,
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_knee_trauma_weightbearing',
      topic: MskTopic.kneePain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Knee trauma with weight-bearing difficulty',
        sourceReference: 'ACR AC Acute Trauma to Knee principles',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      requiresTrauma: true,
      requiresUnableToBearWeight: true,
      priority: 95,
      arabicGuidance:
          'طيحة/إصابة مع صعوبة المشي تغيّر المسار عن ألم مزمن عادي. '
          'التقييم السريري مهم، والتصوير قد يكون مناسباً حسب السياق المراجَع.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.usuallyAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'traumaInabilityBearWeight',
        allowsServiceHandoff: true,
        arabicGuidance:
            'في هذا السياق، مناقشة أشعة قد تكون مناسبة عادةً بعد القرار السريري.',
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'traumaKnee',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'traumaImaging',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.serviceNavigation,
          reasonCode: 'afterEligibility',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.radiology,
          reasonCode: 'radiologyIfEligible',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.specialist,
          reasonCode: 'orthoSemantic',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_known_knee_oa_exercise_no_routine_reimage',
      topic: MskTopic.knownKneeOsteoarthritis,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Osteoarthritis — exercise/education; no routine re-imaging',
        sourceReference: 'NICE NG226 Osteoarthritis',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      requiresKnownOa: true,
      priority: 86,
      arabicGuidance:
          'مع تشخيص سوفان ركبة مذكور من طبيب: '
          'التعليم والتمارين العلاجية/النشاط المناسب ومناقشة العلاج الطبيعي '
          'قد تكون مفيدة. ما نطلب تصويراً روتينياً متكرراً للإدارة المحافظة، '
          'وما نفتح رسالة تخسيس تلقائية فقط لأن التشخيص موجود.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'knownOaNoRoutineReimage',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.exerciseGuidance,
          reasonCode: 'therapeuticExerciseDiscuss',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.physiotherapyDiscussion,
          reasonCode: 'supervisedExerciseDiscuss',
          optional: true,
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifWorsening',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.physiotherapy,
          reasonCode: 'physio',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_shoulder_no_auto_dx',
      topic: MskTopic.shoulderPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Shoulder pain — clinical assessment; avoid premature labels',
        sourceReference: 'NICE CKS Shoulder pain principles',
        sourceVersionOrDate: '2023',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 70,
      arabicGuidance:
          'ألم الكتف يحتاج سياق حركة/رضّ/ضعف. '
          'ما نشخّص إصابة أوتار الكتف أو تيبس الكتف المتقدم من الكلام وحده.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'shoulderNoAutoImage',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'shoulderMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifPersistent',
          optional: true,
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_hip_no_auto_image',
      topic: MskTopic.hipPain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Hip pain — imaging not automatic',
        sourceReference: 'ACR AC Chronic Hip Pain principles',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 70,
      arabicGuidance:
          'ألم الورك: نوضح الوظيفة والرضّ والمدة. التصوير مو تلقائي.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'hipNoAutoImage',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'hipMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifLimiting',
          optional: true,
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_strain_conservative_no_grade',
      topic: MskTopic.muscleStrain,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Soft-tissue injury — conservative care; no home grading',
        sourceReference: 'NICE CKS Sprains and strains principles',
        sourceVersionOrDate: '2023',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 75,
      arabicGuidance:
          'لإصابة عضلية/أنسجة رخوة غير معقّدة: حماية وتعديل نشاط وحركة لطيفة حسب التحمّل '
          'قد تكون مناسبة. ما نصنّف التمزق من البيت إلى مستويات، '
          'وما ننصح براحة تامة مطوّلة كقاعدة.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.ultrasound,
        reasonCode: 'strainNoAutoUs',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.relativeRest,
          reasonCode: 'protection',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'mod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.continueActivityAsTolerated,
          reasonCode: 'gentleAsTolerated',
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_thigh_suspected_injury_no_grade',
      topic: MskTopic.thighMuscleInjury,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Suspected muscle injury — function first; no grade',
        sourceReference: 'NICE soft-tissue injury principles',
        sourceVersionOrDate: '2023',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 76,
      arabicGuidance:
          'شد/تمزق عضلة الفخذ كما ذُكر يبقى إصابة مشتبهة حتى التقييم. '
          'حماية وتعديل النشاط حسب القدرة على المشي؛ نوضح التورم/الكدمة عند الحاجة — '
          'بلا تصنيف تمزق منزلي، وما ننصح براحة تامة مطوّلة كقاعدة.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.ultrasound,
        reasonCode: 'thighNoAutoGradeOrImage',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.relativeRest,
          reasonCode: 'protect',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifSevereLimitation',
          optional: true,
        ),
      ],
    ),
    MskClinicalRule(
      ruleId: 'msk_spasm_no_disc_or_vitamin_inference',
      topic: MskTopic.spasm,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Muscle spasm as symptom — avoid causal overreach',
        sourceReference: 'NICE MSK symptom principles',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 60,
      arabicGuidance:
          'التشنج عرض. ما نستنتج منه نقص عناصر غذائية أو مرض غضروفي تلقائياً.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'spasmMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.generalSelfCare,
          reasonCode: 'selfCare',
        ),
      ],
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.unspecified,
        reasonCode: 'spasmNoAutoImage',
        allowsServiceHandoff: false,
      ),
    ),
    // قاعدة غير مكتملة الدليل — غير نشطة
    MskClinicalRule(
      ruleId: 'msk_incomplete_evidence_inactive',
      topic: MskTopic.jointPainGeneral,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'pending',
        sourceTitle: 'Incomplete review placeholder',
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

  List<MskClinicalRule> get all => List.unmodifiable(_rules);

  List<MskClinicalRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  MskClinicalRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }
}
