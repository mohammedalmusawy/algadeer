import '../../../search/arabic_text_utils.dart';
import 'chronic_care_alias_catalog.dart';
import 'chronic_care_models.dart';

/// مفسّر حزمة رعاية مزمنة سريرية — ليس محرك تشخيص.
class ChronicCareInterpreter {
  const ChronicCareInterpreter({this.aliases = const ChronicCareAliasCatalog()});

  final ChronicCareAliasCatalog aliases;

  ChronicClinicalInterpretation interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return ChronicClinicalInterpretation.none;
    // الأرقام والفاصلة العشرية و/ تُمسّ من التطبيع — نقرأها من النص الخام.
    final rawTrim = raw.trim();

    final other = _otherPerson(n);
    final followUp = RegExp(r'(?:تابع\s*وياي|ذكرني)').hasMatch(n);
    final education = RegExp(
      r'(?:شنو\s*(?:فحوص|اعراض|الطبيعي)|كل\s*شكد|ليش\s*(?:نفحص|هذا|فحص)|'
      r'شلون\s*اقيس|هل\s*قراءه\s*وحده|ما\s*هي\s*فحوص)',
    ).hasMatch(n);
    final whatsLeft = RegExp(r'(?:شنو\s*باقي\s*علي|شنو\s*باقي)').hasMatch(n);
    final checklist = RegExp(
      r'(?:سويلي\s*قائمه|قائمة\s*متابعه|كل\s*الفحوص\s*الدوريه)',
    ).hasMatch(n);
    final whyCare = RegExp(r'(?:ليش\s*(?:فحص|نفحص|هذا\s*الفحص)|ليش\s*تريدني)')
        .hasMatch(n);
    final bpTechnique = RegExp(
      r'(?:شلون\s*اقيس\s*الضغط|قياس\s*الضغط\s*صح|طريقه\s*قياس\s*الضغط)',
    ).hasMatch(n);
    final whereGo =
        RegExp(r'(?:وين\s*اروح|منو\s*اراجع|منو\s*الطبيب)').hasMatch(n);
    final booking = RegExp(r'(?:اريد\s*احجز|أريد\s*أحجز)').hasMatch(n);
    final pregnancy =
        RegExp(r'(?:حامل|حمل|سكري\s*حمل)').hasMatch(n) &&
            !RegExp(r'احتمال').hasMatch(n);
    final cuffless = RegExp(r'(?:الساعه\s*كالت|ساعه\s*ذكيه|بدون\s*كفة)')
        .hasMatch(n);

    final selfDm = RegExp(r'(?:اعتقد\s*عندي\s*سكري|أعتقد\s*عندي\s*سكري)')
        .hasMatch(n);
    final selfHtn = RegExp(r'(?:اعتقد\s*عندي\s*ضغط|أعتقد\s*عندي\s*ضغط)')
        .hasMatch(n);
    final insulin = RegExp(r'(?:انسولين|إنسولين|آخذ\s*انسولين)').hasMatch(n);

    final familyOnly = other &&
        (aliases.looksLikeDiabetes(n) || aliases.looksLikeHypertension(n));

    var dmStatus = ChronicConditionStatus.unknown;
    var htnStatus = ChronicConditionStatus.unknown;
    var dmType = DiabetesTypeContext.unknown;

    if (familyOnly) {
      if (aliases.looksLikeDiabetes(n)) {
        dmStatus = ChronicConditionStatus.familyHistoryOnly;
      }
      if (aliases.looksLikeHypertension(n)) {
        htnStatus = ChronicConditionStatus.familyHistoryOnly;
      }
    } else {
      if (RegExp(
        r'(?:عندي\s*سكري\s*مشخص|الطبيب\s*مشخصني\s*سكري|سكري\s*مشخص|'
        r'عندي\s*سكري\s*والطبيب)',
      ).hasMatch(n)) {
        dmStatus = ChronicConditionStatus.established;
      } else if (selfDm) {
        dmStatus = ChronicConditionStatus.suspected;
      }

      if (RegExp(
        r'(?:عندي\s*ضغط\s*مشخص|الطبيب\s*مشخصني\s*ضغط|ضغط\s*مشخص\s*من\s*الطبيب|'
        r'عندي\s*ضغط\s*مشخص\s*من)',
      ).hasMatch(n)) {
        htnStatus = ChronicConditionStatus.established;
      } else if (selfHtn) {
        htnStatus = ChronicConditionStatus.suspected;
      }

      if (RegExp(r'(?:سكري\s*نوع\s*(?:اول|أول|1)|type\s*1)').hasMatch(n)) {
        dmType = DiabetesTypeContext.type1;
        if (dmStatus == ChronicConditionStatus.unknown) {
          dmStatus = ChronicConditionStatus.established;
        }
      } else if (RegExp(r'(?:سكري\s*نوع\s*(?:ثاني|2)|type\s*2)').hasMatch(n)) {
        dmType = DiabetesTypeContext.type2;
        if (dmStatus == ChronicConditionStatus.unknown) {
          dmStatus = ChronicConditionStatus.established;
        }
      } else if (RegExp(r'(?:سكري\s*حمل|gestational)').hasMatch(n)) {
        dmType = DiabetesTypeContext.gestational;
        if (dmStatus == ChronicConditionStatus.unknown) {
          dmStatus = ChronicConditionStatus.established;
        }
      } else if (dmStatus == ChronicConditionStatus.established) {
        dmType = DiabetesTypeContext.unspecifiedKnownDiabetes;
      }
    }

    // تصحيح النوع
    final correctionType = RegExp(
      r'(?:لا\s*مو\s*سكري\s*نوع\s*اول|مو\s*نوع\s*اول|نوع\s*ثاني)',
    ).hasMatch(n);
    if (correctionType && RegExp(r'نوع\s*ثاني').hasMatch(n)) {
      dmType = DiabetesTypeContext.type2;
    }

    final correctionSubject = RegExp(r'(?:الضغط\s*مو\s*الي|مو\s*إلي|لابويه|لامي)')
        .hasMatch(n);

    // قياسات ضغط — من النص الخام لأن / تُحوَّل لمسافة في normalize
    double? sys;
    double? dia;
    final bpSlash = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(rawTrim);
    final bpAla = RegExp(r'(\d{2,3})\s*على\s*(\d{2,3})').firstMatch(rawTrim) ??
        RegExp(r'(\d{2,3})\s*على\s*(\d{2,3})').firstMatch(n);
    final bpSpaced = RegExp(r'(?:ضغط|الضغط|ضغطي).{0,24}?(\d{2,3})\s+(\d{2,3})')
        .firstMatch(n);
    if (bpSlash != null) {
      sys = double.tryParse(bpSlash.group(1)!);
      dia = double.tryParse(bpSlash.group(2)!);
    } else if (bpAla != null) {
      sys = double.tryParse(bpAla.group(1)!);
      dia = double.tryParse(bpAla.group(2)!);
    } else if (bpSpaced != null) {
      sys = double.tryParse(bpSpaced.group(1)!);
      dia = double.tryParse(bpSpaced.group(2)!);
    }

    final correctionBp = RegExp(r'(?:لا\s*مو\s*\d+|مو\s*\d+,\s*كان)').hasMatch(n);
    if (correctionBp) {
      final repl = RegExp(r'(?:كان|هو)\s*(\d{2,3})').firstMatch(n);
      if (repl != null && sys != null) {
        sys = double.tryParse(repl.group(1)!);
      }
      final replPair =
          RegExp(r'(?:كان|هو)\s*(\d{2,3})\s*(?:على|/)\s*(\d{2,3})').firstMatch(n);
      if (replPair != null) {
        sys = double.tryParse(replPair.group(1)!);
        dia = double.tryParse(replPair.group(2)!);
      }
    }

    // سكر / تراكمي
    double? glucose;
    double? hba1c;
    var measKind = ChronicMeasurementKind.unknown;
    var unitExplicit = false;
    var unitLabel = '';

    final isHba1cCtx = RegExp(r'(?:تراكمي|hb\s*a1c|hba1c)').hasMatch(n);
    final glucoseCtx = RegExp(r'(?:السكر|سكر\s*طلع|قراءه\s*السكر)').hasMatch(n);

    if (isHba1cCtx) {
      final hv = RegExp(
        r'(?:تراكمي|hba1c|hb\s*a1c|HbA1c)\s*(?:مو\s*)?(?:هو\s*)?(\d+(?:[.,]\d+)?)',
        caseSensitive: false,
      ).firstMatch(rawTrim);
      final hvNorm = RegExp(
        r'(?:تراكمي|hba1c)\s*(?:مو\s*)?(?:هو\s*)?(\d+)\s+(\d+)',
      ).firstMatch(n);
      if (hv != null) {
        hba1c = double.tryParse(hv.group(1)!.replaceAll(',', '.'));
      } else if (hvNorm != null) {
        hba1c = double.tryParse('${hvNorm.group(1)}.${hvNorm.group(2)}');
      }
      final corr = RegExp(
        r'(?:مو\s*)?(\d+(?:[.,]\d+)?),\s*هو\s*(\d+(?:[.,]\d+)?)',
      ).firstMatch(rawTrim);
      if (corr != null && isHba1cCtx) {
        hba1c = double.tryParse(corr.group(2)!.replaceAll(',', '.'));
      }
      if (hba1c != null) {
        measKind = ChronicMeasurementKind.hba1c;
        if (RegExp(r'%').hasMatch(n)) {
          unitExplicit = true;
          unitLabel = '%';
        }
        if (RegExp(r'mmol\s*/\s*mol').hasMatch(n)) {
          unitExplicit = true;
          unitLabel = 'mmol/mol';
        }
      }
    } else if (glucoseCtx || RegExp(r'السكر\s*(?:طلع\s*)?\d+').hasMatch(n)) {
      final gv = RegExp(r'(?:السكر|سكر)\s*(?:طلع\s*)?(?:عالي\s*)?(\d{2,3})')
          .firstMatch(n);
      final gv2 = RegExp(r'(\d{2,3})\s*(?:mg|ملغ)').firstMatch(n);
      if (gv != null) {
        glucose = double.tryParse(gv.group(1)!);
      } else if (gv2 != null) {
        glucose = double.tryParse(gv2.group(1)!);
      }
      if (glucose != null) {
        measKind = ChronicMeasurementKind.randomGlucose;
        if (RegExp(r'mg\s*/\s*dl|ملغ').hasMatch(n)) {
          unitExplicit = true;
          unitLabel = 'mg/dL';
        }
        if (RegExp(r'mmol\s*/\s*l').hasMatch(n)) {
          unitExplicit = true;
          unitLabel = 'mmol/L';
        }
      }
    }

    // وحدة مبهمة مع رقم فقط بلا سياق — fail safe لاحقاً
    final ambiguousUnit = RegExp(r'^\s*\d+(?:\.\d+)?\s*$').hasMatch(n);

    final fasting = RegExp(r'(?:صايم|صيام|fasting)').hasMatch(n) &&
        !RegExp(r'(?:مو\s*صايم)').hasMatch(n);
    final postMeal = RegExp(r'(?:بعد\s*الاكل|بعد\s*الأكل|فطور|وجبة)')
            .hasMatch(n) ||
        RegExp(r'مو\s*صايم').hasMatch(n);
    if (fasting && glucose != null) {
      measKind = ChronicMeasurementKind.fastingGlucose;
    } else if (postMeal && glucose != null) {
      measKind = ChronicMeasurementKind.postMealGlucose;
    }

    if (sys != null && dia != null) {
      measKind = ChronicMeasurementKind.systolicBloodPressure;
      if (htnStatus == ChronicConditionStatus.unknown &&
          !familyOnly &&
          !RegExp(r'مشخص').hasMatch(n)) {
        htnStatus = ChronicConditionStatus.singleAbnormalMeasurement;
      }
    }
    if (glucose != null &&
        dmStatus == ChronicConditionStatus.unknown &&
        !familyOnly &&
        !RegExp(r'مشخص').hasMatch(n)) {
      dmStatus = ChronicConditionStatus.singleAbnormalMeasurement;
    }

    // عناصر رعاية مكتملة
    String? completed;
    var approx = '';
    if (RegExp(r'(?:فحصت\s*عيوني|فحص\s*العين)').hasMatch(n)) {
      completed = DiabetesCareItem.eyeAssessment.name;
    } else if (RegExp(r'(?:وظائف\s*الكلى|فحص\s*الكلى|UACR|eGFR)').hasMatch(n) &&
        RegExp(r'(?:سويت|فحصت|قبل)').hasMatch(n)) {
      completed = DiabetesCareItem.kidneyAssessment.name;
    } else if (RegExp(r'(?:سويت\s*تراكمي|التراكمي).{0,20}(?:اسبوع|أسبوع|اليوم)')
        .hasMatch(n)) {
      completed = DiabetesCareItem.glycemicAssessment.name;
    }
    if (RegExp(r'قبل\s*شهرين').hasMatch(n)) {
      approx = 'aboutTwoMonthsAgo';
    } else if (RegExp(r'قبل\s*شهر').hasMatch(n)) {
      approx = 'aboutAMonthAgo';
    } else if (RegExp(r'قبل\s*سنه\s*تقريبا|قبل\s*سنة\s*تقريبا').hasMatch(n)) {
      approx = 'aboutAYearApprox';
    } else if (RegExp(r'(?:الاسبوع|الأسبوع)\s*الماضي').hasMatch(n)) {
      approx = 'aboutAWeekAgo';
    }

    String? careHint;
    if (RegExp(r'(?:الكلى|UACR|eGFR)').hasMatch(n)) {
      careHint = DiabetesCareItem.kidneyAssessment.name;
    } else if (RegExp(r'(?:العين|الشبكيه)').hasMatch(n)) {
      careHint = DiabetesCareItem.eyeAssessment.name;
    } else if (RegExp(r'(?:القدم|الرجلين)').hasMatch(n)) {
      careHint = DiabetesCareItem.footAssessment.name;
    }

    final footWound = RegExp(r'(?:جرح\s*(?:بالقدم|برجلي)|قرحه\s*قدم)').hasMatch(n);
    final numbness = RegExp(r'(?:تنميل|خدر)').hasMatch(n);
    final retinopathy = RegExp(r'(?:اعتلال\s*شبكيه|retinopathy\s*مشخص)').hasMatch(n);

    final metabolicDanger = RegExp(
      r'(?:فقدان\s*وعي|استفراغ\s*مستمر|جفاف\s*شديد|ما\s*اكدر\s*اتنفس|'
      r'ضعف\s*شديد\s*جدا)',
    ).hasMatch(n);
    final bpConcerning = (sys != null || aliases.looksLikeHypertension(n)) &&
        RegExp(
          r'(?:الم\s*صدر|ضيق\s*نفس\s*شديد|ضعف\s*نصفي|تغير\s*نظر|صداع\s*شديد\s*فجائي)',
        ).hasMatch(n);
    final redFlag = metabolicDanger || bpConcerning;

    var kind = ChronicConditionKind.none;
    if (dmStatus != ChronicConditionStatus.unknown &&
        htnStatus != ChronicConditionStatus.unknown &&
        dmStatus != ChronicConditionStatus.familyHistoryOnly) {
      kind = ChronicConditionKind.both;
    } else if (aliases.looksLikeDiabetes(n) ||
        dmStatus != ChronicConditionStatus.unknown) {
      kind = ChronicConditionKind.diabetes;
    } else if (aliases.looksLikeHypertension(n) ||
        htnStatus != ChronicConditionStatus.unknown) {
      kind = ChronicConditionKind.hypertension;
    }

    final topic = _topic(
      education: education,
      whatsLeft: whatsLeft,
      checklist: checklist,
      bpTechnique: bpTechnique,
      whereGo: whereGo || booking,
      followUp: followUp,
      dmStatus: dmStatus,
      htnStatus: htnStatus,
      sys: sys,
      glucose: glucose,
      kind: kind,
    );

    final isTurn = aliases.looksLikeChronicClinical(n) ||
        education ||
        whatsLeft ||
        checklist ||
        bpTechnique ||
        whereGo ||
        booking ||
        followUp ||
        sys != null ||
        glucose != null ||
        hba1c != null ||
        dmStatus != ChronicConditionStatus.unknown ||
        htnStatus != ChronicConditionStatus.unknown;

    return ChronicClinicalInterpretation(
      isChronicClinicalTurn: isTurn && !ambiguousUnit,
      topic: topic,
      conditionKind: kind,
      diabetesStatus: dmStatus,
      hypertensionStatus: htnStatus,
      diabetesType: dmType,
      measurementKind: measKind,
      systolic: sys,
      diastolic: dia,
      glucoseValue: glucose,
      hba1cValue: hba1c,
      unitExplicit: unitExplicit,
      unitLabel: unitLabel,
      measurementContextUnknown: !fasting && !postMeal,
      isFasting: fasting,
      isPostMeal: postMeal,
      careItemHint: careHint,
      careCompletedHint: completed,
      approximateTimingLabel: approx,
      asksWhatsLeft: whatsLeft,
      asksFullChecklist: checklist,
      asksEducation: education,
      asksWhyCareItem: whyCare,
      asksBpTechnique: bpTechnique,
      asksServiceWhere: whereGo,
      asksBooking: booking,
      cufflessDevice: cuffless,
      redFlagCandidate: redFlag,
      metabolicDangerHint: metabolicDanger,
      bpConcerningSymptoms: bpConcerning,
      isAboutOtherPerson: other,
      pregnancyContextHint: pregnancy,
      explicitFollowUp: followUp,
      selfSuspectsDiabetes: selfDm,
      selfSuspectsHypertension: selfHtn,
      insulinMentioned: insulin,
      correctionMeasurement: correctionBp ||
          RegExp(r'(?:التراكمي\s*مو|مو\s*صايم)').hasMatch(n),
      correctionDiabetesType: correctionType,
      correctionSubject: correctionSubject,
      footWoundHint: footWound,
      numbnessHint: numbness,
      knownRetinopathyHint: retinopathy,
    );
  }

  ChronicClinicalTopic _topic({
    required bool education,
    required bool whatsLeft,
    required bool checklist,
    required bool bpTechnique,
    required bool whereGo,
    required bool followUp,
    required ChronicConditionStatus dmStatus,
    required ChronicConditionStatus htnStatus,
    required double? sys,
    required double? glucose,
    required ChronicConditionKind kind,
  }) {
    if (followUp) return ChronicClinicalTopic.followUpRequest;
    if (whereGo) return ChronicClinicalTopic.serviceNavigation;
    if (education) return ChronicClinicalTopic.education;
    if (whatsLeft) return ChronicClinicalTopic.whatsLeft;
    if (checklist) return ChronicClinicalTopic.careChecklist;
    if (bpTechnique) return ChronicClinicalTopic.homeBpTechnique;
    if (sys != null) return ChronicClinicalTopic.singleBpReading;
    if (glucose != null) return ChronicClinicalTopic.singleGlucoseReading;
    if (kind == ChronicConditionKind.both ||
        (dmStatus == ChronicConditionStatus.established &&
            htnStatus == ChronicConditionStatus.established)) {
      return ChronicClinicalTopic.combinedCare;
    }
    if (dmStatus == ChronicConditionStatus.established) {
      return ChronicClinicalTopic.diabetesEstablished;
    }
    if (htnStatus == ChronicConditionStatus.established) {
      return ChronicClinicalTopic.hypertensionEstablished;
    }
    return ChronicClinicalTopic.unknown;
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:انا|اني)(?:\s|$)').hasMatch(n)) return false;
    return RegExp(
          r'(?:^|\s)(?:امي|ابوي|ابويه|ابني|ابنتي|زوجتي|طفلي)(?:\s|$)',
        ).hasMatch(n) ||
        RegExp(r'(?:لابويه|لامي|لأبويه|ابويه\s*عنده)').hasMatch(n);
  }
}
