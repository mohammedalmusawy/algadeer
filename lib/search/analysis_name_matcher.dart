import '../models/lab_models.dart';
import 'analysis_alias_catalog.dart';
import 'arabic_text_utils.dart';

enum AnalysisNameMatchType {
  none,
  exact,
  abbreviation,
  alias,
  strongPrefix,
  contains,
  partial,
}

class AnalysisNameMatch {
  const AnalysisNameMatch({
    required this.score,
    required this.matchType,
    required this.matchedTokens,
    required this.analysisName,
    this.analysisId,
    this.canonicalKey,
  });

  final int score;
  final AnalysisNameMatchType matchType;
  final List<String> matchedTokens;
  final String analysisName;
  final String? analysisId;
  final String? canonicalKey;

  bool get isStrong =>
      score >= 85 &&
      (matchType == AnalysisNameMatchType.exact ||
          matchType == AnalysisNameMatchType.abbreviation ||
          matchType == AnalysisNameMatchType.alias ||
          matchType == AnalysisNameMatchType.strongPrefix);

  static const none = AnalysisNameMatch(
    score: 0,
    matchType: AnalysisNameMatchType.none,
    matchedTokens: [],
    analysisName: '',
  );
}

class AnalysisNameMatchBatch {
  const AnalysisNameMatchBatch({
    required this.query,
    required this.matches,
    required this.isAmbiguous,
  });

  final String query;
  final List<AnalysisNameMatch> matches;
  final bool isAmbiguous;

  AnalysisNameMatch? get best => matches.isEmpty ? null : matches.first;

  List<AnalysisNameMatch> get plausible =>
      matches.where((m) => m.score >= AnalysisNameMatcher.minPlausible).toList();
}

/// مطابقة أسماء تحاليل — حتمية، بدون قواعد أسماء أطباء.
class AnalysisNameMatcher {
  const AnalysisNameMatcher({
    AnalysisAliasSource? aliases,
  }) : _aliases = aliases ?? const AnalysisAliasCatalog();

  final AnalysisAliasSource _aliases;

  static const int minPlausible = 55;
  static const int minConfidentUnique = 85;

  String prepareQuery(String raw) {
    var s = ArabicTextUtils.normalize(raw.trim());
    s = AnalysisTextNormalizer.stripAnalysisRoleWords(s);
    // أزل ضجيج الطلب الشائع.
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:أريد|اريد|ابي|ابحث|دور|عندكم|عندك|اكو|أكو|وين|موجود|بأي|باقه|باقة|مختبر)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return AnalysisTextNormalizer.normalizeForMatch(s);
  }

  AnalysisNameMatchBatch matchAnalyses({
    required String query,
    required List<AnalysisItem> analyses,
  }) {
    final prepared = prepareQuery(query);
    if (prepared.isEmpty || analyses.isEmpty) {
      return AnalysisNameMatchBatch(
        query: prepared,
        matches: const [],
        isAmbiguous: false,
      );
    }

    final scored = <AnalysisNameMatch>[];
    for (final a in analyses) {
      if (!a.isActive) continue;
      final m = _scoreOne(prepared, a);
      if (m.score >= minPlausible) scored.add(m);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final plausible = scored.where((m) => m.score >= minPlausible).toList();
    final top = plausible.isEmpty ? null : plausible.first;
    // غموض حذر: فجوة ضيقة أو تطابق جزئي قوي لعدة مرشحين (مثل «السكر»).
    final ambiguous = top != null &&
        plausible.length > 1 &&
        (plausible[1].score >= top.score - 15 ||
            !top.isStrong ||
            (plausible[1].score >= 75 && top.score - plausible[1].score <= 20));

    return AnalysisNameMatchBatch(
      query: prepared,
      matches: plausible,
      isAmbiguous: ambiguous,
    );
  }

  AnalysisNameMatch _scoreOne(String query, AnalysisItem item) {
    final terms = <String>{
      item.name,
      item.shortName,
      item.nameAr,
      item.descriptionAr,
      ...item.aliases,
      if (item.searchText.isNotEmpty) item.searchText,
    }.where((t) => t.trim().isNotEmpty).toList();

    // كانوني للعنصر فقط — لا تُحقَن aliases الاستعلام في كل صف (كانت تسبب تطابق الجميع).
    String? canonFromItem = _aliases.resolveCanonical(item.name) ??
        _aliases.resolveCanonical(item.shortName) ??
        _aliases.resolveCanonical(item.nameAr);
    if (canonFromItem == null) {
      for (final a in item.aliases) {
        canonFromItem = _aliases.resolveCanonical(a);
        if (canonFromItem != null) break;
      }
    }
    if (canonFromItem != null) {
      terms.add(canonFromItem);
      terms.addAll(_aliases.aliasesForCanonical(canonFromItem));
    }

    final canonFromQuery = _aliases.resolveCanonical(query);
    if (canonFromQuery != null &&
        canonFromItem != null &&
        AnalysisTextNormalizer.normalizeForMatch(canonFromQuery) ==
            AnalysisTextNormalizer.normalizeForMatch(canonFromItem)) {
      final isAbbr = _looksLikeAbbreviation(query);
      return AnalysisNameMatch(
        score: 100,
        matchType: isAbbr
            ? AnalysisNameMatchType.abbreviation
            : AnalysisNameMatchType.alias,
        matchedTokens: [query],
        analysisName: item.displayLabel,
        analysisId: item.id,
        canonicalKey: canonFromQuery,
      );
    }

    var best = AnalysisNameMatch.none;
    for (final term in terms) {
      final nTerm = AnalysisTextNormalizer.normalizeForMatch(term);
      if (nTerm.isEmpty) continue;

      if (nTerm == query) {
        final isAbbr = _looksLikeAbbreviation(query) &&
            (nTerm == AnalysisTextNormalizer.normalizeForMatch(item.shortName) ||
                nTerm == AnalysisTextNormalizer.normalizeForMatch(item.name) ||
                canonFromItem != null);
        final m = AnalysisNameMatch(
          score: 100,
          matchType: isAbbr
              ? AnalysisNameMatchType.abbreviation
              : (canonFromItem != null &&
                      _aliases.resolveCanonical(term) != null
                  ? AnalysisNameMatchType.alias
                  : AnalysisNameMatchType.exact),
          matchedTokens: [query],
          analysisName: item.displayLabel,
          analysisId: item.id,
          canonicalKey: canonFromQuery ?? canonFromItem,
        );
        if (m.score > best.score) best = m;
        continue;
      }

      if (nTerm.startsWith(query) && query.length >= 2) {
        final m = AnalysisNameMatch(
          score: 90,
          matchType: AnalysisNameMatchType.strongPrefix,
          matchedTokens: [query],
          analysisName: item.displayLabel,
          analysisId: item.id,
          canonicalKey: canonFromItem,
        );
        if (m.score > best.score) best = m;
        continue;
      }

      if (nTerm.contains(query) && query.length >= 2) {
        final m = AnalysisNameMatch(
          score: 78,
          matchType: AnalysisNameMatchType.contains,
          matchedTokens: [query],
          analysisName: item.displayLabel,
          analysisId: item.id,
          canonicalKey: canonFromItem,
        );
        if (m.score > best.score) best = m;
        continue;
      }

      final soft = ArabicTextUtils.scoreMatch(term, query);
      if (soft >= minPlausible && soft > best.score) {
        best = AnalysisNameMatch(
          score: soft,
          matchType: AnalysisNameMatchType.partial,
          matchedTokens: [query],
          analysisName: item.displayLabel,
          analysisId: item.id,
          canonicalKey: canonFromItem,
        );
      }
    }
    return best;
  }

  static bool _looksLikeAbbreviation(String q) {
    return RegExp(r'^[a-z0-9]{2,12}$', caseSensitive: false).hasMatch(q);
  }
}
