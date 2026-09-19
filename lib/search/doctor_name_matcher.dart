import 'arabic_text_utils.dart';

/// نوع تطابق اسم طبيب — قابل للتفسير لطبقة العقل الذكي لاحقاً.
enum DoctorNameMatchType {
  none,
  exact,
  compoundExact,
  orderedTokens,
  firstAndFamily,
  progressive,
  partialSingle,
  unordered,
}

/// نتيجة مطابقة طبيب واحد مقابل استعلام.
class DoctorNameMatch {
  const DoctorNameMatch({
    required this.score,
    required this.matchType,
    required this.matchedTokens,
    required this.doctorName,
    this.doctorId,
  });

  final int score;
  final DoctorNameMatchType matchType;
  final List<String> matchedTokens;
  final String doctorName;
  final String? doctorId;

  /// تطابق قوي بما يكفي لفتح مباشر لاحقاً (ليس لاسم أول مشترك فقط).
  bool get isStrong =>
      score >= 90 &&
      (matchType == DoctorNameMatchType.exact ||
          matchType == DoctorNameMatchType.compoundExact ||
          matchType == DoctorNameMatchType.orderedTokens ||
          matchType == DoctorNameMatchType.firstAndFamily);

  static const none = DoctorNameMatch(
    score: 0,
    matchType: DoctorNameMatchType.none,
    matchedTokens: [],
    doctorName: '',
  );
}

/// اقتراح «هل تقصد …؟» لخطأ إملائي بسيط.
///
/// ليس نتيجة بحث ولا اختيار: لا يُفتح ملف ولا يُنفّذ اتصال/واتساب بناءً عليه.
class DoctorNameSuggestion {
  const DoctorNameSuggestion({
    required this.doctorName,
    required this.distance,
    this.doctorId,
  });

  final String doctorName;
  final String? doctorId;

  /// مسافة التحرير للتوكن المختلف الوحيد.
  final int distance;
}

/// نتيجة مطابقة مجموعة أطباء — تحفظ الغموض لـ Step 5 لاحقاً.
class DoctorNameMatchBatch {
  const DoctorNameMatchBatch({
    required this.query,
    required this.matches,
    required this.isAmbiguous,
  });

  final String query;
  final List<DoctorNameMatch> matches;
  final bool isAmbiguous;

  DoctorNameMatch? get best => matches.isEmpty ? null : matches.first;

  List<DoctorNameMatch> get plausible =>
      matches.where((m) => m.score >= DoctorNameMatcher.minPlausibleScore).toList();
}

/// محرك مطابقة أسماء أطباء — حتمي، آمن، بدون AI، بدون قائمة أطباء ثابتة.
///
/// لماذا تطبيع مركّبات «عبد*»؟
/// في العربية يُكتب الاسم نفسه «عبد الله» أو «عبدالله». المقارنة الحرفية
/// للتوكنات تفشل بينهما رغم أنهما نفس المكوّن الاسمي. نوحّد الشكل عبر
/// قائمة مكمّلات مضبوطة فقط — دون شطر كل كلمة تبدأ بـ«عبد».
class DoctorNameMatcher {
  const DoctorNameMatcher();

  /// حد أدنى لظهور مرشّح في نتائج البحث.
  static const int minPlausibleScore = 55;

  /// حد اعتبار تطابق «واثق» وحيد (فتح مباشر لاحقاً).
  static const int minConfidentUniqueScore = 90;

  /// يجهّز نص الاستعلام للمطابقة (ألقاب + ضجيج + مركّبات عبد).
  String prepareQuery(String rawQuery) {
    return ArabicTextUtils.prepareDoctorNameQuery(rawQuery);
  }

  /// يجهّز اسم طبيب مخزّناً للمقارنة.
  String prepareDoctorName(String storedName) {
    return ArabicTextUtils.prepareDoctorStoredName(storedName);
  }

  /// توكنات الاستعلام بعد التجهيز.
  List<String> tokenizeQuery(String rawQuery) {
    final prepared = prepareQuery(rawQuery);
    if (prepared.isEmpty) return const [];
    return prepared.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
  }

  /// هل الاستعلام ألقاب فقط («دكتور») بلا اسم؟
  bool isTitleOnlyQuery(String rawQuery) {
    final stripped = ArabicTextUtils.stripHonorifics(rawQuery).trim();
    if (stripped.isEmpty) return rawQuery.trim().isNotEmpty;
    return prepareQuery(rawQuery).isEmpty;
  }

  /// يطابق طبيباً واحداً مع استعلام.
  DoctorNameMatch score({
    required String doctorName,
    required String query,
    String? doctorId,
  }) {
    if (isTitleOnlyQuery(query)) {
      return DoctorNameMatch(
        score: 0,
        matchType: DoctorNameMatchType.none,
        matchedTokens: const [],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    final h = prepareDoctorName(doctorName);
    final n = prepareQuery(query);
    if (h.isEmpty || n.isEmpty) {
      return DoctorNameMatch(
        score: 0,
        matchType: DoctorNameMatchType.none,
        matchedTokens: const [],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    final queryTokens =
        n.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final nameTokens =
        h.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (queryTokens.isEmpty || nameTokens.isEmpty) {
      return DoctorNameMatch(
        score: 0,
        matchType: DoctorNameMatchType.none,
        matchedTokens: const [],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    // 1) تطابق كامل بعد التطبيع (يشمل توحيد عبدالله).
    if (h == n) {
      return DoctorNameMatch(
        score: 100,
        matchType: DoctorNameMatchType.exact,
        matchedTokens: queryTokens,
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    final matched = <String>[];
    for (final t in queryTokens) {
      if (ArabicTextUtils.nameContainsToken(h, t)) matched.add(t);
    }
    final allHit = matched.length == queryTokens.length;

    // 2) عبارة مرتّبة كاملة داخل الاسم.
    if (queryTokens.length >= 2 && h.contains(n)) {
      return DoctorNameMatch(
        score: 96,
        matchType: DoctorNameMatchType.compoundExact,
        matchedTokens: queryTokens,
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    // 3) كل التوكنات موجودة وبنفس الترتيب النسبي.
    if (allHit && queryTokens.length >= 2) {
      final ordered = _isOrderedSubsequence(nameTokens, queryTokens);
      if (ordered) {
        final firstFamily = queryTokens.length == 2 &&
            nameTokens.isNotEmpty &&
            ArabicTextUtils.nameContainsToken(nameTokens.first, queryTokens.first) &&
            ArabicTextUtils.nameContainsToken(
              nameTokens.last,
              queryTokens.last,
            );
        return DoctorNameMatch(
          score: firstFamily ? 93 : 90,
          matchType: firstFamily
              ? DoctorNameMatchType.firstAndFamily
              : DoctorNameMatchType.orderedTokens,
          matchedTokens: matched,
          doctorName: doctorName,
          doctorId: doctorId,
        );
      }
      // كل التوكنات موجودة لكن بترتيب مختلف — ثقة أقل.
      return DoctorNameMatch(
        score: 72,
        matchType: DoctorNameMatchType.unordered,
        matchedTokens: matched,
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    // 4) كتابة تقدّمية: توكنات سابقة كاملة + بادئة للأخير.
    if (queryTokens.length >= 2) {
      final progressive = _progressiveMatch(nameTokens, queryTokens);
      if (progressive != null) {
        return DoctorNameMatch(
          score: 86,
          matchType: DoctorNameMatchType.progressive,
          matchedTokens: progressive,
          doctorName: doctorName,
          doctorId: doctorId,
        );
      }
      return DoctorNameMatch(
        score: 0,
        matchType: DoctorNameMatchType.none,
        matchedTokens: matched,
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    // 5) اسم واحد — مرشّحون متعددون مسموح (الغموض على مستوى الدفعة).
    final token = queryTokens.first;
    if (h.startsWith(token)) {
      return DoctorNameMatch(
        score: 85,
        matchType: DoctorNameMatchType.partialSingle,
        matchedTokens: [token],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }
    if (nameTokens.any((p) => p == token || ArabicTextUtils.nameContainsToken(p, token))) {
      return DoctorNameMatch(
        score: 82,
        matchType: DoctorNameMatchType.partialSingle,
        matchedTokens: [token],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }
    if (nameTokens.any((p) => p.startsWith(token) && token.length >= 2)) {
      return DoctorNameMatch(
        score: 78,
        matchType: DoctorNameMatchType.partialSingle,
        matchedTokens: [token],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }
    if (ArabicTextUtils.nameContainsToken(h, token)) {
      return DoctorNameMatch(
        score: 75,
        matchType: DoctorNameMatchType.partialSingle,
        matchedTokens: [token],
        doctorName: doctorName,
        doctorId: doctorId,
      );
    }

    return DoctorNameMatch(
      score: 0,
      matchType: DoctorNameMatchType.none,
      matchedTokens: const [],
      doctorName: doctorName,
      doctorId: doctorId,
    );
  }

  /// يطابق قائمة أطباء مسترجعة من Supabase (لا قوائم ثابتة في الكود).
  DoctorNameMatchBatch matchDoctors({
    required String query,
    required List<({String id, String name})> doctors,
    int minScore = minPlausibleScore,
  }) {
    if (isTitleOnlyQuery(query)) {
      return DoctorNameMatchBatch(
        query: query,
        matches: const [],
        isAmbiguous: false,
      );
    }

    final scored = <DoctorNameMatch>[];
    for (final d in doctors) {
      final m = score(doctorName: d.name, query: query, doctorId: d.id);
      if (m.score >= minScore) scored.add(m);
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.doctorName.compareTo(b.doctorName);
    });

    final ambiguous = _detectAmbiguity(scored);
    return DoctorNameMatchBatch(
      query: query,
      matches: scored,
      isAmbiguous: ambiguous,
    );
  }

  /// أقصى مسافة تحرير مسموحة لتوكن واحد — محافظة بحسب طوله.
  static int maxTypoDistanceForToken(String token) =>
      token.length >= 6 ? 2 : 1;

  /// اقتراح تصحيح محافظ لخطأ إملائي بسيط — من الأطباء المحمّلين فعلياً فقط.
  ///
  /// الشروط (كلها إلزامية، وإلا `null` بلا تخمين):
  /// 1) الاستعلام اسم من توكنين على الأقل — لا اقتراح من اسم مفرد.
  /// 2) لا يوجد أي طبيب بتطابق معقول أصلاً (الاقتراح بديل لا-نتيجة فقط).
  /// 3) كل التوكنات مطابقة تماماً إلا توكناً واحداً.
  /// 4) التوكن المختلف قريب: مسافة تحرير ≤ 1 (أو ≤ 2 لطول ≥ 6)
  ///    ويشترك في أول حرفين مع توكن الاسم المخزَّن.
  /// 5) مرشّح وحيد — أي تعدد يعني غموضاً فلا اقتراح.
  DoctorNameSuggestion? suggestCorrection({
    required String query,
    required List<({String id, String name})> doctors,
  }) {
    if (isTitleOnlyQuery(query)) return null;
    final queryTokens = tokenizeQuery(query);
    if (queryTokens.length < 2) return null;

    final candidates = <DoctorNameSuggestion>[];
    for (final d in doctors) {
      if (score(doctorName: d.name, query: query, doctorId: d.id).score >=
          minPlausibleScore) {
        return null;
      }
      final nameTokens = prepareDoctorName(d.name)
          .split(RegExp(r'\s+'))
          .where((t) => t.length >= 2)
          .toList();
      final distance = _nearMissDistance(
        nameTokens: nameTokens,
        queryTokens: queryTokens,
      );
      if (distance != null) {
        candidates.add(
          DoctorNameSuggestion(
            doctorName: d.name,
            doctorId: d.id,
            distance: distance,
          ),
        );
      }
    }

    if (candidates.length != 1) return null;
    return candidates.first;
  }

  /// مسافة التوكن المختلف الوحيد، أو `null` إن لم يكن «قريباً جداً».
  static int? _nearMissDistance({
    required List<String> nameTokens,
    required List<String> queryTokens,
  }) {
    if (nameTokens.isEmpty) return null;
    if (queryTokens.length > nameTokens.length) return null;

    final remaining = [...nameTokens];
    int? typoDistance;

    for (final q in queryTokens) {
      final exact = remaining.indexWhere(
        (p) => p == q || ArabicTextUtils.nameContainsToken(p, q),
      );
      if (exact >= 0) {
        remaining.removeAt(exact);
        continue;
      }
      // توكن مشكوك واحد فقط لكل اسم.
      if (typoDistance != null) return null;

      var bestIndex = -1;
      var bestDistance = 1 << 30;
      for (var i = 0; i < remaining.length; i++) {
        final d = _editDistance(remaining[i], q);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
      if (bestIndex < 0) return null;

      final candidate = remaining[bestIndex];
      if (q.length < 3 || candidate.length < 3) return null;
      final longer = q.length >= candidate.length ? q : candidate;
      if (bestDistance > maxTypoDistanceForToken(longer)) return null;
      if (q.substring(0, 2) != candidate.substring(0, 2)) return null;

      remaining.removeAt(bestIndex);
      typoDistance = bestDistance;
    }

    return typoDistance;
  }

  /// مسافة تحرير محدودة — للاقتراح المحافظ فقط، ليست تسجيل نتائج.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > 3) return 1 << 20;

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

  /// غموض آمن: اسم أول مشترك بعدة مرشّحين، أو أكثر من تطابق قوي متقارب.
  static bool _detectAmbiguity(List<DoctorNameMatch> sorted) {
    if (sorted.length < 2) return false;
    final top = sorted.first;

    if (top.matchType == DoctorNameMatchType.partialSingle) {
      final singles = sorted
          .where(
            (m) =>
                m.matchType == DoctorNameMatchType.partialSingle &&
                m.score >= 75 &&
                (top.score - m.score) <= 10,
          )
          .toList();
      return singles.length >= 2;
    }

    if (top.isStrong) {
      final strongPeers = sorted
          .where((m) => m.isStrong && (top.score - m.score) <= 5)
          .toList();
      return strongPeers.length >= 2;
    }

    final peers = sorted
        .where(
          (m) => m.score >= 82 && (top.score - m.score) <= 10,
        )
        .toList();
    return peers.length >= 2;
  }

  static bool _isOrderedSubsequence(
    List<String> nameTokens,
    List<String> queryTokens,
  ) {
    var i = 0;
    for (final part in nameTokens) {
      if (i >= queryTokens.length) break;
      if (ArabicTextUtils.nameContainsToken(part, queryTokens[i]) ||
          ArabicTextUtils.nameContainsToken(queryTokens[i], part)) {
        i++;
      }
    }
    return i == queryTokens.length;
  }

  static List<String>? _progressiveMatch(
    List<String> nameTokens,
    List<String> queryTokens,
  ) {
    final matched = <String>[];
    for (var qi = 0; qi < queryTokens.length; qi++) {
      final t = queryTokens[qi];
      final isLast = qi == queryTokens.length - 1;
      final fullHit = nameTokens.any(
        (p) =>
            ArabicTextUtils.nameContainsToken(p, t) ||
            ArabicTextUtils.nameContainsToken(t, p),
      );
      if (fullHit) {
        matched.add(t);
        continue;
      }
      if (isLast && t.length >= 2) {
        final prefixHit = nameTokens.any(
          (p) => p.startsWith(t) && p.length > t.length,
        );
        if (prefixHit) {
          matched.add(t);
          continue;
        }
      }
      return null;
    }
    return matched;
  }
}
