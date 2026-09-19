import 'conversation_conduct_catalog_source.dart';
import 'conversation_conduct_models.dart';
import 'conversation_conduct_normalizer.dart';
import 'local_conversation_conduct_catalog.dart';

/// كاشف سلوك حتمي — سياق + كتالوج، ليس blacklist فقط.
class ConversationConductDetector {
  ConversationConductDetector({
    SyncConversationConductCatalogSource? catalog,
    ConversationConductNormalizer? normalizer,
  })  : _catalog = catalog ?? const LocalConversationConductCatalogSource(),
        _norm = normalizer ?? const ConversationConductNormalizer();

  final SyncConversationConductCatalogSource _catalog;
  final ConversationConductNormalizer _norm;

  static final RegExp _quotedFrame = RegExp(
    r'(?:واحد|فلان|شخص|رجل|مره|امراة|امرأة|بنت|ولد)\s*'
    r'(?:سبني|شتمني|كال|گال|قال|حچال|حچالي|گالي|كالي|كتبلي|كتالي)|'
    r'(?:سبني|شتمني)\s*(?:وكال|وقال|وگال|و گال)|'
    r'(?:كال|گال|قال)\s*لي|'
    r'(?:گال|كال|قال)\s*(?:لي|إلي)|'
    r'(?:حچالي|حكالي)',
  );

  static final RegExp _secondPersonCue = RegExp(
    r'(?:^|\s)(?:انت|انته|يا)(?:\s|$)|'
    r'(?:هذا\s*التطبيق|التطبيق|تطبيقكم|تطبيقك)',
  );

  static final RegExp _frustration = RegExp(
    r'(?:ما\s*يشتغل|ما يشتغل|تعبتني|ضجت|ضايج من التطبيق|ليش كل مره|ليش كل مرة|يخرب)',
  );

  static final RegExp _criticism = RegExp(
    r'(?:التطبيق\s*سيء|البحث\s*مو\s*زين|جوابك\s*غلط|جواب غلط|مو\s*زين|سيء)',
  );

  ConversationConductResult detect(String rawQuery) {
    final original = rawQuery.trim();
    if (original.isEmpty) return ConversationConductResult.normal;

    final n = _norm.forMatch(original);

    // إحباط / نقد مشروع — ليس إساءة
    if (_frustration.hasMatch(n) && !_looksLikeDirectedInsult(n)) {
      return const ConversationConductResult(
        level: ConversationConductLevel.normal,
        target: ConversationConductTarget.unknown,
        matchedCategory: ConversationConductCategory.frustration,
        remainderQuery: '',
      );
    }
    if (_criticism.hasMatch(n) && !_looksLikeDirectedInsult(n)) {
      // «التطبيق سيء» نقد؛ «التطبيق غبي» قد تكون rude عبر الكتالوج
      if (!_catalogHitWithoutSecondPerson(n)) {
        return ConversationConductResult(
          level: ConversationConductLevel.normal,
          target: ConversationConductTarget.unknown,
          matchedCategory: ConversationConductCategory.criticism,
          remainderQuery: original,
        );
      }
    }

    final quoted = _quotedFrame.hasMatch(n);
    final hits = _findHits(n);

    if (hits.isEmpty) {
      return ConversationConductResult(
        level: ConversationConductLevel.normal,
        target: ConversationConductTarget.unknown,
        remainderQuery: original,
      );
    }

    // كلام منقول/مقتبس
    if (quoted) {
      return ConversationConductResult(
        level: ConversationConductLevel.normal,
        target: ConversationConductTarget.quotedSpeech,
        matchedCategory: hits.first.category,
        shouldRespond: false,
        matchedEntryIds: [for (final h in hits) h.id],
        remainderQuery: original,
      );
    }

    final best = _pickBest(hits);
    final needsCue = best.requiresSecondPersonCue;
    final hasCue = _secondPersonCue.hasMatch(n);

    if (needsCue && !hasCue) {
      // كلمة موجودة بلا توجيه واضح → لا تُوبّخ
      return ConversationConductResult(
        level: ConversationConductLevel.normal,
        target: ConversationConductTarget.unknown,
        matchedCategory: best.category,
        matchedEntryIds: [best.id],
        remainderQuery: original,
      );
    }

    final target = hasCue || !needsCue
        ? ConversationConductTarget.assistant
        : ConversationConductTarget.unknown;

    final remainder = _stripDirectedAbuse(original, hits);
    final level = best.level;

    return ConversationConductResult(
      level: level,
      target: target,
      matchedCategory: best.category,
      shouldRespond: target == ConversationConductTarget.assistant &&
          (level == ConversationConductLevel.rude ||
              level == ConversationConductLevel.abusive ||
              level == ConversationConductLevel.severeAbuse),
      matchedEntryIds: [for (final h in hits) h.id],
      remainderQuery: remainder,
    );
  }

  bool _looksLikeDirectedInsult(String n) {
    if (!_secondPersonCue.hasMatch(n)) return false;
    return _findHits(n).isNotEmpty;
  }

  bool _catalogHitWithoutSecondPerson(String n) {
    for (final e in _catalog.enabledEntriesSync()) {
      if (!e.enabled || e.requiresSecondPersonCue) continue;
      for (final p in e.patterns) {
        if (n.contains(_norm.forMatch(p))) return true;
      }
    }
    return false;
  }

  List<ConductCatalogEntry> _findHits(String n) {
    final hits = <ConductCatalogEntry>[];
    for (final e in _catalog.enabledEntriesSync()) {
      if (!e.enabled) continue;
      for (final p in e.patterns) {
        final pn = _norm.forMatch(p);
        if (pn.isEmpty) continue;
        if (n.contains(pn)) {
          hits.add(e);
          break;
        }
      }
    }
    return hits;
  }

  ConductCatalogEntry _pickBest(List<ConductCatalogEntry> hits) {
    hits.sort((a, b) {
      final la = _levelRank(a.level);
      final lb = _levelRank(b.level);
      if (la != lb) return lb.compareTo(la);
      return a.id.compareTo(b.id);
    });
    return hits.first;
  }

  int _levelRank(ConversationConductLevel l) {
    switch (l) {
      case ConversationConductLevel.normal:
        return 0;
      case ConversationConductLevel.rude:
        return 1;
      case ConversationConductLevel.abusive:
        return 2;
      case ConversationConductLevel.severeAbuse:
        return 3;
    }
  }

  String _stripDirectedAbuse(String original, List<ConductCatalogEntry> hits) {
    var t = original;
    t = t.replaceAll(
      RegExp(
        r'(?:^|\s)(?:يا\s+)?(?:غبي|غبيه|غبية|احمق|أحمق|حمار|كلب|چلب|تافه|حقير)(?=\s|$)',
      ),
      ' ',
    );
    t = t.replaceAll(
      RegExp(
        r'(?:^|\s)(?:انت|إنت|انته|إنته)\s+(?:غبي|غبيه|غبية|احمق|أحمق|حمار|كلب|تافه|حقير)(?=\s|$)',
      ),
      ' ',
    );
    t = t.replaceAll(
      RegExp(
        r'(?:هذا\s*)?(?:التطبيق|تطبيقكم|تطبيقك)\s*(?:غبي)?',
      ),
      ' ',
    );
    for (final e in hits) {
      for (final p in e.patterns) {
        t = t.replaceAll(RegExp(RegExp.escape(p)), ' ');
      }
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
