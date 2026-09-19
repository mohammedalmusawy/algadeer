import 'preventive_evidence_metadata.dart';
import 'preventive_guidance_models.dart';

/// مصدر كتalog القواعد — قابل للاستبدال (محلي الآن).
abstract class PreventiveGuidanceCatalogSource {
  Future<List<PreventiveGuidanceRule>> loadActiveRules();

  Future<PreventiveGuidanceRule?> findById(String ruleId);
}

/// كتalog محلي مراجَع — لا يتطلب إنترنت.
class LocalPreventiveGuidanceCatalog implements PreventiveGuidanceCatalogSource {
  LocalPreventiveGuidanceCatalog({List<PreventiveGuidanceRule>? rules})
      : _rules = rules ?? _defaultRules;

  final List<PreventiveGuidanceRule> _rules;

  static final DateTime _reviewed = DateTime(2026, 1, 15);

  static final List<PreventiveGuidanceRule> _defaultRules = [
    // —— نشاط بدني عام (WHO-style) ——
    PreventiveGuidanceRule(
      ruleId: 'prev_activity_adult_general',
      topic: PreventiveGuidanceTopic.activity,
      sourceOrganization: 'WHO',
      sourceReference: 'Physical activity guidelines for adults',
      sourceVersionOrDate: '2020',
      reviewedAt: _reviewed,
      applicablePopulation: 'general_adults_18_plus',
      minimumAge: 18,
      guidanceType: PreventiveGuidanceType.physicalActivity,
      personalizationLevel: PreventivePersonalizationLevel.general,
      presentationKey: 'activity_moderate_weekly',
      priority: 80,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_walking_practical_example',
      topic: PreventiveGuidanceTopic.walking,
      sourceOrganization: 'WHO',
      sourceReference: 'Walking as moderate aerobic activity example',
      sourceVersionOrDate: '2020',
      reviewedAt: _reviewed,
      applicablePopulation: 'general_adults',
      minimumAge: 18,
      guidanceType: PreventiveGuidanceType.physicalActivity,
      personalizationLevel: PreventivePersonalizationLevel.general,
      presentationKey: 'walking_example_not_prescription',
      priority: 75,
    ),
    // —— تغذية صحية عامة ——
    PreventiveGuidanceRule(
      ruleId: 'prev_diet_general_adult',
      topic: PreventiveGuidanceTopic.diet,
      sourceOrganization: 'WHO',
      sourceReference: 'Healthy diet fact sheet',
      sourceVersionOrDate: '2023',
      reviewedAt: _reviewed,
      applicablePopulation: 'general_adults',
      minimumAge: 18,
      guidanceType: PreventiveGuidanceType.healthyDiet,
      personalizationLevel: PreventivePersonalizationLevel.general,
      presentationKey: 'diet_balanced_patterns',
      priority: 70,
    ),
    // —— ملح ——
    PreventiveGuidanceRule(
      ruleId: 'prev_salt_general_adult',
      topic: PreventiveGuidanceTopic.salt,
      sourceOrganization: 'WHO',
      sourceReference: 'Salt reduction (<5g/day adults)',
      sourceVersionOrDate: '2023',
      reviewedAt: _reviewed,
      applicablePopulation: 'general_adults_without_special_restriction',
      minimumAge: 18,
      guidanceType: PreventiveGuidanceType.saltReduction,
      personalizationLevel: PreventivePersonalizationLevel.general,
      presentationKey: 'salt_under_5g_general',
      priority: 65,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_salt_hypertension_context',
      topic: PreventiveGuidanceTopic.salt,
      sourceOrganization: 'WHO',
      sourceReference: 'Salt reduction in hypertension context',
      sourceVersionOrDate: '2023',
      reviewedAt: _reviewed,
      applicablePopulation: 'adults_with_hypertension',
      minimumAge: 18,
      requiredConditionKeys: {'hypertension'},
      guidanceType: PreventiveGuidanceType.saltReduction,
      personalizationLevel: PreventivePersonalizationLevel.healthContextual,
      presentationKey: 'salt_hypertension_clinician_aware',
      priority: 85,
    ),
    // —— طالب ——
    PreventiveGuidanceRule(
      ruleId: 'prev_student_sleep_routine',
      topic: PreventiveGuidanceTopic.student,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Student sleep regularity guidance',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'students',
      requiredContext: {'student'},
      guidanceType: PreventiveGuidanceType.studentRoutine,
      personalizationLevel: PreventivePersonalizationLevel.contextual,
      presentationKey: 'student_sleep_balance',
      priority: 72,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_student_exam_routine',
      topic: PreventiveGuidanceTopic.examPeriod,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Exam period study/rest balance',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'students_exam_period',
      requiredContext: {'student'},
      guidanceType: PreventiveGuidanceType.examPeriodRoutine,
      personalizationLevel: PreventivePersonalizationLevel.contextual,
      presentationKey: 'student_exam_short_routine',
      priority: 78,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_student_movement',
      topic: PreventiveGuidanceTopic.student,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Student physical movement',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'students',
      requiredContext: {'student'},
      guidanceType: PreventiveGuidanceType.physicalActivity,
      personalizationLevel: PreventivePersonalizationLevel.contextual,
      presentationKey: 'student_movement_breaks',
      priority: 68,
    ),
    // —— موظف / عمل حر ——
    PreventiveGuidanceRule(
      ruleId: 'prev_employee_movement_breaks',
      topic: PreventiveGuidanceTopic.employeeRoutine,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Prolonged sitting movement breaks',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'office_workers_general',
      requiredContext: {'employee'},
      guidanceType: PreventiveGuidanceType.movementBreak,
      personalizationLevel: PreventivePersonalizationLevel.contextual,
      presentationKey: 'employee_sitting_breaks',
      priority: 74,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_selfemployed_routine',
      topic: PreventiveGuidanceTopic.selfEmployedRoutine,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Self-employed routine balance',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'self_employed_general',
      requiredContext: {'selfEmployed'},
      guidanceType: PreventiveGuidanceType.movementBreak,
      personalizationLevel: PreventivePersonalizationLevel.contextual,
      presentationKey: 'selfemployed_routine_balance',
      priority: 70,
    ),
    // —— فحوصات/نقاش ——
    PreventiveGuidanceRule(
      ruleId: 'prev_screening_bp_adult',
      topic: PreventiveGuidanceTopic.screening,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Blood pressure awareness screening discussion',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'adults_18_plus',
      minimumAge: 18,
      guidanceType: PreventiveGuidanceType.screeningDiscussion,
      personalizationLevel: PreventivePersonalizationLevel.clinicianRequired,
      presentationKey: 'screening_bp_discuss_with_doctor',
      priority: 60,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_screening_age_contextual',
      topic: PreventiveGuidanceTopic.screening,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Age-appropriate screening discussion',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'adults_with_known_age',
      minimumAge: 40,
      guidanceType: PreventiveGuidanceType.screeningDiscussion,
      personalizationLevel: PreventivePersonalizationLevel.clinicianRequired,
      presentationKey: 'screening_age_discuss_not_diagnosis',
      priority: 55,
    ),
    PreventiveGuidanceRule(
      ruleId: 'prev_screening_metabolic_risk',
      topic: PreventiveGuidanceTopic.screening,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Metabolic risk screening discussion',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'adults_with_diabetes_context',
      minimumAge: 18,
      requiredConditionKeys: {'diabetes'},
      guidanceType: PreventiveGuidanceType.screeningDiscussion,
      personalizationLevel: PreventivePersonalizationLevel.clinicianRequired,
      presentationKey: 'screening_metabolic_discuss',
      priority: 58,
    ),
    // —— ضغط دم وعي ——
    PreventiveGuidanceRule(
      ruleId: 'prev_bp_awareness_general',
      topic: PreventiveGuidanceTopic.ageAppropriate,
      sourceOrganization: 'Ghadeer Preventive Review',
      sourceReference: 'Blood pressure awareness general',
      sourceVersionOrDate: '2026-01',
      reviewedAt: _reviewed,
      applicablePopulation: 'adults_with_known_age',
      minimumAge: 30,
      guidanceType: PreventiveGuidanceType.screeningDiscussion,
      personalizationLevel: PreventivePersonalizationLevel.contextual,
      presentationKey: 'bp_awareness_age_context',
      priority: 52,
    ),
    // —— تبغ ——
    PreventiveGuidanceRule(
      ruleId: 'prev_tobacco_avoidance',
      topic: PreventiveGuidanceTopic.general,
      sourceOrganization: 'WHO',
      sourceReference: 'Tobacco cessation public health',
      sourceVersionOrDate: '2023',
      reviewedAt: _reviewed,
      applicablePopulation: 'general_adults',
      minimumAge: 18,
      guidanceType: PreventiveGuidanceType.tobaccoAvoidance,
      personalizationLevel: PreventivePersonalizationLevel.general,
      presentationKey: 'tobacco_avoidance_general',
      priority: 40,
    ),
  ];

  @override
  Future<List<PreventiveGuidanceRule>> loadActiveRules() async {
    return _rules.where((r) => r.isActive).toList(growable: false);
  }

  @override
  Future<PreventiveGuidanceRule?> findById(String ruleId) async {
    for (final r in _rules) {
      if (r.ruleId == ruleId) return r;
    }
    return null;
  }
}
