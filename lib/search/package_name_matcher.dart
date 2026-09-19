import 'arabic_text_utils.dart';

enum PackageNameMatchType {
  none,
  exact,
  normalizedExact,
  orderedTokens,
  contains,
  partial,
}

class PackageNameMatch {
  const PackageNameMatch({
    required this.score,
    required this.matchType,
    required this.matchedTokens,
    required this.packageName,
    this.packageId,
    this.labId,
  });

  final int score;
  final PackageNameMatchType matchType;
  final List<String> matchedTokens;
  final String packageName;
  final String? packageId;
  final String? labId;

  bool get isStrong =>
      score >= 85 &&
      (matchType == PackageNameMatchType.exact ||
          matchType == PackageNameMatchType.normalizedExact ||
          matchType == PackageNameMatchType.orderedTokens ||
          matchType == PackageNameMatchType.contains);

  static const none = PackageNameMatch(
    score: 0,
    matchType: PackageNameMatchType.none,
    matchedTokens: [],
    packageName: '',
  );
}

class PackageNameMatchBatch {
  const PackageNameMatchBatch({
    required this.query,
    required this.matches,
    required this.isAmbiguous,
  });

  final String query;
  final List<PackageNameMatch> matches;
  final bool isAmbiguous;

  PackageNameMatch? get best => matches.isEmpty ? null : matches.first;

  List<PackageNameMatch> get plausible =>
      matches.where((m) => m.score >= PackageNameMatcher.minPlausible).toList();
}

/// مطابقة أسماء باقات — حتمية، بدون قواعد أسماء أطباء.
class PackageNameMatcher {
  const PackageNameMatcher();

  static const int minPlausible = 55;
  static const int minConfidentUnique = 85;

  String prepareQuery(String raw) {
    var s = ArabicTextUtils.normalize(raw.trim());
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:ال)?(?:باقه|باقة|باقات|عرض|عروض|سعر|اسعار|أسعار|شكد|بكم)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:أريد|اريد|ابي|ابحث|دور|عرضلي|وريني|شنو|اكو|أكو|موجوده|موجودة|موجود)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  PackageNameMatchBatch matchPackages({
    required String query,
    required List<({String id, String name, String? labId})> packages,
  }) {
    final prepared = prepareQuery(query);
    if (prepared.isEmpty || packages.isEmpty) {
      return PackageNameMatchBatch(
        query: prepared,
        matches: const [],
        isAmbiguous: false,
      );
    }

    final scored = <PackageNameMatch>[];
    for (final p in packages) {
      final m = _scoreOne(prepared, p.id, p.name, p.labId);
      if (m.score >= minPlausible) scored.add(m);
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final plausible = scored.where((m) => m.score >= minPlausible).toList();
    final top = plausible.isEmpty ? null : plausible.first;
    final ambiguous = top != null &&
        plausible.length > 1 &&
        (plausible[1].score >= top.score - 8 || !top.isStrong);

    return PackageNameMatchBatch(
      query: prepared,
      matches: plausible,
      isAmbiguous: ambiguous,
    );
  }

  PackageNameMatch _scoreOne(
    String query,
    String id,
    String name,
    String? labId,
  ) {
    final h = ArabicTextUtils.normalize(name);
    final n = ArabicTextUtils.normalize(query);
    if (h.isEmpty || n.isEmpty) return PackageNameMatch.none;

    if (h == n) {
      return PackageNameMatch(
        score: 100,
        matchType: PackageNameMatchType.exact,
        matchedTokens: [n],
        packageName: name,
        packageId: id,
        labId: labId,
      );
    }

    // تطابق بعد إزالة بادئة «باقة».
    final hCore = h
        .replaceFirst(RegExp(r'^(?:ال)?(?:باقه|باقة)\s*'), '')
        .trim();
    final nCore = n
        .replaceFirst(RegExp(r'^(?:ال)?(?:باقه|باقة)\s*'), '')
        .trim();
    if (hCore.isNotEmpty && nCore.isNotEmpty && hCore == nCore) {
      return PackageNameMatch(
        score: 98,
        matchType: PackageNameMatchType.normalizedExact,
        matchedTokens: [nCore],
        packageName: name,
        packageId: id,
        labId: labId,
      );
    }

    final soft = ArabicTextUtils.scoreMatch(name, query);
    if (soft >= 90) {
      return PackageNameMatch(
        score: soft,
        matchType: PackageNameMatchType.orderedTokens,
        matchedTokens: [n],
        packageName: name,
        packageId: id,
        labId: labId,
      );
    }
    if (h.contains(n) && n.length >= 3) {
      return PackageNameMatch(
        score: 78,
        matchType: PackageNameMatchType.contains,
        matchedTokens: [n],
        packageName: name,
        packageId: id,
        labId: labId,
      );
    }
    if (soft >= minPlausible) {
      return PackageNameMatch(
        score: soft,
        matchType: PackageNameMatchType.partial,
        matchedTokens: [n],
        packageName: name,
        packageId: id,
        labId: labId,
      );
    }
    return PackageNameMatch.none;
  }
}
