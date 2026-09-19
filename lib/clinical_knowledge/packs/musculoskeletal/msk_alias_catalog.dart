import '../../clinical_knowledge_models.dart';
import 'msk_models.dart';

/// مرادفات عربية/عراقية لمناطق وأعراض MSK.
class MskAliasCatalog {
  const MskAliasCatalog();

  MskBodyRegion? regionFromNormalized(String n) {
    if (RegExp(r'(?:منطقه\s*الحزام|اسفل\s*الظهر|اسفل\s*ظهري|قطني)').hasMatch(n)) {
      return MskBodyRegion.lumbarSpine;
    }
    if (RegExp(r'(?:ظهري|الظهر|ضهري|الظهر)').hasMatch(n) &&
        !RegExp(r'(?:صدر|بطن)').hasMatch(n)) {
      return MskBodyRegion.lumbarSpine;
    }
    if (RegExp(r'(?:رقبتي|الرقبه|رقبه|عنق)').hasMatch(n)) {
      return MskBodyRegion.cervicalSpine;
    }
    if (RegExp(r'(?:ركبتي|الركبه|ركبه|مفصل\s*الركبه)').hasMatch(n)) {
      return MskBodyRegion.knee;
    }
    if (RegExp(r'(?:فخذي|عضله\s*الفخذ|عضلة\s*الفخذ|فخذ)').hasMatch(n)) {
      return MskBodyRegion.thigh;
    }
    if (RegExp(r'(?:كتفي|الكتف|كتف)').hasMatch(n)) {
      return MskBodyRegion.shoulder;
    }
    if (RegExp(r'(?:الورك|وركي|مفصل\s*الورك|حوضي)').hasMatch(n)) {
      return MskBodyRegion.hip;
    }
    if (RegExp(r'(?:كاحل|قدم|رسغ)').hasMatch(n)) {
      return MskBodyRegion.ankleFoot;
    }
    return null;
  }

  ClinicalSeverityClass? severityFromNormalized(String n) {
    if (RegExp(r'(?:ما\s*اتحمله|ما\s*أتحمله|شديد|قوي\s*جدا)').hasMatch(n)) {
      return ClinicalSeverityClass.severe;
    }
    if (RegExp(r'(?:متوسط|قوي)').hasMatch(n)) {
      return ClinicalSeverityClass.moderate;
    }
    if (RegExp(r'(?:خفيف|بسيط)').hasMatch(n)) {
      return ClinicalSeverityClass.mild;
    }
    return null;
  }

  List<MskSymptomType> symptomsFromNormalized(String n) {
    final out = <MskSymptomType>{};
    if (RegExp(r'(?:يوجع|توجع|الم|ألم|وجع)').hasMatch(n)) {
      out.add(MskSymptomType.pain);
    }
    if (RegExp(r'(?:تيبس|تيبس|صلابه|قساوه)').hasMatch(n)) {
      out.add(MskSymptomType.stiffness);
    }
    if (RegExp(r'(?:تورم|منتفخ|انتفاخ)').hasMatch(n)) {
      out.add(MskSymptomType.swelling);
    }
    if (RegExp(r'(?:ضعف)').hasMatch(n)) {
      out.add(MskSymptomType.weakness);
    }
    if (RegExp(r'(?:تنميل|خدر)').hasMatch(n)) {
      out.add(MskSymptomType.numbness);
    }
    if (RegExp(r'(?:وخز|نمل)').hasMatch(n)) {
      out.add(MskSymptomType.tingling);
    }
    if (RegExp(r'(?:تشنج|شد\s*عضل|تشنّج)').hasMatch(n)) {
      out.add(MskSymptomType.spasm);
    }
    if (RegExp(r'(?:تقلص|كرنب)').hasMatch(n)) {
      out.add(MskSymptomType.cramp);
    }
    if (RegExp(r'(?:ما\s*اكدر\s*احرك|محدود\s*الحركه|صعوبة\s*الحركه)')
        .hasMatch(n)) {
      out.add(MskSymptomType.reducedMovement);
    }
    if (RegExp(r'(?:ينزل\s*(?:للرجل|للفخذ|للساق)|يشع|اشعاع|ينزل\s*للذراع)')
        .hasMatch(n)) {
      out.add(MskSymptomType.radiatingPain);
    }
    if (RegExp(r'(?:كدمه|كدمة|ازرق|ازرقاق)').hasMatch(n)) {
      out.add(MskSymptomType.bruising);
    }
    if (RegExp(r'(?:ما\s*اكدر\s*امشي|ما\s*أقدر\s*أمشي|ما\s*اكدر\s*احط\s*وزني|'
            r'ما\s*اكدر\s*أمشي\s*عليها)')
        .hasMatch(n)) {
      out.add(MskSymptomType.difficultyWeightBearing);
    }
    if (RegExp(r'(?:تقفل|تقفّل|locking|تنحجز)').hasMatch(n)) {
      out.add(MskSymptomType.locking);
    }
    if (RegExp(r'(?:تخونني|تنهار|giving\s*way|تفلت)').hasMatch(n)) {
      out.add(MskSymptomType.givingWay);
    }
    return out.toList();
  }

  MskTraumaMechanism? traumaFromNormalized(String n) {
    if (RegExp(r'(?:طحت|وقعت|سقطت|تزحلقت)').hasMatch(n)) {
      return MskTraumaMechanism.fall;
    }
    if (RegExp(r'(?:لويت|التواء|التوت)').hasMatch(n)) {
      return MskTraumaMechanism.twist;
    }
    if (RegExp(r'(?:انضربت|ضربة|ضربة\s*مباشره)').hasMatch(n)) {
      return MskTraumaMechanism.directBlow;
    }
    if (RegExp(r'(?:اثناء\s*اللعب|ركض|رياضه|رياضة|سبورت)').hasMatch(n)) {
      return MskTraumaMechanism.sportsInjury;
    }
    if (RegExp(r'(?:رفعت\s*شي\s*ثقيل|رفع\s*ثقيل|حمل\s*ثقيل)').hasMatch(n)) {
      return MskTraumaMechanism.liftingInjury;
    }
    if (RegExp(r'(?:اصطدام|حادث)').hasMatch(n)) {
      return MskTraumaMechanism.collision;
    }
    if (RegExp(r'(?:اصابه|إصابة|رضه|رضّة|trauma)').hasMatch(n)) {
      return MskTraumaMechanism.unknownTrauma;
    }
    return null;
  }

  MskDurationClass? durationFromNormalized(String n) {
    if (RegExp(r'(?:ساعه|ساعات|من\s*شوي)').hasMatch(n)) {
      return MskDurationClass.hours;
    }
    if (RegExp(r'(?:يومين|ايام|أيام|من\s*يوم)').hasMatch(n)) {
      return MskDurationClass.days;
    }
    if (RegExp(r'(?:اسبوع|أسابيع|اسبوعين)').hasMatch(n)) {
      return MskDurationClass.weeks;
    }
    if (RegExp(r'(?:شهر|اشهر|أشهر)').hasMatch(n)) {
      return MskDurationClass.months;
    }
    if (RegExp(r'(?:مزمن|من\s*زمان)').hasMatch(n)) {
      return MskDurationClass.chronic;
    }
    if (RegExp(r'(?:مستمر|ما\s*يروح)').hasMatch(n)) {
      return MskDurationClass.persistent;
    }
    if (RegExp(r'(?:فجاه|فجأة|هسه\s*صار)').hasMatch(n)) {
      return MskDurationClass.acute;
    }
    return null;
  }
}
