import 'conversation_conduct_models.dart';

/// مصدر كتالوج السلوك — محلي الآن؛ قابل لإعداد مضبوط لاحقاً.
abstract class ConversationConductCatalogSource {
  Future<List<ConductCatalogEntry>> getEnabledEntries();
}

abstract class SyncConversationConductCatalogSource
    implements ConversationConductCatalogSource {
  const SyncConversationConductCatalogSource();

  List<ConductCatalogEntry> enabledEntriesSync();

  @override
  Future<List<ConductCatalogEntry>> getEnabledEntries() async =>
      enabledEntriesSync();
}
