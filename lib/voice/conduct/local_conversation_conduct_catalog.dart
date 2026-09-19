import 'conversation_conduct_catalog_source.dart';
import 'conversation_conduct_models.dart';

/// كتالوج صغير حتمي — ليس رقابة على اللهجة العراقية الطبيعية.
class LocalConversationConductCatalogSource
    extends SyncConversationConductCatalogSource {
  const LocalConversationConductCatalogSource();

  @override
  List<ConductCatalogEntry> enabledEntriesSync() => List.unmodifiable(_entries);

  static final List<ConductCatalogEntry> _entries = [
    const ConductCatalogEntry(
      id: 'insult_ghabi',
      category: ConversationConductCategory.directInsult,
      level: ConversationConductLevel.abusive,
      patterns: ['غبي', 'غبيه', 'غبية', 'يا غبي', 'يا غبية'],
    ),
    const ConductCatalogEntry(
      id: 'insult_ahmaq',
      category: ConversationConductCategory.directInsult,
      level: ConversationConductLevel.abusive,
      patterns: ['احمق', 'أحمق', 'يا احمق', 'يا أحمق'],
    ),
    const ConductCatalogEntry(
      id: 'insult_himar',
      category: ConversationConductCategory.directInsult,
      level: ConversationConductLevel.abusive,
      patterns: ['حمار', 'يا حمار'],
    ),
    const ConductCatalogEntry(
      id: 'insult_kalb',
      category: ConversationConductCategory.directInsult,
      level: ConversationConductLevel.abusive,
      patterns: ['كلب', 'چلب', 'يا كلب', 'يا چلب'],
    ),
    const ConductCatalogEntry(
      id: 'insult_tihish',
      category: ConversationConductCategory.degrading,
      level: ConversationConductLevel.abusive,
      patterns: ['تافه', 'يا تافه', 'حقير', 'يا حقير'],
    ),
    const ConductCatalogEntry(
      id: 'insult_app',
      category: ConversationConductCategory.directInsult,
      level: ConversationConductLevel.rude,
      patterns: [
        'تطبيق غبي',
        'التطبيق غبي',
        'تطبيقكم غبي',
        'هذا التطبيق غبي',
      ],
      requiresSecondPersonCue: false,
    ),
    const ConductCatalogEntry(
      id: 'severe_curse_family',
      category: ConversationConductCategory.degrading,
      level: ConversationConductLevel.severeAbuse,
      patterns: [
        'يلعن',
        'انعل',
        'انعل ابو',
        'انيك',
        'كس ام',
        'كس اخت',
      ],
    ),
    const ConductCatalogEntry(
      id: 'sexual_vulgar',
      category: ConversationConductCategory.sexualVulgarity,
      level: ConversationConductLevel.severeAbuse,
      patterns: ['شرموطة', 'قحبة', 'عرص'],
    ),
  ];
}
