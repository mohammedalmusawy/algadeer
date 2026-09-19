import '../search/arabic_text_utils.dart';
import 'wellness_models.dart';

class WellnessCommandInterpretation {
  const WellnessCommandInterpretation({
    required this.intent,
    required this.topic,
    this.activityType = WellnessActivityType.unknown,
    this.report,
    this.goalDraft,
    this.isAboutOtherPerson = false,
    this.asksPublicHealthTargets = false,
    this.lowMotivation = false,
    this.overwhelmed = false,
  });

  final WellnessIntent intent;
  final WellnessTopic topic;
  final WellnessActivityType activityType;
  final WellnessUserReport? report;
  final WellnessGoalDraft? goalDraft;
  final bool isAboutOtherPerson;
  final bool asksPublicHealthTargets;
  final bool lowMotivation;
  final bool overwhelmed;

  static const none = WellnessCommandInterpretation(
    intent: WellnessIntent.none,
    topic: WellnessTopic.unknownWellness,
  );

  bool get isCommand => intent != WellnessIntent.none;

  Map<String, Object?> debugMap() => {
        'wellnessIntent': intent.name,
        'wellnessTopic': topic.name,
        'activityType': activityType.name,
        'operationType': intent.name,
      };
}

/// مفسّر أوامر العافية — حتمي.
class WellnessCommandInterpreter {
  const WellnessCommandInterpreter();

  bool looksLikeWellnessCommand(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    return RegExp(
      r'(?:امشي|أمشي|مشي|تمشي|اتمرن|أتمرن|تمرين|رياضه|رياضة|'
      r'تحرك|أتحرك|حركه|حركة|جلوس\s*طويل|قاعد\s*اكثر|'
      r'روتين\s*(?:حركه|حركة|رياضي)|استراحه|استراحة|تعافي|'
      r'نوم\s*(?:منظم|مرتب)|هدف\s*(?:المشي|الرياضه|الرياضة)|'
      r'مشيت|تمرنت|ما\s*مشيت|ما\s*عندي\s*نفس\s*اتمرن|'
      r'رتبلي\s*روتين|ابدأ\s*(?:امشي|أتحرك)|ابدأ\s*امشي)',
    ).hasMatch(n);
  }

  WellnessCommandInterpretation interpret(String raw) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return WellnessCommandInterpretation.none;

    final other = _isAboutOtherPerson(n);
    final topic = _topic(n);
    final activity = _activityType(n, topic);
    final lowMot = RegExp(r'(?:ما\s*عندي\s*نفس|ما\s*اقدر\s*اتمرن|مو\s*بمزاج)')
        .hasMatch(n);
    final overwhelmed =
        RegExp(r'(?:كثير|معقد|مرهق|ما\s*اعرف\s*منين\s*ابدأ)').hasMatch(n);

    if (RegExp(r'(?:ما\s*أريد\s*نصائح\s*رياضه|ما\s*اريد\s*نصائح\s*رياضة|'
            r'لا\s*نصائح\s*رياضه)')
        .hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.declineWellnessAdvice,
        topic: topic,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'خل\s*نركز\s*على\s*المشي').hasMatch(n)) {
      return const WellnessCommandInterpretation(
        intent: WellnessIntent.focusWalking,
        topic: WellnessTopic.walking,
        activityType: WellnessActivityType.walking,
      );
    }

    if (RegExp(r'(?:تابع\s*وياي|لا\s*تتابعني)').hasMatch(n) &&
        RegExp(r'(?:مشي|رياض|حرك)').hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.followUpRequest,
        topic: topic,
        activityType: activity,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:وقف\s*هدف\s*المشي|وقف\s*هدف)').hasMatch(n) &&
        RegExp(r'مشي').hasMatch(n)) {
      return const WellnessCommandInterpretation(
        intent: WellnessIntent.pauseGoal,
        topic: WellnessTopic.activityGoal,
        activityType: WellnessActivityType.walking,
        goalDraft: WellnessGoalDraft(
          canonicalKey: 'goal_walking',
          displayLabel: 'الالتزام بالمشي',
        ),
      );
    }

    if (RegExp(r'(?:رجع\s*هدف\s*المشي|رجع\s*هدف)').hasMatch(n) &&
        RegExp(r'مشي').hasMatch(n)) {
      return const WellnessCommandInterpretation(
        intent: WellnessIntent.resumeGoal,
        topic: WellnessTopic.activityGoal,
        activityType: WellnessActivityType.walking,
        goalDraft: WellnessGoalDraft(
          canonicalKey: 'goal_walking',
          displayLabel: 'الالتزام بالمشي',
        ),
      );
    }

    if (RegExp(
          r'(?:الم.{0,12}صدر|ألم.{0,12}صدر|ضيق\s*نفس|اختناق|فاقد\s*وعي|اغمى|'
          r'أدوخ|ادوخ|دوخه\s*شديد)',
        ).hasMatch(n) &&
        RegExp(r'(?:امشي|تمشي|تمرن|رياض|حرك)').hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.healthRelatedActivityQuestion,
        topic: topic,
        activityType: activity,
        isAboutOtherPerson: other,
      );
    }

    final report = _parseReport(n, activity);
    if (report != null) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.reportActivity,
        topic: WellnessTopic.activityProgress,
        activityType: activity,
        report: report,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:ركبتي|رجلي|ظهري|تتعبني|ما\s*كدرت\s*امشي\s*لأن|'
            r'ما\s*كدرت\s*أمشي\s*لأن)')
        .hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.reportBarrier,
        topic: WellnessTopic.exerciseBarrier,
        activityType: activity,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:شلون\s*تقدمي|كيف\s*تقدمي|تقدمي\s*بالمشي|'
            r'شلون\s*تقدمي\s*بالمشي)')
        .hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.askProgress,
        topic: WellnessTopic.activityProgress,
        activityType: WellnessActivityType.walking,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:رتبلي\s*روتين|روتين\s*حركه|روتين\s*حركة|'
            r'روتين\s*رياضي)')
        .hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.askRoutine,
        topic: WellnessTopic.exerciseRoutine,
        activityType: activity,
        isAboutOtherPerson: other,
        overwhelmed: overwhelmed,
      );
    }

    if (RegExp(r'(?:خلي\s*هدفي|تذكر\s*هدفي|هدف\s*امشي|هدف\s*أمشي|'
            r'هدفي\s*امشي|هدفي\s*أمشي)')
        .hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.setGoal,
        topic: WellnessTopic.activityGoal,
        activityType: WellnessActivityType.walking,
        goalDraft: _goalDraft(n),
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:استراحه|استراحة|تعافي|ارتاح|ريحه)').hasMatch(n) &&
        RegExp(r'(?:رياض|تمرين|مشي|حرك)').hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.askGuidance,
        topic: WellnessTopic.restRecovery,
        activityType: WellnessActivityType.rest,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:نوم\s*(?:منظم|مرتب)|ارتب\s*نومي|روتين\s*النوم)')
            .hasMatch(n) &&
        !RegExp(r'(?:انقطاع\s*نفس|شخير\s*مرض|تشخيص)').hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.askGuidance,
        topic: WellnessTopic.sleepRoutine,
        isAboutOtherPerson: other,
      );
    }

    if (RegExp(r'(?:جلوس|سبات|قاعد)').hasMatch(n)) {
      return WellnessCommandInterpretation(
        intent: WellnessIntent.askGuidance,
        topic: WellnessTopic.sedentaryTime,
        activityType: WellnessActivityType.generalMovement,
        isAboutOtherPerson: other,
      );
    }

    final asksTargets = RegExp(
      r'(?:شكد\s*امشي|كم\s*امشي|توصيات\s*(?:النشاط|الحركه|الحركة)|'
      r'150|دليل\s*(?:الصحه|الصحة))',
    ).hasMatch(n);

    if (looksLikeWellnessCommand(original) || asksTargets) {
      return WellnessCommandInterpretation(
        intent: lowMot
            ? WellnessIntent.askGuidance
            : WellnessIntent.askGuidance,
        topic: topic,
        activityType: activity,
        isAboutOtherPerson: other,
        asksPublicHealthTargets: asksTargets,
        lowMotivation: lowMot,
        overwhelmed: overwhelmed,
      );
    }

    return WellnessCommandInterpretation.none;
  }

  bool _isAboutOtherPerson(String n) {
    if (RegExp(r'(?:انا|عني|نفسي|مالتي)').hasMatch(n)) return false;
    return RegExp(
      r'(?:ابني|ابنتي|امي|أمي|ابوي|زوجتي|زوجي|صديقي)',
    ).hasMatch(n);
  }

  WellnessTopic _topic(String n) {
    if (RegExp(r'مشي').hasMatch(n)) return WellnessTopic.walking;
    if (RegExp(r'(?:تمرين|رياضه|رياضة|اتمرن)').hasMatch(n)) {
      return WellnessTopic.exercise;
    }
    if (RegExp(r'(?:جلوس|سبات|قاعد)').hasMatch(n)) {
      return WellnessTopic.sedentaryTime;
    }
    if (RegExp(r'(?:استراحه|استراحة|تعافي)').hasMatch(n)) {
      return WellnessTopic.restRecovery;
    }
    if (RegExp(r'نوم').hasMatch(n)) return WellnessTopic.sleepRoutine;
    if (RegExp(r'روتين').hasMatch(n)) return WellnessTopic.exerciseRoutine;
    if (RegExp(r'(?:تحرك|حركه|حركة)').hasMatch(n)) {
      return WellnessTopic.generalMovement;
    }
    return WellnessTopic.unknownWellness;
  }

  WellnessActivityType _activityType(String n, WellnessTopic topic) {
    switch (topic) {
      case WellnessTopic.walking:
        return WellnessActivityType.walking;
      case WellnessTopic.exercise:
        return WellnessActivityType.exercise;
      case WellnessTopic.restRecovery:
        return WellnessActivityType.rest;
      case WellnessTopic.generalMovement:
      case WellnessTopic.sedentaryTime:
        return WellnessActivityType.generalMovement;
      default:
        if (RegExp(r'مشي').hasMatch(n)) return WellnessActivityType.walking;
        return WellnessActivityType.unknown;
    }
  }

  WellnessUserReport? _parseReport(String n, WellnessActivityType activity) {
    final walked = RegExp(r'(?:مشيت|تمشيت)').hasMatch(n);
    final trained = RegExp(r'(?:تمرنت|تمريت)').hasMatch(n);
    final noneToday = RegExp(r'(?:اليوم\s*ما\s*مشيت|ما\s*مشيت\s*اليوم|'
            r'قعدت\s*اغالب|قعدت\s*أغلب)')
        .hasMatch(n);
    if (!walked && !trained && !noneToday) return null;

    int? minutes;
    final m = RegExp(r'(\d{1,3})\s*(?:دقيقه|دقيقة|د)').firstMatch(n);
    if (m != null) minutes = int.tryParse(m.group(1)!);

    // أرقام عربية بسيطة
    final ar = RegExp(r'(?:نص\s*ساعه|نص\s*ساعة)').hasMatch(n);
    if (ar && minutes == null) minutes = 30;

    int? freq;
    final f = RegExp(r'(\d{1,2})\s*(?:مرات|مره|مرة)').firstMatch(n);
    if (f != null) freq = int.tryParse(f.group(1)!);

    String? period;
    if (RegExp(r'هذا\s*الاسبوع|هذا\s*الأسبوع').hasMatch(n)) {
      period = 'week';
    } else if (RegExp(r'اليوم').hasMatch(n)) {
      period = 'day';
    }

    // لا نستنتج شدة إن لم تُذكر
    String? intensity;
    if (RegExp(r'(?:خفيف|معتدل|قوي|شديد)').hasMatch(n)) {
      if (RegExp(r'خفيف').hasMatch(n)) intensity = 'light';
      if (RegExp(r'معتدل').hasMatch(n)) intensity = 'moderate';
      if (RegExp(r'(?:قوي|شديد)').hasMatch(n)) intensity = 'vigorous';
    }

    return WellnessUserReport(
      activityType: walked
          ? WellnessActivityType.walking
          : (trained
              ? WellnessActivityType.exercise
              : WellnessActivityType.generalMovement),
      durationMinutes: minutes,
      frequencyCount: freq,
      period: period,
      userReportedIntensity: intensity,
      completed: noneToday ? false : true,
    );
  }

  WellnessGoalDraft _goalDraft(String n) {
    String? freq;
    final f = RegExp(r'(\d{1,2})\s*(?:ايام|أيام|مرات)').firstMatch(n);
    if (f != null) freq = '${f.group(1)} أيام/مرات';
    return WellnessGoalDraft(
      canonicalKey: 'goal_walking',
      displayLabel: 'الالتزام بالمشي',
      frequencyHint: freq,
      durationHint: RegExp(r'(\d+)\s*دقيق').firstMatch(n)?.group(0),
    );
  }
}
