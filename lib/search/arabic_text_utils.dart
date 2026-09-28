/// تمثيل استعلام مع فصل النص الأصلي عن التطبيع ومعنى البحث.
///
/// لا يُعدّل محتوى قاعدة البيانات — للتطابق على الجهاز فقط.
class NormalizedQuery {
  const NormalizedQuery({
    required this.originalText,
    required this.normalizedText,
    required this.searchMeaning,
  });

  /// النص كما أدخله المستخدم / أرجعه STT.
  final String originalText;

  /// تطبيع حذر للمقارنة (همزات/ى/ة/أرقام…) بدون aliases دلالية.
  final String normalizedText;

  /// معنى بحث خفيف بعد aliases آمنة (اريد/طبيب/مختبر…) — ليس لأسماء الأطباء المخزّنة.
  final String searchMeaning;
}

/// أدوات تطبيع وتهيئة النص العربي للبحث — بدون منطق AI.
class ArabicTextUtils {
  ArabicTextUtils._();

  static final RegExp _honorifics = RegExp(
    r'(?:^|\s)(?:ال)?د(?:\.|كتور|كتورة)?(?=\s|$)|(?:^|\s)(?:الدكتور|الدكتورة|دكتور|دكتورة)(?=\s|$)',
    caseSensitive: false,
  );

  static final RegExp _punctuation = RegExp(r'[.,،؛;:!؟?\-_/\\()\[\]{}«»"′′]+');

  /// علامات خفية وتشكيل تظهر غالباً من الإدخال الصوتي/النسخ.
  static final RegExp _invisibleAndTashkeel = RegExp(
    r'[\u064B-\u065F\u0670\u06D6-\u06ED\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF\u00A0]',
  );

  /// أرقام عربية-هندية → لاتينية (للاستعلام فقط).
  static final Map<String, String> _arabicDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  /// aliases خفيفة لمعنى البحث — لا تُطبَّق على أسماء مخزّنة في DB.
  static final List<(RegExp, String)> _searchMeaningAliases = [
    (
      RegExp(
        r'(?:^|\s)(?:اريدلي|أريدلي|اريد\s*لي|أريد\s*لي|ابي|أبغى|عاوز)(?=\s|$)',
      ),
      ' ',
    ),
    (RegExp(r'(?:^|\s)(?:اريد|أريد)(?=\s|$)'), ' '),
    (RegExp(r'(?:^|\s)(?:وين)(?=\s|$)'), ' اين '),
    (RegExp(r'(?:^|\s)(?:ال)?(?:دكاتره|دكاترة)(?=\s|$)'), ' طبيب '),
    (
      RegExp(
        r'(?:^|\s)(?:ال)?(?:دكتوره|دكتورة|دكتور|طبيب|طبيبه|طبيبة)(?=\s|$)',
      ),
      ' طبيب ',
    ),
    (RegExp(r'(?:^|\s)(?:مختبرات)(?=\s|$)'), ' مختبر '),
    (RegExp(r'(?:^|\s)(?:تحاليل|تحليلات)(?=\s|$)'), ' تحليل '),
    (RegExp(r'(?:^|\s)(?:باقات)(?=\s|$)'), ' باقه '),
    (RegExp(r'(?:^|\s)(?:عروض)(?=\s|$)'), ' عرض '),
    (RegExp(r'(?:^|\s)(?:اشعه|أشعة|اشعة)(?=\s|$)'), ' اشعه '),
    // لهجة عراقية شائعة — توحيد لمعنى البحث فقط.
    (RegExp(r'(?:^|\s)(?:جهال|الجهال)(?=\s|$)'), ' اطفال '),
    (RegExp(r'(?:^|\s)(?:اطفل)(?=\s|$)'), ' اطفال '),
    (RegExp(r'(?:^|\s)(?:صيدليه|صيدليةه)(?=\s|$)'), ' صيدليه '),
    (RegExp(r'(?:^|\s)(?:وتساب|واتس\s*اب)(?=\s|$)'), ' واتساب '),
    // أخطاء صوت شائعة: طبييعي → طبيعي
    (RegExp(r'(?:^|\s)طبيي+عي(?=\s|$)'), ' طبيعي '),
  ];

  /// مكمّلات مضبوطة لـ«عبد» — تُوحَّد شكلاً مفصولاً/موصولاً.
  /// لا نُشطر كل كلمة تبدأ بـ«عبد» لتجنب دمج أنساب غير مقصودة.
  static const Set<String> _abdComplements = {
    'الله',
    'الرحمن',
    'الرحيم',
    'الكريم',
    'الحسين',
    'الزهرة',
    'الزهرا',
    'العزيز',
    'الوهاب',
    'الستار',
    'الجبار',
    'القادر',
    'الرزاق',
    'اللطيف',
    'المهدي',
    'الرضا',
    'الامام',
    'الإمام',
    'الامير',
    'الأمير',
    'النبي',
    'المطلب',
    'الملك',
  };

  static bool isAbdComplement(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    if (_abdComplements.contains(t)) return true;
    if (t.startsWith('ال') && t.length > 2) {
      return _abdComplements.contains(t) || _abdComplements.contains(t.substring(2));
    }
    return _abdComplements.contains('ال$t');
  }

  /// توحيد مركّبات «عبد*» الشائعة إلى شكل موصول للمقارنة فقط.
  /// عبدالله ↔ عبد الله → عبدالله
  static String canonicalizeCompoundNames(String normalizedSpaced) {
    final raw = normalizedSpaced.trim();
    if (raw.isEmpty) return raw;

    final tokens = raw.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return raw;

    // 1) فك الموصول المعروف: عبدالله → عبد + الله
    final expanded = <String>[];
    for (final t in tokens) {
      if (t.startsWith('عبد') && t.length > 3) {
        final rest = t.substring(3);
        if (isAbdComplement(rest)) {
          expanded.add('عبد');
          expanded.add(rest);
          continue;
        }
      }
      expanded.add(t);
    }

    // 2) دمج عبد + مكمّل معروف → شكل موصول واحد
    final compact = <String>[];
    for (var i = 0; i < expanded.length; i++) {
      if (expanded[i] == 'عبد' &&
          i + 1 < expanded.length &&
          isAbdComplement(expanded[i + 1])) {
        compact.add('عبد${expanded[i + 1]}');
        i++;
      } else {
        compact.add(expanded[i]);
      }
    }
    return compact.join(' ');
  }

  /// تجهيز استعلام اسم طبيب للمطابقة (ألقاب + ضجيج + مركّبات).
  static String prepareDoctorNameQuery(String input) {
    return canonicalizeCompoundNames(_prepareNameQuery(input));
  }

  /// تجهيز استعلام اسم مختبر — نفس ضجيج الاتصال/واتساب، بلا قواعد أطباء.
  /// يعمل لأي مختبر يُضاف لاحقاً (بدون أسماء ثابتة).
  static String prepareLabNameQuery(String input) {
    var s = _prepareNameQuery(input);
    // بقايا «ل/لل» قبل كلمة مختبر (للمختبر / لمختبر الحياة).
    s = s.replaceFirst(RegExp(r'^ل{1,2}(?=مختبر)'), '').trim();
    s = s
        .replaceFirst(
          RegExp(r'^(?:ب|ل|على)?(?:ال)?مختبر(?:ات)?\s*'),
          '',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:مختبر|مختبرات)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// تجهيز استعلام اسم مركز أشعة — عام لأي مركز يُضاف لاحقاً.
  static String prepareRadiologyNameQuery(String input) {
    var s = _prepareNameQuery(input);
    s = s.replaceFirst(RegExp(r'^ل{1,2}(?=اشعه|اشعة|أشعة|مركز)'), '').trim();
    s = s
        .replaceFirst(
          RegExp(r'^(?:ب|ل|على)?(?:ال)?(?:اشعه|اشعة|أشعة|مركز\s*اشعه|مركز\s*أشعة)\s*'),
          '',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:اشعه|اشعة|أشعة|مركز)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// تجهيز استعلام اسم صيدلية — عام لأي صيدلية تُضاف لاحقاً.
  static String preparePharmacyNameQuery(String input) {
    var s = _prepareNameQuery(input);
    s = s.replaceFirst(RegExp(r'^ل{1,2}(?=صيدل)'), '').trim();
    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ب|ل|على)?(?:ال)?(?:صيدليه|صيدلية|صيدليات)\s*',
          ),
          '',
        )
        .replaceAll(
          RegExp(r'(?:^|\s)(?:ال)?(?:صيدليه|صيدلية|صيدليات)(?=\s|$)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// تجهيز استعلام مركز علاج طبيعي — عام لأي مركز في المنصة.
  static String preparePhysioNameQuery(String input) {
    var s = _prepareNameQuery(input);
    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ب|ل|على)?(?:ال)?(?:مركز|مراكز)?\s*'
            r'(?:علاج\s*طبيعي|العلاج\s*الطبيعي|فيزيو(?:ثيرابي)?|'
            r'تاهيل(?:\s*حركي)?|تأهيل(?:\s*حركي)?)\s*',
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:ال)?(?:علاج\s*طبيعي|فيزيو(?:ثيرابي)?|'
            r'تاهيل|تأهيل|معالج\s*طبيعي)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// تجهيز استعلام محل مستلزمات — عام لأي محل في المنصة.
  static String prepareSupplyNameQuery(String input) {
    var s = _prepareNameQuery(input);
    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ب|ل|على)?(?:ال)?(?:محل|محلات|معرض)?\s*'
            r'(?:مستلزمات(?:\s*طبيه)?|تجهيزات(?:\s*طبيه)?|'
            r'مواد\s*طبيه|معدات\s*طبيه)\s*',
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:ال)?(?:مستلزمات|تجهيزات|مواد\s*طبيه|'
            r'معدات\s*طبيه)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// تجهيز اسم مخزَّن للمقارنة مع الاستعلام.
  static String prepareDoctorStoredName(String storedName) {
    return canonicalizeCompoundNames(normalize(stripHonorifics(storedName)));
  }

  /// تحويل الأرقام العربية/الفارسية إلى لاتينية دون تغيير باقي النص.
  static String normalizeDigits(String input) {
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_arabicDigits[ch] ?? ch);
    }
    return buf.toString();
  }

  /// تطبيع للمقارنة الضبابية على الجهاز (ليس لاستعلام Postgres الخام).
  static String normalize(String input) {
    var s = normalizeDigits(input)
        .toLowerCase()
        .replaceAll('\u0640', '') // tatweel
        .replaceAll(_invisibleAndTashkeel, '')
        .replaceAll(_punctuation, ' ');
    // احفظ حرف الجر «على» ككلمة كاملة قبل طي ى→ي (وإلا على→علي).
    // مهم: لا تلمس «الأعلى/أعلى» التي تحتوي على كسلسلة جزئية.
    const alaToken = '\uE000ALA\uE001';
    s = ' $s ';
    s = s.replaceAll(' على ', ' $alaToken ');
    s = s
        // Yeh / Kaf variants (macOS speech often emits Persian forms).
        .replaceAll('ی', 'ي') // U+06CC → U+064A
        .replaceAll('ى', 'ي')
        .replaceAll('ک', 'ك') // U+06A9 → U+0643
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(alaToken, 'على')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// معنى بحث بعد aliases آمنة — للاستعلامات فقط وليس لنصوص قاعدة البيانات.
  static String toSearchMeaning(String input) {
    var s = ' ${normalize(input)} ';
    for (final entry in _searchMeaningAliases) {
      s = s.replaceAll(entry.$1, entry.$2);
    }
    // «د» منفصلة كاختصار شائع لطبيب (حذرة: كلمة كاملة فقط).
    s = s.replaceAll(RegExp(r'(?:^|\s)د(?=\s|$)'), ' طبيب ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// يفصل الأصل عن التطبيع عن معنى البحث.
  static NormalizedQuery prepareQuery(String input) {
    final original = input.trim();
    final normalized = normalize(original);
    return NormalizedQuery(
      originalText: original,
      normalizedText: normalized,
      searchMeaning: toSearchMeaning(original),
    );
  }

  /// هل لمعنيي بحث نفس المفتاح الدلالي الخفيف؟
  static bool sameSearchMeaning(String a, String b) {
    return toSearchMeaning(a) == toSearchMeaning(b);
  }

  /// إزالة ألقاب طبية شائعة من استعلام البحث.
  static String stripHonorifics(String input) {
    var s = input.trim();
    // تكرار بسيط لإزالة أكثر من لقب متتالٍ.
    for (var i = 0; i < 3; i++) {
      final next = s
          .replaceAll(_honorifics, ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (next == s) break;
      s = next;
    }
    // «د.» أو «د » قبل الاسم — لا تقطع «دلني/دورلي/دزله».
    s = s.replaceFirst(RegExp(r'^د\.\s*'), '').trim();
    s = s.replaceFirst(RegExp(r'^د\s+'), '').trim();
    s = s
        .replaceFirst(
          RegExp(r'^(?:ال)?دكتور(?:ه|ة)?\s*'),
          '',
        )
        .trim();
    s = s.replaceFirst(RegExp(r'^(?:ال)?دكتورة?\s*'), '').trim();
    // ألقاب شائعة إضافية قد تسبق الاسم (ليست جزءاً من النسب).
    s = s
        .replaceAll(
          RegExp(
            r'(?:^|\s)(?:الاستشاري|الأستشاري|الاستشارية|الأستشارية)(?=\s|$)',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// أشكال همزة الألف الشائعة لاستخدامها في ilike على Postgres.
  static Set<String> alefVariants(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return {};
    final out = <String>{raw};

    final flattened = raw
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ی', 'ي')
        .replaceAll('ى', 'ي')
        .replaceAll('ک', 'ك');
    out.add(flattened);

    if (flattened.isNotEmpty && flattened.startsWith('ا')) {
      out.add('أ${flattened.substring(1)}');
      out.add('إ${flattened.substring(1)}');
      out.add('آ${flattened.substring(1)}');
    }

    return out.where((e) => e.trim().isNotEmpty).toSet();
  }

  /// أشكال للـ ilike على Postgres: الموصول والمفصول لمركّبات عبد المعروفة.
  static List<String> doctorNameIlikeNeedles(String query) {
    final out = <String>{};
    final stripped = stripHonorifics(query).trim();
    if (stripped.isNotEmpty) out.add(stripped);

    final prepared = prepareDoctorNameQuery(query);
    if (prepared.isNotEmpty) out.add(prepared);

    // أضف الشكل المفصول لكل مكمّل عبد موصول ليوافق صفوف DB التي تفصل المسافة.
    for (final token in prepared.split(RegExp(r'\s+'))) {
      if (token.startsWith('عبد') &&
          token.length > 3 &&
          isAbdComplement(token.substring(3))) {
        out.add(prepared.replaceAll(token, 'عبد ${token.substring(3)}'));
      }
    }

    final tokens = meaningfulNameTokens(query);
    if (tokens.length >= 2) {
      out.add(tokens.take(2).join(' '));
      // مفصول لأول توكن عبد* إن وُجد
      final spacedPair = tokens.take(2).map((t) {
        if (t.startsWith('عبد') &&
            t.length > 3 &&
            isAbdComplement(t.substring(3))) {
          return 'عبد ${t.substring(3)}';
        }
        return t;
      }).join(' ');
      out.add(spacedPair);
    }
    for (final t in tokens.take(3)) {
      out.add(t);
      if (t.startsWith('عبد') &&
          t.length > 3 &&
          isAbdComplement(t.substring(3))) {
        out.add('عبد ${t.substring(3)}');
      }
    }

    return out
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.length >= 2)
        .toSet()
        .toList();
  }

  /// رموز بحث مفيدة لأسماء الأطباء (بدون ألقاب، مع أشكال الهمزة).
  static List<String> doctorSearchVariants(String query) {
    final variants = <String>{};
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    variants.add(trimmed);

    final stripped = stripHonorifics(trimmed);
    if (stripped.isNotEmpty) {
      variants.add(stripped);
      variants.addAll(alefVariants(stripped));
      // صيغة مطبّعة للبحث في Postgres (تعالج ي الفارسية من الصوت).
      final normalizedSpacey = normalize(stripped);
      if (normalizedSpacey.isNotEmpty) {
        variants.add(normalizedSpacey);
      }
    }

    final tokens = stripped
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toList();

    for (final token in tokens) {
      variants.add(token);
      variants.addAll(alefVariants(token));
      final nt = normalize(token);
      if (nt.isNotEmpty) variants.add(nt);
      // بدون «ال» للقب النسب.
      if (token.startsWith('ال') && token.length > 3) {
        final bare = token.substring(2);
        variants.add(bare);
        variants.addAll(alefVariants(bare));
      }
    }

    // إذا بقي أكثر من كلمة، أضف أول كلمتين معًا (اسم + جزء من النسب).
    if (tokens.length >= 2) {
      final pair = '${tokens[0]} ${tokens[1]}';
      variants.add(pair);
      variants.addAll(alefVariants(pair));
      variants.add(normalize(pair));
    }

    return variants
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  /// كلمات استعلام شائعة ليست جزءاً من اسم الطبيب.
  static final RegExp _nameQueryNoise = RegExp(
    r'(?:^|\s)(?:افتح|اريدلي|أريدلي|اريد|أريد|اكو|أكو|ابي|أبغى|عاوز|وين|'
    r'ابحث(?:\s*لي)?(?:\s+عن)?|'
    r'عياده|عيادته|عيادة|عيادتها|مكان|مكانه|موقع|موقعه|عنوان|عنوانه|'
    r'رساله|رسالة|راسل|مارسل|مرسل|'
    r'اتصل|اتصال|كل[مّ]|كلم|رن|رنّ|dial|call|'
    r'واتساب|واتس|وتساب|whatsapp|watsapp|'
    r'دزله|دزّله|دزوله|راسل|أرسل|ارسل)(?=\s|$)',
  );

  /// أجزاء الاسم ذات المعنى بعد إزالة الألقاب وضجيج الاستعلام.
  static List<String> meaningfulNameTokens(String input) {
    final cleaned = prepareDoctorNameQuery(input);
    if (cleaned.isEmpty) return const [];
    return cleaned.split(RegExp(r'\s+')).where((e) => e.length >= 2).toList();
  }

  static String _prepareNameQuery(String input) {
    // تطبيع مبكّر ثم إزالة فعل الاتصال وحرف الجر قبل اللقب، ثم الألقاب.
    // مهم: stripHonorifics قبل إزالة «علي»(من «على») يحوّل
    // «علي دكتور علي ناصر» → «علي علي ناصر» ويُفسد المطابقة.
    var s = normalize(input.replaceAll('%', ''));
    s = s
        .replaceFirst(
          RegExp(
            r'^(?:اتصل|اتصال|كل[مّ]|كلم|رن|رنّ|dial|call)\s+',
          ),
          '',
        )
        .trim();
    // بالدكتور / للدكتور / على الدكتور / علي الدكتور (بعد تطبيع على→علي)
    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ب|ل|على|علي)?\s*(?:ال)?(?:دكتور|دكتوره|طبيب|طبيبه)\s+',
          ),
          '',
        )
        .trim();
    // بقايا «على/علي» قبل لقب إن بقي اللقب، أو قبل ترتيب فقط.
    s = s.replaceFirst(
      RegExp(
        r'^(?:على|علي)\s+(?=ال?(?:دكتور|دكتوره|طبيب|طبيبه)|'
        r'ال?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير))',
      ),
      '',
    );
    s = stripHonorifics(s);
    s = normalize(s);
    s = s
        .replaceAll(_nameQueryNoise, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    s = s.replaceFirst(RegExp(r'^[بل]\s+'), '').trim();
    if (RegExp(
      r'^(?:على|علي)\s+ال?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)\b',
    ).hasMatch(s)) {
      return '';
    }
    // ترتيب وحده بعد إزالة «على/علي» — ليس اسم طبيب.
    if (RegExp(
      r'^ال?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?$',
    ).hasMatch(s)) {
      return '';
    }
    // أفعال إرشاد بلا هدف.
    if (RegExp(
      r'^(?:دلني|وريني|شوفلي|طلعلي|دورلي|جيبلي)(?:\s+على)?$',
    ).hasMatch(s)) {
      return '';
    }
    return s;
  }

  /// مطابقة جزء اسم مع مراعاة أداة التعريف «ال».
  static bool nameContainsToken(
    String haystackNormalized,
    String tokenNormalized,
  ) {
    final h = haystackNormalized;
    final t = tokenNormalized;
    if (t.isEmpty) return false;
    if (h.contains(t)) return true;

    if (t.startsWith('ال') && t.length > 3) {
      final bare = t.substring(2);
      if (h.contains(bare)) return true;
      // تطابق جزء اسم كامل بدون «ال» (سعيدي ↔ السعيدي).
      for (final part in h.split(RegExp(r'\s+'))) {
        if (part == bare) return true;
        if (part.startsWith('ال') &&
            part.length > 3 &&
            part.substring(2) == bare) {
          return true;
        }
      }
    } else if (!t.startsWith('ال') && h.contains('ال$t')) {
      return true;
    }
    return false;
  }

  /// كل أجزاء الاسم ذات المعنى في الاستعلام موجودة في اسم الطبيب نفسه.
  static bool allDoctorNameTokensMatch(String doctorName, String query) {
    final tokens = meaningfulNameTokens(query);
    if (tokens.isEmpty) return false;
    final h = prepareDoctorStoredName(doctorName);
    return tokens.every((t) => nameContainsToken(h, t));
  }

  /// ترتيب أسماء الأطباء عبر [DoctorNameMatcher] (مصدر واحد للمطابقة).
  ///
  /// إذا احتوى الاستعلام على جزئين أو أكثر (مثل «علي ناصر») فلا تُعدّ كلمة
  /// مشتركة واحدة («علي») تطابقاً قوياً مع طبيب آخر.
  static int scoreDoctorNameMatch(String doctorName, String query) {
    // استيراد متأخر عبر ملف المنادي لتجنب دورة: نستدعي المنطق هنا مباشرة
    // بنفس قواعد DoctorNameMatcher — التفويض عبر إنشاء خفيف.
    return _doctorNameMatcherScore(doctorName, query);
  }

  static int _doctorNameMatcherScore(String doctorName, String query) {
    // يُنفَّذ في doctor_name_matcher عبر الاستدعاء من SmartSearch؛
    // هنا نسخة متزامنة مع التطبيع المركّب للحفاظ على الاختبارات القديمة.
    final h = prepareDoctorStoredName(doctorName);
    final n = prepareDoctorNameQuery(query);
    if (n.isEmpty || h.isEmpty) return 0;
    if (h == n) return 100;

    final queryTokens =
        n.split(RegExp(r'\s+')).where((e) => e.length >= 2).toList();
    if (queryTokens.isEmpty) return 0;

    final hitCount = queryTokens.where((t) => nameContainsToken(h, t)).length;
    final allHit = hitCount == queryTokens.length;

    if (queryTokens.length >= 2 && h.contains(n)) return 96;

    if (queryTokens.length >= 2) {
      final loosePhrase = queryTokens
          .map((t) => (t.startsWith('ال') && t.length > 3) ? t.substring(2) : t)
          .join(' ');
      if (loosePhrase.isNotEmpty && h.contains(loosePhrase)) return 93;
    }

    if (allHit && queryTokens.length >= 2) {
      final nameParts = h.split(RegExp(r'\s+'));
      var ordered = true;
      var ni = 0;
      for (final part in nameParts) {
        if (ni >= queryTokens.length) break;
        if (nameContainsToken(part, queryTokens[ni]) ||
            nameContainsToken(queryTokens[ni], part)) {
          ni++;
        }
      }
      ordered = ni == queryTokens.length;
      return ordered ? 90 : 72;
    }

    if (queryTokens.length >= 2) {
      final nameParts = h.split(RegExp(r'\s+'));
      var progressiveOk = true;
      for (var i = 0; i < queryTokens.length; i++) {
        final t = queryTokens[i];
        final isLast = i == queryTokens.length - 1;
        if (nameContainsToken(h, t)) continue;
        if (isLast && t.length >= 2) {
          final prefixHit = nameParts.any(
            (p) => p.startsWith(t) && p.length > t.length,
          );
          if (prefixHit) continue;
        }
        progressiveOk = false;
        break;
      }
      if (progressiveOk) return 86;
      return 0;
    }

    final token = queryTokens.first;
    if (h.startsWith(token)) return 85;
    final nameParts = h.split(RegExp(r'\s+'));
    if (nameParts.any((p) => p == token || nameContainsToken(p, token))) {
      return 82;
    }
    if (nameParts.any((p) => p.startsWith(token) && token.length >= 2)) {
      return 78;
    }
    if (nameContainsToken(h, token)) return 75;
    // لا fuzzy واسع في مسار الأسماء — أفضل لا نتيجة من طبيب خاطئ.
    return 0;
  }

  /// هل يبدو الاستعلام بحثاً عن اسم طبيب (لقب أو أجزاء اسم متعددة)؟
  static bool looksLikeDoctorNameQuery(String query) {
    final raw = query.trim();
    if (raw.isEmpty) return false;
    final n = normalize(raw);
    // أفعال إرشاد بلا هدف — ليست اسم طبيب ولو صارت كلمتين بعد التطبيع.
    if (RegExp(
      r'^(?:دلني|وريني|شوفلي|طلعلي|دورلي|جيبلي)(?:\s+على)?$',
    ).hasMatch(n)) {
      return false;
    }
    if (_honorifics.hasMatch(raw) ||
        raw.startsWith('د.') ||
        raw.startsWith('د ')) {
      return true;
    }
    return meaningfulNameTokens(raw).length >= 2;
  }

  /// درجة تطابق اسم عربي بعد التطبيع وإزالة الألقاب.
  static int scoreMatch(String haystack, String needle) {
    final h = normalize(stripHonorifics(haystack));
    final n = normalize(stripHonorifics(needle.replaceAll('%', '')));
    if (n.isEmpty || h.isEmpty) return 0;
    if (h == n) return 100;
    if (h.startsWith(n)) return 90;
    if (h.contains(n)) return 70;

    final parts = n.split(RegExp(r'\s+')).where((e) => e.length >= 2).toList();
    if (parts.isEmpty) return 0;

    var hits = 0;
    for (final p in parts) {
      if (nameContainsToken(h, p)) hits++;
    }
    if (hits == 0) return 0;
    if (hits == parts.length) {
      return 55 + (parts.length >= 2 ? 15 : 0);
    }
    return 30 + ((hits / parts.length) * 35).round();
  }
}
