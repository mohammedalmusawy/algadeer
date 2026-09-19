import '../search/arabic_text_utils.dart';
import 'daily_context_models.dart';

class DailyContextInterpretation {
  const DailyContextInterpretation({
    this.signals = const [],
    this.isAboutOtherPerson = false,
    this.asksSummary = false,
    this.asksDailyPlan = false,
    this.explicitFocusCategory,
    this.isCorrection = false,
    this.looksLikeEntityEscape = false,
    this.looksLikeLongTermRemember = false,
    this.looksLikeFollowUpRequest = false,
    this.urgentMedicalHint = false,
    this.mentalSafetyHint = false,
  });

  final List<DailyContextSignalDraft> signals;
  final bool isAboutOtherPerson;
  final bool asksSummary;
  final bool asksDailyPlan;
  final DailyContextCategory? explicitFocusCategory;
  final bool isCorrection;
  final bool looksLikeEntityEscape;
  final bool looksLikeLongTermRemember;
  final bool looksLikeFollowUpRequest;
  final bool urgentMedicalHint;
  final bool mentalSafetyHint;

  static const none = DailyContextInterpretation();

  bool get hasSignals => signals.isNotEmpty;

  bool get isDailyContextTurn =>
      hasSignals || asksSummary || asksDailyPlan || isCorrection;

  Map<String, Object?> debugMap() => {
        'dailySignalCount': signals.length,
        'dailyCategories': [for (final s in signals) s.category.name],
      };
}

/// مسودة إشارة قبل تطبيق انتهاء الصلاحية.
class DailyContextSignalDraft {
  const DailyContextSignalDraft({
    required this.category,
    required this.state,
    required this.timing,
    this.subject = DailyContextSubjectKind.accountOwner,
  });

  final DailyContextCategory category;
  final String state;
  final DailyContextTiming timing;
  final DailyContextSubjectKind subject;
}

/// مفسّر سياق يومي — يستخرج إشارات متعددة من دورة واحدة.
class DailyContextInterpreter {
  const DailyContextInterpreter();

  bool looksLikeDailyContext(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    if (_entityEscape(n)) return false;
    return RegExp(
      r'(?:اليوم|البارحه|البارحة|باچر|باجر|غدا|هذا\s*الاسبوع|'
      r'نومي|نوم\s*قليل|طاقة|متوتر|مضغوط|امتحان|دوامي|دوام|'
      r'ما\s*مشيت|رتبلي\s*يومي|شنو\s*فاهم\s*عن\s*وضعي|'
      r'تعبان|نعسان|شغل\s*هواي)',
    ).hasMatch(n);
  }

  DailyContextInterpretation interpret(
    String raw, {
    DateTime? now,
  }) {
    final n = ArabicTextUtils.normalize(raw.trim());
    if (n.isEmpty) return DailyContextInterpretation.none;

    final urgent = RegExp(
      r'(?:الم.{0,12}صدر|ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف)',
    ).hasMatch(n);
    final mental = RegExp(
      r'(?:اقتل\s*نفسي|انتحار|اذي\s*نفسي|أذي\s*نفسي)',
    ).hasMatch(n);

    if (_entityEscape(n)) {
      return DailyContextInterpretation(
        looksLikeEntityEscape: true,
        urgentMedicalHint: urgent,
        mentalSafetyHint: mental,
      );
    }

    final other = _otherPerson(n);
    final subject = other
        ? DailyContextSubjectKind.otherPerson
        : DailyContextSubjectKind.accountOwner;

    if (RegExp(r'(?:تذكر|احفظ)').hasMatch(n) &&
        RegExp(r'(?:دائما|دائم|دايما|كل\s*يوم)').hasMatch(n)) {
      return const DailyContextInterpretation(looksLikeLongTermRemember: true);
    }
    if (RegExp(r'(?:تابع\s*وياي)').hasMatch(n)) {
      return const DailyContextInterpretation(looksLikeFollowUpRequest: true);
    }

    final asksSummary = RegExp(
      r'(?:شنو\s*فاهم\s*عن\s*وضعي|وضع\s*اليوم|شنو\s*تعرف\s*عن\s*يومي)',
    ).hasMatch(n);
    final asksPlan = RegExp(r'(?:رتبلي\s*يومي|نظم\s*يومي|خطط\s*يومي)')
        .hasMatch(n);

    DailyContextCategory? focus;
    if (RegExp(
          r'(?:نريد\s*نركز|اريد\s*نركز|أريد\s*نركز|ركز\s*على\s*الدراسه|'
          r'ركز\s*علي\s*الدراسه|ركز\s*على\s*الدراسة|نركز\s*على\s*الدراسه|'
          r'نركز\s*علي\s*الدراسه)',
        ).hasMatch(n)) {
      focus = DailyContextCategory.study;
    }

    final drafts = <DailyContextSignalDraft>[];
    final isCorrection = RegExp(r'(?:لا\s*مو|مو\s*|لا\s*اليوم|صحح)')
        .hasMatch(n);

    void add(DailyContextCategory c, String state, DailyContextTiming t) {
      drafts.add(
        DailyContextSignalDraft(
          category: c,
          state: state,
          timing: t,
          subject: subject,
        ),
      );
    }

    // نوم
    if (RegExp(r'(?:نومي\s*قليل|نمت\s*قليل|نمت\s*ساعتين|نوم\s*قليل|'
            r'ما\s*نمت|نعسان)')
        .hasMatch(n)) {
      final t = RegExp(r'البارحه|البارحة').hasMatch(n)
          ? DailyContextTiming.yesterday
          : DailyContextTiming.today;
      final state = RegExp(r'نعسان').hasMatch(n) &&
              RegExp(r'(?:مو\s*تعبان|ليس\s*تعبان)').hasMatch(n)
          ? 'userReportsSleepyNotFatigued'
          : (RegExp(r'ساعتين').hasMatch(n)
              ? 'userReportsVeryLowSleep'
              : 'userReportsLowSleep');
      add(DailyContextCategory.sleep, state, t);
    }

    // طاقة
    if (RegExp(r'(?:ما\s*عندي\s*طاقه|ما\s*عندي\s*طاقة|تعبان|حاس\s*نفسي\s*تعبان)')
            .hasMatch(n) &&
        !RegExp(r'مو\s*تعبان').hasMatch(n)) {
      add(
        DailyContextCategory.energy,
        'userReportsLowEnergy',
        DailyContextTiming.today,
      );
    }
    if (RegExp(r'(?:اليوم\s*نشيط|(?:^|[^ا])عندي\s*طاقه|(?:^|[^ا])عندي\s*طاقة)')
            .hasMatch(n) &&
        !RegExp(r'ما\s*عندي\s*طاق').hasMatch(n)) {
      add(
        DailyContextCategory.energy,
        'userReportsHighEnergy',
        DailyContextTiming.today,
      );
    }

    // توتر / ضغط
    if (RegExp(r'(?:متوتر|مضغوط|توتر)').hasMatch(n)) {
      add(
        DailyContextCategory.emotionalState,
        'userReportsStressed',
        DailyContextTiming.today,
      );
      add(
        DailyContextCategory.stressLoad,
        'userReportsHighStress',
        DailyContextTiming.today,
      );
    }

    // امتحان
    if (RegExp(r'امتحان').hasMatch(n)) {
      DailyContextTiming t = DailyContextTiming.unknown;
      if (RegExp(r'(?:باچر|باجر|غدا|بكره)').hasMatch(n)) {
        t = DailyContextTiming.tomorrow;
      } else if (RegExp(r'اليوم').hasMatch(n)) {
        t = DailyContextTiming.today;
      } else if (RegExp(r'(?:بعد\s*يومين|هذا\s*الاسبوع|هذا\s*الأسبوع)')
          .hasMatch(n)) {
        t = DailyContextTiming.thisWeek;
      }
      add(DailyContextCategory.exam, 'upcomingExam', t);
      add(DailyContextCategory.study, 'studyLoad', t);
    }

    // أسبوع مذكور صراحة بلا امتحان
    if (RegExp(r'هذا\s*الاسبوع|هذا\s*الأسبوع').hasMatch(n) &&
        !drafts.any((d) => d.timing == DailyContextTiming.thisWeek)) {
      if (RegExp(r'(?:مضغوط|شغل|امتحانات)').hasMatch(n)) {
        add(
          DailyContextCategory.scheduleLoad,
          'userReportsBusyWeek',
          DailyContextTiming.thisWeek,
        );
      }
    }

    // عمل
    if (RegExp(r'(?:دوامي\s*طويل|دوام\s*طويل|شغل\s*هواي|شغلي\s*كثير)')
        .hasMatch(n)) {
      add(
        DailyContextCategory.work,
        'userReportsHighWorkload',
        DailyContextTiming.today,
      );
      add(
        DailyContextCategory.scheduleLoad,
        'userReportsBusyDay',
        DailyContextTiming.today,
      );
    }

    // نشاط
    if (RegExp(r'(?:اليوم\s*ما\s*مشيت|ما\s*مشيت\s*اليوم)').hasMatch(n)) {
      add(
        DailyContextCategory.activity,
        'userReportsNoActivityToday',
        DailyContextTiming.today,
      );
    }
    if (RegExp(r'(?:اليوم\s*مشيت|مشيت\s*اليوم)').hasMatch(n) &&
        !RegExp(r'ما\s*مشيت').hasMatch(n)) {
      add(
        DailyContextCategory.activity,
        'userReportsActivityToday',
        DailyContextTiming.today,
      );
    }

    // راحة
    if (RegExp(r'(?:أريد\s*أرتاح|اريد\s*ارتاح|أحتاج\s*راحه|احتاج\s*راحة)')
        .hasMatch(n)) {
      add(
        DailyContextCategory.restNeed,
        'userRequestsRest',
        DailyContextTiming.today,
      );
    }

    // صحة عامة غير عاجلة
    if (RegExp(r'(?:صداع|تعب\s*عام)').hasMatch(n) && !urgent) {
      add(
        DailyContextCategory.healthConcern,
        'userReportsMildConcern',
        DailyContextTiming.today,
      );
    }

    // تصحيح توقيت امتحان
    if (isCorrection && RegExp(r'امتحان').hasMatch(n)) {
      drafts.removeWhere((d) => d.category == DailyContextCategory.exam);
      final t = RegExp(r'بعد\s*يومين').hasMatch(n)
          ? DailyContextTiming.thisWeek
          : (RegExp(r'باچر|باجر').hasMatch(n)
              ? DailyContextTiming.tomorrow
              : DailyContextTiming.unknown);
      add(DailyContextCategory.exam, 'upcomingExam', t);
    }

    if (isCorrection &&
        RegExp(r'(?:مو\s*تعبان|ليس\s*تعبان).{0,12}نعسان').hasMatch(n)) {
      drafts.removeWhere((d) => d.category == DailyContextCategory.energy);
      drafts.removeWhere((d) => d.category == DailyContextCategory.sleep);
      add(
        DailyContextCategory.sleep,
        'userReportsSleepyNotFatigued',
        DailyContextTiming.today,
      );
    }

    if (isCorrection && RegExp(r'(?:لا\s*اليوم\s*مشيت|اليوم\s*مشيت)').hasMatch(n)) {
      drafts.removeWhere((d) => d.category == DailyContextCategory.activity);
      add(
        DailyContextCategory.activity,
        'userReportsActivityToday',
        DailyContextTiming.today,
      );
    }

    return DailyContextInterpretation(
      signals: drafts,
      isAboutOtherPerson: other,
      asksSummary: asksSummary,
      asksDailyPlan: asksPlan,
      explicitFocusCategory: focus,
      isCorrection: isCorrection,
      urgentMedicalHint: urgent,
      mentalSafetyHint: mental,
    );
  }

  bool _otherPerson(String n) {
    if (RegExp(r'(?:انا|أني|اني)\b').hasMatch(n)) return false;
    return RegExp(r'(?:امي|أمي|ابني|ابنتي|ابوي|زوجتي|زوجي)').hasMatch(n);
  }

  bool _entityEscape(String n) => RegExp(
        r'(?:أريد|اريد|ابي|دور)\s*(?:رقم\s*)?(?:طبيب|دكتور|مختبر)|'
        r'(?:رقم\s*(?:مختبر|الطبيب))',
      ).hasMatch(n);
}
