import '../search/arabic_text_utils.dart';

/// فئة محادثة اجتماعية — Phase 3D STEP 2/3.
enum GhadeerSocialCategory {
  greeting,
  morning,
  evening,
  howAreYou,
  thanks,
  positiveFeedback,
  affection,
  goodbye,
  goodNight,
}

/// حالة اجتماعية جلسة فقط — بلا ثبات دائم وبلا بيانات طبية.
class GhadeerSocialContext {
  const GhadeerSocialContext({
    this.lastCategory,
    this.lastVariantIndex = 0,
    this.socialTurnCount = 0,
    this.nameUsedOnLastTurn = false,
  });

  static const empty = GhadeerSocialContext();

  final GhadeerSocialCategory? lastCategory;
  final int lastVariantIndex;
  final int socialTurnCount;

  /// هل استُخدم الاسم في آخر رد اجتماعي؟ لمنع التكرار الممل.
  final bool nameUsedOnLastTurn;

  GhadeerSocialContext copyWith({
    GhadeerSocialCategory? lastCategory,
    int? lastVariantIndex,
    int? socialTurnCount,
    bool? nameUsedOnLastTurn,
  }) {
    return GhadeerSocialContext(
      lastCategory: lastCategory ?? this.lastCategory,
      lastVariantIndex: lastVariantIndex ?? this.lastVariantIndex,
      socialTurnCount: socialTurnCount ?? this.socialTurnCount,
      nameUsedOnLastTurn: nameUsedOnLastTurn ?? this.nameUsedOnLastTurn,
    );
  }

  Map<String, Object?> debugMap() => {
        'socialLastCategory': lastCategory?.name,
        'socialLastVariantIndex': lastVariantIndex,
        'socialTurnCount': socialTurnCount,
        'socialNameUsedOnLastTurn': nameUsedOnLastTurn,
      };
}

/// نتيجة رد اجتماعي مع تحديث الحالة.
class GhadeerSocialReply {
  const GhadeerSocialReply({
    required this.message,
    required this.category,
    required this.variantIndex,
    required this.usedName,
    required this.nextContext,
  });

  final String message;
  final GhadeerSocialCategory category;
  final int variantIndex;
  final bool usedName;
  final GhadeerSocialContext nextContext;
}

/// Phase 3D STEP 2/3 — محادثة اجتماعية عراقية خفيفة وحتمية.
///
/// جمل standalone فقط. لا طب، لا بحث، لا ملف دائم، لا OpenAI.
class GhadeerSocialConversation {
  const GhadeerSocialConversation();

  // —— STEP 2 ثابتات = المتغير الأول لكل فئة (توافق خلفي) ——
  static const String answerGreeting = 'هلا بيك، شلون أگدر أساعدك؟';
  static const String answerMorning =
      'صباح النور، أتمنى لك يوم طيب. شلون أگدر أساعدك؟';
  static const String answerEvening = 'مساء النور، شلون أگدر أساعدك؟';
  static const String answerHowAreYou =
      'بخير، دامك بخير. شلون أگدر أساعدك؟';
  static const String answerThanks = 'تدلل، بالخدمة دائماً.';
  static const String answerPositiveFeedback =
      'تسلم، هذا الكلام يسعدني، وإن شاء الله أبقى عند حسن ظنك بالخدمة.';
  static const String answerAffection =
      'تسلم، كلامك عزيز عليّ، وآني موجود حتى أساعدك 🌷';
  static const String answerGoodbye = 'بأمان الله، وأي وقت تحتاجني آني موجود.';
  static const String answerGoodNight =
      'وإنت من أهله، ليلة هادئة إن شاء الله.';

  static const Map<GhadeerSocialCategory, List<String>> catalogs = {
    GhadeerSocialCategory.greeting: [
      answerGreeting,
      'أهلاً بيك، شتحتاج مني؟',
      'هلا وغلا، شلون أساعدك؟',
    ],
    GhadeerSocialCategory.morning: [
      answerMorning,
      'صباح النور، يومك طيب إن شاء الله. شلون أگدر أساعدك؟',
    ],
    GhadeerSocialCategory.evening: [
      answerEvening,
      'مساء النور، شتحتاج مني؟',
    ],
    GhadeerSocialCategory.howAreYou: [
      answerHowAreYou,
      'تمام والحمد لله، شلونك إنت؟ شلون أگدر أساعدك؟',
    ],
    GhadeerSocialCategory.thanks: [
      answerThanks,
      'العفو، هذا واجبي.',
      'تدلل، بأي وقت.',
    ],
    GhadeerSocialCategory.positiveFeedback: [
      answerPositiveFeedback,
      'تسلم، سعيد إن التطبيق عجبك.',
      'شكراً إلك، هذا يشجعني أكون أفضل.',
    ],
    GhadeerSocialCategory.affection: [
      answerAffection,
    ],
    GhadeerSocialCategory.goodbye: [
      answerGoodbye,
      'بأمان الله، يومك سعيد.',
      'في أمان الله، نشوفك على خير.',
    ],
    GhadeerSocialCategory.goodNight: [
      answerGoodNight,
    ],
  };

  /// توافق STEP 2: بدون سياق/اسم → المتغير 0.
  String? tryAnswer(
    String query, {
    String? firstName,
    GhadeerSocialContext socialContext = GhadeerSocialContext.empty,
  }) {
    return resolve(
      query,
      firstName: firstName,
      socialContext: socialContext,
    )?.message;
  }

  GhadeerSocialReply? resolve(
    String query, {
    String? firstName,
    GhadeerSocialContext socialContext = GhadeerSocialContext.empty,
  }) {
    final category = detectCategory(query);
    if (category == null) return null;

    final catalog = catalogs[category]!;
    final variantIndex = _selectVariantIndex(
      category: category,
      catalogLength: catalog.length,
      socialContext: socialContext,
    );
    final base = catalog[variantIndex];
    final useName = _shouldUseName(
      category: category,
      firstName: firstName,
      socialContext: socialContext,
    );
    final message = useName
        ? _applyFirstName(base, firstName!.trim(), category)
        : base;

    final next = GhadeerSocialContext(
      lastCategory: category,
      lastVariantIndex: variantIndex,
      socialTurnCount: socialContext.socialTurnCount + 1,
      nameUsedOnLastTurn: useName,
    );

    return GhadeerSocialReply(
      message: message,
      category: category,
      variantIndex: variantIndex,
      usedName: useName,
      nextContext: next,
    );
  }

  bool isStandaloneSocial(String query) => detectCategory(query) != null;

  GhadeerSocialCategory? detectCategory(String query) {
    final n = _normalize(query);
    if (n.isEmpty) return null;
    if (_isGoodNight(n)) return GhadeerSocialCategory.goodNight;
    if (_isMorning(n)) return GhadeerSocialCategory.morning;
    if (_isEvening(n)) return GhadeerSocialCategory.evening;
    if (_isHowAreYou(n)) return GhadeerSocialCategory.howAreYou;
    if (_isAffection(n)) return GhadeerSocialCategory.affection;
    if (_isPositiveFeedback(n)) return GhadeerSocialCategory.positiveFeedback;
    if (_isThanks(n)) return GhadeerSocialCategory.thanks;
    if (_isGoodbye(n)) return GhadeerSocialCategory.goodbye;
    if (_isGreeting(n)) return GhadeerSocialCategory.greeting;
    return null;
  }

  /// اختيار حتمي: عند تكرار نفس الفئة ندوّر، وإلا نبدأ من 0 ثم نستند لعداد الأدوار.
  static int _selectVariantIndex({
    required GhadeerSocialCategory category,
    required int catalogLength,
    required GhadeerSocialContext socialContext,
  }) {
    if (catalogLength <= 1) return 0;
    if (socialContext.lastCategory == category) {
      return (socialContext.lastVariantIndex + 1) % catalogLength;
    }
    return socialContext.socialTurnCount % catalogLength;
  }

  /// استخدم الاسم إذا وُجد ولم يُستخدم في الدور الاجتماعي السابق، وللفئات المناسبة فقط.
  static bool _shouldUseName({
    required GhadeerSocialCategory category,
    required String? firstName,
    required GhadeerSocialContext socialContext,
  }) {
    final name = firstName?.trim() ?? '';
    if (name.isEmpty) return false;
    if (socialContext.nameUsedOnLastTurn) return false;
    switch (category) {
      case GhadeerSocialCategory.greeting:
      case GhadeerSocialCategory.morning:
      case GhadeerSocialCategory.evening:
      case GhadeerSocialCategory.howAreYou:
      case GhadeerSocialCategory.thanks:
      case GhadeerSocialCategory.goodbye:
        return true;
      case GhadeerSocialCategory.positiveFeedback:
      case GhadeerSocialCategory.affection:
      case GhadeerSocialCategory.goodNight:
        return false;
    }
  }

  static String _applyFirstName(
    String base,
    String name,
    GhadeerSocialCategory category,
  ) {
    switch (category) {
      case GhadeerSocialCategory.greeting:
        if (base.startsWith('هلا بيك')) {
          return base.replaceFirst('هلا بيك', 'هلا $name');
        }
        if (base.startsWith('أهلاً بيك') || base.startsWith('اهلا بيك')) {
          return base
              .replaceFirst('أهلاً بيك', 'أهلاً $name')
              .replaceFirst('اهلا بيك', 'اهلا $name');
        }
        if (base.startsWith('هلا وغلا')) {
          return 'هلا وغلا $name، شلون أساعدك؟';
        }
        return 'هلا $name، شلون أگدر أساعدك؟';
      case GhadeerSocialCategory.morning:
        return base.replaceFirst('صباح النور،', 'صباح النور $name،');
      case GhadeerSocialCategory.evening:
        return base.replaceFirst('مساء النور،', 'مساء النور $name،');
      case GhadeerSocialCategory.howAreYou:
        if (base.startsWith('بخير،')) {
          return base.replaceFirst('بخير،', 'بخير $name،');
        }
        if (base.startsWith('تمام')) {
          return 'تمام $name والحمد لله، شلونك إنت؟ شلون أگدر أساعدك؟';
        }
        return 'بخير $name، دامك بخير. شلون أگدر أساعدك؟';
      case GhadeerSocialCategory.thanks:
        if (base.startsWith('تدلل')) {
          return base.replaceFirst('تدلل', 'تدلل $name');
        }
        if (base.startsWith('العفو')) {
          return 'العفو $name، هذا واجبي.';
        }
        return 'تدلل $name، بالخدمة دائماً.';
      case GhadeerSocialCategory.goodbye:
        if (base.startsWith('بأمان الله')) {
          return base.replaceFirst('بأمان الله،', 'بأمان الله $name،');
        }
        if (base.startsWith('في أمان الله')) {
          return base.replaceFirst('في أمان الله،', 'في أمان الله $name،');
        }
        return 'بأمان الله $name، وأي وقت تحتاجني آني موجود.';
      case GhadeerSocialCategory.positiveFeedback:
      case GhadeerSocialCategory.affection:
      case GhadeerSocialCategory.goodNight:
        return base;
    }
  }

  static String _normalize(String raw) {
    var s = ArabicTextUtils.normalize(raw.trim());
    s = s
        .replaceAll(RegExp(r'[؟?!.،,;:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  static bool _isGreeting(String n) => RegExp(
        r'^(?:هلا(?:\s*بيك)?|مرحبا|مرحباً)$',
      ).hasMatch(n);

  static bool _isMorning(String n) => RegExp(
        r'^(?:صباح\s*(?:الخير|النور))$',
      ).hasMatch(n);

  static bool _isEvening(String n) => RegExp(
        r'^(?:مساء\s*الخير|مساك\s*الله\s*بالخير)$',
      ).hasMatch(n);

  static bool _isHowAreYou(String n) => RegExp(
        r'^(?:شلونك|شخبارك|شكو\s*ماكو)$',
      ).hasMatch(n);

  static bool _isThanks(String n) => RegExp(
        r'^(?:شكرا|شكراً|ممنون|عاشت\s*ايدك|تسلم)$',
      ).hasMatch(n);

  static bool _isPositiveFeedback(String n) => RegExp(
        r'^(?:خوش\s*تطبيق|تطبيق\s*(?:حلو|رائع)|(?:انت|أنت)\s*خوش\s*مساعد)$',
      ).hasMatch(n);

  static bool _isAffection(String n) => RegExp(
        r'^(?:احبك|أحبك)$',
      ).hasMatch(n);

  static bool _isGoodbye(String n) => RegExp(
        r'^(?:مع\s*السلامه|باي|اشوفك\s*بعدين)$',
      ).hasMatch(n);

  static bool _isGoodNight(String n) => RegExp(
        r'^(?:تصبح(?:ون)?\s*عل[يى]\s*خير)$',
      ).hasMatch(n);
}
