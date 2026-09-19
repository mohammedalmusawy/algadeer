import '../../../search/arabic_text_utils.dart';
import '../../clinical_knowledge_models.dart';
import 'msk_alias_catalog.dart';
import 'msk_models.dart';

/// مفسّر MSK — نص أولاً؛ ليس محرك تشخيص.
class MskInterpreter {
  const MskInterpreter({this.aliases = const MskAliasCatalog()});

  final MskAliasCatalog aliases;

  bool looksLikeMsk(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    // يجب وجود منطقة/موضوع MSK — لا يكفي «يوجعني» وحده (بطن/رأس…).
    if (aliases.regionFromNormalized(n) != null) return true;
    return RegExp(
      r'(?:منطقه\s*الحزام|اسفل\s*الظهر|سوفان|غضروف|ديسك|'
      r'تشنج|شد\s*عضل|تمزق|عضله\s*الفخذ|الم\s*مفصل|'
      r'انزلاق\s*غضروفي|علاج\s*طبيعي)',
    ).hasMatch(n);
  }

  MskInterpretation interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return MskInterpretation.none;

    final other = _otherPerson(n);
    final followUp = RegExp(r'تابع\s*وياي').hasMatch(n);
    final education = RegExp(
      r'(?:شنو\s*اعراض|شنو\s*أعراض|ما\s*هي\s*اعراض|أعراض\s*)',
    ).hasMatch(n);
    final whereGo = RegExp(r'(?:وين\s*اروح|وين\s*أروح|منو\s*الطبيب)').hasMatch(n);
    final booking = RegExp(r'(?:اريد\s*احجز|أريد\s*أحجز|احجزلي)').hasMatch(n);
    // أسئلة تصوير شائعة أثناء جلسة ظهر/MSK — ليس فقط «وين أسوي الأشعة».
    final imagingWhere = RegExp(
      r'(?:وين\s*اسوي\s*الاشعه|وين\s*أسوي\s*الأشعة|'
      r'(?:احتاج|أحتاج|لازم|اسوي|أسوي|احتاج|هل\s*(?:احتاج|أحتاج))\s*'
      r'(?:اشعه|أشعة|تصوير)|'
      r'(?:اشعه|أشعة|تصوير)\s*(?:لو\s*لا|؟|\?))',
    ).hasMatch(n);
    final suspectsOa = RegExp(r'(?:اعتقد\s*عندي\s*سوفان|أعتقد\s*عندي\s*سوفان)')
        .hasMatch(n);
    final pregnancyHint =
        RegExp(r'(?:حامل|حمل)').hasMatch(n) && !RegExp(r'احتمال').hasMatch(n);

    final region = aliases.regionFromNormalized(n) ?? MskBodyRegion.unknown;
    final symptoms = aliases.symptomsFromNormalized(n);
    final severity =
        aliases.severityFromNormalized(n) ?? ClinicalSeverityClass.unknown;
    final duration =
        aliases.durationFromNormalized(n) ?? MskDurationClass.unknown;
    final trauma =
        aliases.traumaFromNormalized(n) ?? MskTraumaMechanism.noneReported;

    var known = MskKnownDiagnosisKind.none;
    var knownLabel = '';
    if (RegExp(
      r'(?:مشخص|مشخّص|بالرنين|الرنين\s*الممغنط).{0,40}(?:انزلاق|غضروف|ديسك)|'
      r'(?:انزلاق\s*غضروفي\s*مشخص|ديسك\s*مشخص)',
    ).hasMatch(n)) {
      known = MskKnownDiagnosisKind.discDisease;
      knownLabel = 'disc_disease_user_reported';
    }
    if (RegExp(
      r'(?:الطبيب\s*مشخصني\s*سوفان|مشخصه?\s*سوفان\s*ركبه|'
      r'سوفان\s*ركبه\s*مشخص|osteoarthritis)',
    ).hasMatch(n)) {
      known = MskKnownDiagnosisKind.kneeOsteoarthritis;
      knownLabel = 'knee_oa_user_reported';
    }

    ClinicalFunctionalImpact impact = ClinicalFunctionalImpact.unknown;
    if (symptoms.contains(MskSymptomType.difficultyWeightBearing) ||
        RegExp(r'ما\s*اكدر\s*امشي').hasMatch(n)) {
      impact = ClinicalFunctionalImpact.difficultyWalking;
    } else if (RegExp(r'(?:يأثر\s*على\s*النوم|ما\s*انام)').hasMatch(n)) {
      impact = ClinicalFunctionalImpact.difficultySleeping;
    } else if (RegExp(r'(?:ما\s*اكدر\s*اشتغل|يحدد\s*نشاطي)').hasMatch(n)) {
      impact = ClinicalFunctionalImpact.limitedActivity;
    }

    final redFlag = RegExp(
      r'(?:فقدت?\s*وعي|فقدان\s*وعي|تشوه|بارده?\s*و?زرقا|سلس|مثانه|'
      r'اضرار\s*اعصاب\s*تقدم|حراره\s*مع\s*الم\s*شديد|'
      r'ما\s*اكدر\s*امشي\s*نهائيا|خدر\s*في\s*منطقه\s*السرج)',
    ).hasMatch(n);

    final topic = _topic(
      n: n,
      region: region,
      symptoms: symptoms,
      known: known,
      education: education,
      whereGo: whereGo || booking || imagingWhere,
    );

    final isMsk = looksLikeMsk(raw) ||
        education ||
        whereGo ||
        booking ||
        imagingWhere ||
        known != MskKnownDiagnosisKind.none;

    return MskInterpretation(
      isMskTurn: isMsk,
      topic: topic,
      region: region,
      symptoms: symptoms,
      severity: severity,
      functionalImpact: impact,
      duration: duration,
      trauma: trauma,
      knownDiagnosis: known,
      knownDiagnosisLabel: knownLabel,
      redFlagCandidate: redFlag,
      asksEducation: education,
      asksServiceWhere: whereGo,
      asksBooking: booking,
      asksImagingWhere: imagingWhere,
      selfSuspectsOa: suspectsOa,
      isAboutOtherPerson: other,
      pregnancyContextHint: pregnancyHint,
      looksLikeFollowUp: followUp,
      explicitFollowUp: followUp,
    );
  }

  MskTopic _topic({
    required String n,
    required MskBodyRegion region,
    required List<MskSymptomType> symptoms,
    required MskKnownDiagnosisKind known,
    required bool education,
    required bool whereGo,
  }) {
    if (whereGo) return MskTopic.serviceNavigation;
    if (education) return MskTopic.educationQuery;
    if (known == MskKnownDiagnosisKind.discDisease) {
      return MskTopic.knownDiscDisease;
    }
    if (known == MskKnownDiagnosisKind.kneeOsteoarthritis) {
      return MskTopic.knownKneeOsteoarthritis;
    }
    if (RegExp(r'(?:شد\s*بعضله|تمزق|تمزقت\s*عضله|عضله\s*الفخذ)').hasMatch(n)) {
      return region == MskBodyRegion.thigh
          ? MskTopic.thighMuscleInjury
          : MskTopic.muscleStrain;
    }
    if (symptoms.contains(MskSymptomType.spasm) &&
        !symptoms.contains(MskSymptomType.radiatingPain)) {
      return MskTopic.spasm;
    }
    if (symptoms.contains(MskSymptomType.radiatingPain)) {
      return MskTopic.radiatingLimbPain;
    }
    switch (region) {
      case MskBodyRegion.lumbarSpine:
      case MskBodyRegion.thoracicSpine:
        return MskTopic.lowBackPain;
      case MskBodyRegion.cervicalSpine:
        return MskTopic.neckPain;
      case MskBodyRegion.knee:
        return MskTopic.kneePain;
      case MskBodyRegion.shoulder:
        return MskTopic.shoulderPain;
      case MskBodyRegion.hip:
        return MskTopic.hipPain;
      case MskBodyRegion.thigh:
        return MskTopic.thighMuscleInjury;
      default:
        if (RegExp(r'مفصل').hasMatch(n)) return MskTopic.jointPainGeneral;
        return MskTopic.unknown;
    }
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:^|\s)(?:انا|اني)(?:\s|$)').hasMatch(n)) return false;
    return RegExp(r'(?:^|\s)(?:امي|ابوي|ابني|ابنتي|زوجتي)(?:\s|$)').hasMatch(n) ||
        RegExp(r'(?:لامي|لأمي)').hasMatch(n);
  }
}
