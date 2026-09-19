import '../../../search/arabic_text_utils.dart';
import 'respiratory_alias_catalog.dart';
import 'respiratory_models.dart';

/// مفسّر تنفسي — نص أولاً؛ ليس محرك تشخيص.
class RespiratoryInterpreter {
  const RespiratoryInterpreter({this.aliases = const RespiratoryAliasCatalog()});

  final RespiratoryAliasCatalog aliases;

  bool looksLikeRespiratory(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    if (aliases.looksLikeCough(n)) return true;
    if (aliases.looksLikeBreathlessness(n)) return true;
    return RegExp(
      r'(?:صفير\s*(?:بالنفس|بالصدر)|'
      r'بلغم|دم\s*(?:ويا|بال)?(?:السعال|البلغم)|اكح\s*دم|'
      r'ربو|copd|مرض\s*رئوي|التهاب\s*صدر|'
      r'اشعه\s*صدر|أشعة\s*صدر|صدر\s*(?:يوجع|توجع)|'
      r'الم\s*(?:بال)?صدر|وجع\s*صدر|سعال|كحه)',
    ).hasMatch(n);
  }

  /// رد عمر قصير قد يكمّل جلسة تنفسية نشطة (ابن/طفل) — ليس فتح أسنان.
  bool looksLikeAgeReply(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return false;
    // نية صريحة أخرى تتجاوز استمرارية العمر.
    if (RegExp(
      r'(?:طبيب\s*اسنان|أسنان|اسنان|ظهر|رقبه|حامل|مختبر|اشعه\s*(?!صدر))',
    ).hasMatch(n)) {
      return false;
    }
    // «عمري …» للمالك — ليس عمر الطفل في جلسة ابني.
    if (RegExp(r'(?:^|\s)عمري(?:\s|$)').hasMatch(n)) return false;
    return RegExp(
      r'(?:عمر[هة]\s*\d{1,2}\s*(?:سنه|سنة|سنوات|سنين)?|'
      r'\d{1,2}\s*(?:سنه|سنة|سنوات|سنين))',
    ).hasMatch(n);
  }

  RespiratoryInterpretation interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return RespiratoryInterpretation.none;

    final other = _otherPerson(n);
    final followUp = RegExp(r'تابع\s*وياي').hasMatch(n);
    final education = RegExp(
      r'(?:شنو\s*اعراض|شنو\s*أعراض|شنو\s*اسباب|متى\s*السعال\s*يحتاج|'
      r'ما\s*هي\s*اعراض)',
    ).hasMatch(n);
    final whereGo =
        RegExp(r'(?:وين\s*اروح|وين\s*أروح|منو\s*اراجع|منو\s*أراجع|منو\s*الطبيب)')
            .hasMatch(n);
    final booking =
        RegExp(r'(?:اريد\s*احجز|أريد\s*أحجز|احجزلي|اريد\s*رقم)').hasMatch(n);
    final imagingWhere = RegExp(
      r'(?:وين\s*اسويها|وين\s*أسويها|وين\s*اسوي\s*الاشعه|'
      r'وين\s*الغدير|اريد\s*اسوي\s*الاشعه)',
    ).hasMatch(n);
    final directXray = RegExp(
      r'(?:اريد\s*(?:اسوي\s*)?اشعه\s*صدر|أريد\s*(?:أسوي\s*)?أشعة\s*صدر|'
      r'اشعه\s*صدر)',
    ).hasMatch(n);
    final pregnancyHint =
        RegExp(r'(?:حامل|حمل)').hasMatch(n) && !RegExp(r'احتمال').hasMatch(n);
    // طفل بالقرابة أو عمر صريح بضمير الغائب — بلا التقاط «عمري 35» للمالك.
    final childHint = RegExp(
      r'(?:طفلي|ابنتي|ابني|طفل|'
      r'عمر[هة]\s*\d{1,2}|'
      r'عمر[هة]\s*(?:سنتين|٣|٣\s*سنين|٣\s*سنوات|٤|٥|٦|٧|٨|٩|١٠)|'
      r'(?:سنه|سنة)\s*(?:واحد|اثنين|ثلاث))',
    ).hasMatch(n);

    final selfSuspects = RegExp(
      r'(?:اعتقد\s*عندي\s*التهاب|أعتقد\s*عندي\s*التهاب)',
    ).hasMatch(n);

    final correctionDuration = RegExp(
      r'(?:لا\s*مو\s*(?:شهرين|اسبوعين|ايام)|مو\s*(?:شهرين|اسبوعين)|'
      r'تقريبا\s*(?:اسبوعين|ايام|شهر))',
    ).hasMatch(n);
    final correctionCough = RegExp(
      r'(?:مو\s*بلغم|مو\s*رطب|سعال\s*ناشف|كحه\s*ناشفه)',
    ).hasMatch(n);

    final coughPresent = aliases.looksLikeCough(n);
    var coughType =
        aliases.coughTypeFromNormalized(n) ?? RespiratoryCoughType.unknown;
    if (correctionCough &&
        RegExp(r'(?:ناشف|جاف)').hasMatch(n)) {
      coughType = RespiratoryCoughType.dry;
    }

    final durationBucket =
        aliases.durationBucketFromNormalized(n) ?? RespiratoryDurationBucket.unknown;

    final sputum = aliases.triState(
          n: n,
          presentPatterns: const [r'(?:بلغم|مخاط)'],
          absentPatterns: const [
            r'(?:ما\s*عندي\s*بلغم|ماكو\s*بلغم|بدون\s*بلغم|مو\s*بلغم|لا\s*بس)',
          ],
        ) ??
        RespiratoryTriState.unknown;
    // «لا بس بلغم» = sputum present, no hemoptysis/breathlessness from that phrase
    final sputumFromOnlyPhlegm =
        RegExp(r'(?:لا\s*بس\s*بلغم|بس\s*بلغم)').hasMatch(n);

    final breathlessness = aliases.triState(
          n: n,
          presentPatterns: RespiratoryAliasCatalog.breathlessnessPresentPatterns,
          absentPatterns: const [
            r'(?:ما\s*عندي\s*ضيق|ماكو\s*ضيق|بدون\s*ضيق|لا\s*(?:ضيق|ما\s*عندي))',
          ],
        ) ??
        RespiratoryTriState.unknown;

    final wheeze = aliases.triState(
          n: n,
          presentPatterns: const [
            r'(?:صفير\s*(?:بالنفس|بالصدر))',
          ],
          absentPatterns: const [r'(?:ما\s*عندي\s*صفير|ماكو\s*صفير|بدون\s*صفير)'],
        ) ??
        RespiratoryTriState.unknown;

    final fever = aliases.triState(
          n: n,
          presentPatterns: const [r'(?:حراره|حمى|حرارة)'],
          absentPatterns: const [
            r'(?:بدون\s*حراره|ما\s*عندي\s*حراره|ماكو\s*حراره|بلا\s*حراره)',
          ],
        ) ??
        RespiratoryTriState.unknown;

    final hemoptysis = aliases.triState(
          n: n,
          presentPatterns: const [
            r'(?:دم\s*(?:ويا|بال)?(?:السعال|البلغم|الكحه)|اكح\s*دم|أسعل\s*دم|'
                r'دم\s*ويا\s*السعال)',
          ],
          absentPatterns: const [
            r'(?:ماكو\s*دم|ما\s*عندي\s*دم|بدون\s*دم|لا\s*(?:دم|ماكو\s*دم))',
          ],
        ) ??
        RespiratoryTriState.unknown;

    final chestPain = aliases.triState(
          n: n,
          presentPatterns: const [
            r'(?:الم\s*(?:بالصدر|في\s*الصدر|صدر)|صدر(?:ي)?\s*(?:يوجع|توجع)|وجع\s*صدر)',
          ],
          absentPatterns: const [r'(?:ما\s*عندي\s*الم\s*صدر|بدون\s*الم\s*صدر)'],
        ) ??
        RespiratoryTriState.unknown;

    final weightLoss = aliases.triState(
          n: n,
          presentPatterns: const [
            r'(?:نزول\s*وزن|خسرت\s*وزن|وزني\s*نازل|فقدان\s*وزن)',
          ],
          absentPatterns: const [r'(?:ما\s*في\s*نزول\s*وزن|بدون\s*نزول\s*وزن)'],
        ) ??
        RespiratoryTriState.unknown;

    // إجابات قصيرة بعد سؤال مرافق
    var breathlessnessResolved = breathlessness;
    var hemoptysisResolved = hemoptysis;
    var sputumResolved = sputum;
    if (sputumFromOnlyPhlegm) {
      sputumResolved = RespiratoryTriState.present;
      coughType = RespiratoryCoughType.productive;
      if (RegExp(r'^لا\b').hasMatch(n) || RegExp(r'لا\s*بس').hasMatch(n)) {
        breathlessnessResolved = RespiratoryTriState.absent;
        hemoptysisResolved = RespiratoryTriState.absent;
      }
    }
    if (RegExp(r'^(?:لا|لاء|ماكو)(?:\s|$)').hasMatch(n) &&
        !sputumFromOnlyPhlegm &&
        !coughPresent &&
        durationBucket == RespiratoryDurationBucket.unknown) {
      // نفي عام قصير — يُفسَّر حسب lastQuestion في المنسّق؛ هنا نبقي unknown
    }

    final smoking =
        aliases.smokingFromNormalized(n) ?? RespiratorySmokingState.unknown;
    final impact = aliases.functionalFromNormalized(n) ??
        RespiratoryFunctionalImpact.unknown;

    var known = RespiratoryKnownCondition.none;
    if (RegExp(
      r'(?:الطبيب\s*مشخصني\s*التهاب\s*صدر|التهاب\s*رئوي\s*مشخص|'
      r'مشخص\s*ذات\s*الرئه|مشخصني\s*التهاب\s*صدر)',
    ).hasMatch(n)) {
      known = RespiratoryKnownCondition.pneumoniaEstablished;
    } else if (RegExp(
      r'(?:الطبيب\s*مشخصني\s*ربو|ربو\s*مشخص|عندي\s*ربو\s*مشخص|مشخص\s*ربو)',
    ).hasMatch(n)) {
      known = RespiratoryKnownCondition.asthma;
    } else if (RegExp(
      r'(?:copd\s*مشخص|عندي\s*copd\s*مشخص|مشخصني\s*copd|'
      r'مرض\s*الرئه\s*الانسدادي\s*مشخص)',
    ).hasMatch(n)) {
      known = RespiratoryKnownCondition.copd;
    } else if (RegExp(r'(?:عندي\s*التهاب\s*صدر)').hasMatch(n) &&
        !selfSuspects) {
      known = RespiratoryKnownCondition.chestInfectionSelfLabel;
    }

    final recurrent = RegExp(
      r'(?:التهاب\s*صدر\s*يتكرر|كل\s*فتره\s*تجيني\s*التهاب|'
      r'التهاب\s*بالصدر\s*متكرر)',
    ).hasMatch(n);
    final recentIllness = RegExp(
      r'(?:بعد\s*(?:نزله|انفلونزا|التهاب\s*صدر)|بعد\s*المرض\s*التنفسي)',
    ).hasMatch(n);

    final severeDistress = RegExp(
      r'(?:ما\s*اكدر\s*اتنفس|اختناق|ازرق\s*(?:الشفايف|الوجه)|'
      r'ضيق\s*نفس\s*شديد\s*جدا|ما\s*اكدر\s*اتكلم\s*من\s*الضيق)',
    ).hasMatch(n);

    final chestPainSafety = chestPain == RespiratoryTriState.present &&
        RegExp(
          r'(?:صدر|قلب|ضغط|تعرق|اشعاع\s*لليد|فجاه)',
        ).hasMatch(n);

    final redFlag = severeDistress ||
        hemoptysisResolved == RespiratoryTriState.present ||
        chestPainSafety ||
        RegExp(
          r'(?:دم\s*ويا\s*السعال|اختناق|ازرق)',
        ).hasMatch(n);

    final keys = <String>[];
    if (coughPresent) keys.add('cough');
    if (sputumResolved == RespiratoryTriState.present) keys.add('sputum');
    if (breathlessnessResolved == RespiratoryTriState.present) {
      keys.add('breathlessness');
    }
    if (wheeze == RespiratoryTriState.present) keys.add('wheeze');
    if (fever == RespiratoryTriState.present) keys.add('fever');
    if (hemoptysisResolved == RespiratoryTriState.present) {
      keys.add('hemoptysis');
    }
    if (chestPain == RespiratoryTriState.present) keys.add('chestPain');
    if (weightLoss == RespiratoryTriState.present) keys.add('weightLoss');

    final topic = _topic(
      n: n,
      cough: coughPresent,
      duration: durationBucket,
      breathlessness: breathlessnessResolved,
      wheeze: wheeze,
      hemoptysis: hemoptysisResolved,
      chestPain: chestPain,
      known: known,
      recurrent: recurrent,
      recentIllness: recentIllness,
      education: education,
      whereGo: whereGo || booking || imagingWhere || directXray,
      sputum: sputumResolved,
    );

    final isResp = looksLikeRespiratory(raw) ||
        education ||
        whereGo ||
        booking ||
        imagingWhere ||
        directXray ||
        known != RespiratoryKnownCondition.none ||
        recurrent ||
        (sputumFromOnlyPhlegm && aliases.looksLikeCough(n)) ||
        (correctionDuration && aliases.looksLikeCough(n)) ||
        (correctionCough && aliases.looksLikeCough(n));

    return RespiratoryInterpretation(
      isRespiratoryTurn: isResp,
      topic: topic,
      durationBucket: durationBucket,
      coughType: coughType,
      sputum: sputumFromOnlyPhlegm
          ? RespiratoryTriState.present
          : sputumResolved,
      breathlessness: breathlessnessResolved,
      wheeze: wheeze,
      chestPain: chestPain,
      fever: fever,
      hemoptysis: hemoptysisResolved,
      weightLoss: weightLoss,
      functionalImpact: impact,
      knownCondition: known,
      smoking: smoking,
      recurrentInfection: recurrent,
      recentRespiratoryIllness: recentIllness,
      redFlagCandidate: redFlag,
      chestPainSafetyFirst: chestPainSafety,
      severeDistress: severeDistress,
      asksEducation: education,
      asksServiceWhere: whereGo,
      asksBooking: booking,
      asksImagingWhere: imagingWhere,
      asksDirectChestXray: directXray,
      selfSuspectsInfection: selfSuspects,
      isAboutOtherPerson: other,
      pregnancyContextHint: pregnancyHint,
      population: childHint
          ? RespiratoryPopulation.child
          : RespiratoryPopulation.unknown,
      explicitFollowUp: followUp,
      correctionDuration: correctionDuration,
      correctionCoughType: correctionCough,
      symptomKeys: keys,
    );
  }

  RespiratoryTopic _topic({
    required String n,
    required bool cough,
    required RespiratoryDurationBucket duration,
    required RespiratoryTriState breathlessness,
    required RespiratoryTriState wheeze,
    required RespiratoryTriState hemoptysis,
    required RespiratoryTriState chestPain,
    required RespiratoryKnownCondition known,
    required bool recurrent,
    required bool recentIllness,
    required bool education,
    required bool whereGo,
    required RespiratoryTriState sputum,
  }) {
    if (whereGo) return RespiratoryTopic.serviceNavigation;
    if (education) return RespiratoryTopic.educationQuery;
    if (known == RespiratoryKnownCondition.asthma) {
      return RespiratoryTopic.knownAsthma;
    }
    if (known == RespiratoryKnownCondition.copd) {
      return RespiratoryTopic.knownCopd;
    }
    if (hemoptysis == RespiratoryTriState.present) {
      return RespiratoryTopic.hemoptysis;
    }
    if (recurrent) return RespiratoryTopic.recurrentChestInfection;
    if (recentIllness) return RespiratoryTopic.postRespiratoryIllness;
    if (chestPain == RespiratoryTriState.present && cough) {
      return RespiratoryTopic.respiratoryChestPain;
    }
    if (breathlessness == RespiratoryTriState.present && !cough) {
      return RespiratoryTopic.breathlessness;
    }
    if (wheeze == RespiratoryTriState.present && !cough) {
      return RespiratoryTopic.wheeze;
    }
    if (sputum == RespiratoryTriState.present && !cough) {
      return RespiratoryTopic.sputum;
    }
    if (cough) {
      // التصنيف المزمن/الحاد يُشتق لاحقاً من القاعدة — هنا مدة خام فقط
      if (duration == RespiratoryDurationBucket.months) {
        return RespiratoryTopic.chronicCough;
      }
      if (duration == RespiratoryDurationBucket.weeks) {
        return RespiratoryTopic.persistentCough;
      }
      return RespiratoryTopic.acuteCough;
    }
    if (RegExp(r'(?:تنفس|صدر|رئه)').hasMatch(n)) {
      return RespiratoryTopic.generalRespiratory;
    }
    return RespiratoryTopic.unknownRespiratory;
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:انا|اني)(?:\s|$)').hasMatch(n)) return false;
    // طفل/ابن يُعالَج عبر population.child
    return RegExp(r'(?:^|\s)(?:امي|ابوي|زوجتي)(?:\s|$)').hasMatch(n) ||
        RegExp(r'(?:لامي|لأمي)').hasMatch(n);
  }

  /// نفي قصير لإجابة سؤال سابق.
  RespiratoryTriState? shortAnswerPolarity(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (RegExp(r'^(?:لا|لاء|ماكو|ما\s*عندي)(?:\s|$)').hasMatch(n)) {
      return RespiratoryTriState.absent;
    }
    if (RegExp(r'^(?:اي|نعم|اه|آه|موجود)(?:\s|$)').hasMatch(n)) {
      return RespiratoryTriState.present;
    }
    return null;
  }
}
