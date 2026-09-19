import 'medical_safety_models.dart';

/// مصدر قواعد السلامة — محلي الآن؛ قابل لـ Supabase لاحقاً.
///
/// قواعد السلامة الطبية يجب ألا تُعدَّل كقواعد تسويق.
/// الحوكمة المستقبلية: enabled / reviewed / version / priority.
abstract class MedicalSafetyRuleSource {
  Future<List<MedicalSafetyRule>> getEnabledRules();
}

abstract class SyncMedicalSafetyRuleSource implements MedicalSafetyRuleSource {
  const SyncMedicalSafetyRuleSource();

  List<MedicalSafetyRule> enabledRulesSync();

  @override
  Future<List<MedicalSafetyRule>> getEnabledRules() async =>
      enabledRulesSync();
}
