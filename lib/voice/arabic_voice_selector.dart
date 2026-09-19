import 'voice_settings.dart';

/// نتيجة اختيار صوت عربي متوافق مع تفضيل ذكر/أنثى.
class ArabicTtsVoiceChoice {
  const ArabicTtsVoiceChoice({
    required this.name,
    required this.locale,
    required this.identifier,
    required this.reason,
    required this.isGenuineFemale,
    required this.isGenuineMale,
    this.platformGender,
    this.quality,
  });

  final String name;
  final String locale;
  final String identifier;
  final String reason;

  /// true فقط عند وجود metadata/منصة تؤكد أن الصوت أنثوي عربي.
  final bool isGenuineFemale;
  final bool isGenuineMale;
  final String? platformGender;
  final String? quality;

  Map<String, String> toFlutterVoiceMap() {
    final map = <String, String>{
      'name': name,
      'locale': locale,
      'identifier': identifier,
    };
    return map;
  }
}

/// اكتشاف واختيار أصوات عربية فقط — بدون إنجليزي وبدون «أنثى مزيفة» عبر pitch.
class ArabicTtsVoiceSelector {
  ArabicTtsVoiceSelector._();

  static bool isArabicLocale(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    final locale = raw.toLowerCase().replaceAll('_', '-').trim();
    return locale == 'ar' || locale.startsWith('ar-');
  }

  static bool isBannedEnglishVoice(Map<String, dynamic> map) {
    final name = '${map['name'] ?? ''}'.toLowerCase();
    final locale = '${map['locale'] ?? map['language'] ?? ''}'.toLowerCase();
    final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
    if (locale.startsWith('en')) return true;
    const banned = [
      'samantha',
      'karen',
      'moira',
      'tessa',
      'kathy',
      'fiona',
      'victoria',
      'zoe',
      'allison',
      'ava',
      'susan',
      'serena',
    ];
    for (final b in banned) {
      if (name.contains(b) || id.contains(b)) return true;
    }
    return false;
  }

  static bool isArabicVoice(Map<String, dynamic> map) {
    if (isBannedEnglishVoice(map)) return false;
    final locale = '${map['locale'] ?? map['language'] ?? ''}';
    if (isArabicLocale(locale)) return true;
    final name = '${map['name'] ?? ''}'.toLowerCase();
    final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
    return name.contains('arabic') ||
        name.contains('arab') ||
        name.contains('majed') ||
        name.contains('maged') ||
        name.contains('soha') ||
        name.contains('samer') ||
        id.contains('.ar-') ||
        id.contains('.ar_') ||
        id.contains('arabic') ||
        id.contains('ttsbundle') ||
        id.contains('gryphon');
  }

  /// جنس مؤكد من المنصة فقط — لا تخمين من قوائم أسماء ثابتة.
  static String? platformGenderOf(Map<String, dynamic> map) {
    final raw = '${map['gender'] ?? map['voiceGender'] ?? ''}'.trim();
    if (raw.isEmpty) return null;
    return raw.toLowerCase();
  }

  static bool isGenuineFemale(Map<String, dynamic> map) {
    if (!isArabicVoice(map)) return false;
    final g = platformGenderOf(map);
    if (g == null) return false;
    return g.contains('female') || g.contains('woman');
  }

  static bool isGenuineMale(Map<String, dynamic> map) {
    if (!isArabicVoice(map)) return false;
    final g = platformGenderOf(map);
    if (g == null) {
      // Majed معروف ذكرًا على Apple عند غياب الحقل في بعض الجسور.
      final name = '${map['name'] ?? ''}'.toLowerCase();
      final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
      return name.contains('majed') ||
          name.contains('maged') ||
          id.contains('maged') ||
          id.contains('majed');
    }
    return g.contains('male') && !g.contains('female');
  }

  /// صوت Siri العصبي المكتشف (مثل Soha) — ليس اسم العرض وحده.
  static bool isDiscoveredSiriNeuralArabic(Map<String, dynamic> map) {
    if (!isArabicVoice(map)) return false;
    final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
    final source = '${map['source'] ?? ''}'.toLowerCase();
    return id.contains('ttsbundle') ||
        id.contains('gryphon') ||
        source == 'spoken_content' ||
        source == 'asset';
  }

  static String normalizeArabicLocale(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'ar-SA';
    final locale = raw.trim();
    if (isArabicLocale(locale)) return locale;
    return 'ar-SA';
  }

  static List<Map<String, dynamic>> arabicVoicesFrom(
    List<Map<String, dynamic>> all,
  ) => all.where(isArabicVoice).toList(growable: false);

  static List<Map<String, dynamic>> femaleCandidates(
    List<Map<String, dynamic>> all,
  ) => arabicVoicesFrom(all).where(isGenuineFemale).toList(growable: false);

  static List<Map<String, dynamic>> maleCandidates(
    List<Map<String, dynamic>> all,
  ) => arabicVoicesFrom(all).where(isGenuineMale).toList(growable: false);

  static ArabicTtsVoiceChoice? select({
    required List<Map<String, dynamic>> voices,
    required AssistantVoiceGender gender,
  }) {
    final arabic = arabicVoicesFrom(voices);
    if (arabic.isEmpty) return null;

    if (gender == AssistantVoiceGender.female) {
      final females = femaleCandidates(voices);
      if (females.isNotEmpty) {
        final best = _bestScored(
          females,
          preferMajedFallback: false,
          preferSiriNeuralFemale: true,
          preferSiriNeuralMale: false,
        );
        if (best != null) {
          return _choice(
            best,
            reason: 'genuine_arabic_female',
            genuineFemale: true,
            genuineMale: false,
          );
        }
      }
      // لا يوجد صوت أنثوي عربي حقيقي — أبقِ العربية عبر صوت ذكر/افتراضي
      // مع تصريح صريح: ليس اختيار أنثى ناجحًا.
      final fallback = _bestScored(
        arabic,
        preferMajedFallback: true,
        preferSiriNeuralFemale: false,
        preferSiriNeuralMale: true,
      );
      if (fallback == null) return null;
      return _choice(
        fallback,
        reason: 'no_arabic_female_available',
        genuineFemale: false,
        genuineMale: isGenuineMale(fallback),
      );
    }

    // ذكر: Siri Voice 1 أولًا إن وُجد؛ Majed احتياطي فقط.
    final males = maleCandidates(voices);
    final pool = males.isNotEmpty ? males : arabic;
    final hasSiriMale = pool.any(isSiriArabicVoice1Male);
    final best = _bestScored(
      pool,
      preferMajedFallback: !hasSiriMale,
      preferSiriNeuralFemale: false,
      preferSiriNeuralMale: true,
    );
    if (best == null) return null;
    final usedSiriMale = isSiriArabicVoice1Male(best);
    return _choice(
      best,
      reason: usedSiriMale ? 'genuine_arabic_male_siri' : 'arabic_male_fallback',
      genuineFemale: false,
      genuineMale: isGenuineMale(best),
    );
  }

  /// Siri Arabic Voice 1 (ذكر) — من معرّف مكتشف يحتوي samer.
  static bool isSiriArabicVoice1Male(Map<String, dynamic> map) {
    if (!isGenuineMale(map)) return false;
    if (!isDiscoveredSiriNeuralArabic(map)) return false;
    final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
    final name = '${map['name'] ?? ''}'.toLowerCase();
    return id.contains('samer') || name.contains('samer');
  }

  /// Siri Arabic Voice 2 (أنثى) — Soha.
  static bool isSiriArabicVoice2Female(Map<String, dynamic> map) {
    if (!isGenuineFemale(map)) return false;
    if (!isDiscoveredSiriNeuralArabic(map)) return false;
    final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
    final name = '${map['name'] ?? ''}'.toLowerCase();
    return id.contains('soha') || name.contains('soha');
  }

  static bool isMajedFallbackMale(Map<String, dynamic> map) {
    if (!isArabicVoice(map)) return false;
    final name = '${map['name'] ?? ''}'.toLowerCase();
    final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
    return name.contains('majed') ||
        name.contains('maged') ||
        id.contains('maged') ||
        id.contains('majed');
  }

  static Map<String, dynamic>? _bestScored(
    List<Map<String, dynamic>> maps, {
    required bool preferMajedFallback,
    required bool preferSiriNeuralFemale,
    required bool preferSiriNeuralMale,
  }) {
    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final map in maps) {
      final name = '${map['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final locale = '${map['locale'] ?? map['language'] ?? ''}';
      final id = '${map['identifier'] ?? map['id'] ?? ''}'.toLowerCase();
      var score = 10;
      if (isArabicLocale(locale)) score += 50;
      final loc = locale.toLowerCase().replaceAll('_', '-');
      if (loc.contains('ar-sa')) score += 20;
      if (loc.contains('ar-001')) score += 15;
      final quality = map['quality'];
      if (quality is num) score += quality.toInt() * 5;
      final qStr = '${map['quality'] ?? ''}'.toLowerCase();
      if (qStr.contains('enhanced') || qStr.contains('premium')) score += 25;
      if (id.contains('enhanced') || id.contains('premium')) score += 20;
      if (id.contains('neural') || id.contains('gryphon')) score += 30;
      final source = '${map['source'] ?? ''}'.toLowerCase();
      if (source == 'spoken_content') score += 35;
      if (source == 'asset') score += 25;

      if (preferSiriNeuralFemale && isGenuineFemale(map)) {
        if (isSiriArabicVoice2Female(map)) score += 80;
        if (isDiscoveredSiriNeuralArabic(map)) score += 40;
      }

      if (preferSiriNeuralMale && isGenuineMale(map)) {
        if (isSiriArabicVoice1Male(map)) score += 90;
        if (isDiscoveredSiriNeuralArabic(map) && !id.contains('soha')) {
          score += 40;
        }
      }

      // Majed: احتياطي فقط عندما لا يتوفر Siri Voice 1.
      if (preferMajedFallback && isMajedFallbackMale(map)) {
        score += 40;
      } else if (isMajedFallbackMale(map) && preferSiriNeuralMale) {
        score -= 20;
      }

      // لا تخلط الأجناس عند التفضيل الصريح.
      if (preferSiriNeuralMale && id.contains('soha')) score -= 100;
      if (preferSiriNeuralFemale && id.contains('samer')) score -= 100;

      if (score > bestScore) {
        bestScore = score;
        best = map;
      }
    }
    return best;
  }

  static ArabicTtsVoiceChoice? _choice(
    Map<String, dynamic> map, {
    required String reason,
    required bool genuineFemale,
    required bool genuineMale,
  }) {
    final name = '${map['name'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    final locale = normalizeArabicLocale(
      '${map['locale'] ?? map['language'] ?? ''}',
    );
    final identifier = '${map['identifier'] ?? map['id'] ?? name}'.trim();
    return ArabicTtsVoiceChoice(
      name: name,
      locale: locale,
      identifier: identifier,
      reason: reason,
      isGenuineFemale: genuineFemale,
      isGenuineMale: genuineMale,
      platformGender: platformGenderOf(map),
      quality: map['quality']?.toString(),
    );
  }

  /// كتلة تشخيص للطباعة في اللوج.
  static String formatDiagnostic(List<Map<String, dynamic>> all) {
    final arabic = arabicVoicesFrom(all);
    final females = femaleCandidates(all);
    final males = maleCandidates(all);
    final buf = StringBuffer()
      ..writeln('AVAILABLE ARABIC TTS VOICES:')
      ..writeln(arabic.isEmpty ? '[none]' : '')
      ..writeln(
        arabic
            .map(
              (m) =>
                  'name=${m['name']} | locale=${m['locale'] ?? m['language']} | '
                  'identifier=${m['identifier'] ?? m['id']} | '
                  'quality=${m['quality']} | gender=${m['gender'] ?? m['voiceGender']} | '
                  'raw=$m',
            )
            .join('\n'),
      )
      ..writeln('FEMALE CANDIDATES:')
      ..writeln(
        females.isEmpty
            ? '[none] — NO ARABIC FEMALE VOICE INSTALLED/AVAILABLE'
            : females
                  .map(
                    (m) =>
                        'name=${m['name']} | locale=${m['locale']} | '
                        'identifier=${m['identifier'] ?? m['id']} | gender=${m['gender']}',
                  )
                  .join('\n'),
      )
      ..writeln('MALE CANDIDATES:')
      ..writeln(
        males.isEmpty
            ? '[none]'
            : males
                  .map(
                    (m) =>
                        'name=${m['name']} | locale=${m['locale']} | '
                        'identifier=${m['identifier'] ?? m['id']} | gender=${m['gender']}',
                  )
                  .join('\n'),
      );
    return buf.toString();
  }
}
