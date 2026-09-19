import 'health_guidance_models.dart';

/// مصدر قواعد التوجيه — محلي الآن؛ قابل لـ Supabase لاحقاً.
abstract class HealthGuidanceRuleSource {
  Future<List<HealthGuidanceRule>> getEnabledRules();
}

abstract class SyncHealthGuidanceRuleSource implements HealthGuidanceRuleSource {
  const SyncHealthGuidanceRuleSource();

  List<HealthGuidanceRule> enabledRulesSync();

  @override
  Future<List<HealthGuidanceRule>> getEnabledRules() async =>
      enabledRulesSync();
}
