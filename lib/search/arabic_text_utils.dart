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

  /// تطبيع للمقارنة الضبابية على الجهاز (ليس لاستعلام Postgres الخام).
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('\u0640', '') // tatweel
        .replaceAll(_invisibleAndTashkeel, '')
        .replaceAll(_punctuation, ' ')
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
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
    // «د.» أو «د» في البداية.
    s = s.replaceFirst(RegExp(r'^د\.?\s*'), '').trim();
    // ألقاب شائعة إضافية قد تسبق الاسم (ليست جزءاً من النسب).
    s = s
        .replaceAll(
          RegExp(r'(?:^|\s)(?:الاستشاري|الأستشاري|الاستشارية|الأستشارية)(?=\s|$)'),
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
    r'(?:^|\s)(?:افتح|اريد|أريد|اكو|أكو|ابي|أبغى|عاوز|ابحث(?:\s+عن)?)(?=\s|$)',
  );

  /// أجزاء الاسم ذات المعنى بعد إزالة الألقاب وضجيج الاستعلام.
  static List<String> meaningfulNameTokens(String input) {
    final cleaned = _prepareNameQuery(input);
    if (cleaned.isEmpty) return const [];
    return cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.length >= 2)
        .toList();
  }

  static String _prepareNameQuery(String input) {
    var s = normalize(stripHonorifics(input.replaceAll('%', '')));
    s = s.replaceAll(_nameQueryNoise, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// مطابقة جزء اسم مع مراعاة أداة التعريف «ال».
  static bool nameContainsToken(String haystackNormalized, String tokenNormalized) {
    final h = haystackNormalized;
    final t = tokenNormalized;
    if (t.isEmpty) return false;
    if (h.contains(t)) return true;

    if (t.startsWith('ال') && t.length > 3) {
      final bare = t.substring(2);
      if (h.contains(bare)) return true;
    } else if (!t.startsWith('ال') && h.contains('ال$t')) {
      return true;
    }
    return false;
  }

  /// كل أجزاء الاسم ذات المعنى في الاستعلام موجودة في اسم الطبيب نفسه.
  static bool allDoctorNameTokensMatch(String doctorName, String query) {
    final tokens = meaningfulNameTokens(query);
    if (tokens.isEmpty) return false;
    final h = normalize(stripHonorifics(doctorName));
    return tokens.every((t) => nameContainsToken(h, t));
  }

  /// ترتيب أسماء الأطباء: تطابق كامل ثم عبارة ثم كل الأجزاء ثم بادئة ثم ضبابي.
  ///
  /// إذا احتوى الاستعلام على جزئين أو أكثر (مثل «علي ناصر») فلا تُعدّ كلمة
  /// مشتركة واحدة («علي») تطابقاً قوياً مع طبيب آخر.
  static int scoreDoctorNameMatch(String doctorName, String query) {
    final h = normalize(stripHonorifics(doctorName));
    final n = _prepareNameQuery(query);
    if (n.isEmpty || h.isEmpty) return 0;

    // 1. تطابق الاسم الكامل بعد التطبيع.
    if (h == n) return 100;

    final queryTokens =
        n.split(RegExp(r'\s+')).where((e) => e.length >= 2).toList();
    if (queryTokens.isEmpty) return 0;

    final hitCount = queryTokens.where((t) => nameContainsToken(h, t)).length;
    final allHit = hitCount == queryTokens.length;

    // 2. تطابق عبارة متعددة الكلمات كما هي داخل الاسم.
    if (queryTokens.length >= 2 && h.contains(n)) {
      return 95;
    }
    // عبارة بعد إزالة «ال» من الأجزاء.
    if (queryTokens.length >= 2) {
      final loosePhrase = queryTokens
          .map((t) => (t.startsWith('ال') && t.length > 3) ? t.substring(2) : t)
          .join(' ');
      if (loosePhrase.isNotEmpty && h.contains(loosePhrase)) {
        return 93;
      }
    }

    // 3. كل أجزاء الاسم ذات المعنى موجودة في نفس الطبيب.
    if (allHit && queryTokens.length >= 2) {
      return 90;
    }

    // بحث باسم واحد («علي»): نتائج متعددة مقبولة.
    if (queryTokens.length == 1) {
      final token = queryTokens.first;
      if (h.startsWith(token)) return 85;
      final nameParts = h.split(RegExp(r'\s+'));
      if (nameParts.any((p) => p == token || nameContainsToken(p, token))) {
        return 82;
      }
      if (nameContainsToken(h, token)) return 75;
      if (_fuzzyNameTokenHit(h, token)) return 40;
      return 0;
    }

    // 4–5. جزآن أو أكثر بدون تطابق كامل: ليست نتيجة قوية.
    return 0;
  }

  static bool _fuzzyNameTokenHit(String haystack, String token) {
    if (token.length < 3) return false;
    for (final part in haystack.split(RegExp(r'\s+'))) {
      if (part.length < 3) continue;
      if (part.startsWith(token) || token.startsWith(part)) return true;
      if (part.substring(0, 3) == token.substring(0, 3)) return true;
    }
    return false;
  }

  /// هل يبدو الاستعلام بحثاً عن اسم طبيب (لقب أو أجزاء اسم متعددة)؟
  static bool looksLikeDoctorNameQuery(String query) {
    final raw = query.trim();
    if (raw.isEmpty) return false;
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
