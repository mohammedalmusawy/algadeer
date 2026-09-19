import 'daily_context_models.dart';

/// استراتيجية رد واحدة متماسكة — بلا إغراق نصائح.
class DailyContextResponseStrategy {
  const DailyContextResponseStrategy();

  String build({
    required DailyContextPriority priority,
    required DailyLifeContext context,
    required bool highLoad,
    bool asksPlan = false,
    bool asksSummary = false,
    bool aboutOther = false,
  }) {
    if (aboutOther) {
      return 'فهمت إن الموضوع يخص شخص ثاني. '
          'ما أخلط وضعك الشخصي مع وضعهم. '
          'أكدر أساعد بمعلومة عامة قصيرة إذا تحب.';
    }

    if (asksSummary) {
      return _summary(context);
    }

    if (asksPlan) {
      return _dailyPlan(context, priority, highLoad);
    }

    switch (priority) {
      case DailyContextPriority.urgentMedicalSafety:
      case DailyContextPriority.mentalHealthSafety:
        return ''; // يُترك لمسارات السلامة
      case DailyContextPriority.restSleepNeed:
        return highLoad
            ? 'حسب اللي ذكرت، نومك قليل وفي حمل (امتحان/ضغط). '
                'الأولوية هسه للراحة وترتيب الضروري فقط — '
                'ما تضغط على هدف المشي أو قائمة إنجازات طويلة اليوم.'
            : 'بما إن نومك قليل، الأفضل تخفّف الحمل وتركّز على راحة قصيرة '
                'وما يلزمك الآن. الراحة خيار صحيح، مو فشل.';
      case DailyContextPriority.immediateFunctionalNeed:
        return highLoad
            ? 'يومك يبدو مزدحماً. خطوة واحدة الآن: حدّد أهم شيء لازم يخلص، '
                'وبعدها راحة قصيرة إن قدرت. ما راح أراكم نصائح حركة ودراسة ونوم دفعة واحدة.'
            : 'تمام، خلّينا نركّز على المهمة اللي أمامك بهالمدة.';
      case DailyContextPriority.explicitUserGoal:
        return 'زين، نركّز على اللي طلبته. ما أحوّل الحديث لنصائح ثانية إلا إذا احتجت.';
      case DailyContextPriority.emotionalLoad:
        return 'واضح إن في ضغط. ما في حكم على إنتاجيتك. '
            'إذا تحب، نأخذ خطوة واحدة صغيرة تهدّي اليوم — أو راحة إذا هذي اللي تحتاجها.';
      case DailyContextPriority.activeHealthConcern:
        return 'بالنسبة للي ذكرت من أعراض/تعب، ما أشخّص السبب. '
            'إذا تحب نوضّح العرض شوي، أو نركز على راحة آمنة إلى أن ترتاح.';
      case DailyContextPriority.activityWellness:
        return 'فهمت وضع الحركة/الطاقة لليوم. '
            'إذا تحب خطوة خفيفة اختيارية أكدر أقترح، بلا ضغط ولا سلسلة.';
      case DailyContextPriority.lowerOptimization:
        return 'فهمت سياق يومك بشكل مختصر. شنو تحب نركّز عليه الآن؟';
      case DailyContextPriority.none:
        return '';
    }
  }

  String _summary(DailyLifeContext context) {
    final active = context
        .activeSignals()
        .where((s) => s.subject == DailyContextSubjectKind.accountOwner)
        .toList();
    if (active.isEmpty) {
      return 'ما عندي سياق يومي مؤقت واضح حالياً من كلامك. '
          'هذا غير الذاكرة الدائمة — أعتمد على اللي تذكره بهالمحادثة.';
    }
    final cats = active.map((s) => _label(s.category)).toSet().join('، ');
    return 'حسب اللي ذكرت بهالمحادثة (سياق مؤقت لليوم/الفترة): $cats. '
        'هذا مو سجل دائم لحياتك، وما أعتمد على أجهزة أو حسّاسات.';
  }

  String _dailyPlan(
    DailyLifeContext context,
    DailyContextPriority priority,
    bool highLoad,
  ) {
    final blocks = <String>[];
    if (highLoad || priority == DailyContextPriority.restSleepNeed) {
      blocks.addAll([
        '• ضروري الآن: راحة / ترتيب أهم واجب فقط',
        '• صحة: راحة ونوم إن قدرت',
        '• اختياري لاحقاً: حركة خفيفة إذا صارت مناسبة',
      ]);
    } else {
      blocks.addAll([
        '• يجب: المهمة الأهم عندك',
        '• راحة/صحة: استراحة قصيرة',
        '• هدف أساسي: خطوة واحدة مرتبطة بأولويتك',
        '• اختياري: حركة بسيطة',
        '• ختام: تهدئة قبل النوم',
      ]);
    }
    final limited = blocks.take(highLoad ? 3 : 5).join('\n');
    return 'ترتيب بسيط ليومك (مو نظام إنتاجية كامل):\n$limited\n'
        'ما في حكم إن ما خلصت كل شيء.';
  }

  String _label(DailyContextCategory c) {
    switch (c) {
      case DailyContextCategory.sleep:
        return 'نوم';
      case DailyContextCategory.energy:
        return 'طاقة';
      case DailyContextCategory.exam:
        return 'امتحان';
      case DailyContextCategory.study:
        return 'دراسة';
      case DailyContextCategory.work:
        return 'عمل';
      case DailyContextCategory.activity:
        return 'نشاط';
      case DailyContextCategory.emotionalState:
      case DailyContextCategory.stressLoad:
        return 'ضغط';
      case DailyContextCategory.restNeed:
        return 'حاجة راحة';
      case DailyContextCategory.healthConcern:
        return 'قلق صحي مذكور';
      default:
        return c.name;
    }
  }

  bool containsForbidden(String msg) {
    if (RegExp(
      r'(?:ضيعت\s*يومك|أنت\s*كسول|لازم\s*تنجز|فشلت\s*اليوم|'
      r'صداعك\s*بسبب\s*قلة\s*النوم|'
      r'اضطراب\s*قلق|تشخيص\s*اكتئاب|أرق\s*مزمن)',
    ).hasMatch(msg)) {
      return true;
    }
    // ادّعاء مراقبة فقط إن لم يُنفَ
    if (RegExp(r'أراقب\s*يومك').hasMatch(msg) &&
        !RegExp(r'(?:لا|ولا|ما)\s*أراقب').hasMatch(msg)) {
      return true;
    }
    if (RegExp(r'أعرف\s*(?:نومك|نشاطك)').hasMatch(msg) &&
        !RegExp(r'(?:لا|ما)\s*أعرف').hasMatch(msg)) {
      return true;
    }
    return false;
  }
}