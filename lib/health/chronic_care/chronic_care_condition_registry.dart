import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'chronic_care_models.dart';

/// سجل تعريفات الحالات المزمنة — قابل للتمديد بلا دماغ منفصل لكل مرض.
class ChronicCareConditionRegistry {
  const ChronicCareConditionRegistry();

  static final diabetes = ChronicCareConditionDefinition(
    canonicalKey: HealthCanonicalConditionKey.diabetes.name,
    displayNameAr: 'السكري',
    aliases: const ['سكري', 'السكري', 'سكر'],
    supportedMeasurementTypes: const [
      ChronicMeasurementType.bloodGlucose,
      ChronicMeasurementType.fastingGlucose,
      ChronicMeasurementType.postMealGlucose,
      ChronicMeasurementType.hba1c,
    ],
    followUpQuestionOrder: const [
      ChronicCareQuestionKind.recentStatus,
      ChronicCareQuestionKind.lastMeasurement,
      ChronicCareQuestionKind.controlStatus,
      ChronicCareQuestionKind.lastFollowUp,
      ChronicCareQuestionKind.doctorFollowUp,
    ],
  );

  static final hypertension = ChronicCareConditionDefinition(
    canonicalKey: HealthCanonicalConditionKey.hypertension.name,
    displayNameAr: 'ارتفاع ضغط الدم',
    aliases: const ['ضغط', 'الضغط', 'ارتفاع ضغط'],
    supportedMeasurementTypes: const [
      ChronicMeasurementType.bloodPressure,
    ],
    followUpQuestionOrder: const [
      ChronicCareQuestionKind.recentStatus,
      ChronicCareQuestionKind.lastMeasurement,
      ChronicCareQuestionKind.controlStatus,
      ChronicCareQuestionKind.lastFollowUp,
      ChronicCareQuestionKind.doctorFollowUp,
    ],
  );

  List<ChronicCareConditionDefinition> get all => [
        diabetes,
        hypertension,
      ];

  ChronicCareConditionDefinition? byKey(String key) {
    for (final d in all) {
      if (d.canonicalKey == key) return d;
    }
    return null;
  }

  ChronicCareConditionDefinition? matchAlias(String normalized) {
    for (final d in all) {
      for (final a in d.aliases) {
        if (normalized.contains(a)) return d;
      }
    }
    return null;
  }
}
