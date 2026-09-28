import 'arabic_text_utils.dart';

/// نوع تطابق اسم مركز أشعة — أبسط من مطابقة الأطباء (بدون مركّبات عبد).
enum RadiologyNameMatchType {
  none,
  exact,
  strongPrefix,
  contains,
  orderedTokens,
  partial,
}

class RadiologyNameMatch {
  const RadiologyNameMatch({
    required this.score,
    required this.matchType,
    required this.matchedTokens,
    required this.centerName,
    this.centerId,
  });

  final int score;
  final RadiologyNameMatchType matchType;
  final List<String> matchedTokens;
  final String centerName;
  final String? centerId;

  bool get isStrong =>
      score >= 85 &&
      (matchType == RadiologyNameMatchType.exact ||
          matchType == RadiologyNameMatchType.strongPrefix ||
          matchType == RadiologyNameMatchType.orderedTokens ||
          matchType == RadiologyNameMatchType.contains);

  static const none = RadiologyNameMatch(
    score: 0,
    matchType: RadiologyNameMatchType.none,
    matchedTokens: [],
    centerName: '',
  );
}

class RadiologyNameMatchBatch {
  const RadiologyNameMatchBatch({
    required this.query,
    required this.matches,
    required this.isAmbiguous,
  });

  final String query;
  final List<RadiologyNameMatch> matches;
  final bool isAmbiguous;

  RadiologyNameMatch? get best => matches.isEmpty ? null : matches.first;

  List<RadiologyNameMatch> get plausible =>
      matches.where((m) => m.score >= RadiologyNameMatcher.minPlausible).toList();
}

/// مطابقة أسماء مراكز الأشعة — حتمية، بدون قواعد أطباء/مختبرات.
class RadiologyNameMatcher {
  const RadiologyNameMatcher();

  static const int minPlausible = 55;
  static const int minConfidentUnique = 85;

  String prepareQuery(String raw) {
    return ArabicTextUtils.prepareRadiologyNameQuery(raw);
  }

  RadiologyNameMatchBatch matchCenters({
    required String query,
    required List<({String id, String name})> centers,
  }) {
    final prepared = prepareQuery(query);
    if (prepared.isEmpty || centers.isEmpty) {
      return RadiologyNameMatchBatch(
        query: prepared,
        matches: const [],
        isAmbiguous: false,
      );
    }

    final scored = <RadiologyNameMatch>[];
    for (final lab in centers) {
      final m = _scoreOne(prepared, lab.id, lab.name);
      if (m.score >= minPlausible) scored.add(m);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final plausible = scored.where((m) => m.score >= minPlausible).toList();
    final top = plausible.isEmpty ? null : plausible.first;
    final ambiguous = top != null &&
        plausible.length > 1 &&
        (plausible[1].score >= top.score - 8 || !top.isStrong);

    return RadiologyNameMatchBatch(
      query: prepared,
      matches: plausible,
      isAmbiguous: ambiguous,
    );
  }

  RadiologyNameMatch _scoreOne(String query, String id, String name) {
    final h = ArabicTextUtils.normalize(name);
    final n = ArabicTextUtils.normalize(query);
    if (h.isEmpty || n.isEmpty) return RadiologyNameMatch.none;

    if (h == n) {
      return RadiologyNameMatch(
        score: 100,
        matchType: RadiologyNameMatchType.exact,
        matchedTokens: n.split(' '),
        centerName: name,
        centerId: id,
      );
    }

    // بدون «ال»
    final hBare = h.startsWith('ال') && h.length > 2 ? h.substring(2) : h;
    final nBare = n.startsWith('ال') && n.length > 2 ? n.substring(2) : n;
    if (hBare == nBare || h == nBare || hBare == n) {
      return RadiologyNameMatch(
        score: 96,
        matchType: RadiologyNameMatchType.exact,
        matchedTokens: [nBare],
        centerName: name,
        centerId: id,
      );
    }

    if (h.startsWith(n) || hBare.startsWith(nBare)) {
      return RadiologyNameMatch(
        score: 90,
        matchType: RadiologyNameMatchType.strongPrefix,
        matchedTokens: [n],
        centerName: name,
        centerId: id,
      );
    }

    if (h.contains(n) || hBare.contains(nBare)) {
      return RadiologyNameMatch(
        score: 80,
        matchType: RadiologyNameMatchType.contains,
        matchedTokens: [n],
        centerName: name,
        centerId: id,
      );
    }

    final qParts = n.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final hParts = h.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (qParts.isEmpty) return RadiologyNameMatch.none;

    var hits = 0;
    final matched = <String>[];
    for (final p in qParts) {
      final ok = hParts.any((hp) {
        if (hp == p || hp.contains(p) || p.contains(hp)) return true;
        if (hp.startsWith('ال') && hp.length > 2 && hp.substring(2) == p) {
          return true;
        }
        // خطأ إملائي بسيط (حرف واحد) على أي توكن — لأي مختبر جديد.
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
      // خطأ إملائي صغير على توكن واحد — ينطبق على أي مختبر في القاعدة.
      if (qParts.length == 1 && qParts.first.length >= 3) {
        final q = qParts.first;
        for (final hp in hParts) {
          final bare =
              hp.startsWith('ال') && hp.length > 2 ? hp.substring(2) : hp;
          if ((bare.length - q.length).abs() <= 1 &&
              _editDistance(q, bare) <= 1) {
            return RadiologyNameMatch(
              score: 82,
              matchType: RadiologyNameMatchType.partial,
              matchedTokens: [q],
              centerName: name,
              centerId: id,
            );
          }
        }
      }
      final soft = ArabicTextUtils.scoreMatch(name, query);
      if (soft < minPlausible) return RadiologyNameMatch.none;
      return RadiologyNameMatch(
        score: soft,
        matchType: RadiologyNameMatchType.partial,
        matchedTokens: matched,
        centerName: name,
        centerId: id,
      );
    }
    if (hits == qParts.length) {
      return RadiologyNameMatch(
        score: 70 + (qParts.length >= 2 ? 15 : 5),
        matchType: RadiologyNameMatchType.orderedTokens,
        matchedTokens: matched,
        centerName: name,
        centerId: id,
      );
    }
    return RadiologyNameMatch(
      score: 40 + ((hits / qParts.length) * 40).round(),
      matchType: RadiologyNameMatchType.partial,
      matchedTokens: matched,
      centerName: name,
      centerId: id,
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
