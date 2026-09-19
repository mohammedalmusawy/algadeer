import '../../models/lab_models.dart';
import '../../search/analysis_name_matcher.dart';
import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

enum AnalysisTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class AnalysisTargetResolution {
  const AnalysisTargetResolution({
    required this.source,
    this.analysis,
    this.analysisItem,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final AnalysisTargetSource source;
  final SmartSearchResult? analysis;
  final AnalysisItem? analysisItem;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasAnalysis =>
      analysis != null && analysis!.type == SmartSearchResultType.analysis;

  bool get isResolved =>
      source == AnalysisTargetSource.explicitName ||
      source == AnalysisTargetSource.ordinal ||
      source == AnalysisTargetSource.selectedContext;

  static const unresolved = AnalysisTargetResolution(
    source: AnalysisTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي تحليل تقصد؟ اذكر اسم التحليل أو اختصاره أولاً.',
  );
}

/// حل هدف التحليل: اسم صريح → ترتيب → سياق محدد → غير محلول.
class AnalysisTargetResolver {
  const AnalysisTargetResolver();

  AnalysisTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitAnalysisName(entities.analysis, normalized);
    if (explicit != null) {
      return AnalysisTargetResolution(
        source: AnalysisTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal = entities.resultIndex ??
        ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedAnalysis;
    if (selected != null && selected.type == SmartSearchResultType.analysis) {
      return AnalysisTargetResolution(
        source: AnalysisTargetSource.selectedContext,
        analysis: selected,
      );
    }

    final sole = _soleAnalysis(context);
    if (sole != null) {
      context.selectAnalysis(sole);
      return AnalysisTargetResolution(
        source: AnalysisTargetSource.selectedContext,
        analysis: sole,
      );
    }

    if (_isAnalysisAction(intentResult.intent) ||
        context.activeEntityType == ConversationEntityType.analysis) {
      return AnalysisTargetResolution(
        source: AnalysisTargetSource.unresolved,
        requiresClarification: true,
        candidates: context.authoritativeItemsFor(
          ConversationEntityType.analysis,
        ),
        message: AnalysisTargetResolution.unresolved.message,
      );
    }

    return AnalysisTargetResolution.unresolved;
  }

  bool _ordinalApplies(IntentResult intent) {
    return intent.intent == AssistantIntent.selectResult ||
        intent.isActionIntent ||
        _isAnalysisAction(intent.intent);
  }

  AnalysisTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    final list =
        context.authoritativeItemsFor(ConversationEntityType.analysis);

    if (list.isEmpty) {
      return const AnalysisTargetResolution(
        source: AnalysisTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي نتائج تحاليل سابقة. ابحث عن تحليل أولاً.',
      );
    }

    final index = ordinal == -1 ? list.length : ordinal;
    if (index < 1 || index > list.length) {
      final n = list.length;
      return AnalysisTargetResolution(
        source: AnalysisTargetSource.unresolved,
        requiresClarification: true,
        resultIndex: ordinal,
        candidates: list,
        message: n == 2
            ? 'عندي خياران فقط. تقصد الأول أم الثاني؟'
            : 'الرقم خارج النطاق. اختر من 1 إلى $n.',
      );
    }

    final chosen = list[index - 1];
    context.selectAnalysis(chosen);
    return AnalysisTargetResolution(
      source: AnalysisTargetSource.ordinal,
      analysis: chosen,
      resultIndex: index,
    );
  }

  static SmartSearchResult? _soleAnalysis(ConversationContext context) {
    final list =
        context.authoritativeItemsFor(ConversationEntityType.analysis);
    if (list.length == 1) return list.first;
    return null;
  }

  static String? _explicitAnalysisName(String? raw, String normalizedFull) {
    var cleaned = (raw ?? '').trim();
    if (cleaned.isEmpty) {
      final m = RegExp(
        r'(?:ال)?تحليل\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(normalizedFull);
      cleaned = (m?.group(1) ?? '').trim();
    }
    cleaned = AnalysisNameMatcher().prepareQuery(cleaned);
    if (cleaned.isEmpty || cleaned.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|موجود|باقه|باقة|مختبر)$',
    ).hasMatch(ArabicTextUtils.normalize(cleaned))) {
      return null;
    }
    return cleaned;
  }

  static bool _isAnalysisAction(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.findAnalysis:
      case AssistantIntent.findPackage:
        return true;
      default:
        return false;
    }
  }

  static SmartSearchResult toSearchResult(AnalysisItem item) {
    final title = item.arabicDisplayName.isNotEmpty
        ? item.arabicDisplayName
        : item.displayLabel;
    return SmartSearchResult(
      type: SmartSearchResultType.analysis,
      title: title,
      subtitle: item.englishDisplayName.isNotEmpty
          ? item.englishDisplayName
          : 'تحليل',
      analysisId: item.id,
      bioSnippet: item.arabicDescriptionDisplay.isNotEmpty
          ? item.arabicDescriptionDisplay
          : null,
      score: 100,
    );
  }
}
