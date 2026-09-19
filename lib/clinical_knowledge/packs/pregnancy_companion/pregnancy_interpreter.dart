import '../../../search/arabic_text_utils.dart';
import 'pregnancy_models.dart';

class PregnancyInterpreter {
  const PregnancyInterpreter();

  PregnancyInterpretation interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return PregnancyInterpretation.none;

    final other = _otherPerson(n);
    final otherLabel = _otherLabel(n);
    final correctionSubject = RegExp(
      r'(?:لا\s*مو\s*اني|مو\s*اني|مو\s*إلي|لزوجتي|لاختي)',
    ).hasMatch(n);

    final loss = RegExp(
      r'(?:اسقطت|اجهاض|فقدت\s*الحمل|انتهى\s*الحمل)',
    ).hasMatch(n);
    final trying = RegExp(r'(?:احاول\s*احمل|نحاول\s*حمل|تخطيط\s*حمل)').hasMatch(n);
    final possibleOnly = RegExp(
      r'(?:تاخر\s*الدوره|احتمال\s*حمل|يمكن\s*حامل)',
    ).hasMatch(n);

    // أعراض وحدها لا تؤكد حمل ولا تفعّل رفيق الحمل
    final symptomOnlyNoConfirm = RegExp(
          r'(?:غثيان|ترجيع|تعب|ثدي)',
        ).hasMatch(n) &&
        !RegExp(r'(?:حامل|حمل\s*مؤكد|فحص\s*الحمل\s*موجب|حمل)').hasMatch(n);

    var status = PregnancyStatus.unknown;
    if (loss) {
      status = PregnancyStatus.pregnancyLossReported;
    } else if (trying) {
      status = PregnancyStatus.tryingToConceive;
    // تنظيف الشروط المتناقضة
    } else if (possibleOnly) {
      status = PregnancyStatus.possible;
    } else if (RegExp(
      r'(?:اني\s*حامل|انا\s*حامل|حامل\s*بالاسبوع|الدكتوره?\s*(?:اكدت|أكدت)\s*الحمل|'
      r'فحص\s*الحمل\s*طلع\s*موجب|حمل\s*مؤكد)',
    ).hasMatch(n)) {
      status = PregnancyStatus.confirmed;
    } else if (RegExp(r'(?:حامل|حمل)').hasMatch(n) &&
        !RegExp(r'احتمال').hasMatch(n) &&
        !RegExp(r'حمل\s*ثقيل|حمله\b').hasMatch(n) &&
        !symptomOnlyNoConfirm) {
      status = PregnancyStatus.confirmed;
    }

    final followUp = RegExp(r'(?:تابع\s*وياي|ذكرني)').hasMatch(n);
    final whatsLeft = RegExp(r'(?:شنو\s*باقي\s*علي|شنو\s*اسوي\s*هسه)').hasMatch(n);
    final checklist = RegExp(r'(?:قائمه\s*متابعه|كل\s*الفحوص|checklist)').hasMatch(n);
    final education = RegExp(
      r'(?:شنو\s*يصير|شنو\s*المتوقع|متى\s*اعرف\s*جنس|شنو\s*اكل)',
    ).hasMatch(n);
    final usAsk = RegExp(r'(?:سونار|التراساوند|ultrasound|اشعه\s*حمل)').hasMatch(n);
    final sexAsk = RegExp(r'(?:جنس\s*الطفل|ولد\s*او\s*بنت|بنت\s*او\s*ولد)').hasMatch(n);
    final activity = RegExp(r'(?:اكدر\s*امشي|اكدر\s*اتمرن|أتمرن)').hasMatch(n);
    final nutrition = RegExp(r'(?:شنو\s*اكل|تغذيه|اكل\s*الحامل)').hasMatch(n);
    final whereGo = RegExp(r'(?:وين\s*اروح|منو\s*اراجع)').hasMatch(n);
    final booking = RegExp(r'(?:اريد\s*احجز|أريد\s*أحجز)').hasMatch(n);

    // عمر حملي
    int? weeks;
    int? daysExtra;
    var dating = GestationalDatingSource.unknown;
    final weekMatch = RegExp(
      r'(?:بال)?(?:الاسبوع|الأسبوع|اسبوع|أسبوع)\s*(\d{1,2})'
      r'(?:\s*و\s*(\d)\s*(?:ايام|أيام|يوم))?',
    ).firstMatch(raw);
    final weekMatchN = RegExp(
      r'(?:بال)?(?:الاسبوع|اسبوع)\s*(\d{1,2})',
    ).firstMatch(n);
    if (weekMatch != null || weekMatchN != null) {
      final m = weekMatch ?? weekMatchN!;
      weeks = int.tryParse(m.group(1)!);
      if (weekMatch != null && weekMatch.groupCount >= 2 && weekMatch.group(2) != null) {
        daysExtra = int.tryParse(weekMatch.group(2)!);
      }
      dating = GestationalDatingSource.explicitWeek;
    }

    // تصحيح أسبوع شائع: «مو 20»، «لا 22»، «آسف 23»، «مو 24، 22»
    final correctionWeek = RegExp(
      r'(?:مو\s*\d+\s*(?:اسبوع|أسبوع)?|لا[،,]?\s*\d{1,2}|اسف\s*\d{1,2}|آسف\s*\d{1,2})',
    ).hasMatch(n);
    if (weeks == null && correctionWeek) {
      final pair = RegExp(
        r'(?:مو|لا)\s*\d{1,2}\s*[^\d]{1,8}(\d{1,2})',
      ).firstMatch(n);
      final bare = RegExp(
        r'(?:مو|لا[،,]?|اسف|آسف)\s*(\d{1,2})\s*(?:اسبوع|أسبوع)?\s*$',
      ).firstMatch(n);
      final rawWeek = pair?.group(1) ?? bare?.group(1);
      if (rawWeek != null) {
        final v = int.tryParse(rawWeek);
        if (v != null && v >= 1 && v <= 42) {
          weeks = v;
          dating = GestationalDatingSource.explicitWeek;
        }
      }
    } else if (correctionWeek && weeks != null) {
      // إن التقط weekMatch الرقم القديم فقط، فضّل الرقم الثاني من التصحيح
      final pair = RegExp(
        r'(?:مو|لا)\s*\d{1,2}\s*[^\d]{1,8}(\d{1,2})',
      ).firstMatch(n);
      if (pair != null) {
        final v = int.tryParse(pair.group(1)!);
        if (v != null && v >= 1 && v <= 42) weeks = v;
      }
    }
    if (correctionWeek && weeks != null) {
      dating = GestationalDatingSource.explicitWeek;
    }

    int? trimester;
    if (RegExp(r'(?:الثلث\s*الاول|ثلث\s*اول)').hasMatch(n)) trimester = 1;
    if (RegExp(r'(?:الثلث\s*الثاني|ثلث\s*ثاني)').hasMatch(n)) trimester = 2;
    if (RegExp(r'(?:الثلث\s*الثالث|ثلث\s*ثالث)').hasMatch(n)) trimester = 3;
    if (trimester != null && weeks == null) {
      dating = GestationalDatingSource.trimesterOnly;
    }

    int? monthColloquial;
    final monthDigit = RegExp(
      r'(?:الشهر\s*(?:ال)?(\d)|دخلت\s*(?:ال)?(\d)|صارلي\s*(\d)\s*اشهر)',
    ).firstMatch(n);
    if (monthDigit != null) {
      monthColloquial = int.tryParse(
        monthDigit.group(1) ?? monthDigit.group(2) ?? monthDigit.group(3) ?? '',
      );
    } else {
      const arabicMonths = {
        'الاول': 1,
        'اول': 1,
        'الثاني': 2,
        'ثاني': 2,
        'الثالث': 3,
        'ثالث': 3,
        'الرابع': 4,
        'رابع': 4,
        'الخامس': 5,
        'خامس': 5,
        'السادس': 6,
        'سادس': 6,
        'السابع': 7,
        'سابع': 7,
        'الثامن': 8,
        'ثامن': 8,
        'التاسع': 9,
        'تاسع': 9,
      };
      for (final e in arabicMonths.entries) {
        if (RegExp('(?:الشهر\\s*${e.key}|دخلت\\s*${e.key}|دخلت\\s*ال${e.key})')
            .hasMatch(n)) {
          monthColloquial = e.value;
          break;
        }
      }
    }
    if (monthColloquial != null && weeks == null) {
      dating = GestationalDatingSource.monthColloquial;
    }

    if (RegExp(r'(?:بالسونار|السونار\s*حدد)').hasMatch(n) && weeks != null) {
      dating = GestationalDatingSource.ultrasoundEstimate;
    }
    if (RegExp(r'(?:الدكتوره?\s*(?:حددت|گالت|قالت).{0,20}اسبوع)').hasMatch(n)) {
      dating = GestationalDatingSource.clinicianEstimate;
    }

    final stage = _stage(weeks, trimester, monthColloquial);

    String? completed;
    if (RegExp(r'(?:سويت\s*السونار|سونار\s*(?:الاسبوع|أمس|اليوم))').hasMatch(n)) {
      completed = PregnancyCareItem.ultrasoundDating.name;
    } else if (RegExp(r'(?:حللت\s*الدم|فحصت\s*الدم)').hasMatch(n)) {
      completed = PregnancyCareItem.routineBloodTesting.name;
    } else if (RegExp(r'(?:فحصت\s*السكر|سكر\s*الحمل)').hasMatch(n) &&
        RegExp(r'(?:سويت|فحصت)').hasMatch(n)) {
      completed = PregnancyCareItem.gestationalDiabetesScreening.name;
    } else if (RegExp(r'(?:راجعت\s*الطبيبه|راجعت\s*الدكتوره)').hasMatch(n)) {
      completed = PregnancyCareItem.antenatalContact.name;
    }

    var clinicianSaid = '';
    if (RegExp(r'(?:الدكتوره?\s*(?:گالت|قالت|اكدت))').hasMatch(n)) {
      clinicianSaid = 'clinician_statement';
    }
    var fetalSex = '';
    if (RegExp(r'(?:گالت\s*بنت|قالت\s*بنت|اكدت\s*بنت)').hasMatch(n)) {
      fetalSex = 'female';
    } else if (RegExp(r'(?:گالت\s*ولد|قالت\s*ولد|اكدت\s*ولد)').hasMatch(n)) {
      fetalSex = 'male';
    }

    final gdm = RegExp(r'(?:سكر\s*حمل|سكري\s*حمل|gestational\s*diabetes\s*مشخص)')
        .hasMatch(n);
    final preexistingDm = RegExp(r'(?:عندي\s*سكري\s*(?:قبل|مشخص).{0,10}حامل|حامل.{0,15}سكري\s*مشخص)')
        .hasMatch(n);
    final highBp = RegExp(r'(?:ضغطي\s*مرتفع|ضغط\s*الحمل|تسمم\s*حمل)').hasMatch(n);

    final bleeding = RegExp(r'(?:نزل\s*علي\s*دم|نزيف|دم\s*من\s*المهبل)').hasMatch(n);
    final reducedMove = RegExp(r'(?:حركه\s*الطفل\s*قلت|قلت\s*الحركه|ما\s*احس\s*حركه)')
        .hasMatch(n);
    final severePain = RegExp(r'(?:وجع\s*(?:بطن|حوض)\s*شديد|الم\s*بطن\s*شديد)').hasMatch(n);
    final severeHead = RegExp(r'(?:صداع\s*شديد|تشوش\s*نظر|زرقة)').hasMatch(n);
    final breath = RegExp(r'(?:ضيق\s*نفس\s*شديد|اختناق)').hasMatch(n);
    final seizure = RegExp(r'(?:تشنج|فقدان\s*وعي)').hasMatch(n);
    final vomitDehyd = RegExp(r'(?:ترجيع\s*مستمر|جفاف)').hasMatch(n);
    final redFlag = bleeding ||
        severePain ||
        severeHead ||
        breath ||
        seizure ||
        (reducedMove && (weeks ?? 0) >= 24) ||
        vomitDehyd;

    String symptomKey = '';
    var symptomClass = PregnancySymptomClass.unknown;
    if (RegExp(r'غثيان|ترجيع').hasMatch(n)) {
      symptomKey = 'nausea';
      symptomClass = vomitDehyd
          ? PregnancySymptomClass.deferTo10E
          : PregnancySymptomClass.commonPossible;
    } else if (RegExp(r'ظهري\s*يوجع|وجع\s*ظهر').hasMatch(n)) {
      symptomKey = 'backPain';
      symptomClass = PregnancySymptomClass.commonPossible;
    } else if (RegExp(r'حرقة|حرقه\s*معده').hasMatch(n)) {
      symptomKey = 'heartburn';
      symptomClass = PregnancySymptomClass.selfCareEligible;
    } else if (RegExp(r'امساك').hasMatch(n)) {
      symptomKey = 'constipation';
      symptomClass = PregnancySymptomClass.selfCareEligible;
    } else if (RegExp(r'تعب|تعبانه').hasMatch(n)) {
      symptomKey = 'fatigue';
      symptomClass = PregnancySymptomClass.commonPossible;
    } else if (RegExp(r'صداع').hasMatch(n)) {
      symptomKey = 'headache';
      symptomClass = severeHead
          ? PregnancySymptomClass.deferTo10E
          : PregnancySymptomClass.needsClarification;
    } else if (RegExp(r'دوخه|دوار').hasMatch(n)) {
      symptomKey = 'dizziness';
      symptomClass = PregnancySymptomClass.needsClarification;
    } else if (bleeding) {
      symptomKey = 'bleeding';
      symptomClass = PregnancySymptomClass.deferTo10E;
    }

    final fear = RegExp(r'(?:خايفه|خايفة|خوف\s*من\s*الولاده)').hasMatch(n);

    final intent = _intent(
      whatsLeft: whatsLeft,
      checklist: checklist,
      education: education,
      usAsk: usAsk,
      sexAsk: sexAsk,
      activity: activity,
      nutrition: nutrition,
      fear: fear,
      redFlag: redFlag,
      weeks: weeks,
      status: status,
      clinicianSaid: clinicianSaid.isNotEmpty,
    );

    final isTurn = (RegExp(r'(?:حامل|حمل|سكر\s*حمل|جنس\s*الطفل|EDD|LMP|ثلث)')
                .hasMatch(n) ||
            (RegExp(r'(?:سونار|التراساوند)').hasMatch(n) &&
                RegExp(r'(?:حامل|حمل|حملی|نسائيه|توليد)').hasMatch(n))) &&
        !RegExp(r'احتمال\s*حمل|حمل\s*ثقيل|حمله\b').hasMatch(n) &&
        !symptomOnlyNoConfirm;

    return PregnancyInterpretation(
      // ما نسرق «شنو باقي علي» من حزم أخرى بدون سياق حمل
      isPregnancyTurn: isTurn ||
          (status != PregnancyStatus.unknown && status != PregnancyStatus.notPregnant),
      intent: intent,
      status: status,
      datingSource: dating,
      gestationalWeeks: weeks,
      gestationalDaysExtra: daysExtra,
      trimesterHint: trimester,
      monthColloquial: monthColloquial,
      stage: stage,
      isAboutOtherPerson: other || correctionSubject,
      otherPersonLabel: otherLabel,
      asksWhatsLeft: whatsLeft,
      asksFullChecklist: checklist,
      asksEducation: education,
      asksUltrasound: usAsk,
      asksFetalSex: sexAsk,
      asksActivity: activity,
      asksNutrition: nutrition,
      asksServiceWhere: whereGo,
      asksBooking: booking,
      explicitFollowUp: followUp,
      careCompletedHint: completed,
      clinicianSaid: clinicianSaid,
      fetalSexFromClinician: fetalSex,
      symptomKey: symptomKey,
      symptomClass: symptomClass,
      redFlagCandidate: redFlag,
      bleedingHint: bleeding,
      reducedMovementHint: reducedMove,
      gdmEstablished: gdm,
      preexistingDiabetes: preexistingDm,
      highBpHint: highBp,
      correctionSubject: correctionSubject,
      correctionWeek: correctionWeek,
      pregnancyLossHint: loss,
      tryingToConceive: trying,
      possibleOnly: possibleOnly,
    );
  }

  PregnancyStage _stage(int? weeks, int? trimester, int? month) {
    if (weeks != null) {
      if (weeks < 14) return PregnancyStage.firstTrimester;
      if (weeks < 28) return PregnancyStage.secondTrimester;
      if (weeks < 37) return PregnancyStage.thirdTrimester;
      return PregnancyStage.termContext;
    }
    if (trimester == 1) return PregnancyStage.firstTrimester;
    if (trimester == 2) return PregnancyStage.secondTrimester;
    if (trimester == 3) return PregnancyStage.thirdTrimester;
    if (month != null) {
      // لا نحوّل الشهر لأسبوع دقيق — مرحلة تقريبية فقط
      if (month <= 3) return PregnancyStage.firstTrimester;
      if (month <= 6) return PregnancyStage.secondTrimester;
      return PregnancyStage.thirdTrimester;
    }
    return PregnancyStage.unknown;
  }

  PregnancyCompanionIntent _intent({
    required bool whatsLeft,
    required bool checklist,
    required bool education,
    required bool usAsk,
    required bool sexAsk,
    required bool activity,
    required bool nutrition,
    required bool fear,
    required bool redFlag,
    required int? weeks,
    required PregnancyStatus status,
    required bool clinicianSaid,
  }) {
    if (redFlag) return PregnancyCompanionIntent.safetyConcern;
    if (whatsLeft) return PregnancyCompanionIntent.whatIsDue;
    if (checklist) return PregnancyCompanionIntent.careChecklist;
    if (sexAsk) return PregnancyCompanionIntent.fetalSexQuestion;
    if (usAsk) return PregnancyCompanionIntent.ultrasoundQuestion;
    if (activity) return PregnancyCompanionIntent.activityQuestion;
    if (nutrition) return PregnancyCompanionIntent.nutritionQuestion;
    if (fear) return PregnancyCompanionIntent.emotionalSupport;
    if (clinicianSaid) return PregnancyCompanionIntent.clinicianPlanQuestion;
    if (education || weeks != null) return PregnancyCompanionIntent.whatToExpect;
    if (status == PregnancyStatus.confirmed) {
      return PregnancyCompanionIntent.pregnancyGeneralQuestion;
    }
    return PregnancyCompanionIntent.unknown;
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:اني|انا)(?:\s|$)').hasMatch(n) &&
        !RegExp(r'(?:زوجتي|امي|اختي)').hasMatch(n)) {
      return false;
    }
    return RegExp(r'(?:زوجتي|امي|اختي|حمل\s*مال\s*زوجتي)').hasMatch(n);
  }

  String _otherLabel(String n) {
    if (RegExp(r'زوجتي').hasMatch(n)) return 'spouse';
    if (RegExp(r'امي').hasMatch(n)) return 'mother';
    if (RegExp(r'اختي').hasMatch(n)) return 'sister';
    return '';
  }
}
