import '../../voice/guided_conversation/guided_conversation_models.dart';
import '../guidance/health_follow_up_models.dart';
import '../guidance/health_follow_up_question_catalog.dart';
import '../guidance/health_guidance_models.dart';
import '../understanding/symptom_models.dart';
import 'medical_safety_models.dart';
import 'medical_safety_rule_source.dart';

/// مجموعة صغيرة عالية الإشارة — ليست موسوعة طوارئ.
/// لا أسماء أطباء / مختبرات / باقات. لا تشخيصات مرضية.
class LocalMedicalSafetyRuleSource extends SyncMedicalSafetyRuleSource {
  const LocalMedicalSafetyRuleSource();

  static final GuidedQuestion severityChestBreathing =
      HealthFollowUpQuestionCatalog.withMeta(
    const GuidedQuestion(
      id: 'safety_severity_chest_breathing',
      type: GuidedQuestionType.singleChoice,
      prompt: 'شلون شدة الألم أو ضيق النفس؟',
      expectedAnswerType: GuidedAnswerType.singleChoice,
      options: [
        GuidedChoiceOption(id: 'mild', label: 'خفيف', aliases: ['بسيط']),
        GuidedChoiceOption(id: 'moderate', label: 'متوسط'),
        GuidedChoiceOption(
          id: 'severe',
          label: 'شديد',
          aliases: ['قوي', 'كلش قوي', 'ما اتحمله', 'كلش'],
        ),
      ],
    ),
    const HealthQuestionMeta(
      factKey: HealthFactKey.severity,
      purpose: HealthQuestionPurpose.severity,
      missingFact: HealthMissingFact.severity,
      clarificationPrompt: 'أقصد شدة الألم أو الضيق: خفيف أو متوسط أو شديد.',
      whyExplanation:
          'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
    ),
  );

  static final GuidedQuestion breathingWithChest =
      HealthFollowUpQuestionCatalog.withMeta(
    const GuidedQuestion(
      id: 'safety_associated_breathing',
      type: GuidedQuestionType.yesNo,
      prompt: 'عندك ضيق نفس مع ألم الصدر؟',
      expectedAnswerType: GuidedAnswerType.yesNo,
    ),
    const HealthQuestionMeta(
      factKey: HealthFactKey.symptomPresence,
      purpose: HealthQuestionPurpose.symptomPresence,
      symptomConceptId: 'shortness_of_breath',
      clarificationPrompt: 'أقصد هل تحس بضيق في التنفس حالياً: نعم أو لا.',
      whyExplanation:
          'حتى أفهم وصف الأعراض بشكل أدق وأحدد نوع التوجيه المناسب.',
    ),
  );

  @override
  List<MedicalSafetyRule> enabledRulesSync() => List.unmodifiable(_rules);

  static final List<MedicalSafetyRule> _rules = [
    // 1) ألم صدر + ضيق نفس + شدة شديدة → تقييم عاجل (منقول من 10C)
    MedicalSafetyRule(
      id: 'safety_chest_breathing_severe',
      priority: 1000,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'chest_pain'),
        SymptomRequirement(conceptId: 'shortness_of_breath'),
      ],
      minSeverity: UserStatedSeverity.severe,
      severityConceptIds: const ['chest_pain', 'shortness_of_breath'],
      missingFactsIfIncomplete: const [HealthMissingFact.severity],
      followUpQuestionBuilders: {
        HealthMissingFact.severity: severityChestBreathing,
      },
      missingSymptomQuestions: {
        'shortness_of_breath': breathingWithChest,
        'chest_pain': breathingWithChest,
      },
      responseCategory: MedicalSafetyResponseCategory.urgentEvaluation,
      rationaleCode: 'safety_chest_dyspnea_severe',
    ),

    // 2) ضيق نفس شديد صريح وحدها
    MedicalSafetyRule(
      id: 'safety_severe_breathing',
      priority: 920,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'shortness_of_breath'),
      ],
      minSeverity: UserStatedSeverity.severe,
      severityConceptIds: const ['shortness_of_breath'],
      missingFactsIfIncomplete: const [HealthMissingFact.severity],
      followUpQuestionBuilders: {
        HealthMissingFact.severity: severityChestBreathing,
      },
      responseCategory: MedicalSafetyResponseCategory.urgentEvaluation,
      rationaleCode: 'safety_severe_dyspnea',
    ),

    // 3) ضعف مفاجئ بجهة واحدة → طوارئ (ليس «جلطة»)
    MedicalSafetyRule(
      id: 'safety_sudden_unilateral_weakness',
      priority: 980,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'weakness'),
      ],
      requireOnset: OnsetPattern.sudden,
      requireKnownLaterality: true,
      lateralityConceptId: 'weakness',
      missingFactsIfIncomplete: const [
        HealthMissingFact.onset,
        HealthMissingFact.laterality,
      ],
      followUpQuestionBuilders: {
        HealthMissingFact.onset: HealthFollowUpQuestionCatalog.onset(
          symptomConceptId: 'weakness',
        ),
        HealthMissingFact.laterality:
            HealthFollowUpQuestionCatalog.abdominalLocation(
          symptomConceptId: 'weakness',
        ),
      },
      responseCategory: MedicalSafetyResponseCategory.emergencyEvaluation,
      rationaleCode: 'safety_sudden_unilateral_weakness',
    ),

    // 4) فقدان وعي صريح
    MedicalSafetyRule(
      id: 'safety_loss_of_consciousness',
      priority: 990,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'loss_of_consciousness'),
      ],
      responseCategory: MedicalSafetyResponseCategory.emergencyEvaluation,
      rationaleCode: 'safety_loss_of_consciousness',
    ),

    // 5) نوبة تشنج صريحة
    MedicalSafetyRule(
      id: 'safety_seizure',
      priority: 985,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'seizure'),
      ],
      responseCategory: MedicalSafetyResponseCategory.emergencyEvaluation,
      rationaleCode: 'safety_seizure',
    ),

    // 6) نزيف نشط شديد
    MedicalSafetyRule(
      id: 'safety_severe_active_bleeding',
      priority: 970,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'active_bleeding'),
      ],
      minSeverity: UserStatedSeverity.severe,
      severityConceptIds: const ['active_bleeding'],
      missingFactsIfIncomplete: const [HealthMissingFact.severity],
      followUpQuestionBuilders: {
        HealthMissingFact.severity: HealthFollowUpQuestionCatalog.severity(
          symptomConceptId: 'active_bleeding',
        ),
      },
      responseCategory: MedicalSafetyResponseCategory.urgentEvaluation,
      rationaleCode: 'safety_severe_active_bleeding',
    ),

    // 7) بطن يمين + حرارة + استفراغ → تقييم عاجل (ليس «زائدة»)
    MedicalSafetyRule(
      id: 'safety_rlq_abdomen_fever_vomiting',
      priority: 880,
      reviewed: true,
      version: 1,
      requiredSymptoms: const [
        SymptomRequirement(conceptId: 'abdominal_pain'),
        SymptomRequirement(conceptId: 'fever'),
        SymptomRequirement(conceptId: 'vomiting'),
      ],
      requireKnownLaterality: true,
      requireLateralitySide: Laterality.right,
      lateralityConceptId: 'abdominal_pain',
      missingFactsIfIncomplete: const [
        HealthMissingFact.abdominalLocationDetail,
      ],
      followUpQuestionBuilders: {
        HealthMissingFact.abdominalLocationDetail:
            HealthFollowUpQuestionCatalog.abdominalLocation(
          symptomConceptId: 'abdominal_pain',
        ),
      },
      responseCategory: MedicalSafetyResponseCategory.urgentEvaluation,
      rationaleCode: 'safety_rlq_abdomen_fever_vomiting',
    ),
  ];
}
