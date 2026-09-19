import 'arabic_text_utils.dart';

/// نوع تطابق اسم مختبر — أبسط من مطابقة الأطباء (بدون مركّبات عبد).
enum LaboratoryNameMatchType {
  none,
  exact,
  strongPrefix,
  contains,
  orderedTokens,
  partial,
}

class LaboratoryNameMatch {
  const LaboratoryNameMatch({
    required this.score,
    required this.matchType,
    required this.matchedTokens,
    required this.labName,
    this.labId,
  });

  final int score;
  final LaboratoryNameMatchType matchType;
  final List<String> matchedTokens;
  final String labName;
  final String? labId;

  bool get isStrong =>
      score >= 85 &&
      (matchType == LaboratoryNameMatchType.exact ||
          matchType == LaboratoryNameMatchType.strongPrefix ||
          matchType == LaboratoryNameMatchType.orderedTokens ||
          matchType == LaboratoryNameMatchType.contains);

  static const none = LaboratoryNameMatch(
    score: 0,
    matchType: LaboratoryNameMatchType.none,
    matchedTokens: [],
    labName: '',
  );
}

class LaboratoryNameMatchBatch {
  const LaboratoryNameMatchBatch({
    required this.query,
    required this.matches,
    required this.isAmbiguous,
  });

  final String query;
  final List<LaboratoryNameMatch> matches;
  final bool isAmbiguous;

  LaboratoryNameMatch? get best => matches.isEmpty ? null : matches.first;

  List<LaboratoryNameMatch> get plausible =>
      matches.where((m) => m.score >= LaboratoryNameMatcher.minPlausible).toList();
}

/// مطابقة أسماء مختبرات — حتمية، بدون قواعد أطباء.
class LaboratoryNameMatcher {
  const LaboratoryNameMatcher();

  static const int minPlausible = 55;
  static const int minConfidentUnique = 85;

  String prepareQuery(String raw) {
    var s = ArabicTextUtils.normalize(raw.trim());
    s = s
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:مختبر|مختبرات)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  LaboratoryNameMatchBatch matchLabs({
    required String query,
    required List<({String id, String name})> labs,
  }) {
    final prepared = prepareQuery(query);
    if (prepared.isEmpty || labs.isEmpty) {
      return LaboratoryNameMatchBatch(
        query: prepared,
        matches: const [],
        isAmbiguous: false,
      );
    }

    final scored = <LaboratoryNameMatch>[];
    for (final lab in labs) {
      final m = _scoreOne(prepared, lab.id, lab.name);
      if (m.score >= minPlausible) scored.add(m);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final plausible = scored.where((m) => m.score >= minPlausible).toList();
    final top = plausible.isEmpty ? null : plausible.first;
    final ambiguous = top != null &&
        plausible.length > 1 &&
        (plausible[1].score >= top.score - 8 || !top.isStrong);

    return LaboratoryNameMatchBatch(
      query: prepared,
      matches: plausible,
      isAmbiguous: ambiguous,
    );
  }

  LaboratoryNameMatch _scoreOne(String query, String id, String name) {
    final h = ArabicTextUtils.normalize(name);
    final n = ArabicTextUtils.normalize(query);
    if (h.isEmpty || n.isEmpty) return LaboratoryNameMatch.none;

    if (h == n) {
      return LaboratoryNameMatch(
        score: 100,
        matchType: LaboratoryNameMatchType.exact,
        matchedTokens: n.split(' '),
        labName: name,
        labId: id,
      );
    }

    // بدون «ال»
    final hBare = h.startsWith('ال') && h.length > 2 ? h.substring(2) : h;
    final nBare = n.startsWith('ال') && n.length > 2 ? n.substring(2) : n;
    if (hBare == nBare || h == nBare || hBare == n) {
      return LaboratoryNameMatch(
        score: 96,
        matchType: LaboratoryNameMatchType.exact,
        matchedTokens: [nBare],
        labName: name,
        labId: id,
      );
    }

    if (h.startsWith(n) || hBare.startsWith(nBare)) {
      return LaboratoryNameMatch(
        score: 90,
        matchType: LaboratoryNameMatchType.strongPrefix,
        matchedTokens: [n],
        labName: name,
        labId: id,
      );
    }

    if (h.contains(n) || hBare.contains(nBare)) {
      return LaboratoryNameMatch(
        score: 80,
        matchType: LaboratoryNameMatchType.contains,
        matchedTokens: [n],
        labName: name,
        labId: id,
      );
    }

    final qParts = n.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final hParts = h.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (qParts.isEmpty) return LaboratoryNameMatch.none;

    var hits = 0;
    final matched = <String>[];
    for (final p in qParts) {
      final ok = hParts.any(
        (hp) =>
            hp == p ||
            hp.contains(p) ||
            p.contains(hp) ||
            (hp.startsWith('ال') && hp.length > 2 && hp.substring(2) == p),
      );
      if (ok) {
        hits++;
        matched.add(p);
      }
    }
    if (hits == 0) {
      final soft = ArabicTextUtils.scoreMatch(name, query);
      if (soft < minPlausible) return LaboratoryNameMatch.none;
      return LaboratoryNameMatch(
        score: soft,
        matchType: LaboratoryNameMatchType.partial,
        matchedTokens: matched,
        labName: name,
        labId: id,
      );
    }
    if (hits == qParts.length) {
      return LaboratoryNameMatch(
        score: 70 + (qParts.length >= 2 ? 15 : 5),
        matchType: LaboratoryNameMatchType.orderedTokens,
        matchedTokens: matched,
        labName: name,
        labId: id,
      );
    }
    return LaboratoryNameMatch(
      score: 40 + ((hits / qParts.length) * 40).round(),
      matchType: LaboratoryNameMatchType.partial,
      matchedTokens: matched,
      labName: name,
      labId: id,
    );
  }
}
