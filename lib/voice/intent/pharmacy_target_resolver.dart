import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

/// مصدر هدف الصيدلية.
enum PharmacyTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class PharmacyTargetResolution {
  const PharmacyTargetResolution({
    required this.source,
    this.pharmacy,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final PharmacyTargetSource source;
  final SmartSearchResult? pharmacy;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasPharmacy =>
      pharmacy != null && pharmacy!.type == SmartSearchResultType.pharmacy;

  bool get isResolved =>
      source == PharmacyTargetSource.explicitName ||
      source == PharmacyTargetSource.ordinal ||
      source == PharmacyTargetSource.selectedContext;

  static const unresolved = PharmacyTargetResolution(
    source: PharmacyTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي صيدلية تقصد؟ اذكر اسمها أو ابحث أولاً.',
  );
}

/// حل هدف الصيدلية: اسم صريح → ترتيب → سياق محدد → غير محلول.
class PharmacyTargetResolver {
  const PharmacyTargetResolver();

  PharmacyTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitPharmacyName(entities.pharmacy, normalized);
    if (explicit != null) {
      return PharmacyTargetResolution(
        source: PharmacyTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal = entities.resultIndex ??
        ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedPharmacy;
    if (selected != null && selected.type == SmartSearchResultType.pharmacy) {
      return PharmacyTargetResolution(
        source: PharmacyTargetSource.selectedContext,
        pharmacy: selected,
      );
    }

    final sole = _solePharmacy(context);
    if (sole != null) {
      context.selectPharmacy(sole);
      return PharmacyTargetResolution(
        source: PharmacyTargetSource.selectedContext,
        pharmacy: sole,
      );
    }

    if (_isPharmacyAction(intentResult.intent) ||
        context.activeEntityType == ConversationEntityType.pharmacy) {
      return PharmacyTargetResolution(
        source: PharmacyTargetSource.unresolved,
        requiresClarification: true,
        candidates: context.authoritativeItemsFor(
          ConversationEntityType.pharmacy,
        ),
        message: PharmacyTargetResolution.unresolved.message,
      );
    }

    return PharmacyTargetResolution.unresolved;
  }

  bool _ordinalApplies(IntentResult intent) {
    return intent.intent == AssistantIntent.selectResult ||
        intent.isActionIntent ||
        _isPharmacyAction(intent.intent);
  }

  PharmacyTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    final list =
        context.authoritativeItemsFor(ConversationEntityType.pharmacy);

    if (list.isEmpty) {
      return const PharmacyTargetResolution(
        source: PharmacyTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي نتائج صيدليات سابقة. ابحث عن صيدلية أولاً.',
      );
    }

    final index = ordinal == -1 ? list.length : ordinal;
    if (index < 1 || index > list.length) {
      final n = list.length;
      return PharmacyTargetResolution(
        source: PharmacyTargetSource.unresolved,
        requiresClarification: true,
        resultIndex: ordinal,
        candidates: list,
        message: n == 2
            ? 'عندي خياران فقط. تقصد الأول أم الثاني؟'
            : 'الرقم خارج النطاق. اختر من 1 إلى $n.',
      );
    }

    final chosen = list[index - 1];
    context.selectPharmacy(chosen);
    return PharmacyTargetResolution(
      source: PharmacyTargetSource.ordinal,
      pharmacy: chosen,
      resultIndex: index,
    );
  }

  static SmartSearchResult? _solePharmacy(ConversationContext context) {
    final list =
        context.authoritativeItemsFor(ConversationEntityType.pharmacy);
    if (list.length == 1) return list.first;
    return null;
  }

  /// يستخرج اسم صيدلية حقيقي — بدون كلمة «صيدلية» وأفعال/ضجيج الاتصال.
  static String? _explicitPharmacyName(String? raw, String normalizedFull) {
    var cleaned = ArabicTextUtils.preparePharmacyNameQuery(raw ?? '');
    if (cleaned.isEmpty) {
      final m = RegExp(r'(?:ال)?(?:صيدليه|صيدلية|صيدليات)\s+(.+)$')
          .firstMatch(normalizedFull);
      cleaned = ArabicTextUtils.preparePharmacyNameQuery(m?.group(1) ?? '');
    }
    if (cleaned.isEmpty || cleaned.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|وياه|هذا|هاي|الاول|الأول|الثاني|الثالث|الرابع|الخامس|عن|في|من|الى|إلى)$',
    ).hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  static bool _isPharmacyAction(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.findPharmacy:
      case AssistantIntent.callPharmacy:
      case AssistantIntent.messagePharmacy:
        return true;
      default:
        return false;
    }
  }
}
