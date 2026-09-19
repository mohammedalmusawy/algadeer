import '../../clinical_knowledge_models.dart';
import 'respiratory_models.dart';

/// قاعدة تنفسية منظّمة — عتبات المدة هنا وليس في المفسّر.
class RespiratoryClinicalRule {
  const RespiratoryClinicalRule({
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
    this.investigationType = RespiratoryInvestigationType.none,
    this.minDurationBucket,
    this.maxDurationBucket,
    this.mapsToDurationClass,
    this.chronicCoughMinWeeks,
    this.requiresHemoptysis = false,
    this.requiresKnownCopd = false,
    this.requiresKnownAsthma = false,
    this.requiresRecurrentInfection = false,
    this.requiresPostPneumoniaRisk = false,
    this.adultOnly = true,
    this.blocksPregnancyStandardPathway = false,
    this.priority = 50,
  });

  final String ruleId;
  final RespiratoryTopic topic;
  final ClinicalEvidenceReference evidence;
  final DateTime reviewedAt;
  final ClinicalEvidenceFreshness freshness;
  final bool clinicalReviewRequired;
  final bool isActive;
  final ClinicalImagingGuidance? imaging;
  final List<ClinicalGuidanceAction> actions;
  final List<ClinicalCareDestinationHint> destinations;
  final String arabicGuidance;
  final RespiratoryInvestigationType investigationType;
  final RespiratoryDurationBucket? minDurationBucket;
  final RespiratoryDurationBucket? maxDurationBucket;
  final ClinicalCoughDurationClass? mapsToDurationClass;

  /// عتبة مزمنة من الدليل — ليست في المفسّر.
  final int? chronicCoughMinWeeks;
  final bool requiresHemoptysis;
  final bool requiresKnownCopd;
  final bool requiresKnownAsthma;
  final bool requiresRecurrentInfection;
  final bool requiresPostPneumoniaRisk;
  final bool adultOnly;
  final bool blocksPregnancyStandardPathway;
  final int priority;

  bool get hasEvidenceMetadata =>
      evidence.sourceOrganization.isNotEmpty &&
      evidence.sourceReference.isNotEmpty;
}

/// كتالوج قواعد تنفسية مراجَعة — data-driven.
class RespiratoryRuleCatalog {
  RespiratoryRuleCatalog({List<RespiratoryClinicalRule>? rules})
      : _rules = rules ?? activeRules;

  final List<RespiratoryClinicalRule> _rules;

  static final DateTime _reviewed = DateTime(2026, 3, 1);

  /// عتبة السعال المزمن بالأسابيع — ملكية الدليل لا المحادثة.
  static const int chronicCoughThresholdWeeks = 8;

  static final List<RespiratoryClinicalRule> activeRules = [
    RespiratoryClinicalRule(
      ruleId: 'resp_acute_cough_self_limiting_no_auto_cxr',
      topic: RespiratoryTopic.acuteCough,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Acute cough — usually self-limiting; no routine antibiotics/CXR',
        sourceReference: 'NICE NG120 / NG237 acute cough principles',
        sourceVersionOrDate: 'NG120',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 80,
      maxDurationBucket: RespiratoryDurationBucket.weeks,
      mapsToDurationClass: ClinicalCoughDurationClass.acute,
      arabicGuidance:
          'السعال الحاد غالباً محدود ذاتياً وقد يستمر أسابيع. '
          'رعاية داعمة عامة ومراجعة إن تسارع التدهور أو ظهرت أعراض مقلقة. '
          'ما نصف مضاداً حيوياً تلقائياً وما نطلب صورة صدر روتينية لهذا السياق.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'acuteCoughNoRoutineCxr',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.generalSelfCare,
          reasonCode: 'supportive',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifWorsening',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.selfCare,
          reasonCode: 'initial',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gpIfWorsening',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_persistent_cough_clinician_path',
      topic: RespiratoryTopic.persistentCough,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Persistent cough — contextual assessment',
        sourceReference: 'NICE cough pathway principles',
        sourceVersionOrDate: 'NG120-related',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 85,
      minDurationBucket: RespiratoryDurationBucket.weeks,
      mapsToDurationClass: ClinicalCoughDurationClass.subacute,
      arabicGuidance:
          'سعال مستمر يحتاج سياقاً أوضح (ضيق، دم، حرارة، أثر وظيفي). '
          'مراجعة سريرية قد تكون مناسبة إن لم يتحسن أو أثر على الحياة.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'persistentCoughEvaluation',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'persistent',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_chronic_cough_cxr_eligible_adult',
      topic: RespiratoryTopic.chronicCough,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Chronic cough — Chest X-ray often initial imaging',
        sourceReference: 'ACR Appropriateness Criteria Chronic Cough',
        sourceVersionOrDate: 'ACR AC Chronic Cough',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 92,
      minDurationBucket: RespiratoryDurationBucket.months,
      mapsToDurationClass: ClinicalCoughDurationClass.chronic,
      chronicCoughMinWeeks: chronicCoughThresholdWeeks,
      adultOnly: true,
      arabicGuidance:
          'بحسب مدة السعال والأعراض المذكورة، تقييم الطبيب وصورة الصدر '
          'قد تكون مناسبة كخطوة أولية مراجَعة. هذا مو تشخيص سبب السعال.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.usuallyAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'chronicCoughEvaluation',
        allowsServiceHandoff: true,
        arabicGuidance:
            'صورة الصدر قد تُناقش كفحص أولي ضمن تقييم سريري — وليست تأكيداً لكل الأسباب.',
      ),
      investigationType: RespiratoryInvestigationType.chestXray,
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'chronicCough',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'cxrDiscuss',
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
          reasonCode: 'chestXrayIfEligible',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'primaryCare',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.specialist,
          reasonCode: 'pulmonologySemantic',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_hemoptysis_escalate_not_ordinary',
      topic: RespiratoryTopic.hemoptysis,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Hemoptysis — urgent clinical assessment pathway',
        sourceReference: 'NICE NG12 selected urgent CXR risk contexts',
        sourceVersionOrDate: 'NG12',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 98,
      requiresHemoptysis: true,
      arabicGuidance:
          'وجود دم مع السعال/البلغم سياق مهم — مو سعال عادي. '
          'يلزم تقييم سريري عاجل حسب السلامة الطبية، بلا طمأنة زائفة وبلا تشخيص سرطان/سل من النص.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.urgentImagingConsideration,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'hemoptysisUrgentContext',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.emergencyCare,
          reasonCode: 'safetyFirst',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.emergency,
          reasonCode: 'urgent',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_known_copd_no_med_change',
      topic: RespiratoryTopic.knownCopd,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'COPD — assess change; do not alter inhalers in chat',
        sourceReference: 'NICE NG115 / QS10 COPD evaluation principles',
        sourceVersionOrDate: 'NG115',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 88,
      requiresKnownCopd: true,
      arabicGuidance:
          'مع COPD مذكور: نوضح التغيّر الحالي (سعال/بلغم/ضيق) والحاجة لتقييم سريري. '
          'ما نغيّر البخاخات أو الأدوية من هنا، وصورة الصدر ما «تثبت» COPD.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'knownDiseaseInitialEvaluation',
        allowsServiceHandoff: false,
      ),
      investigationType: RespiratoryInvestigationType.clinicianDirected,
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'copdChange',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.investigationDiscussion,
          reasonCode: 'spirometryDiscussOptional',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.specialist,
          reasonCode: 'pulmonologySemantic',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_suspected_copd_spirometry_discuss',
      topic: RespiratoryTopic.generalRespiratory,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Suspected COPD — spirometry discussion; CXR does not confirm',
        sourceReference: 'NICE NG115 diagnosis/evaluation principles',
        sourceVersionOrDate: 'NG115',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 70,
      adultOnly: true,
      arabicGuidance:
          'أعراض مزمنة + تدخين مصرّح به قد تبرر مناقشة تقييم سريري ومقياس تنفس (spirometry). '
          'هذا مو تشخيص COPD، وصورة الصدر وحدها ما تؤكد التشخيص.',
      investigationType: RespiratoryInvestigationType.spirometry,
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'cxrDoesNotConfirmCopd',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'suspectCopdEval',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.investigationDiscussion,
          reasonCode: 'spirometry',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_known_asthma_no_inhaler_change',
      topic: RespiratoryTopic.knownAsthma,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Known asthma — contextual; no inhaler dose change in chat',
        sourceReference: 'NICE asthma management boundary principles',
        sourceVersionOrDate: 'CKS/related',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 86,
      requiresKnownAsthma: true,
      arabicGuidance:
          'مع ربو مشخص مذكور: نوضح الأعراض الحالية. '
          'ما نغيّر جرعة البخاخ وما نبني خطة ربو كاملة هنا.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'asthmaReview',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_recurrent_chest_infection_eval',
      topic: RespiratoryTopic.recurrentChestInfection,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Recurrent chest infection — clinician evaluation',
        sourceReference: 'NICE respiratory infection evaluation principles',
        sourceVersionOrDate: 'NG237-related',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 87,
      requiresRecurrentInfection: true,
      arabicGuidance:
          'التهاب صدر متكرر كما ذُكر يستدعي تقييماً سريرياً — بلا تشخيص مرض كامن من المحادثة.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'recurrentChestInfection',
        allowsServiceHandoff: true,
      ),
      investigationType: RespiratoryInvestigationType.chestXray,
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'recurrent',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'cxrMayDiscuss',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.radiology,
          reasonCode: 'ifEligible',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_post_pneumonia_selected_followup_imaging',
      topic: RespiratoryTopic.postRespiratoryIllness,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Pneumonia follow-up imaging — selected, not routine for all',
        sourceReference: 'NICE NG250 pneumonia follow-up imaging principles',
        sourceVersionOrDate: 'NG250',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 84,
      requiresPostPneumoniaRisk: true,
      arabicGuidance:
          'متابعة صورة الصدر بعد التهاب رئوي مشخص ليست روتيناً للجميع. '
          'قد تُناقش عند استمرار/تدهور الأعراض أو عوامل خطورة مراجَعة — مو تشخيص التهاب من الشات.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'postPneumoniaFollowUpSelected',
        allowsServiceHandoff: true,
      ),
      investigationType: RespiratoryInvestigationType.chestXray,
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'postPneumonia',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'selectedFollowUp',
          optional: true,
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gp',
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_wheeze_symptom_no_asthma_dx',
      topic: RespiratoryTopic.wheeze,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Wheeze as symptom — avoid premature asthma label',
        sourceReference: 'NICE respiratory symptom principles',
        sourceVersionOrDate: 'CKS-related',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.current,
      clinicalReviewRequired: true,
      isActive: true,
      priority: 65,
      arabicGuidance:
          'الصفير عرض. ما نشخّص ربو من الصفير وحده.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifPersistent',
          optional: true,
        ),
      ],
    ),
    RespiratoryClinicalRule(
      ruleId: 'resp_ct_requires_separate_indication_inactive_placeholder',
      topic: RespiratoryTopic.generalRespiratory,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'CT chest — specific clinical question required',
        sourceReference: 'ACR AC — CT not upgrade of CXR',
        sourceVersionOrDate: 'ACR principles',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      clinicalReviewRequired: true,
      isActive: false,
      priority: 5,
      arabicGuidance: 'CT يتطلب استطباباً منفصلاً مراجَعاً — غير مفعّل كمسار عام.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.ct,
        reasonCode: 'ctRequiresSeparateIndication',
        allowsServiceHandoff: false,
      ),
      investigationType: RespiratoryInvestigationType.ctChest,
    ),
    // قاعدة غير مكتملة الدليل
    RespiratoryClinicalRule(
      ruleId: 'resp_incomplete_evidence_inactive',
      topic: RespiratoryTopic.unknownRespiratory,
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

  List<RespiratoryClinicalRule> get all => List.unmodifiable(_rules);

  List<RespiratoryClinicalRule> get active =>
      _rules.where((r) => r.isActive).toList(growable: false);

  RespiratoryClinicalRule? findById(String id) {
    for (final r in _rules) {
      if (r.ruleId == id) return r;
    }
    return null;
  }

  /// يشتق فئة المدة من الدليل — لا من رقم ثابت في المفسّر.
  ClinicalCoughDurationClass classifyDuration(
    RespiratoryDurationBucket bucket,
  ) {
    switch (bucket) {
      case RespiratoryDurationBucket.hours:
      case RespiratoryDurationBucket.days:
        return ClinicalCoughDurationClass.acute;
      case RespiratoryDurationBucket.weeks:
        return ClinicalCoughDurationClass.subacute;
      case RespiratoryDurationBucket.months:
        return ClinicalCoughDurationClass.chronic;
      case RespiratoryDurationBucket.unknown:
        return ClinicalCoughDurationClass.unknown;
    }
  }
}
