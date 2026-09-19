import 'symptom_models.dart';

/// مصدر كتالوج الأعراض — محلي الآن؛ قابل لاحقاً لـ Supabase بدون إعادة كتابة المحرك.
///
/// مخطط مستقبلي مقترح (لا ترحيل في Step 10B):
/// - symptoms(id, canonical_name_ar, enabled, display_order, …)
/// - symptom_aliases(symptom_id, alias, dialect, enabled)
abstract class SymptomCatalogSource {
  Future<List<SymptomConcept>> getEnabledSymptoms();

  Future<List<SymptomAliasEntry>> getEnabledAliases();

  Future<List<BodyRegionConcept>> getEnabledBodyRegions();
}

/// تنفيذ محلي متزامن للاختبارات والتشغيل على الجهاز.
abstract class SyncSymptomCatalogSource implements SymptomCatalogSource {
  const SyncSymptomCatalogSource();

  List<SymptomConcept> enabledSymptomsSync();

  List<SymptomAliasEntry> enabledAliasesSync();

  List<BodyRegionConcept> enabledBodyRegionsSync();

  @override
  Future<List<SymptomConcept>> getEnabledSymptoms() async =>
      enabledSymptomsSync();

  @override
  Future<List<SymptomAliasEntry>> getEnabledAliases() async =>
      enabledAliasesSync();

  @override
  Future<List<BodyRegionConcept>> getEnabledBodyRegions() async =>
      enabledBodyRegionsSync();
}
