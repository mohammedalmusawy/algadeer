import '../../voice/guided_conversation/arabic_duration_parser.dart';
import '../../voice/guided_conversation/guided_conversation_models.dart';
import 'health_language_normalizer.dart';
import 'local_symptom_catalog.dart';
import 'symptom_catalog_source.dart';
import 'symptom_models.dart';

class _AliasHit {
  _AliasHit({
    required this.symptomId,
    required this.alias,
    required this.start,
    required this.end,
    required this.confidence,
  });

  final String symptomId;
  final String alias;
  final int start;
  final int end;
  final SymptomMatchConfidence confidence;
}

/// مطابقة حتمية لأطول عبارة مع نفي/عدم تأكد ونطاق محافظ.
class SymptomMatcher {
  SymptomMatcher({
    SyncSymptomCatalogSource? catalog,
    HealthLanguageNormalizer? normalizer,
    ArabicDurationParser? durationParser,
  })  : _catalog = catalog ?? const LocalSymptomCatalog(),
        _normalizer = normalizer ?? const HealthLanguageNormalizer(),
        _duration = durationParser ?? const ArabicDurationParser();

  final SyncSymptomCatalogSource _catalog;
  final HealthLanguageNormalizer _normalizer;
  final ArabicDurationParser _duration;

  List<_CompiledAlias> _compiled = const [];
  List<_CompiledRegion> _regions = const [];
  bool _ready = false;

  void ensureLoaded() {
    if (_ready) return;
    final concepts = {
      for (final c in _catalog.enabledSymptomsSync()) c.id: c,
    };
    final entries = <_CompiledAlias>[];
    for (final a in _catalog.enabledAliasesSync()) {
      if (!a.enabled) continue;
      if (!concepts.containsKey(a.symptomId)) continue;
      final norm = _normalizer.normalize(a.alias);
      if (norm.isEmpty) continue;
      entries.add(_CompiledAlias(
        symptomId: a.symptomId,
        aliasNorm: norm,
        aliasRaw: a.alias,
        concept: concepts[a.symptomId]!,
      ));
    }
    entries.sort((a, b) => b.aliasNorm.length.compareTo(a.aliasNorm.length));
    _compiled = List.unmodifiable(entries);

    final regs = <_CompiledRegion>[];
    for (final r in _catalog.enabledBodyRegionsSync()) {
      if (!r.enabled) continue;
      final aliases = [r.canonicalArabicName, ...r.aliases];
      for (final al in aliases) {
        final n = _normalizer.normalize(al);
        if (n.isEmpty) continue;
        regs.add(_CompiledRegion(id: r.id, aliasNorm: n));
      }
    }
    regs.sort((a, b) => b.aliasNorm.length.compareTo(a.aliasNorm.length));
    _regions = List.unmodifiable(regs);
    _ready = true;
  }

  HealthUnderstandingResult match(String originalText) {
    ensureLoaded();
    final normalized = _normalizer.normalize(originalText);
    if (normalized.isEmpty) {
      return HealthUnderstandingResult.empty(originalText);
    }

    final padded = ' $normalized ';
    final hits = <_AliasHit>[];

    for (final alias in _compiled) {
      var from = 0;
      while (true) {
        final idx = padded.indexOf(' ${alias.aliasNorm} ', from);
        if (idx < 0) break;
        // padded = ' ' + normalized + ' ' — بداية العبارة في normalized = idx
        final start = idx;
        final end = start + alias.aliasNorm.length;
        if (start < 0 || end > normalized.length) {
          from = idx + 1;
          continue;
        }
        hits.add(_AliasHit(
          symptomId: alias.symptomId,
          alias: alias.aliasRaw,
          start: start,
          end: end,
          confidence: alias.aliasNorm ==
                      _normalizer.normalize(alias.concept.canonicalArabicName)
                  ? SymptomMatchConfidence.exactAlias
                  : (alias.aliasNorm.split(' ').length > 1
                      ? SymptomMatchConfidence.phrasePattern
                      : SymptomMatchConfidence.normalizedAlias),
        ));
        from = idx + 1;
      }
    }

    // أطول أولاً — تجاهل التداخلات.
    hits.sort((a, b) {
      final lenCmp = (b.end - b.start).compareTo(a.end - a.start);
      if (lenCmp != 0) return lenCmp;
      return a.start.compareTo(b.start);
    });

    final accepted = <_AliasHit>[];
    final occupied = <bool>[];
    // خريطة تغطية على النص المطبّع
    final cover = List<bool>.filled(normalized.length, false);

    for (final h in hits) {
      if (h.start < 0 || h.end > normalized.length) continue;
      var overlaps = false;
      for (var i = h.start; i < h.end; i++) {
        if (cover[i]) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;
      for (var i = h.start; i < h.end; i++) {
        cover[i] = true;
      }
      accepted.add(h);
      occupied.add(true);
    }

    final concepts = {
      for (final c in _catalog.enabledSymptomsSync()) c.id: c,
    };

    final duration = _duration.parse(originalText);
    final globalLaterality = _extractLaterality(normalized);
    final globalSeverity = _extractSeverity(normalized);
    final onset = _extractOnset(normalized);
    final temporal = _extractTemporal(normalized);
    final regionsFound = _extractRegions(normalized);
    final userConditions = _extractUserStatedConditions(normalized);

    final symptoms = <DetectedSymptom>[];
    for (final h in accepted) {
      final concept = concepts[h.symptomId];
      final polarity = _polarityForSpan(normalized, h.start, h.end);
      var region = concept?.bodyRegions.isNotEmpty == true
          ? concept!.bodyRegions.first
          : _nearestRegion(regionsFound, h.start, h.end);
      // ركبة + ألم → knee_pain يفضّل المنطقة
      if (h.symptomId == 'knee_pain') region = BodyRegionId.knee;
      if (h.symptomId == 'numbness') {
        region ??= _nearestRegion(regionsFound, h.start, h.end);
      }

      // ألم عام قرب الركبة بدون مفهوم knee_pain صريح
      var conceptId = h.symptomId;
      if (conceptId == 'joint_pain' &&
          regionsFound.any((r) => r.id == BodyRegionId.knee)) {
        conceptId = 'knee_pain';
        region = BodyRegionId.knee;
      }

      // «ألم … بالركبة» عبر نمط ألم + منطقة
      final localLaterality =
          _lateralityNear(normalized, h.start, h.end) ?? globalLaterality;
      final localSeverity =
          _severityNear(normalized, h.start, h.end) ?? globalSeverity;

      var confidence = h.confidence;
      if (concept?.metadata['broad'] == true &&
          normalized.split(' ').length <= 2) {
        confidence = SymptomMatchConfidence.ambiguous;
      }

      symptoms.add(DetectedSymptom(
        conceptId: conceptId,
        status: polarity,
        matchedText: h.alias,
        confidence: confidence,
        bodyRegion: region,
        laterality: localLaterality,
        userSeverity: localSeverity,
        duration: duration,
        onset: onset,
        temporalModifiers: temporal,
        spanStart: h.start,
        spanEnd: h.end,
      ));
    }

    // نمط «ألم … بالركبة» إن لم يُلتقط كمفهوم ركبة
    _maybeAddKneePainFromPattern(
      normalized: normalized,
      symptoms: symptoms,
      duration: duration,
      globalLaterality: globalLaterality,
      globalSeverity: globalSeverity,
      onset: onset,
      temporal: temporal,
    );

    // نمط «الألم يروح ويجي» كمعدّل زمني عام إن وُجد ألم
    // (المعدّلات الزمنية مُخزَّنة أصلاً في temporal)

    // إزالة تكرار نفس المفهوم مع تفضيل present على absent عند التعارض النادر
    final deduped = _dedupeSymptoms(symptoms);

    final health = deduped.isNotEmpty ||
        regionsFound.isNotEmpty ||
        userConditions.isNotEmpty ||
        _hasGenericHealthCue(normalized);

    return HealthUnderstandingResult(
      originalText: originalText,
      normalizedText: normalized,
      symptoms: deduped,
      bodyRegions: [
        ...{for (final r in regionsFound) r.id},
      ],
      duration: duration,
      laterality: globalLaterality,
      userSeverity: globalSeverity,
      onset: onset,
      temporalModifiers: temporal,
      userStatedConditions: userConditions,
      containsHealthLanguage: health,
    );
  }

  void _maybeAddKneePainFromPattern({
    required String normalized,
    required List<DetectedSymptom> symptoms,
    required DurationValue? duration,
    required Laterality globalLaterality,
    required UserStatedSeverity globalSeverity,
    required OnsetPattern onset,
    required List<String> temporal,
  }) {
    if (symptoms.any((s) => s.conceptId == 'knee_pain')) return;
    final hasPain = RegExp(r'(?:الم|ألم|وجع)').hasMatch(normalized);
    final knee = RegExp(r'(?:ركبه|ركبة|رگبه|رگبة|ركبتي|رگبتي)')
        .firstMatch(normalized);
    if (!hasPain || knee == null) return;

    final start = knee.start;
    final end = knee.end;
    symptoms.add(DetectedSymptom(
      conceptId: 'knee_pain',
      status: _polarityForSpan(normalized, start, end),
      matchedText: knee.group(0)!,
      confidence: SymptomMatchConfidence.phrasePattern,
      bodyRegion: BodyRegionId.knee,
      laterality: _lateralityNear(normalized, start, end) ?? globalLaterality,
      userSeverity: _severityNear(normalized, start, end) ?? globalSeverity,
      duration: duration,
      onset: onset,
      temporalModifiers: temporal,
      spanStart: start,
      spanEnd: end,
    ));
  }

  List<DetectedSymptom> _dedupeSymptoms(List<DetectedSymptom> input) {
    final byId = <String, DetectedSymptom>{};
    for (final s in input) {
      final prev = byId[s.conceptId];
      if (prev == null) {
        byId[s.conceptId] = s;
        continue;
      }
      // فضّل present ثم uncertain ثم absent؛ وأطول مطابقة.
      final rank = _polarityRank(s.status);
      final prevRank = _polarityRank(prev.status);
      if (rank < prevRank ||
          (rank == prevRank &&
              (s.matchedText.length > prev.matchedText.length))) {
        byId[s.conceptId] = s;
      }
    }
    return byId.values.toList(growable: false);
  }

  int _polarityRank(SymptomPolarity p) {
    switch (p) {
      case SymptomPolarity.present:
        return 0;
      case SymptomPolarity.uncertain:
        return 1;
      case SymptomPolarity.absent:
        return 2;
    }
  }

  SymptomPolarity _polarityForSpan(String text, int start, int end) {
    final windowStart = (start - 28).clamp(0, text.length);
    final before = text.substring(windowStart, start);
    final afterEnd = (end + 12).clamp(0, text.length);
    final around = text.substring(windowStart, afterEnd);
    final span = text.substring(start, end);

    // «ما عندي حرارة» عندما تُطابق العبارة الأطول «عندي حرارة».
    if (span.startsWith('عندي') &&
        RegExp(r'(?:^|[\s،,])(?:بس\s+)?ما\s*$').hasMatch(before.trimRight())) {
      return SymptomPolarity.absent;
    }

    // عدم تأكد محلّي
    if (RegExp(
      r'(?:يمكن|يمكن\s*عندي|احس\s*يمكن|مو\s*متاكد|مو\s*متأكد|مرات)',
    ).hasMatch(before) ||
        RegExp(r'(?:يمكن|مو\s*متاكد|مو\s*متأكد)').hasMatch(around)) {
      if (!_hasLocalNegation(before, around, start - windowStart)) {
        return SymptomPolarity.uncertain;
      }
    }

    if (_hasLocalNegation(before, around, start - windowStart)) {
      return SymptomPolarity.absent;
    }
    return SymptomPolarity.present;
  }

  bool _hasLocalNegation(String before, String around, int relStart) {
    // عبارات العرض نفسها قد تبدأ بـ «ما اسمع / ما اكدر» — ليست نفياً.
    if (RegExp(
      r'(?:ما\s*(?:اسمع|أسمع|اكدر|أقدر|اتنفس|أتنفس))\s*$',
    ).hasMatch(before.trimRight())) {
      return false;
    }

    // نفي مباشر قبل العرض
    if (RegExp(
      r'(?:^|[\s،,])(?:ما\s*عندي|ماكو|ما\s*كو|بدون|بلا|مو\s*عندي)\s*$',
    ).hasMatch(before.trimRight())) {
      return true;
    }
    if (RegExp(
      r'(?:بس\s+)?(?:ما\s*عندي|ماكو|بدون)\s*$',
    ).hasMatch(before.trimRight())) {
      return true;
    }
    if (RegExp(
      r'(?:بس\s*)?(?:ما\s*عندي|ماكو|بدون)\s+\S{0,24}$',
    ).hasMatch(before)) {
      return true;
    }
    // «ما عندي X ولا Y»
    if (RegExp(r'(?:ما\s*عندي|ماكو|بدون).{0,40}(?:\sولا\s|\sلا\s)')
            .hasMatch(around) &&
        RegExp(r'(?:ما\s*عندي|ماكو|بدون|ولا)').hasMatch(before)) {
      return true;
    }
    // «ولا استفراغ» بعد نفي سابق في الجملة
    if (RegExp(r'(?:^|[\s،,])ولا\s*$').hasMatch(before.trimRight())) {
      return true;
    }
    return false;
  }

  Laterality _extractLaterality(String n) {
    if (RegExp(
      r'(?:بالطرفين|اثنينهم|كلا\s*الجانبين|الجانبين)',
    ).hasMatch(n)) {
      return Laterality.bilateral;
    }
    if (RegExp(
      r'(?:الجهه\s*اليمنى|الجهة\s*اليمنى|اليمنى|اليمني|اليمين|يمين)',
    ).hasMatch(n)) {
      return Laterality.right;
    }
    if (RegExp(
      r'(?:الجهه\s*اليسرى|الجهة\s*اليسرى|اليسرى|اليسري|اليسار|يسار)',
    ).hasMatch(n)) {
      return Laterality.left;
    }
    return Laterality.unknown;
  }

  Laterality? _lateralityNear(String n, int start, int end) {
    final a = (start - 18).clamp(0, n.length);
    final b = (end + 18).clamp(0, n.length);
    final local = n.substring(a, b);
    final v = _extractLaterality(local);
    return v == Laterality.unknown ? null : v;
  }

  UserStatedSeverity _extractSeverity(String n) {
    if (RegExp(
      r'(?:كلش\s*قوي|ما\s*اتحمله|ما\s*أتحمله|شديد|قوي\s*جدا|قوي)',
    ).hasMatch(n)) {
      return UserStatedSeverity.severe;
    }
    if (RegExp(r'(?:متوسط|وسط)').hasMatch(n)) {
      return UserStatedSeverity.moderate;
    }
    if (RegExp(r'(?:خفيف|بسيط)').hasMatch(n)) {
      return UserStatedSeverity.mild;
    }
    return UserStatedSeverity.unknown;
  }

  UserStatedSeverity? _severityNear(String n, int start, int end) {
    final a = (start - 20).clamp(0, n.length);
    final b = (end + 12).clamp(0, n.length);
    final v = _extractSeverity(n.substring(a, b));
    return v == UserStatedSeverity.unknown ? null : v;
  }

  OnsetPattern _extractOnset(String n) {
    if (RegExp(
      r'(?:فجاه|فجأة|بشكل\s*مفاجئ|مره\s*وحده|مرة\s*وحدة|بدا\s*فجاه|بدأ\s*فجأة)',
    ).hasMatch(n)) {
      return OnsetPattern.sudden;
    }
    if (RegExp(
      r'(?:بالتدريج|شوي\s*شوي|شوية\s*شوية|بدا\s*شوي|بدأ\s*شوي)',
    ).hasMatch(n)) {
      return OnsetPattern.gradual;
    }
    return OnsetPattern.unknown;
  }

  List<String> _extractTemporal(String n) {
    final out = <String>[];
    void add(String id, RegExp re) {
      if (re.hasMatch(n) && !out.contains(id)) out.add(id);
    }

    add('continuous', RegExp(r'(?:مستمر|باستمرار)'));
    add('intermittent', RegExp(r'(?:يروح\s*و\s*يجي|يجي\s*و\s*يروح|متقطع)'));
    add('at_night', RegExp(r'(?:بالليل|ليلا)'));
    add('at_day', RegExp(r'(?:بالنهار|نهارا)'));
    add('after_eating', RegExp(r'(?:بعد\s*الاكل|بعد\s*الأكل)'));
    add('before_eating', RegExp(r'(?:قبل\s*الاكل|قبل\s*الأكل)'));
    add('with_movement', RegExp(r'(?:مع\s*الحركه|مع\s*الحركة)'));
    add('while_walking', RegExp(r'(?:وقت\s*المشي|عند\s*المشي)'));
    return List.unmodifiable(out);
  }

  List<({BodyRegionId id, int start, int end})> _extractRegions(String n) {
    final padded = ' $n ';
    final cover = List<bool>.filled(n.length, false);
    final found = <({BodyRegionId id, int start, int end})>[];
    for (final r in _regions) {
      var from = 0;
      while (true) {
        final idx = padded.indexOf(' ${r.aliasNorm} ', from);
        if (idx < 0) break;
        final start = idx;
        final end = start + r.aliasNorm.length;
        if (start < 0 || end > n.length) {
          from = idx + 1;
          continue;
        }
        var overlap = false;
        for (var i = start; i < end && i < cover.length; i++) {
          if (cover[i]) {
            overlap = true;
            break;
          }
        }
        if (!overlap) {
          for (var i = start; i < end && i < cover.length; i++) {
            cover[i] = true;
          }
          found.add((id: r.id, start: start, end: end));
        }
        from = idx + 1;
      }
    }
    return found;
  }

  BodyRegionId? _nearestRegion(
    List<({BodyRegionId id, int start, int end})> regions,
    int start,
    int end,
  ) {
    BodyRegionId? best;
    var bestDist = 9999;
    for (final r in regions) {
      final gap = r.end < start
          ? start - r.end
          : (end < r.start ? r.start - end : 0);
      if (gap < bestDist && gap <= 24) {
        bestDist = gap;
        best = r.id;
      }
    }
    return best;
  }

  List<String> _extractUserStatedConditions(String n) {
    final out = <String>[];
    final m = RegExp(
      r'(?:عندي|اصابني|مصاب\s*ب)\s+(سكري|ضغط|ربو|حساسية|صرع|ثلاسيميا)',
    ).allMatches(n);
    for (final hit in m) {
      final c = hit.group(1);
      if (c != null && !out.contains(c)) out.add(c);
    }
    // ذكر نصّي بلا استدلال مرضي
    if (RegExp(r'(?:التهاب|انفلونزا|نزلة)').hasMatch(n)) {
      final word = RegExp(r'(التهاب|انفلونزا|نزلة)').firstMatch(n)?.group(1);
      if (word != null && !out.contains(word)) out.add(word);
    }
    return List.unmodifiable(out);
  }

  bool _hasGenericHealthCue(String n) {
    return RegExp(
      r'(?:عندي\s*الم|عندي\s*ألم|اعراض|أعراض|وجع|يوجعني|يعورني)',
    ).hasMatch(n);
  }
}

class _CompiledAlias {
  const _CompiledAlias({
    required this.symptomId,
    required this.aliasNorm,
    required this.aliasRaw,
    required this.concept,
  });

  final String symptomId;
  final String aliasNorm;
  final String aliasRaw;
  final SymptomConcept concept;
}

class _CompiledRegion {
  const _CompiledRegion({
    required this.id,
    required this.aliasNorm,
  });

  final BodyRegionId id;
  final String aliasNorm;
}
