import 'arabic_text_utils.dart';

/// مطابقة أسماء كيانات الكتالوج المحلي (صيدلية/فيزيو/مستلزمات) —
/// حتمية، بلا أسماء ثابتة في الكود؛ القائمة تُمرَّر من Platform Data.
enum CatalogNameMatchType {
  none,
  exact,
  strongPrefix,
  contains,
  orderedTokens,
  partial,
}

class CatalogNameMatch {
  const CatalogNameMatch({
    required this.score,
    required this.matchType,
    required this.matchedTokens,
    required this.entityName,
    this.entityId,
  });

  final int score;
  final CatalogNameMatchType matchType;
  final List<String> matchedTokens;
  final String entityName;
  final String? entityId;

  bool get isStrong =>
      score >= 85 &&
      (matchType == CatalogNameMatchType.exact ||
          matchType == CatalogNameMatchType.strongPrefix ||
          matchType == CatalogNameMatchType.orderedTokens ||
          matchType == CatalogNameMatchType.contains);

  static const none = CatalogNameMatch(
    score: 0,
    matchType: CatalogNameMatchType.none,
    matchedTokens: [],
    entityName: '',
  );
}

class CatalogNameMatchBatch {
  const CatalogNameMatchBatch({
    required this.query,
    required this.matches,
    required this.isAmbiguous,
  });

  final String query;
  final List<CatalogNameMatch> matches;
  final bool isAmbiguous;

  CatalogNameMatch? get best => matches.isEmpty ? null : matches.first;

  List<CatalogNameMatch> get plausible =>
      matches.where((m) => m.score >= CatalogNameMatcher.minPlausible).toList();
}

/// مطابقة عامة لأسماء مزوّدي المنصة من قائمة ديناميكية.
class CatalogNameMatcher {
  const CatalogNameMatcher({this.prepareQuery});

  /// اختياري: يزيل ألقاب القسم (صيدلية/علاج طبيعي/…) قبل المطابقة.
  final String Function(String raw)? prepareQuery;

  static const int minPlausible = 55;
  static const int minConfidentUnique = 85;

  String _prepare(String raw) {
    final p = prepareQuery;
    if (p != null) return p(raw);
    return ArabicTextUtils.normalize(raw).trim();
  }

  CatalogNameMatchBatch match({
    required String query,
    required List<({String id, String name})> entities,
  }) {
    final prepared = _prepare(query);
    if (prepared.isEmpty || entities.isEmpty) {
      return CatalogNameMatchBatch(
        query: prepared,
        matches: const [],
        isAmbiguous: false,
      );
    }

    final scored = <CatalogNameMatch>[];
    for (final e in entities) {
      final m = _scoreOne(prepared, e.id, e.name);
      if (m.score >= minPlausible) scored.add(m);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final plausible = scored.where((m) => m.score >= minPlausible).toList();
    final top = plausible.isEmpty ? null : plausible.first;
    final ambiguous = top != null &&
        plausible.length > 1 &&
        (plausible[1].score >= top.score - 8 || !top.isStrong);

    return CatalogNameMatchBatch(
      query: prepared,
      matches: plausible,
      isAmbiguous: ambiguous,
    );
  }

  CatalogNameMatch _scoreOne(String query, String id, String name) {
    final h = ArabicTextUtils.normalize(name);
    final n = ArabicTextUtils.normalize(query);
    if (h.isEmpty || n.isEmpty) return CatalogNameMatch.none;

    if (h == n) {
      return CatalogNameMatch(
        score: 100,
        matchType: CatalogNameMatchType.exact,
        matchedTokens: n.split(' '),
        entityName: name,
        entityId: id,
      );
    }

    final hBare = h.startsWith('ال') && h.length > 2 ? h.substring(2) : h;
    final nBare = n.startsWith('ال') && n.length > 2 ? n.substring(2) : n;
    if (hBare == nBare || h == nBare || hBare == n) {
      return CatalogNameMatch(
        score: 96,
        matchType: CatalogNameMatchType.exact,
        matchedTokens: [nBare],
        entityName: name,
        entityId: id,
      );
    }

    if (h.startsWith(n) || hBare.startsWith(nBare)) {
      return CatalogNameMatch(
        score: 90,
        matchType: CatalogNameMatchType.strongPrefix,
        matchedTokens: [n],
        entityName: name,
        entityId: id,
      );
    }

    if (h.contains(n) || hBare.contains(nBare)) {
      return CatalogNameMatch(
        score: 80,
        matchType: CatalogNameMatchType.contains,
        matchedTokens: [n],
        entityName: name,
        entityId: id,
      );
    }

    final qParts = n.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final hParts = h.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (qParts.isEmpty) return CatalogNameMatch.none;

    var hits = 0;
    final matched = <String>[];
    for (final p in qParts) {
      final ok = hParts.any((hp) {
        if (hp == p || hp.contains(p) || p.contains(hp)) return true;
        if (hp.startsWith('ال') && hp.length > 2 && hp.substring(2) == p) {
          return true;
        }
        final bare =
            hp.startsWith('ال') && hp.length > 2 ? hp.substring(2) : hp;
        final qBare = p.startsWith('ال') && p.length > 2 ? p.substring(2) : p;
        if (qBare.length >= 3 &&
            (bare.length - qBare.length).abs() <= 1 &&
            _editDistance(qBare, bare) <= 1) {
          return true;
        }
        return false;
      });
      if (ok) {
        hits++;
        matched.add(p);
      }
    }
    if (hits == 0) {
      if (qParts.length == 1 && qParts.first.length >= 3) {
        final q = qParts.first;
        for (final hp in hParts) {
          final bare =
              hp.startsWith('ال') && hp.length > 2 ? hp.substring(2) : hp;
          if ((bare.length - q.length).abs() <= 1 &&
              _editDistance(q, bare) <= 1) {
            return CatalogNameMatch(
              score: 82,
              matchType: CatalogNameMatchType.partial,
              matchedTokens: [q],
              entityName: name,
              entityId: id,
            );
          }
        }
      }
      final soft = ArabicTextUtils.scoreMatch(name, query);
      if (soft < minPlausible) return CatalogNameMatch.none;
      return CatalogNameMatch(
        score: soft,
        matchType: CatalogNameMatchType.partial,
        matchedTokens: matched,
        entityName: name,
        entityId: id,
      );
    }
    if (hits == qParts.length) {
      return CatalogNameMatch(
        score: 70 + (qParts.length >= 2 ? 15 : 5),
        matchType: CatalogNameMatchType.orderedTokens,
        matchedTokens: matched,
        entityName: name,
        entityId: id,
      );
    }
    return CatalogNameMatch(
      score: 40 + ((hits / qParts.length) * 40).round(),
      matchType: CatalogNameMatchType.partial,
      matchedTokens: matched,
      entityName: name,
      entityId: id,
    );
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > 2) return 1 << 20;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final insert = current[j - 1] + 1;
        final delete = previous[j] + 1;
        final replace = previous[j - 1] + cost;
        var best = insert < delete ? insert : delete;
        if (replace < best) best = replace;
        current[j] = best;
      }
      previous = List<int>.from(current);
    }
    return previous[b.length];
  }
}
