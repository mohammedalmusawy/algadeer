import '../../search/arabic_text_utils.dart';
import '../../search/smart_search_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

/// مصدر هدف المختبر.
enum LaboratoryTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class LaboratoryTargetResolution {
  const LaboratoryTargetResolution({
    required this.source,
    this.laboratory,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final LaboratoryTargetSource source;
  final SmartSearchResult? laboratory;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasLab =>
      laboratory != null && laboratory!.type == SmartSearchResultType.lab;

  bool get isResolved =>
      source == LaboratoryTargetSource.explicitName ||
      source == LaboratoryTargetSource.ordinal ||
      source == LaboratoryTargetSource.selectedContext;

  static const unresolved = LaboratoryTargetResolution(
    source: LaboratoryTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي مختبر تقصد؟ ابحث عن المختبر أو اذكر اسمه أولاً.',
  );
}

/// حل هدف المختبر: اسم صريح → ترتيب → سياق محدد → غير محلول.
class LaboratoryTargetResolver {
  const LaboratoryTargetResolver();

  LaboratoryTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitLabName(entities.laboratory, normalized);
    if (explicit != null) {
      return LaboratoryTargetResolution(
        source: LaboratoryTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal = entities.resultIndex ??
        ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedLaboratory;
    if (selected != null && selected.type == SmartSearchResultType.lab) {
      return LaboratoryTargetResolution(
        source: LaboratoryTargetSource.selectedContext,
        laboratory: selected,
      );
    }

    final sole = _soleLab(context);
    if (sole != null) {
      context.selectLaboratory(sole);
      return LaboratoryTargetResolution(
        source: LaboratoryTargetSource.selectedContext,
        laboratory: sole,
      );
    }

    if (_isLabAction(intentResult.intent) ||
        context.activeEntityType == ConversationEntityType.laboratory) {
      return LaboratoryTargetResolution(
        source: LaboratoryTargetSource.unresolved,
        requiresClarification: true,
        candidates: context.authoritativeItemsFor(
          ConversationEntityType.laboratory,
        ),
        message: LaboratoryTargetResolution.unresolved.message,
      );
    }

    return LaboratoryTargetResolution.unresolved;
  }

  bool _ordinalApplies(IntentResult intent) {
    return intent.intent == AssistantIntent.selectResult ||
        intent.isActionIntent ||
        _isLabAction(intent.intent);
  }

  LaboratoryTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    // PC-0.2: clarification صريحة أو ResultContext — بلا lastLabSnapshot.
    final list =
        context.authoritativeItemsFor(ConversationEntityType.laboratory);

    if (list.isEmpty) {
      return const LaboratoryTargetResolution(
        source: LaboratoryTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي نتائج مختبرات سابقة. ابحث عن مختبر أولاً.',
      );
    }

    final index = ordinal == -1 ? list.length : ordinal;
    if (index < 1 || index > list.length) {
      final n = list.length;
      return LaboratoryTargetResolution(
        source: LaboratoryTargetSource.unresolved,
        requiresClarification: true,
        resultIndex: ordinal,
        candidates: list,
        message: n == 2
            ? 'عندي خياران فقط. تقصد الأول أم الثاني؟'
            : 'الرقم خارج النطاق. اختر من 1 إلى $n.',
      );
    }

    final chosen = list[index - 1];
    context.selectLaboratory(chosen);
    return LaboratoryTargetResolution(
      source: LaboratoryTargetSource.ordinal,
      laboratory: chosen,
      resultIndex: index,
    );
  }

  static SmartSearchResult? _soleLab(ConversationContext context) {
    final labs =
        context.authoritativeItemsFor(ConversationEntityType.laboratory);
    if (labs.length == 1) return labs.first;
    return null;
  }

  /// يستخرج اسم مختبر حقيقي — بدون كلمة «مختبر» وأفعال الإجراء.
  static String? _explicitLabName(String? raw, String normalizedFull) {
    var cleaned = ArabicTextUtils.normalize((raw ?? '').trim());
    if (cleaned.isEmpty) {
      final m = RegExp(r'(?:ال)?مختبر\s+(.+)$').firstMatch(normalizedFull);
      cleaned = ArabicTextUtils.normalize((m?.group(1) ?? '').trim());
    }
    cleaned = cleaned
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:مختبر|مختبرات)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|وياه|هذا|هاي|الاول|الأول|الثاني|الثالث|الرابع|الخامس)$',
    ).hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  static bool _isLabAction(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.findLab:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
      case AssistantIntent.findPackage:
      case AssistantIntent.findAnalysis:
        return true;
      default:
        return false;
    }
  }
}
