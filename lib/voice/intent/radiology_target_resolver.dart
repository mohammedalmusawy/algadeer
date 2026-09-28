import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

/// مصدر هدف الأشعة.
enum RadiologyTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class RadiologyTargetResolution {
  const RadiologyTargetResolution({
    required this.source,
    this.radiology,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final RadiologyTargetSource source;
  final SmartSearchResult? radiology;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasRadiology =>
      radiology != null && radiology!.type == SmartSearchResultType.radiology;

  bool get isResolved =>
      source == RadiologyTargetSource.explicitName ||
      source == RadiologyTargetSource.ordinal ||
      source == RadiologyTargetSource.selectedContext;

  static const unresolved = RadiologyTargetResolution(
    source: RadiologyTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي مركز أشعة تقصد؟ اذكر اسمه أو ابحث أولاً.',
  );
}

/// حل هدف الأشعة: اسم صريح → ترتيب → سياق محدد → غير محلول.
class RadiologyTargetResolver {
  const RadiologyTargetResolver();

  RadiologyTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitRadiologyName(entities.radiology, normalized);
    if (explicit != null) {
      return RadiologyTargetResolution(
        source: RadiologyTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal = entities.resultIndex ??
        ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedRadiology;
    if (selected != null && selected.type == SmartSearchResultType.radiology) {
      return RadiologyTargetResolution(
        source: RadiologyTargetSource.selectedContext,
        radiology: selected,
      );
    }

    final sole = _soleRadiology(context);
    if (sole != null) {
      context.selectRadiology(sole);
      return RadiologyTargetResolution(
        source: RadiologyTargetSource.selectedContext,
        radiology: sole,
      );
    }

    if (_isRadiologyAction(intentResult.intent) ||
        context.activeEntityType == ConversationEntityType.radiology) {
      return RadiologyTargetResolution(
        source: RadiologyTargetSource.unresolved,
        requiresClarification: true,
        candidates: context.authoritativeItemsFor(
          ConversationEntityType.radiology,
        ),
        message: RadiologyTargetResolution.unresolved.message,
      );
    }

    return RadiologyTargetResolution.unresolved;
  }

  bool _ordinalApplies(IntentResult intent) {
    return intent.intent == AssistantIntent.selectResult ||
        intent.isActionIntent ||
        _isRadiologyAction(intent.intent);
  }

  RadiologyTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    // PC-0.2: clarification صريحة أو ResultContext — بلا lastLabSnapshot.
    final list =
        context.authoritativeItemsFor(ConversationEntityType.radiology);

    if (list.isEmpty) {
      return const RadiologyTargetResolution(
        source: RadiologyTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي نتائج أشعة سابقة. ابحث عن مركز أشعة أولاً.',
      );
    }

    final index = ordinal == -1 ? list.length : ordinal;
    if (index < 1 || index > list.length) {
      final n = list.length;
      return RadiologyTargetResolution(
        source: RadiologyTargetSource.unresolved,
        requiresClarification: true,
        resultIndex: ordinal,
        candidates: list,
        message: n == 2
            ? 'عندي خياران فقط. تقصد الأول أم الثاني؟'
            : 'الرقم خارج النطاق. اختر من 1 إلى $n.',
      );
    }

    final chosen = list[index - 1];
    context.selectRadiology(chosen);
    return RadiologyTargetResolution(
      source: RadiologyTargetSource.ordinal,
      radiology: chosen,
      resultIndex: index,
    );
  }

  static SmartSearchResult? _soleRadiology(ConversationContext context) {
    final labs =
        context.authoritativeItemsFor(ConversationEntityType.radiology);
    if (labs.length == 1) return labs.first;
    return null;
  }

  /// يستخرج اسم أشعة حقيقي — بدون كلمة «أشعة» وأفعال/ضجيج الاتصال.
  static String? _explicitRadiologyName(String? raw, String normalizedFull) {
    var cleaned = ArabicTextUtils.prepareRadiologyNameQuery(raw ?? '');
    if (cleaned.isEmpty) {
      final m = RegExp(r'(?:ال)?(?:اشعه|اشعة|أشعة)\s+(.+)$')
          .firstMatch(normalizedFull);
      cleaned = ArabicTextUtils.prepareRadiologyNameQuery(m?.group(1) ?? '');
    }
    if (cleaned.isEmpty || cleaned.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|وياه|هذا|هاي|الاول|الأول|الثاني|الثالث|الرابع|الخامس)$',
    ).hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  static bool _isRadiologyAction(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.findRadiology:
      case AssistantIntent.callRadiology:
      case AssistantIntent.messageRadiology:
        return true;
      default:
        return false;
    }
  }
}
