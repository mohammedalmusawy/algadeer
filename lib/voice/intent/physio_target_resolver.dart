import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

enum PhysioTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class PhysioTargetResolution {
  const PhysioTargetResolution({
    required this.source,
    this.physio,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final PhysioTargetSource source;
  final SmartSearchResult? physio;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasPhysio =>
      physio != null && physio!.type == SmartSearchResultType.physio;

  static const unresolved = PhysioTargetResolution(
    source: PhysioTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي مركز علاج طبيعي تقصد؟ اذكر اسمه أو ابحث أولاً.',
  );
}

class PhysioTargetResolver {
  const PhysioTargetResolver();

  PhysioTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitName(entities.physio, normalized);
    if (explicit != null) {
      return PhysioTargetResolution(
        source: PhysioTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal =
        entities.resultIndex ?? ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedPhysio;
    if (selected != null && selected.type == SmartSearchResultType.physio) {
      return PhysioTargetResolution(
        source: PhysioTargetSource.selectedContext,
        physio: selected,
      );
    }

    final items = context.authoritativeItemsFor(ConversationEntityType.physio);
    if (items.length == 1) {
      return PhysioTargetResolution(
        source: PhysioTargetSource.selectedContext,
        physio: items.first,
      );
    }
    if (items.length > 1) {
      return PhysioTargetResolution(
        source: PhysioTargetSource.unresolved,
        requiresClarification: true,
        candidates: items,
        message: 'أي مركز تقصد؟ قل الأول أو الثاني أو الاسم.',
      );
    }
    return PhysioTargetResolution.unresolved;
  }

  PhysioTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    final items = context.authoritativeItemsFor(ConversationEntityType.physio);
    if (items.isEmpty) {
      return const PhysioTargetResolution(
        source: PhysioTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي قائمة مراكز حالياً. ابحث أولاً عن علاج طبيعي.',
      );
    }
    final idx = ordinal == -1 ? items.length - 1 : ordinal - 1;
    if (idx < 0 || idx >= items.length) {
      return PhysioTargetResolution(
        source: PhysioTargetSource.unresolved,
        requiresClarification: true,
        candidates: items,
        message: 'الرقم خارج القائمة. عندي ${items.length} مراكز.',
      );
    }
    return PhysioTargetResolution(
      source: PhysioTargetSource.ordinal,
      physio: items[idx],
      resultIndex: ordinal,
    );
  }

  static bool _ordinalApplies(IntentResult intent) {
    switch (intent.intent) {
      case AssistantIntent.findPhysio:
      case AssistantIntent.callPhysio:
      case AssistantIntent.messagePhysio:
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
      return ArabicTextUtils.preparePhysioNameQuery(fromEntity);
    }
    // لا نستخرج اسماً من جملة بحث عامة بلا كيان صريح.
    if (RegExp(
      r'(?:علاج\s*طبيعي|فيزيو|تاهيل|تأهيل)',
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
        RegExp(r'^(?:علاج|طبيعي|فيزيو|تاهيل|تأهيل|مركز|مراكز)$').hasMatch(n);
  }
}
