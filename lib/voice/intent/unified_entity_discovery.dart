import '../../search/arabic_text_utils.dart';
import '../../search/catalog_name_matcher.dart';
import '../../search/doctor_name_matcher.dart';
import '../../search/laboratory_name_matcher.dart';
import '../../search/pharmacy_name_matcher.dart';
import '../../search/smart_search_models.dart';
import '../conversation_context.dart';

/// تمثيل خفيف للبحث/الحل فقط — لا يستبدل نماذج الدومين.
class SearchablePlatformEntity {
  const SearchablePlatformEntity({
    required this.canonicalId,
    required this.entityType,
    required this.displayName,
    required this.result,
    this.aliases = const [],
  });

  final String canonicalId;
  final ConversationEntityType entityType;
  final String displayName;
  final List<String> aliases;

  /// الحمولة الجاهزة للمسارات القائمة (اتصال/واتساب/ملف).
  final SmartSearchResult result;

  String get normalizedName => ArabicTextUtils.normalize(displayName);
}

/// نتيجة مطابقة موحّدة عبر أنواع المنصة.
class UnifiedEntityHit {
  const UnifiedEntityHit({
    required this.entity,
    required this.score,
  });

  final SearchablePlatformEntity entity;
  final int score;

  SmartSearchResult get result => entity.result;
  ConversationEntityType get entityType => entity.entityType;
  String get canonicalId => entity.canonicalId;
}

class UnifiedEntityDiscoveryResult {
  const UnifiedEntityDiscoveryResult({
    required this.query,
    required this.hits,
    required this.isAmbiguous,
  });

  final String query;
  final List<UnifiedEntityHit> hits;
  final bool isAmbiguous;

  static const empty = UnifiedEntityDiscoveryResult(
    query: '',
    hits: [],
    isAmbiguous: false,
  );

  UnifiedEntityHit? get best => hits.isEmpty ? null : hits.first;
  bool get isEmpty => hits.isEmpty;
  bool get isNotEmpty => hits.isNotEmpty;
}

/// اكتشاف كيان من بيانات المنصة الحالية — بلا أسماء ثابتة في الكود.
///
/// المسار: اسم مستخرج → مطابقة exact/token/prefix/fuzzy حذرة →
/// تحليل المرشّحين → ambiguous أو best.
class UnifiedEntityDiscovery {
  const UnifiedEntityDiscovery({
    DoctorNameMatcher doctorMatcher = const DoctorNameMatcher(),
    PharmacyNameMatcher pharmacyMatcher = const PharmacyNameMatcher(),
    LaboratoryNameMatcher labMatcher = const LaboratoryNameMatcher(),
  })  : _doctorMatcher = doctorMatcher,
        _pharmacyMatcher = pharmacyMatcher,
        _labMatcher = labMatcher;

  final DoctorNameMatcher _doctorMatcher;
  final PharmacyNameMatcher _pharmacyMatcher;
  final LaboratoryNameMatcher _labMatcher;

  static const int minPlausible = 70;
  static const int ambiguousGap = 8;

  /// يستخرج عبارة اسم محتملة بعد إزالة أفعال الطلب/الاتصال/ألقاب الأقسام.
  static String? extractNamePhrase(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s.replaceFirst(
      RegExp(
        r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:اتصل|اتصال|كلّم|كلم|راسل|أرسل|ارسل|دزله|دزّله|دزوله|دز\s+|'
        r'افتح|اعرض|ابحث(?:لي)?|دور(?:لي)?|طل[عّ](?:لي)?|طلعلي|وريني|'
        r'وين|اين|أين)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceFirst(
      RegExp(
        r'^(?:رسالة\s+)?(?:واتساب|واتس\s*اب|واتس|whatsapp)\s*(?:ل|على|الى|إلى)?\s*',
        caseSensitive: false,
      ),
      '',
    );
    // لا تُزال «ب» من «بيه/به» — ضمائر سياقية.
    s = s.replaceFirst(RegExp(r'^(?:ل|على)\s*'), '');
    s = s.replaceFirst(RegExp(r'^ب(?!يه\b|ه\b|ها\b)'), '');
    // ألقاب لغة اختيارية (ليست محتوى منصة). «مركز» جزء شائع من الاسم — لا يُزال.
    final stripped = s
        .replaceFirst(
          RegExp(
            r'^(?:ال)?(?:دكتور|دكتورة|طبيب|طبيبة|صيدليه|صيدلية|مختبر)\s+',
          ),
          '',
        )
        .trim();
    final n = ArabicTextUtils.normalize(
      stripped.isNotEmpty ? stripped : s,
    );
    if (n.length < 3) return null;
    // كلمات قسم وحدها ليست اسماً.
    if (RegExp(
      r'^(?:علاج\s*طبيعي|فيزيو|تاهيل|تأهيل|مستلزمات|تجهيزات|'
      r'صيدليه|صيدلية|مختبر|طبيب|دكتور|اشعه|اشعة)$',
    ).hasMatch(n)) {
      return null;
    }
    // ضمائر / ترتيب.
    if (RegExp(
      r'^(?:بيه|به|يه|ها|ه|وياه|هذا|هاي|الاول|الأول|الثاني|الثالث|عن|في|من)$',
    ).hasMatch(n)) {
      return null;
    }
    return n;
  }

  /// تلميح نوع من كلمات اللغة (ليست محتوى منصة).
  static ConversationEntityType? typeHintFromQuery(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (RegExp(
      r'(?:علاج\s*طبيعي|فيزيو|تاهيل|تأهيل|معالج\s*طبيعي)',
    ).hasMatch(n)) {
      return ConversationEntityType.physio;
    }
    if (RegExp(r'(?:مستلزمات|تجهيزات|مواد\s*طبيه|معدات\s*طبيه)')
        .hasMatch(n)) {
      return ConversationEntityType.supply;
    }
    if (RegExp(r'(?:صيدليه|صيدلية|صيدليات)').hasMatch(n)) {
      return ConversationEntityType.pharmacy;
    }
    if (RegExp(r'(?:مختبر|مختبرات)').hasMatch(n)) {
      return ConversationEntityType.laboratory;
    }
    if (RegExp(r'(?:اشعه|اشعة|أشعة)').hasMatch(n)) {
      return ConversationEntityType.radiology;
    }
    if (RegExp(r'(?:دكتور|دكتورة|طبيب|طبيبة)').hasMatch(n)) {
      return ConversationEntityType.doctor;
    }
    return null;
  }

  static SearchablePlatformEntity fromResult(SmartSearchResult r) {
    final type = switch (r.type) {
      SmartSearchResultType.doctor => ConversationEntityType.doctor,
      SmartSearchResultType.lab => ConversationEntityType.laboratory,
      SmartSearchResultType.radiology => ConversationEntityType.radiology,
      SmartSearchResultType.pharmacy => ConversationEntityType.pharmacy,
      SmartSearchResultType.physio => ConversationEntityType.physio,
      SmartSearchResultType.supply => ConversationEntityType.supply,
      _ => ConversationEntityType.none,
    };
    final id = switch (r.type) {
      SmartSearchResultType.doctor => (r.doctorId ?? '').trim(),
      SmartSearchResultType.lab => (r.labId ?? '').trim(),
      SmartSearchResultType.radiology => (r.radiologyId ?? '').trim(),
      SmartSearchResultType.pharmacy => (r.pharmacyId ?? '').trim(),
      SmartSearchResultType.physio => (r.physioId ?? '').trim(),
      SmartSearchResultType.supply => (r.supplyId ?? '').trim(),
      _ => '',
    };
    return SearchablePlatformEntity(
      canonicalId: id.isNotEmpty ? id : r.title,
      entityType: type,
      displayName: r.title,
      result: r,
    );
  }

  /// يبحث في كتالوجات حالية ممرَّرة من المنصة (ديناميكية بالكامل).
  UnifiedEntityDiscoveryResult resolve({
    required String nameQuery,
    required List<SearchablePlatformEntity> catalog,
    ConversationEntityType? typeHint,
  }) {
    final prepared = extractNamePhrase(nameQuery) ??
        ArabicTextUtils.normalize(nameQuery).trim();
    if (prepared.isEmpty || catalog.isEmpty) {
      return UnifiedEntityDiscoveryResult(
        query: prepared,
        hits: const [],
        isAmbiguous: false,
      );
    }

    final pool = typeHint == null || typeHint == ConversationEntityType.none
        ? catalog
        : [
            for (final e in catalog)
              if (e.entityType == typeHint) e,
          ];
    // إن التلميح صفّى الكل — ابحث في الكل (اسم بلا نوع كافٍ).
    final effective = pool.isNotEmpty ? pool : catalog;

    final hits = <UnifiedEntityHit>[];
    for (final e in effective) {
      final score = _score(prepared, e);
      if (score >= minPlausible) {
        hits.add(UnifiedEntityHit(entity: e, score: score));
      }
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      // تلميح النوع يُفضَّل عند التعادل.
      if (typeHint != null) {
        final aBoost = a.entityType == typeHint ? 1 : 0;
        final bBoost = b.entityType == typeHint ? 1 : 0;
        if (aBoost != bBoost) return bBoost.compareTo(aBoost);
      }
      return a.entity.displayName.compareTo(b.entity.displayName);
    });

    if (hits.isEmpty) {
      return UnifiedEntityDiscoveryResult(
        query: prepared,
        hits: const [],
        isAmbiguous: false,
      );
    }

    final top = hits.first;
    final rivals = [
      for (final h in hits)
        if (h.canonicalId != top.canonicalId ||
            h.entityType != top.entityType)
          h,
    ];
    final ambiguous = rivals.isNotEmpty &&
        (rivals.first.score >= top.score - ambiguousGap ||
            (top.score < 90 && rivals.first.score >= minPlausible));

    return UnifiedEntityDiscoveryResult(
      query: prepared,
      hits: hits,
      isAmbiguous: ambiguous,
    );
  }

  int _score(String query, SearchablePlatformEntity entity) {
    switch (entity.entityType) {
      case ConversationEntityType.doctor:
        return _doctorMatcher
            .score(
              doctorName: entity.displayName,
              query: query,
              doctorId: entity.canonicalId,
            )
            .score;
      case ConversationEntityType.pharmacy:
        final batch = _pharmacyMatcher.matchPharmacies(
          query: query,
          pharmacies: [(id: entity.canonicalId, name: entity.displayName)],
        );
        return batch.best?.score ?? 0;
      case ConversationEntityType.laboratory:
        final batch = _labMatcher.matchLabs(
          query: query,
          labs: [(id: entity.canonicalId, name: entity.displayName)],
        );
        return batch.best?.score ?? 0;
      case ConversationEntityType.physio:
      case ConversationEntityType.supply:
      case ConversationEntityType.radiology:
        final batch = const CatalogNameMatcher().match(
          query: query,
          entities: [(id: entity.canonicalId, name: entity.displayName)],
        );
        return batch.best?.score ?? 0;
      case ConversationEntityType.analysis:
      case ConversationEntityType.package:
      case ConversationEntityType.none:
        return 0;
    }
  }
}
