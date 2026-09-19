import '../../../search/arabic_text_utils.dart';
import '../../clinical_knowledge_models.dart';
import 'dental_models.dart';

class DentalInterpreter {
  const DentalInterpreter();

  DentalInterpretation interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return DentalInterpretation.none;

    final isAgeYearsUnit = RegExp(
      r'(?:عمر[يهاه]?\s*)?\d{1,2}\s*(?:سنه|سنة|سنوات|سنين)|'
      r'(?:سنوات|سنين)(?!\s*يوجع)',
    ).hasMatch(n);
    final dentalCue = RegExp(
      // «سني» = ضرسي، لكن «سنين» وحدة عمر — يستثنيها الاستباق كما في «سن».
      // «لثه» ⊄ «الثالثه» (ترتيب مؤنث) — نفس فكرة استثناء «سن» من «سنه/سنين».
      r'(?:سن(?![ةه]|ين|وات)|سني(?!ن)|اسنان|أسنان|ضرس|ضرسي|طاحونه|(?<!ثا)لثه|لثتي|خراج|'
      r'ضرس\s*العقل|قرحه\s*(?:بالفم|فم)|حبه\s*بالفم|فكي|'
      r'طبيب\s*اسنان|اشعه\s*اسنان|مضاد.{0,12}(?:سن|ضرس)|'
      r'tooth|dental|abscess|wisdom|'
      r'سن[ةه]\s*يوجع|يوجع(?:ه|ها)?\s*(?:ال)?سن)',
    ).hasMatch(n) ||
        // «موضوع سنه» / «سنه» كسنّ — فقط خارج عبارة عمر بالسنوات
        (!isAgeYearsUnit && RegExp(r'سن[ةه]').hasMatch(n));

    final education = RegExp(
      r'(?:شنو\s*(?:هو|يعني)\s*(?:تسوس|التهاب\s*لثه|حساسيه\s*اسنان|عصب)|'
      r'كيف\s*احافظ|شنو\s*اسوي\s*حتى\s*احافظ|فرشاه|خيط\s*اسنان|فلورايد)',
    ).hasMatch(n);

    final other = _otherPerson(n);
    final correctionSubject = RegExp(
      r'(?:لا\s*مو\s*اني|مو\s*إلي|لابني|مو\s*إلي\s*لابني)',
    ).hasMatch(n);

    final preg = RegExp(r'(?:حامل|حمل)').hasMatch(n) &&
        !RegExp(r'احتمال').hasMatch(n);
    final dm = RegExp(r'سكري').hasMatch(n);
    final htn = RegExp(r'(?:ضغط|ارتفاع\s*ضغط)').hasMatch(n);
    final child = RegExp(r'(?:طفلي|ابني|بنتي|طفل)').hasMatch(n) || other;

    final negSwell = RegExp(r'(?:ماكو\s*ورم|ما\s*عندي\s*ورم|بس\s*الم)').hasMatch(n);
    final negFever = RegExp(r'(?:ما\s*عندي\s*حراره|ماكو\s*حراره)').hasMatch(n);
    final negBleed = RegExp(r'(?:ماكو\s*دم|ما\s*ينزف)').hasMatch(n);
    final negTrauma = RegExp(r'(?:مو\s*من\s*ضربه|ماكو\s*ضربه)').hasMatch(n);

    DentalToothType toothType = DentalToothType.unknown;
    if (RegExp(r'(?:لبني|اسنان\s*لبنيه)').hasMatch(n)) {
      toothType = DentalToothType.primary;
    } else if (RegExp(r'(?:دائم|دائمه)').hasMatch(n)) {
      toothType = DentalToothType.permanent;
    }
    final correctionToothType =
        RegExp(r'(?:السن\s*لبني\s*مو\s*دائم|لبني\s*مو\s*دائم)').hasMatch(n);
    if (correctionToothType) toothType = DentalToothType.primary;

    final triggers = <DentalPainTrigger>[];
    if (RegExp(r'(?:بارد|بالبارد|اشرب\s*بارد)').hasMatch(n)) {
      triggers.add(DentalPainTrigger.cold);
    }
    if (RegExp(r'(?:حار|بالحار)').hasMatch(n)) {
      triggers.add(DentalPainTrigger.hot);
    }
    if (RegExp(r'(?:حلو|سكره)').hasMatch(n)) {
      triggers.add(DentalPainTrigger.sweet);
    }
    if (RegExp(r'(?:عض|مضغ|اكل)').hasMatch(n) && dentalCue) {
      triggers.add(DentalPainTrigger.biting);
    }
    if (RegExp(r'(?:بالليل|يزيد\s*بالليل|ليل)').hasMatch(n) && dentalCue) {
      triggers.add(DentalPainTrigger.night);
    }
    if (RegExp(r'(?:من\s*نفسه|تلقائي|مستمر)').hasMatch(n) && dentalCue) {
      triggers.add(DentalPainTrigger.spontaneous);
    }

    var severity = ClinicalSeverityClass.unknown;
    if (RegExp(r'(?:شديد|قوي\s*جدا|ما\s*اتحمله)').hasMatch(n)) {
      severity = ClinicalSeverityClass.severe;
    } else if (RegExp(r'(?:متوسط)').hasMatch(n)) {
      severity = ClinicalSeverityClass.moderate;
    } else if (RegExp(r'(?:خفيف|بسيط)').hasMatch(n)) {
      severity = ClinicalSeverityClass.mild;
    }

    DentalSwellingClass swelling = DentalSwellingClass.unknown;
    final gumMatch = RegExp(
      r'(?:(?:لثتي|اللثه|لثه)\s*(?:وارمه|منتفخه|متورمه)|ورم\s*(?:بال)?لثه)',
    ).hasMatch(n);
    final facialMatch = RegExp(
      r'(?:وجهي\s*(?:وارم|ورم)|ورم\s*(?:بالوجه|وجهي|الوجه)|ينتشر)',
    ).hasMatch(n);
    // نفي ورم الوجه مع إثبات لثة في نفس الدورة → لثة (وليس none ثم بقاء facial بالٍ)
    if (negSwell && gumMatch) {
      swelling = DentalSwellingClass.gum;
    } else if (negSwell) {
      swelling = DentalSwellingClass.none;
    } else if (RegExp(r'(?:عين|حول\s*العين).{0,20}ورم|ورم.{0,20}عين')
        .hasMatch(n)) {
      swelling = DentalSwellingClass.eyeArea;
    } else if (facialMatch) {
      swelling = RegExp(r'يزداد|ينتشر|يزيد').hasMatch(n)
          ? DentalSwellingClass.progressiveFacial
          : DentalSwellingClass.facial;
    } else if (gumMatch) {
      swelling = DentalSwellingClass.gum;
    } else if (RegExp(r'(?:ورم|وارم|انتفاخ)').hasMatch(n) && dentalCue) {
      swelling = DentalSwellingClass.localizedIntraoral;
    }

    DentalTraumaKind trauma = DentalTraumaKind.none;
    if (negTrauma) {
      trauma = DentalTraumaKind.none;
    } else if (RegExp(r'(?:طاح\s*من\s*مكانه|انخلع|السن\s*كله\s*طاح|avuls)')
        .hasMatch(n)) {
      trauma = DentalTraumaKind.avulsion;
    } else if (RegExp(r'(?:تحرك|مائل|انزاح)').hasMatch(n) &&
        RegExp(r'(?:طاح|ضربه|حادث)').hasMatch(n)) {
      trauma = DentalTraumaKind.displaced;
    } else if (RegExp(r'(?:سن\s*(?:يتحرك|متحرك)|ضرس\s*يتحرك)').hasMatch(n) &&
        RegExp(r'(?:طاح|ضربه)').hasMatch(n)) {
      trauma = DentalTraumaKind.looseAfterTrauma;
    } else if (RegExp(r'(?:انكسر|مكسور|انشطر)').hasMatch(n) && dentalCue) {
      trauma = DentalTraumaKind.fracture;
    } else if (RegExp(r'(?:تشقق|انقطع\s*جزء|chip)').hasMatch(n) && dentalCue) {
      trauma = DentalTraumaKind.chip;
    } else if (RegExp(r'(?:طاح|ضربه|حادث).{0,30}(?:سن|ضرس|وجه)').hasMatch(n) ||
        RegExp(r'(?:سن|ضرس).{0,20}(?:طاح|ضربه)').hasMatch(n)) {
      trauma = DentalTraumaKind.unknown;
    }

    final bleed = !negBleed &&
        RegExp(r'(?:تنزف|ينزف|نزف|دم\s*من\s*(?:اللثه|الفم))').hasMatch(n);
    final fever = !negFever &&
        RegExp(r'(?:حراره|حمى|قشعريره|تعب\s*شديد\s*مع\s*(?:سن|ضرس))')
            .hasMatch(n);
    final diffSwallow = RegExp(r'(?:ما\s*اكدر\s*ابلع|صعوبه\s*بلع|ما\s*اقدر\s*ابلع)')
        .hasMatch(n);
    final diffBreath = RegExp(r'(?:ما\s*اكدر\s*اتنفس|ضيق\s*نفس|صعوبه\s*تنفس)')
        .hasMatch(n);
    final trismus = RegExp(
      r'(?:ما\s*اكدر\s*افتح\s*(?:فمي|حلقي|فم)|صعوبه\s*فتح\s*الفم|trismus)',
    ).hasMatch(n);
    final abscess = RegExp(r'(?:خراج|صديد)').hasMatch(n);

    final redFlag = diffBreath ||
        diffSwallow ||
        swelling == DentalSwellingClass.eyeArea ||
        swelling == DentalSwellingClass.progressiveFacial ||
        (swelling == DentalSwellingClass.facial && (fever || trismus)) ||
        RegExp(r'(?:نزف\s*ما\s*يوقف|نزيف\s*شديد)').hasMatch(n);

    final asksAbx = RegExp(
      r'(?:احتاج\s*مضاد|أحتاج\s*مضاد|مضاد\s*حيوي|اموكسيسيلين|مترونيدازول|'
      r'كلندامايسين|amoxicillin|leftover\s*antibiotic|بقايا\s*مضاد)',
    ).hasMatch(n);
    final namedAbx = RegExp(
      r'(?:اموكسيسيلين|مترونيدازول|كلندامايسين|amoxicillin|metronidazole)',
    ).hasMatch(n);
    final prophylaxis = RegExp(
      r'(?:مضاد\s*وقائي|prophylaxis|مفصل\s*صناعي|صمام\s*قلب).{0,20}مضاد|'
      r'مضاد.{0,20}(?:قبل\s*(?:خلع|زرع))',
    ).hasMatch(n);
    final asksAnalgesic = RegExp(
      r'(?:مسكن|باراسيتامول|ايبوبروفين|أحتاج\s*دواء\s*للالم)',
    ).hasMatch(n);
    final asksImaging = RegExp(
      r'(?:احتاج\s*اشعه|أحتاج\s*أشعة|اشعه\s*اسنان|بانوراما|panoramic|'
      r'تصوير\s*(?:سن|ضرس))',
    ).hasMatch(n);
    final whereGo = RegExp(r'(?:وين\s*اروح|منو\s*اراجع|اراجع\s*طبيب\s*اسنان)')
        .hasMatch(n);
    final booking = RegExp(r'(?:اريد\s*احجز|أريد\s*أحجز)').hasMatch(n);
    final followUp = RegExp(r'(?:تابع\s*وياي|ذكرني)').hasMatch(n);
    final fear = RegExp(r'(?:خايف\s*من\s*(?:ال)?(?:طبيب|دكتور)\s*اسنان|خوف\s*اسنان)')
        .hasMatch(n);
    final anticoag = RegExp(r'(?:مميع|وارفارين|اسبرين\s*يوميا|anticoagul)')
        .hasMatch(n);

    final topic = _topic(
      n: n,
      dentalCue: dentalCue,
      education: education,
      abscess: abscess,
      trauma: trauma,
      swelling: swelling,
      bleed: bleed,
      asksAbx: asksAbx,
      asksImaging: asksImaging,
      triggers: triggers,
      preg: preg,
      child: child,
      trismus: trismus,
    );

    final isTurn = dentalCue ||
        (education && RegExp(r'(?:تسوس|لثه|اسنان|حساسيه\s*اسنان)').hasMatch(n)) ||
        asksAbx && RegExp(r'(?:سن|ضرس|اسنان)').hasMatch(n);

    return DentalInterpretation(
      isDentalTurn: isTurn,
      topic: topic,
      severity: severity,
      triggers: triggers,
      swelling: swelling,
      trauma: trauma,
      toothType: toothType,
      redFlagCandidate: redFlag,
      hasFeverOrSystemic: fever,
      difficultySwallowing: diffSwallow,
      difficultyBreathing: diffBreath,
      difficultyOpeningMouth: trismus,
      bleeding: bleed,
      asksEducation: education,
      asksAntibiotic: asksAbx,
      asksAnalgesic: asksAnalgesic,
      asksImaging: asksImaging,
      asksServiceWhere: whereGo,
      asksBooking: booking,
      isAboutOtherPerson: other || correctionSubject,
      otherPersonLabel: _otherLabel(n),
      pregnancyContextHint: preg,
      diabetesContextHint: dm,
      hypertensionContextHint: htn,
      childContextHint: child,
      userReportedAbscess: abscess,
      explicitFollowUp: followUp,
      negatesSwelling: negSwell,
      negatesFever: negFever,
      negatesBleeding: negBleed,
      negatesTrauma: negTrauma,
      correctionSubject: correctionSubject,
      correctionToothType: correctionToothType,
      fearDentist: fear,
      anticoagulantHint: anticoag,
      prophylaxisRequest: prophylaxis,
      namedAntibioticRequest: namedAbx,
    );
  }

  DentalTopic _topic({
    required String n,
    required bool dentalCue,
    required bool education,
    required bool abscess,
    required DentalTraumaKind trauma,
    required DentalSwellingClass swelling,
    required bool bleed,
    required bool asksAbx,
    required bool asksImaging,
    required List<DentalPainTrigger> triggers,
    required bool preg,
    required bool child,
    required bool trismus,
  }) {
    if (education && !RegExp(r'(?:يوجع|وجع|ورم|طاح)').hasMatch(n)) {
      return DentalTopic.educationOnly;
    }
    if (asksAbx) return DentalTopic.antibioticQuestion;
    if (asksImaging) return DentalTopic.dentalImagingQuestion;
    if (trauma == DentalTraumaKind.avulsion) return DentalTopic.lostTooth;
    if (trauma == DentalTraumaKind.fracture || trauma == DentalTraumaKind.chip) {
      return DentalTopic.brokenTooth;
    }
    if (trauma == DentalTraumaKind.looseAfterTrauma) {
      return DentalTopic.looseTooth;
    }
    if (trauma != DentalTraumaKind.none) return DentalTopic.dentalTrauma;
    if (abscess) return DentalTopic.suspectedDentalInfection;
    if (swelling == DentalSwellingClass.facial ||
        swelling == DentalSwellingClass.progressiveFacial ||
        swelling == DentalSwellingClass.eyeArea) {
      return DentalTopic.facialSwelling;
    }
    if (RegExp(r'ضرس\s*العقل').hasMatch(n)) {
      return DentalTopic.wisdomToothConcern;
    }
    if (RegExp(r'(?:قرحه|حبه\s*بالفم|آفه|كتله\s*(?:بالفم|فم))').hasMatch(n)) {
      return RegExp(r'(?:مستمر|اكثر\s*من\s*اسبوعين|ما\s*تزول)').hasMatch(n)
          ? DentalTopic.oralLesion
          : DentalTopic.oralUlcer;
    }
    if (bleed) return DentalTopic.gumBleeding;
    if (swelling == DentalSwellingClass.gum) return DentalTopic.gumSwelling;
    if (trismus) return DentalTopic.wisdomToothConcern;
    if (RegExp(r'فكي').hasMatch(n) && !dentalCue) return DentalTopic.jawPain;
    if (RegExp(r'فكي').hasMatch(n)) return DentalTopic.jawPain;
    if (triggers.contains(DentalPainTrigger.cold) ||
        triggers.contains(DentalPainTrigger.hot) ||
        triggers.contains(DentalPainTrigger.sweet)) {
      return DentalTopic.toothSensitivity;
    }
    if (preg && dentalCue) return DentalTopic.pregnancyDentalConcern;
    if (child && dentalCue) return DentalTopic.childDentalConcern;
    if (RegExp(r'(?:يوجع|وجع|الم)').hasMatch(n) && dentalCue) {
      return DentalTopic.toothPain;
    }
    if (dentalCue) return DentalTopic.toothPain;
    return DentalTopic.unknown;
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:اني|انا|سني|ضرسي)(?:\s|$)').hasMatch(n) &&
        !RegExp(r'(?:ابني|بنتي|زوجتي|امي|طفلي)').hasMatch(n)) {
      return false;
    }
    return RegExp(r'(?:ابني|بنتي|زوجتي|امي|طفلي|سنه\s*يوجع)').hasMatch(n);
  }

  String _otherLabel(String n) {
    if (RegExp(r'(?:ابني|بنتي|طفلي)').hasMatch(n)) return 'child';
    if (RegExp(r'زوجتي').hasMatch(n)) return 'spouse';
    if (RegExp(r'امي').hasMatch(n)) return 'mother';
    return '';
  }
}
