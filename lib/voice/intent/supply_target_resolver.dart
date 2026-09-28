import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

enum SupplyTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class SupplyTargetResolution {
  const SupplyTargetResolution({
    required this.source,
    this.supply,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final SupplyTargetSource source;
  final SmartSearchResult? supply;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasSupply =>
      supply != null && supply!.type == SmartSearchResultType.supply;

  static const unresolved = SupplyTargetResolution(
    source: SupplyTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي محل مستلزمات تقصد؟ اذكر اسمه أو ابحث أولاً.',
  );
}

class SupplyTargetResolver {
  const SupplyTargetResolver();

  SupplyTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitName(entities.supply, normalized);
    if (explicit != null) {
      return SupplyTargetResolution(
        source: SupplyTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal =
        entities.resultIndex ?? ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedSupply;
    if (selected != null && selected.type == SmartSearchResultType.supply) {
      return SupplyTargetResolution(
        source: SupplyTargetSource.selectedContext,
        supply: selected,
      );
    }

    final items = context.authoritativeItemsFor(ConversationEntityType.supply);
    if (items.length == 1) {
      return SupplyTargetResolution(
        source: SupplyTargetSource.selectedContext,
        supply: items.first,
      );
    }
    if (items.length > 1) {
      return SupplyTargetResolution(
        source: SupplyTargetSource.unresolved,
        requiresClarification: true,
        candidates: items,
        message: 'أي محل تقصد؟ قل الأول أو الثاني أو الاسم.',
      );
    }
    return SupplyTargetResolution.unresolved;
  }

  SupplyTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    final items = context.authoritativeItemsFor(ConversationEntityType.supply);
    if (items.isEmpty) {
      return const SupplyTargetResolution(
        source: SupplyTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي قائمة مستلزمات حالياً. ابحث أولاً.',
      );
    }
    final idx = ordinal == -1 ? items.length - 1 : ordinal - 1;
    if (idx < 0 || idx >= items.length) {
      return SupplyTargetResolution(
        source: SupplyTargetSource.unresolved,
        requiresClarification: true,
        candidates: items,
        message: 'الرقم خارج القائمة. عندي ${items.length} محلات.',
      );
    }
    return SupplyTargetResolution(
      source: SupplyTargetSource.ordinal,
      supply: items[idx],
      resultIndex: ordinal,
    );
  }

  static bool _ordinalApplies(IntentResult intent) {
    switch (intent.intent) {
      case AssistantIntent.findSupply:
      case AssistantIntent.callSupply:
      case AssistantIntent.messageSupply:
      case AssistantIntent.showLocation:
      case AssistantIntent.showProfile:
      case AssistantIntent.selectResult:
      case AssistantIntent.callDoctor:
      case AssistantIntent.messageDoctor:
        return true;
      default:
        return intent.entities.resultIndex != null;
    }
  }

  static String? _explicitName(String? extracted, String normalized) {
    final fromEntity = (extracted ?? '').trim();
    if (fromEntity.isNotEmpty && !_rejectToken(fromEntity)) {
      return ArabicTextUtils.prepareSupplyNameQuery(fromEntity);
    }
    if (RegExp(
      r'(?:مستلزمات|تجهيزات|مواد\s*طبي|معدات\s*طبي)',
    ).hasMatch(ArabicTextUtils.normalize(normalized))) {
      return null;
    }
    return null;
  }

  static bool _rejectToken(String raw) {
    final n = ArabicTextUtils.normalize(raw).trim();
    return n.isEmpty ||
        n == 'عن' ||
        n == 'في' ||
        n == 'من' ||
        n == 'على' ||
        RegExp(
          r'^(?:مستلزمات|تجهيزات|مواد|معدات|طبيه|طبية|محل|محلات)$',
        ).hasMatch(n);
  }
}
