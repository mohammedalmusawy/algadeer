import '../../doctors/specialty_catalog.dart';
import '../../search/arabic_text_utils.dart';

/// مُعدِّلات بحث عراقية طبيعية فوق أوامر البحث الحالية:
/// «متوفر / متاح / اليوم / هسه» → المتاحون أولاً،
/// «الأكثر طلبًا / الأعلى طلبًا» → ترتيب بمؤشرات الطلب الحقيقية.
///
/// تحليل قاعدي بحت (نص = صوت). لا يقرر أي حقيقة — فقط يفهم الطلب؛
/// الحقيقة والترتيب من بيانات Supabase في [SearchRefiner].
class SearchModifiers {
  const SearchModifiers({
    this.availableOnly = false,
    this.byDemand = false,
    this.cleanedQuery = '',
  });

  static const SearchModifiers none = SearchModifiers();

  /// المستخدم طلب «متوفر/اليوم» — المتاحون اليوم أولاً.
  final bool availableOnly;

  /// المستخدم طلب «الأكثر طلبًا».
  final bool byDemand;

  /// الاستعلام بعد إزالة كلمات المُعدِّل وتوحيد فعل الطلب (فارغ عند عدم وجود مُعدِّل).
  final String cleanedQuery;

  bool get isNone => !availableOnly && !byDemand;

  static const Set<String> _availTokens = {
    'متوفر', 'متوفره', 'متوفرين', 'متوفرات',
    'متاح', 'متاحه', 'متاحين', 'متاحات',
    'متواجد', 'متواجده', 'متواجدين', 'متواجدات',
  };

  static const Set<String> _todayTokens = {
    'اليوم', 'هسه', 'هسع', 'الحين', 'هاليوم', 'الان',
  };

  /// «الموجودة/الموجودين» تُعدّ مُعدِّل توفر فقط في سياق قائمة أطباء/مختبرات.
  static const Set<String> _listPresenceTokens = {
    'موجود', 'موجوده', 'موجودين', 'موجودات',
    'الموجود', 'الموجوده', 'الموجودين', 'الموجودات',
  };

  static const Set<String> _providerListNouns = {
    'مختبر', 'مختبرات', 'المختبر', 'المختبرات',
    'اطباء', 'الاطباء', 'دكاتره', 'الدكاتره',
  };

  static const Set<String> _notProviderListTokens = {
    'تحليل', 'تحاليل', 'التحليل', 'التحاليل',
    'وين', 'اين', 'باقه', 'باقات', 'الباقه', 'الباقات',
    'عرض', 'عروض', 'العرض', 'العروض',
  };

  static const Set<String> _mostTokens = {
    'اكثر', 'الاكثر', 'اعلي', 'الاعلي', 'اشهر', 'الاشهر',
  };

  static const Set<String> _demandWords = {
    'طلبا', 'طلب', 'مطلوب', 'مطلوبه', 'مطلوبين', 'شعبيه', 'زياره',
  };

  /// أفعال «جيبلي» العراقية → تُوحَّد إلى «اريد» كي يفهمها محلّل النية الحالي.
  static const Set<String> _leadFillers = {
    'جدلي', 'جيبلي', 'جبلي', 'هاتلي', 'لگلي', 'لكلي', 'الكلي',
    'منو', 'منهو', 'شنو', 'اي', 'هل', 'اكو',
  };

  static const Set<String> _requestVerbs = {
    'اريد', 'ابي', 'ابغي', 'ابحث', 'ابحثلي', 'دور', 'دورلي',
    'وريني', 'اعرض',
  };

  static final Set<String> _allModifierTokens = {
    ..._availTokens,
    ..._todayTokens,
    ..._mostTokens,
    ..._demandWords,
  };

  static String _modifierKey(String t) {
    if (t.length > 3 && t.startsWith('و')) {
      final rest = t.substring(1);
      if (_allModifierTokens.contains(rest)) return rest;
    }
    return t;
  }

  static SearchModifiers parse(String query) {
    final original = query.trim();
    if (original.isEmpty) return none;

    final rawTokens =
        original.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    // «والاكثر طلبا» / «ومتوفر»: واو العطف الملتصقة تُسقَط إن كان الباقي مُعدِّلًا.
    final norm = <String>[
      for (final t in rawTokens) _modifierKey(ArabicTextUtils.normalize(t)),
    ];

    final providerList = norm.any(_providerListNouns.contains) &&
        !norm.any(_notProviderListTokens.contains);

    var availableOnly = false;
    for (final t in norm) {
      if (_availTokens.contains(t) ||
          _todayTokens.contains(t) ||
          (providerList && _listPresenceTokens.contains(t))) {
        availableOnly = true;
      }
    }

    final hasMost = norm.any(_mostTokens.contains);
    final hasDemandWord = norm.any(_demandWords.contains);
    final byDemand = (hasMost && hasDemandWord) ||
        norm.any((t) => t == 'اشهر' || t == 'الاشهر');

    if (!availableOnly && !byDemand) return none;

    final kept = <String>[];
    for (var i = 0; i < rawTokens.length; i++) {
      final t = norm[i];
      final drop = _availTokens.contains(t) ||
          _todayTokens.contains(t) ||
          (providerList && _listPresenceTokens.contains(t)) ||
          (byDemand && (_mostTokens.contains(t) || _demandWords.contains(t)));
      if (drop) continue;
      final cleaned = rawTokens[i].replaceAll(RegExp(r'[؟?!.,،]+$'), '');
      if (cleaned.isNotEmpty) kept.add(cleaned);
    }

    if (kept.isNotEmpty) {
      final first = ArabicTextUtils.normalize(kept.first);
      if (_leadFillers.contains(first)) {
        kept[0] = 'اريد';
        // «هل في طبيب…» / «اكو في…»: «في» بعد الفعل الموحَّد زائدة.
        if (kept.length > 1 && ArabicTextUtils.normalize(kept[1]) == 'في') {
          kept.removeAt(1);
        }
      } else if (!_requestVerbs.contains(first) &&
          kept.length >= 2 &&
          _startsWithProviderNoun(kept)) {
        kept.insert(0, 'اريد');
      }
    }

    return SearchModifiers(
      availableOnly: availableOnly,
      byDemand: byDemand,
      cleanedQuery: kept.join(' ').trim(),
    );
  }

  static bool _startsWithProviderNoun(List<String> kept) {
    final first = ArabicTextUtils.normalize(kept.first);
    return first == 'طبيب' ||
        first == 'دكتور' ||
        first == 'مختبر' ||
        first == 'المختبرات' ||
        first == 'مختبرات' ||
        first == 'اطباء';
  }
}

/// سؤال تواجد طبيب باسمه: «هل دكتورة ميعاد متواجدة اليوم؟».
///
/// يرجع اسم الطبيب المذكور فقط (بلا لقب/كلمات تواجد)، أو null إن لم يكن
/// سؤال تواجد صريحًا (طلب بحث/اتصال/واتساب/اختصاص يمر في المسار العادي).
class DoctorPresenceQuestion {
  DoctorPresenceQuestion._();

  static const Set<String> _presenceTokens = {
    'متواجد', 'متواجده', 'متواجدين', 'موجود', 'موجوده',
    'متوفر', 'متوفره', 'متاح', 'متاحه',
    'حاضر', 'حاضره', 'يداوم', 'تداوم', 'داوم', 'داومه', 'دوام',
    'دوامه', 'دوامها',
  };

  static const Set<String> _titleTokens = {
    'دكتور', 'الدكتور', 'دكتوره', 'الدكتوره', 'د',
    'طبيب', 'الطبيب', 'طبيبه', 'الطبيبه',
  };

  static const Set<String> _fillerTokens = {
    'هل', 'اكو', 'هسه', 'هسع', 'اليوم', 'الحين', 'هاليوم', 'الان',
    'عندكم', 'عنده', 'عندها', 'في', 'ب', 'بالعياده', 'العياده',
    'هذا', 'شلون', 'لو', 'ياب',
  };

  /// أي فعل طلب/تنفيذ يعني أن الجملة ليست سؤال تواجد.
  static const Set<String> _blockTokens = {
    'اريد', 'ابي', 'ابغي', 'ابحث', 'ابحثلي', 'دور', 'دورلي',
    'وريني', 'اعرض', 'جدلي', 'جيبلي', 'جبلي', 'هاتلي',
    'شنو', 'منو', 'منهو',
    'اتصل', 'دق', 'دك', 'دقله', 'واتساب', 'واتس', 'دز', 'دزله',
    'راسل', 'ارسل', 'افتح', 'احجز', 'احجزلي',
  };

  static String? tryParseName(String query) {
    final tokens = ArabicTextUtils.normalize(query)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    if (tokens.any(_blockTokens.contains)) return null;
    if (!tokens.any(_presenceTokens.contains)) return null;
    if (!tokens.any(_titleTokens.contains)) return null;

    final nameTokens = <String>[];
    for (final t in tokens) {
      if (_titleTokens.contains(t) ||
          _presenceTokens.contains(t) ||
          _fillerTokens.contains(t)) {
        continue;
      }
      nameTokens.add(t);
    }
    if (nameTokens.isEmpty) return null;

    // «طبيب أطفال متوفر اليوم» = بحث اختصاص بمُعدِّل، لا سؤال عن طبيب باسمه.
    final joined = nameTokens.join(' ');
    if (SpecialtyCatalog.isSpecialtyTerm(joined)) return null;
    for (final t in nameTokens) {
      if (SpecialtyCatalog.isSpecialtyTerm(t)) return null;
    }
    return joined;
  }
}
