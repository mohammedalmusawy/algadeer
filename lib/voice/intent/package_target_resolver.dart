import '../../search/package_name_matcher.dart';
import '../../search/smart_search_models.dart';
import '../clarification/clarification_models.dart';
import '../context_resolver.dart';
import '../conversation_context.dart';
import 'assistant_intent.dart';
import 'intent_result.dart';

enum PackageTargetSource {
  explicitName,
  ordinal,
  selectedContext,
  unresolved,
}

class PackageTargetResolution {
  const PackageTargetResolution({
    required this.source,
    this.package,
    this.explicitName,
    this.resultIndex,
    this.requiresSearch = false,
    this.requiresClarification = false,
    this.candidates = const [],
    this.message = '',
  });

  final PackageTargetSource source;
  final SmartSearchResult? package;
  final String? explicitName;
  final int? resultIndex;
  final bool requiresSearch;
  final bool requiresClarification;
  final List<SmartSearchResult> candidates;
  final String message;

  bool get hasPackage =>
      package != null &&
      (package!.type == SmartSearchResultType.package ||
          package!.type == SmartSearchResultType.offer);

  bool get isResolved =>
      source == PackageTargetSource.explicitName ||
      source == PackageTargetSource.ordinal ||
      source == PackageTargetSource.selectedContext;

  static const unresolved = PackageTargetResolution(
    source: PackageTargetSource.unresolved,
    requiresClarification: true,
    message: 'أي باقة تقصد؟ اذكر اسم الباقة أولاً.',
  );
}

/// حل هدف الباقة: اسم صريح → ترتيب → سياق محدد → غير محلول.
class PackageTargetResolver {
  const PackageTargetResolver();

  PackageTargetResolution resolve({
    required IntentResult intentResult,
    required ConversationContext context,
  }) {
    final entities = intentResult.entities;
    final normalized = intentResult.normalizedText;

    final explicit = _explicitPackageName(entities.packageName, normalized);
    if (explicit != null) {
      return PackageTargetResolution(
        source: PackageTargetSource.explicitName,
        explicitName: explicit,
        requiresSearch: true,
      );
    }

    final ordinal =
        entities.resultIndex ?? ContextResolver.extractOrdinal(normalized);
    if (ordinal != null && _ordinalApplies(intentResult)) {
      return _resolveOrdinal(ordinal, context);
    }

    final selected = context.selectedPackage;
    if (selected != null &&
        (selected.type == SmartSearchResultType.package ||
            selected.type == SmartSearchResultType.offer)) {
      return PackageTargetResolution(
        source: PackageTargetSource.selectedContext,
        package: selected,
      );
    }

    final sole = _solePackage(context);
    if (sole != null) {
      context.selectPackage(sole);
      return PackageTargetResolution(
        source: PackageTargetSource.selectedContext,
        package: sole,
      );
    }

    if (_isPackageAction(intentResult.intent) ||
        context.activeEntityType == ConversationEntityType.package) {
      return PackageTargetResolution(
        source: PackageTargetSource.unresolved,
        requiresClarification: true,
        candidates: context.authoritativeItemsFor(
          ConversationEntityType.package,
        ),
        message: PackageTargetResolution.unresolved.message,
      );
    }

    return PackageTargetResolution.unresolved;
  }

  bool _ordinalApplies(IntentResult intent) {
    return intent.intent == AssistantIntent.selectResult ||
        intent.isActionIntent ||
        _isPackageAction(intent.intent);
  }

  PackageTargetResolution _resolveOrdinal(
    int ordinal,
    ConversationContext context,
  ) {
    final fromPending =
        context.pendingClarification?.entityType ==
                ClarificationEntityType.package
            ? context.pendingClarification!.candidates
                .map((c) => c.payload)
                .whereType<SmartSearchResult>()
                .where(
                  (r) =>
                      r.type == SmartSearchResultType.package ||
                      r.type == SmartSearchResultType.offer,
                )
                .toList()
            : const <SmartSearchResult>[];

    final list = fromPending.isNotEmpty
        ? fromPending
        : context.authoritativeItemsFor(ConversationEntityType.package);

    if (list.isEmpty) {
      return const PackageTargetResolution(
        source: PackageTargetSource.unresolved,
        requiresClarification: true,
        message: 'ما عندي نتائج باقات سابقة. ابحث عن باقة أولاً.',
      );
    }

    final index = ordinal == -1 ? list.length : ordinal;
    if (index < 1 || index > list.length) {
      final n = list.length;
      return PackageTargetResolution(
        source: PackageTargetSource.unresolved,
        requiresClarification: true,
        resultIndex: ordinal,
        candidates: list,
        message: n == 2
            ? 'عندي خياران فقط. تقصد الأولى أم الثانية؟'
            : 'الرقم خارج النطاق. اختر من 1 إلى $n.',
      );
    }

    final chosen = list[index - 1];
    context.selectPackage(chosen);
    return PackageTargetResolution(
      source: PackageTargetSource.ordinal,
      package: chosen,
      resultIndex: index,
    );
  }

  static SmartSearchResult? _solePackage(ConversationContext context) {
    // PC-0.2: لا lastPackageSnapshot / lastAnalysisPackageSnapshot كسلطة محادثة.
    final list =
        context.authoritativeItemsFor(ConversationEntityType.package);
    if (list.length == 1) return list.first;
    return null;
  }

  static String? _explicitPackageName(String? raw, String normalizedFull) {
    var cleaned = (raw ?? '').trim();
    if (cleaned.isEmpty) {
      final m = RegExp(
        r'(?:ال)?(?:باقه|باقة)\s+(.+)$',
      ).firstMatch(normalizedFull);
      cleaned = (m?.group(1) ?? '').trim();
    }
    cleaned = PackageNameMatcher().prepareQuery(cleaned);
    if (cleaned.isEmpty || cleaned.length <= 1) return null;
    if (RegExp(
      r'^(?:بيه|به|بيها|بها|هذا|هاي|هذي|هذه|هذاك|ذاك|مالته|مالتها|الاول|الأول|الثاني|موجود|مختبر|سعرها|تحاليلها)$',
    ).hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  static bool _isPackageAction(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.findPackage:
      case AssistantIntent.findOffer:
        return true;
      default:
        return false;
    }
  }

  static SmartSearchResult toSearchResult({
    required String id,
    required String name,
    required String labId,
    required String labName,
    int? oldPrice,
    int? newPrice,
    int? discountPercent,
    String? description,
    String? imageUrl,
  }) {
    final isOffer = discountPercent != null && discountPercent > 0;
    return SmartSearchResult(
      type: isOffer ? SmartSearchResultType.offer : SmartSearchResultType.package,
      title: name,
      subtitle: labName.isNotEmpty ? labName : 'باقة',
      packageId: id,
      labId: labId.isNotEmpty ? labId : null,
      labName: labName.isNotEmpty ? labName : null,
      oldPrice: oldPrice,
      newPrice: newPrice,
      discountPercent: discountPercent,
      bioSnippet: (description ?? '').isNotEmpty ? description : null,
      imageUrl: (imageUrl ?? '').isNotEmpty ? imageUrl : null,
      score: 100,
    );
  }
}
