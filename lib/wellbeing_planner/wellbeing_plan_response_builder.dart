import 'wellbeing_planner_models.dart';

/// رد هادئ عملي — بلا جداول سريرية ضخمة.
class WellbeingPlanResponseBuilder {
  const WellbeingPlanResponseBuilder();

  String buildPlan(WellbeingActionPlan plan, WellbeingPlanContextEnvelope env) {
    if (plan.actions.isEmpty) {
      return 'ما عندي خطة مخصّصة واضحة هسه بدون ما أخترع تفاصيل. '
          'قول شنو تحب نركّز عليه: راحة، حركة خفيفة، أو ترتيب أولوية.';
    }

    final foot = StringBuffer();
    if (env.hasLowSleep && env.hasExamSoon) {
      foot.write(
        'ما أضغط هدف المشي اليوم — الأولوية للراحة/الامتحان حسب اللي ذكرت.',
      );
    }

    if (plan.oneNextStepMode) {
      final a = plan.actions.first;
      final extra = foot.isEmpty ? '' : '\n$foot';
      return 'خطوة واحدة الآن: ${a.label}.\n'
          'إذا صارت مناسبة، نقدر نضيف اللي بعدها.$extra';
    }

    final buf = StringBuffer();
    if (env.planHorizon == WellbeingPlanHorizon.thisWeek) {
      buf.writeln('إطار أسبوعي بسيط (مو روزنامة دقيقة ولا تنبيهات):');
    } else {
      buf.writeln('خطة عافية قصيرة:');
    }

    for (final a in plan.actions) {
      final tag = switch (a.slot) {
        'now' => 'الآن',
        'next' => 'بعدها',
        _ => 'إذا عندك مجال',
      };
      buf.writeln('• $tag: ${a.label}');
    }

    if (foot.isNotEmpty) {
      buf.writeln(foot.toString());
    }

    buf.write('ما في حكم إن ما خلصت كل شيء.');
    return buf.toString().trim();
  }

  String buildOtherPersonSafe() {
    return 'طلب الخطة يخص شخص ثاني. '
        'ما أستخدم عمرك أو أهدافك أو صحتك أو سياق يومك لبناء خطة فردية له. '
        'أكدر أعطي إرشادات عامة آمنة فقط، بدون تخطيط مخصّص للعائلة في هذه المرحلة.';
  }

  String buildExplanation(
    WellbeingActionPlan plan,
    WellbeingPlanContextEnvelope env,
  ) {
    final reasons = <String>[];
    if (env.hasLowSleep) reasons.add('ذكرت أن نومك قليل');
    if (env.hasExamSoon) reasons.add('عندك امتحان قريب');
    if (env.hasHighDailyLoad) reasons.add('الحمل اليومي عالي');
    if (env.userExplicitPriority != null) {
      reasons.add('أولويتك الصريحة');
    }
    if (env.eligibleWalkingGoal &&
        plan.actions.any((a) => a.category == WellbeingActionCategory.walking ||
            a.category == WellbeingActionCategory.personalGoal)) {
      reasons.add('هدف المشي الحالي إن ناسب');
    }
    if (reasons.isEmpty) {
      reasons.add('نطاق طلبك الحالي');
    }
    return 'رتّبتها لأن: ${reasons.join('، ')}. '
        'ما أكشف معلومات صحية مخفية، وأعتمد على السياق المسموح بهالمحادثة.';
  }

  String buildMissedNoGuilt() {
    return 'ما في مشكلة إن ما سويت الخطة اليوم — مو تقييم سلبي. '
        'نكدر نصغّر الخطوة الجاية أو نكمّل لاحقاً حسب وضعك هسه.';
  }

  String buildFamilyGeneralOnly() {
    return 'معلومة عامة: الراحة والنوم المنتظم والحركة الخفيفة مفيدة لكثير من الناس. '
        'بدون خطة فردية مبنية على ملفك الشخصي.';
  }

  bool containsForbidden(String msg) {
    if (RegExp(
      r'(?:لا\s*تخيب\s*ظني|لا\s*تكسر\s*الخطة|لازم\s*تكمل|'
      r'انا\s*اراقب\s*تقدمك|أزعل|نقاط|شارة|streak|'
      r'اعرف\s*انك\s*التزمت|راح\s*اذكرك\s*الساعه|ضفتها\s*لجدولك|'
      r'علاج\s*نفسي\s*كامل|وصف\s*دواء|مكمل\s*غذائي\s*لازم|'
      r'سعرات|calorie|metabolic)',
    ).hasMatch(msg)) {
      return true;
    }
    if (RegExp(r'أراقب\s*(?:يومك|تقدمك)').hasMatch(msg) &&
        !RegExp(r'(?:لا|ولا|ما)\s*أراقب').hasMatch(msg)) {
      return true;
    }
    return false;
  }
}
