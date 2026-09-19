import '../search/smart_search_models.dart';
import 'conversation_context.dart';
import 'intent/assistant_intent.dart';

/// ثقة حتمية لحل مرجعي — ليست احتمالية AI.
enum ReferenceConfidence {
  explicit,
  strongContext,
  relationshipContext,
  ambiguous,
  unresolved,
}

/// سياق نتائج مطبوع النوع — يمنع تسرّب الأرقام الترتيبية بين أنواع الكيانات.
///
/// PC-0.2 invariant: Conversation ordinals resolve against the latest
/// authoritative typed ResultContext, never a legacy/display cache.
class ResultContext {
  const ResultContext({
    required this.entityType,
    required this.items,
    this.sourceIntent,
    required this.turnId,
  });

  final ConversationEntityType entityType;
  final List<SmartSearchResult> items;
  final AssistantIntent? sourceIntent;
  final int turnId;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get length => items.length;

  SmartSearchResult? atOrdinal(int oneBased) {
    if (oneBased == -1) {
      return items.isEmpty ? null : items.last;
    }
    if (oneBased < 1 || oneBased > items.length) return null;
    return items[oneBased - 1];
  }

  ResultContext copyWithItems(List<SmartSearchResult> next) => ResultContext(
        entityType: entityType,
        items: List<SmartSearchResult>.unmodifiable(next),
        sourceIntent: sourceIntent,
        turnId: turnId,
      );
}

/// مرجع كيان حديث محدود — للعودة الصريحة وعبور العلاقات بدون تاريخ غير محدود.
class RecentEntityReference {
  const RecentEntityReference({
    required this.entityType,
    required this.entityId,
    required this.payload,
    this.sourceIntent,
    this.relationFromPrevious,
    required this.turnId,
  });

  final ConversationEntityType entityType;
  final String entityId;
  final SmartSearchResult payload;
  final AssistantIntent? sourceIntent;
  final String? relationFromPrevious;
  final int turnId;
}

/// توافق نوع الكيان مع فعل محادثة — حتمي بدون استدلال طبي.
class EntityActionCompatibility {
  const EntityActionCompatibility._();

  static bool supportsCall(ConversationEntityType t) =>
      t == ConversationEntityType.doctor ||
      t == ConversationEntityType.laboratory;

  static bool supportsWhatsApp(ConversationEntityType t) =>
      t == ConversationEntityType.doctor ||
      t == ConversationEntityType.laboratory;

  static bool supportsLocation(ConversationEntityType t) =>
      t == ConversationEntityType.doctor ||
      t == ConversationEntityType.laboratory ||
      t == ConversationEntityType.package; // → مختبر أب

  static bool supportsPrice(ConversationEntityType t) =>
      t == ConversationEntityType.package;

  static bool supportsAnalysesList(ConversationEntityType t) =>
      t == ConversationEntityType.package ||
      t == ConversationEntityType.laboratory;

  static bool supportsPackagesList(ConversationEntityType t) =>
      t == ConversationEntityType.laboratory ||
      t == ConversationEntityType.analysis;

  static ConversationEntityType? fromResultType(SmartSearchResultType type) {
    switch (type) {
      case SmartSearchResultType.doctor:
        return ConversationEntityType.doctor;
      case SmartSearchResultType.lab:
        return ConversationEntityType.laboratory;
      case SmartSearchResultType.analysis:
        return ConversationEntityType.analysis;
      case SmartSearchResultType.package:
      case SmartSearchResultType.offer:
        return ConversationEntityType.package;
      case SmartSearchResultType.specialty:
        return null;
    }
  }
}
