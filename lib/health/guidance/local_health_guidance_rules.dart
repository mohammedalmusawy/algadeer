import '../../voice/guided_conversation/guided_conversation_models.dart';
import '../understanding/symptom_models.dart';
import 'health_guidance_models.dart';
import 'health_guidance_rule_source.dart';

/// قواعد أولية تمثيلية — ليست موسوعة طبية.
/// لا أسماء أطباء / لا تحاليل / لا تصوير / لا أدوية.
class LocalHealthGuidanceRuleSource extends SyncHealthGuidanceRuleSource {
  const LocalHealthGuidanceRuleSource();

  static final GuidedQuestion _qAbdominalLocation = GuidedQuestion(
    id: 'health_abdominal_location',
    type: GuidedQuestionType.singleChoice,
    prompt: 'وين مكان الألم تقريباً؟',
    expectedAnswerType: GuidedAnswerType.singleChoice,
    options: [
      GuidedChoiceOption(
        id: 'upper',
        label: 'أعلى البطن',
        aliases: ['فوق', 'اعلى', 'أعلى'],
      ),
      GuidedChoiceOption(
        id: 'lower',
        label: 'أسفل البطن',
        aliases: ['تحت', 'اسفل', 'أسفل'],
      ),
      GuidedChoiceOption(
        id: 'right',
        label: 'الجهة اليمنى',
        aliases: ['يمين', 'اليمنى', 'بالجهة اليمنى'],
      ),
      GuidedChoiceOption(
        id: 'left',
        label: 'الجهة اليسرى',
        aliases: ['يسار', 'اليسرى', 'بالجهة اليسرى'],
      ),
      GuidedChoiceOption(
        id: 'center',
        label: 'الوسط',
        aliases: ['وسط', 'منتصف'],
      ),
    ],
  );

  static final GuidedQuestion _qDuration = GuidedQuestion(
    id: 'health_duration',
    type: GuidedQuestionType.duration,
    prompt: 'من متى بدأت المشكلة؟',
    expectedAnswerType: GuidedAnswerType.duration,
  );

  static final GuidedQuestion _qFever = GuidedQuestion(
    id: 'health_associated_fever',
    type: GuidedQuestionType.yesNo,
    prompt: 'هل عندك حرارة؟',
    expectedAnswerType: GuidedAnswerType.yesNo,
  );

  static final GuidedQuestion _qPatientChild = GuidedQuestion(
    id: 'health_patient_is_child',
    type: GuidedQuestionType.yesNo,
    prompt: 'هل الاستشارة تخص طفلاً؟',
    expectedAnswerType: GuidedAnswerType.yesNo,
  );

  @override
  List<HealthGuidanceRule> enabledRulesSync() => List.unmodifiable(_rules);

  static final List<HealthGuidanceRule> _rules = [
    // —— سلامة عالية الإشارة نُقلت إلى Step 10E (MedicalSafetyEngine) ——

    // —— أنف وأذن وحنجرة ——
    HealthGuidanceRule(
      id: 'ent_hearing_loss',
      priority: 80,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'hearing_loss'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('ent'),
      rationaleCode: 'ent_hearing_loss',
    ),
    HealthGuidanceRule(
      id: 'ent_tinnitus',
      priority: 80,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'tinnitus'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('ent'),
      rationaleCode: 'ent_tinnitus',
    ),
    HealthGuidanceRule(
      id: 'ent_ear_pain',
      priority: 80,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'ear_pain'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('ent'),
      rationaleCode: 'ent_ear_pain',
    ),
    HealthGuidanceRule(
      id: 'ent_nasal_congestion',
      priority: 70,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'nasal_congestion'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('ent'),
      rationaleCode: 'ent_nasal_congestion',
    ),
    HealthGuidanceRule(
      id: 'ent_hoarseness',
      priority: 70,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'hoarseness'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('ent'),
      rationaleCode: 'ent_hoarseness',
    ),
    HealthGuidanceRule(
      id: 'ent_combo_hearing_tinnitus',
      priority: 90,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'hearing_loss'),
        SymptomRequirement(conceptId: 'tinnitus'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('ent'),
      rationaleCode: 'ent_hearing_tinnitus',
      minPresentSymptomCount: 2,
    ),

    // —— جملة عصبية (غير عاجل) ——
    HealthGuidanceRule(
      id: 'neuro_tremor',
      priority: 75,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'tremor'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('neurology'),
      rationaleCode: 'neuro_tremor',
    ),
    HealthGuidanceRule(
      id: 'neuro_balance',
      priority: 75,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'balance_problem'),
      ],
      destination: GuidanceDestination.specialtyFromCatalog('neurology'),
      rationaleCode: 'neuro_balance',
    ),
    HealthGuidanceRule(
      id: 'neuro_numbness_with_duration',
      priority: 72,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'numbness'),
      ],
      missingFactsIfIncomplete: const [HealthMissingFact.duration],
      followUpQuestionBuilders: {
        HealthMissingFact.duration: _qDuration,
      },
      destination: GuidanceDestination.specialtyFromCatalog('neurology'),
      rationaleCode: 'neuro_numbness',
    ),

    // —— عظام عند ألم ركبة واضح ——
    HealthGuidanceRule(
      id: 'ortho_knee_pain',
      priority: 74,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'knee_pain'),
      ],
      bodyRegions: const [BodyRegionId.knee],
      destination: GuidanceDestination.specialtyFromCatalog('ortho'),
      rationaleCode: 'ortho_knee',
    ),

    // —— ألم بطن عام: مكان ثم مدة ثم شدة ثم تقييم عام ——
    HealthGuidanceRule(
      id: 'abdomen_guided',
      priority: 70,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'abdominal_pain'),
      ],
      missingFactsIfIncomplete: const [
        HealthMissingFact.abdominalLocationDetail,
        HealthMissingFact.duration,
        HealthMissingFact.severity,
      ],
      followUpQuestionBuilders: {
        HealthMissingFact.abdominalLocationDetail: _qAbdominalLocation,
        HealthMissingFact.duration: _qDuration,
        HealthMissingFact.associatedFever: _qFever,
      },
      destination: GuidanceDestination.general,
      rationaleCode: 'abdomen_guided_general',
    ),

    // —— صداع واسع: معلومات إضافية أو تقييم عام ——
    HealthGuidanceRule(
      id: 'headache_needs_duration',
      priority: 55,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'headache'),
      ],
      missingFactsIfIncomplete: const [HealthMissingFact.duration],
      followUpQuestionBuilders: {
        HealthMissingFact.duration: _qDuration,
      },
      destination: GuidanceDestination.specialtyFromCatalog('neurology'),
      rationaleCode: 'headache_needs_duration',
    ),

    // —— أطفال فقط عند معرفة صريحة ——
    HealthGuidanceRule(
      id: 'pediatrics_when_child_known',
      priority: 85,
      requirePatientIsChild: true,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'fever'),
      ],
      missingFactsIfIncomplete: const [HealthMissingFact.patientIsChild],
      followUpQuestionBuilders: {
        HealthMissingFact.patientIsChild: _qPatientChild,
      },
      destination: GuidanceDestination.specialtyFromCatalog('pediatrics'),
      rationaleCode: 'pediatrics_child_fever',
    ),

    // —— تعب غامض ——
    HealthGuidanceRule(
      id: 'fatigue_general',
      priority: 20,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'fatigue'),
      ],
      destination: GuidanceDestination.general,
      rationaleCode: 'fatigue_broad',
    ),
  ];
}
