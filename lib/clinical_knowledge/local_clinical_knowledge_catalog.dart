import 'clinical_knowledge_models.dart';

/// كتalog معرفة سريرية — قابل للاستبدال (محلي الآن).
abstract class ClinicalKnowledgeCatalog {
  Future<List<ClinicalKnowledgeRule>> loadRules({bool activeOnly = true});

  Future<ClinicalKnowledgeRule?> findById(String ruleId);

  List<ClinicalDomain> supportedDomains();
}

/// كتalog محلي صغير للتحقق المعماري — ليس المكتبة الطبية النهائية.
class LocalClinicalKnowledgeCatalog implements ClinicalKnowledgeCatalog {
  LocalClinicalKnowledgeCatalog({List<ClinicalKnowledgeRule>? rules})
      : _rules = rules ?? foundationRules;

  final List<ClinicalKnowledgeRule> _rules;

  static final DateTime _reviewed = DateTime(2026, 3, 1);

  /// قواعد أساس محدودة — للتحقق من المعمارية فقط.
  static final List<ClinicalKnowledgeRule> foundationRules = [
    // —— ألم أسفل الظهر غير النوعي: تصوير غير روتيني ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_msk_lbp_imaging_not_routine',
      domain: ClinicalDomain.musculoskeletal,
      topic: ClinicalKnowledgeTopic.lowBackPain,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'ACR Appropriateness Criteria — Low Back Pain',
        sourceReference: 'ACR AC Low Back Pain',
        sourceVersionOrDate: '2021',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      symptomKeys: const ['low_back_pain', 'back_pain'],
      englishCanonicalKey: 'nonspecific_low_back_pain_imaging',
      arabicSummary:
          'لألم أسفل الظهر غير النوعي بدون علامات خطر، التصوير الشعاعي '
          'ليس روتينياً تلقائياً. القرار سريري سياقي.',
      iraqiAliases: const ['وجع ضهري', 'الم ظهر', 'ظهري يوجعني'],
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'relativeRestPreferred',
          arabicHint: 'تعديل نشاط حسب التحمّل وليس راحة سريرية مطلقة',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.continueActivityAsTolerated,
          reasonCode: 'activityAsTolerated',
          optional: true,
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.physiotherapyDiscussion,
          reasonCode: 'physioMayDiscuss',
          optional: true,
          arabicHint: 'مناقشة علاج طبيعي قد تكون مناسبة حسب السياق',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'clinicianIfPersists',
          optional: true,
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'imagingNotRoutine',
        ),
      ],
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'nonspecificBackPainNoRoutineXray',
        allowsServiceHandoff: false,
        arabicGuidance:
            'ما نوصي بأشعة روتينية تلقائية لمجرد ألم ظهر غير نوعي بدون سياق خطر.',
      ),
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.selfCare,
          reasonCode: 'initialSelfCare',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.physiotherapy,
          reasonCode: 'physioDiscuss',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gpIfNeeded',
        ),
      ],
      minimumQuestions: const [
        ClinicalQuestionDefinition(
          questionKey: 'duration',
          canonicalKey: 'duration',
          arabicPrompt: 'منو صاير الألم؟',
          iraqiAliases: ['منو صار', 'شگد صارله'],
        ),
        ClinicalQuestionDefinition(
          questionKey: 'red_flag_neuro',
          canonicalKey: 'neurological_symptom',
          arabicPrompt: 'عدك تنميل أو ضعف بالرجل؟',
        ),
      ],
      redFlagKeys: const ['neurological_deficit', 'cauda_equina_concern'],
      priority: 90,
    ),

    // —— سعال مزمن: مسار تصوير سياقي بالمدة ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_resp_chronic_cough_imaging_pathway',
      domain: ClinicalDomain.respiratory,
      topic: ClinicalKnowledgeTopic.chronicCough,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Cough — clinical knowledge / pathway considerations',
        sourceReference: 'NICE CKS Cough',
        sourceVersionOrDate: '2024',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      symptomKeys: const ['cough', 'chronic_cough'],
      coughDurationClass: ClinicalCoughDurationClass.chronic,
      requiredContext: const {'duration_chronic'},
      englishCanonicalKey: 'chronic_cough_imaging_discussion',
      arabicSummary:
          'السعال المزمن قد يستدعي مناقشة تصوير/تقييم حسب المدة والسياق، '
          'وليس لكل سعال عابر.',
      iraqiAliases: const ['كحة مستمرة', 'سعال هواي'],
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'chronicCoughReview',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'chronicCoughCriteria',
        ),
      ],
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'chronicCoughCriteria',
        allowsServiceHandoff: true,
        arabicGuidance:
            'حسب مدة السعال والسياق، مناقشة تصوير قد تكون مناسبة مع مختص — '
            'مو لكل كحة بسيطة.',
      ),
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'gpReview',
        ),
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.radiology,
          reasonCode: 'imagingIfEligible',
        ),
      ],
      minimumQuestions: const [
        ClinicalQuestionDefinition(
          questionKey: 'cough_duration',
          canonicalKey: 'duration',
          arabicPrompt: 'الكحة منو صايرة؟',
          iraqiAliases: ['شگد صارلها الكحة'],
        ),
      ],
      priority: 85,
    ),

    // —— سعال حاد عام: لا أشعة تلقائية ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_resp_acute_cough_no_auto_cxr',
      domain: ClinicalDomain.respiratory,
      topic: ClinicalKnowledgeTopic.acuteCough,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'NICE',
        sourceTitle: 'Acute cough — avoid routine imaging without indication',
        sourceReference: 'NICE CKS Cough acute considerations',
        sourceVersionOrDate: '2024',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      symptomKeys: const ['cough'],
      coughDurationClass: ClinicalCoughDurationClass.acute,
      englishCanonicalKey: 'acute_cough_no_routine_cxr',
      arabicSummary: 'السعال الحاد غير المعقّد لا يعني أشعة صدر روتينية.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.generalSelfCare,
          reasonCode: 'supportiveCare',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'ifWorsens',
          optional: true,
        ),
      ],
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'acuteCoughNoRoutineCxr',
        allowsServiceHandoff: false,
      ),
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.selfCare,
          reasonCode: 'selfCareFirst',
        ),
      ],
      priority: 70,
    ),

    // —— سكري وحده لا يعني أشعة صدر روتينية ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_dm_no_routine_chest_xray',
      domain: ClinicalDomain.diabetes,
      topic: ClinicalKnowledgeTopic.diabetesRoutineCare,
      population: ClinicalPopulation.knownDiabetes,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Standards of Care in Diabetes — routine follow-up domains',
        sourceReference: 'ADA Standards of Care',
        sourceVersionOrDate: '2025',
        evidenceType: ClinicalEvidenceType.professionalStandard,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      knownDiagnosisKeys: const ['diabetes', 'diabetes_mellitus'],
      englishCanonicalKey: 'diabetes_no_routine_chest_xray',
      arabicSummary:
          'مرض السكري وحده لا يستدعي أشعة صدر روتينية دون مؤشر سريري منفصل. '
          'المتابعة تشمل مجالات أخرى (سكر، عين، كلية، قدم...) عبر مسار المزمن.',
      iraqiAliases: const ['سكري', 'السكري'],
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'diabetesRoutineClinician',
        ),
      ],
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'diabetesAloneNoRoutineCxr',
        allowsServiceHandoff: false,
      ),
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'chronicFollowUp',
        ),
      ],
      priority: 80,
    ),

    // —— نشاط مع علامات خطر: انتظر تقييماً ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_wellness_activity_defer_on_red_flag',
      domain: ClinicalDomain.wellness,
      topic: ClinicalKnowledgeTopic.activityWithRedFlags,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Physical activity — safety considerations',
        sourceReference: 'WHO PA safety context',
        sourceVersionOrDate: '2020',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'medical_red_flag'},
      englishCanonicalKey: 'activity_defer_red_flag',
      arabicSummary:
          'عند وجود علامة خطر طبية، تأجيل نصائح التمرين العامة حتى التقييم.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.emergencyCare,
          reasonCode: 'deferTo10E',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.emergency,
          reasonCode: 'urgentEvaluation',
        ),
      ],
      priority: 100,
    ),

    // —— ضغط: أساس مجال (بدون بروتوكول كامل) ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_htn_foundation_clinician_review',
      domain: ClinicalDomain.hypertension,
      topic: ClinicalKnowledgeTopic.hypertensionRoutineCare,
      population: ClinicalPopulation.knownHypertension,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Hypertension guideline — clinician follow-up foundation',
        sourceReference: 'WHO hypertension guidance',
        sourceVersionOrDate: '2021',
        evidenceType: ClinicalEvidenceType.clinicalGuideline,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      knownDiagnosisKeys: const ['hypertension'],
      englishCanonicalKey: 'hypertension_foundation',
      arabicSummary: 'أساس معرفة ضغط الدم: متابعة سريرية ونمط حياة — سلطة القياس/المتابعة لـ PC-1.5.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'htnClinician',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.generalPractitioner,
          reasonCode: 'htnFollowUp',
        ),
      ],
      priority: 60,
    ),

    // —— حمل: أساس مجال — بلا رفيق حمل ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_preg_foundation_requires_explicit',
      domain: ClinicalDomain.pregnancy,
      topic: ClinicalKnowledgeTopic.pregnancyRoutineCare,
      population: ClinicalPopulation.pregnant,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACOG',
        sourceTitle: 'Prenatal care foundation — explicit confirmation required',
        sourceReference: 'ACOG prenatal care principles',
        sourceVersionOrDate: '2023',
        evidenceType: ClinicalEvidenceType.professionalStandard,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'explicit_pregnancy_confirmed'},
      englishCanonicalKey: 'pregnancy_foundation_explicit_only',
      arabicSummary:
          'توجيه الحمل يتطلب تأكيداً صريحاً من المستخدمة. لا استنتاج من العمر/الجنس.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.clinicianReview,
          reasonCode: 'obgynRespect',
          arabicHint: 'ناقشي مع طبيبتك — بدون انتقاص لخطة علاجك',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.obstetricsGynecology,
          reasonCode: 'obgyn',
        ),
      ],
      priority: 55,
    ),

    // —— أسنان: أساس مجال ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_dental_pain_foundation',
      domain: ClinicalDomain.dental,
      topic: ClinicalKnowledgeTopic.dentalPain,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ADA',
        sourceTitle: 'Dental pain — professional dental evaluation pathway',
        sourceReference: 'ADA dental care principles',
        sourceVersionOrDate: '2023',
        evidenceType: ClinicalEvidenceType.professionalStandard,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      symptomKeys: const ['dental_pain', 'toothache'],
      englishCanonicalKey: 'dental_pain_foundation',
      arabicSummary:
          'ألم الأسنان يستدعي تقييماً سنّياً — تُعالَج الشكاوى السنّية المؤهلة عبر حزمة PC-1.22 عند التفعيل.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.dentalReview,
          reasonCode: 'dentalReview',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.dentist,
          reasonCode: 'dentist',
        ),
      ],
      priority: 65,
    ),

    // —— صحة نفسية: وجهة مهنية — بلا استبدال PC-1.6 ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_mh_professional_pathway_foundation',
      domain: ClinicalDomain.mentalHealth,
      topic: ClinicalKnowledgeTopic.generalClinical,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Mental health care pathways — professional support',
        sourceReference: 'WHO mental health',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'mental_health_topic'},
      englishCanonicalKey: 'mental_health_pathway_foundation',
      arabicSummary:
          'مسار دعم مهني محتمل — السلامة العاطفية تبقى سلطة PC-1.6.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.mentalHealthSupport,
          reasonCode: 'mhSupport',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.mentalHealthProfessional,
          reasonCode: 'mhProfessional',
        ),
      ],
      priority: 50,
    ),

    // —— مراهقون: أساس مجال ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_adolescent_foundation',
      domain: ClinicalDomain.adolescentHealth,
      topic: ClinicalKnowledgeTopic.generalClinical,
      population: ClinicalPopulation.adolescent,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Adolescent health — age-appropriate support foundation',
        sourceReference: 'WHO adolescent health',
        sourceVersionOrDate: '2023',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'adolescent_population'},
      englishCanonicalKey: 'adolescent_health_foundation',
      arabicSummary:
          'أساس صحة المراهقين — بلا استنتاج سمات حسّاسة. '
          'السياقات النمائية المؤهلة تُعالَج عبر رفيق PC-1.23 عند التفعيل.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.generalSelfCare,
          reasonCode: 'ageAppropriateSupport',
        ),
      ],
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.primaryCare,
          reasonCode: 'primaryIfNeeded',
        ),
      ],
      priority: 40,
    ),

    // —— قاعدة غير نشطة (للتحقق من عدم الاختيار) ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_inactive_example_do_not_select',
      domain: ClinicalDomain.other,
      topic: ClinicalKnowledgeTopic.other,
      population: ClinicalPopulation.unknown,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'CDC',
        sourceTitle: 'Inactive placeholder',
        sourceReference: 'inactive',
        sourceVersionOrDate: '2020',
        evidenceType: ClinicalEvidenceType.other,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: false,
      freshness: ClinicalEvidenceFreshness.superseded,
      supersedesRuleId: null,
      englishCanonicalKey: 'inactive_placeholder',
      arabicSummary: 'قاعدة غير نشطة للاختبار.',
      priority: 1,
    ),

    // —— مثال reviewDue ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_example_review_due',
      domain: ClinicalDomain.generalMedicine,
      topic: ClinicalKnowledgeTopic.generalClinical,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'WHO',
        sourceTitle: 'Example review-due rule',
        sourceReference: 'example',
        sourceVersionOrDate: '2018',
        evidenceType: ClinicalEvidenceType.evidenceSummary,
      ),
      reviewedAt: DateTime(2018, 1, 1),
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.reviewDue,
      requiredContext: const {'force_review_due_example'},
      englishCanonicalKey: 'review_due_example',
      arabicSummary: 'مثال قاعدة تحتاج مراجعة حداثة.',
      priority: 10,
    ),

    // —— تصوير usuallyAppropriate / clinicianDecision / MRI/CT/US أمثلة معمارية ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_imaging_modalities_architecture_example',
      domain: ClinicalDomain.musculoskeletal,
      topic: ClinicalKnowledgeTopic.kneePain,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Imaging modalities architecture example',
        sourceReference: 'ACR AC architecture sample',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'trauma_with_bony_concern'},
      symptomKeys: const ['knee_pain'],
      englishCanonicalKey: 'knee_trauma_imaging_architecture',
      arabicSummary:
          'مثال معماري: تصوير الركبة عند سياق رضّي معيّن — ليس لكل ألم ركبة.',
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.imagingDiscussion,
          reasonCode: 'trauma',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.serviceNavigation,
          reasonCode: 'afterClinicalEligibility',
          optional: true,
        ),
      ],
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.usuallyAppropriate,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'trauma',
        allowsServiceHandoff: true,
        arabicGuidance:
            'عند سياق رضّي يستدعي تقييماً عظمياً، قد يكون التصوير مناسباً عادةً — '
            'ثم يمكن لغدير المساعدة في إيجاد خدمة أشعة متوفرة.',
      ),
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.radiology,
          reasonCode: 'radiologyIfEligible',
        ),
      ],
      priority: 75,
    ),

    ClinicalKnowledgeRule(
      ruleId: 'ck_imaging_clinician_decision_example',
      domain: ClinicalDomain.musculoskeletal,
      topic: ClinicalKnowledgeTopic.shoulderPain,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Shoulder imaging — clinician decision example',
        sourceReference: 'ACR AC Shoulder',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'clinician_imaging_decision'},
      englishCanonicalKey: 'shoulder_clinician_decision',
      arabicSummary: 'قرار التصوير يبقى سريرياً في هذا المثال.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.clinicianDecision,
        modality: ClinicalImagingModality.mri,
        reasonCode: 'clinicianDirectedEvaluation',
        allowsServiceHandoff: false,
      ),
      destinations: const [
        ClinicalCareDestinationHint(
          destination: ClinicalCareDestination.specialist,
          reasonCode: 'specialist',
        ),
      ],
      priority: 45,
    ),

    ClinicalKnowledgeRule(
      ruleId: 'ck_imaging_ct_us_architecture',
      domain: ClinicalDomain.generalMedicine,
      topic: ClinicalKnowledgeTopic.generalClinical,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'CT/US modality architecture placeholders',
        sourceReference: 'ACR modality architecture',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'modality_architecture_ct_us'},
      englishCanonicalKey: 'ct_us_architecture',
      arabicSummary: 'دعم معماري لـ CT والموجات فوق الصوتية.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.ct,
        reasonCode: 'specificRedFlag',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.investigationDiscussion,
          reasonCode: 'modalityChoice',
        ),
      ],
      priority: 20,
    ),

    ClinicalKnowledgeRule(
      ruleId: 'ck_imaging_ultrasound_architecture',
      domain: ClinicalDomain.generalMedicine,
      topic: ClinicalKnowledgeTopic.generalClinical,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Ultrasound modality architecture',
        sourceReference: 'ACR US architecture',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      requiredContext: const {'modality_architecture_ultrasound'},
      englishCanonicalKey: 'ultrasound_architecture',
      arabicSummary: 'دعم معماري للموجات فوق الصوتية.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.mayBeAppropriate,
        modality: ClinicalImagingModality.ultrasound,
        reasonCode: 'clinicianDirectedEvaluation',
        allowsServiceHandoff: false,
      ),
      priority: 20,
    ),

    // —— رقبة/ركبة عامة: لا أشعة تلقائية ——
    ClinicalKnowledgeRule(
      ruleId: 'ck_msk_neck_no_auto_xray',
      domain: ClinicalDomain.musculoskeletal,
      topic: ClinicalKnowledgeTopic.neckPain,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Cervical pain — no automatic X-ray',
        sourceReference: 'ACR AC Cervical',
        sourceVersionOrDate: '2021',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      symptomKeys: const ['neck_pain'],
      englishCanonicalKey: 'nonspecific_neck_pain_no_auto_xray',
      arabicSummary: 'ألم الرقبة غير النوعي لا يعني أشعة تلقائية.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'nonspecificNeckNoRoutineXray',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'relativeRest',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.generalSelfCare,
          reasonCode: 'selfCare',
        ),
      ],
      priority: 70,
    ),

    ClinicalKnowledgeRule(
      ruleId: 'ck_msk_knee_no_auto_xray',
      domain: ClinicalDomain.musculoskeletal,
      topic: ClinicalKnowledgeTopic.kneePain,
      population: ClinicalPopulation.generalAdult,
      evidence: const ClinicalEvidenceReference(
        sourceOrganization: 'ACR',
        sourceTitle: 'Knee pain — no automatic X-ray without context',
        sourceReference: 'ACR AC Knee',
        sourceVersionOrDate: '2022',
        evidenceType: ClinicalEvidenceType.appropriatenessCriteria,
      ),
      reviewedAt: _reviewed,
      schemaVersion: 1,
      clinicalReviewRequired: true,
      isActive: true,
      freshness: ClinicalEvidenceFreshness.current,
      symptomKeys: const ['knee_pain'],
      excludedContext: const {'trauma_with_bony_concern'},
      englishCanonicalKey: 'nonspecific_knee_pain_no_auto_xray',
      arabicSummary: 'ألم الركبة العام لا يعني أشعة تلقائية.',
      imaging: const ClinicalImagingGuidance(
        appropriateness: ClinicalImagingAppropriateness.notRoutinelyIndicated,
        modality: ClinicalImagingModality.xray,
        reasonCode: 'nonspecificKneeNoRoutineXray',
        allowsServiceHandoff: false,
      ),
      actions: const [
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.activityModification,
          reasonCode: 'activityMod',
        ),
        ClinicalGuidanceAction(
          actionType: ClinicalCareActionType.physiotherapyDiscussion,
          reasonCode: 'physioOptional',
          optional: true,
        ),
      ],
      priority: 70,
    ),
  ];

  @override
  Future<List<ClinicalKnowledgeRule>> loadRules({bool activeOnly = true}) async {
    if (!activeOnly) return List.unmodifiable(_rules);
    return _rules.where((r) => r.isActive).toList(growable: false);
  }

  @override
  Future<ClinicalKnowledgeRule?> findById(String ruleId) async {
    for (final r in _rules) {
      if (r.ruleId == ruleId) return r;
    }
    return null;
  }

  @override
  List<ClinicalDomain> supportedDomains() => ClinicalDomain.values;
}
