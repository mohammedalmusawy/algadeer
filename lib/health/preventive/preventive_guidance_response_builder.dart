import 'preventive_evidence_metadata.dart';
import 'preventive_guidance_catalog_source.dart';
import 'preventive_guidance_context.dart';
import 'preventive_guidance_models.dart';

/// عرض محلي — منفصل عن الدليل الطبي.
class PreventiveGuidanceResponseBuilder {
  PreventiveGuidanceResponseBuilder({
    PreventiveGuidanceCatalogSource? catalog,
  }) : _catalog = catalog ?? LocalPreventiveGuidanceCatalog();

  final PreventiveGuidanceCatalogSource _catalog;

  static const morePrompt = 'إذا تحب أكمل لك باقي النصائح، قول «أكمل».';

  Future<String> build({
    required PreventiveGuidancePlan plan,
    required PreventiveGuidanceContext context,
  }) async {
    if (plan.selectedRuleIds.isEmpty) {
      return _emptyResponse(context);
    }

    final lines = <String>[];
    for (final id in plan.selectedRuleIds) {
      final rule = await _catalog.findById(id);
      if (rule == null) continue;
      final text = _localizedPresentation(rule, context);
      if (text.isNotEmpty) lines.add(text);
    }

    if (lines.isEmpty) return _emptyResponse(context);

    final intro = _introFor(context, plan);
    final body = lines.map((l) => '• $l').join('\n');
    var msg = intro.isEmpty ? body : '$intro\n$body';

    if (plan.hasMore && !context.emotionalOverload) {
      msg = '$msg\n\n$morePrompt';
    }

    // clinician-required footer
    if (plan.personalizationLevel ==
        PreventivePersonalizationLevel.clinicianRequired) {
      msg =
          '$msg\n\nملاحظة: هذي معلومات عامة للنقاش مع طبيبك، مو تشخيص ولا بديل عن الفحص.';
    }

    return msg;
  }

  String _introFor(
    PreventiveGuidanceContext context,
    PreventiveGuidancePlan plan,
  ) {
    switch (plan.topic) {
      case PreventiveGuidanceTopic.ageAppropriate:
        if (!context.hasKnownAge) {
          return 'ما عندي عمرك محفوظ، فهذي نصائح عامة آمنة:';
        }
        return 'حسب عمرك المعروف، هذي اقتراحات وقائية مناسبة:';
      case PreventiveGuidanceTopic.student:
        return 'نصائح قصيرة تناسب وضعك كطالب:';
      case PreventiveGuidanceTopic.examPeriod:
        return 'لفترة الامتحانات، خطوات بسيطة ممكن تساعد:';
      case PreventiveGuidanceTopic.diet:
        return 'أنماط أكل صحية عامة:';
      case PreventiveGuidanceTopic.walking:
      case PreventiveGuidanceTopic.activity:
        return 'حركة ونشاط — بشكل عام:';
      case PreventiveGuidanceTopic.screening:
        return 'موضوعات فحص/وقاية للنقاش مع الطبيب:';
      case PreventiveGuidanceTopic.salt:
        return 'بخصوص الملح — إرشاد عام:';
      default:
        return context.emotionalOverload
            ? 'خطوة واحدة صغيرة ممكن تساعد:'
            : 'هذي اقتراحات وقائية مختصرة:';
    }
  }

  String _emptyResponse(PreventiveGuidanceContext context) {
    if (!context.catalogAvailable) {
      return 'ما أقدر أطلع نصائح وقائية حالياً. جرّب لاحقاً أو اسأل طبيبك مباشرة.';
    }
    if (!context.hasKnownAge &&
        (context.requestTopic == PreventiveGuidanceTopic.ageAppropriate ||
            context.requestTopic == PreventiveGuidanceTopic.screening)) {
      return 'ما عندي عمرك محفوظ، فما أقدر أقترح فحوصات حسب العمر. '
          'إذا تحب، احفظ سنة ميلادك بالملف أو اسأل طبيبك مباشرة.';
    }
    return 'ما لقيت نصيحة وقائية مناسبة للسياق المعروف حالياً. '
        'تقدر تسأل عن موضوع محدد مثل الحركة، الأكل، أو النوم.';
  }

  String _localizedPresentation(
    PreventiveGuidanceRule rule,
    PreventiveGuidanceContext context,
  ) {
    // العرض المحلي — قابل للتكييف العراقي لاحقاً دون تغيير ruleId
    switch (rule.presentationKey) {
      case 'activity_moderate_weekly':
        return 'حاول توصل تقريباً 150–300 دقيقة أسبوعياً من نشاط معتدل '
            '(أو نشاط أقوى بكمية أقل)، مع تدرّج إذا كنت مبتدئ.';
      case 'walking_example_not_prescription':
        return 'المشي ممكن يكون مثال عملي للنشاط المعتدل — مو جرعة ثابتة '
            'للجميع. ابدأ بما يناسبك واستشر طبيبك إذا عندك قيود طبية.';
      case 'diet_balanced_patterns':
        return 'ركّز على خضار وفواكه، بقوليات، حبوب كاملة، بروtein مناسب، '
            'وقلّل الملح الزائد والسكريات المضافة والأطعمة المصنّعة الثقيلة.';
      case 'salt_under_5g_general':
        return 'إرشاد عام للبالغين: حاول تقلّل الملح لأقل من 5 غram يومياً '
            'حيث ينطبق — بدون تعليمات علاجية فردية.';
      case 'salt_hypertension_clinician_aware':
        return 'بما إن عندك سياق ضغط مسموح بالملف، الملح مهم — '
            'ناقش هدفك المناسب مع طبيبك; لا أعدّل الدواء ولا الجرعة.';
      case 'student_sleep_balance':
        return 'حاول ثبّت وقت نوم واستيقاظ قدر الإمكان، خصوصاً أيام الدراسة.';
      case 'student_exam_short_routine':
        return 'قسّم الدراسة لفترات قصيرة مع استراحة — نوم كافٍ أهم من '
            'سحب ليلي طويل. تجنّب الاعتماد الزائد على منبهات/كافيين.';
      case 'student_movement_breaks':
        return 'كل ساعة دراسة، قوم 3–5 دقائق حركة خفيفة — يفرّغ الرأس شوي.';
      case 'employee_sitting_breaks':
        return 'إذا جلسك طويل بالعمل، حاول كل 45–60 دقيقة وقفة حركة قصيرة.';
      case 'selfemployed_routine_balance':
        return 'نظّم يومك بفترات عمل واستراحة — حركة خفيفة بين المهام '
            'أحسن من جلسة واحدة طويلة.';
      case 'screening_bp_discuss_with_doctor':
        return 'قد يكون مناسب تناقش قياس ضغط الدم الدوري مع طبيبك حسب '
            'عمرك وعوامل الخطورة — مو تشخيص.';
      case 'screening_age_discuss_not_diagnosis':
        return 'حسب عمرك، قد يكون مناسب تناقش فحوصات وقائية مع طبيبك '
            '(مثل بعض فحوصات السرطان أو السكر) — القرار يعتمد على '
            'عواملك الشخصية، مو قاعدة واحدة للجميع.';
      case 'screening_metabolic_discuss':
        return 'مع سياق السكري المسموح، ناقش متابعة/Follow-up المناسبة '
            'مع طبيبك — ما أحدّد حالة سريرية جديدة.';
      case 'bp_awareness_age_context':
        return 'الوعي بضغط الدم مهم مع تقدّم العمر — قياس دوري '
            'يناقش مع الطبيب أفضل من الاستنتاج الذاتي.';
      case 'tobacco_avoidance_general':
        return 'تجنّب التدخين ومنتجات التبغ — من أهم خطوات الوقاية العامة.';
      default:
        return '';
    }
  }

  /// للتحقق: لا مكملات تلقائية.
  bool containsSupplementRecommendation(String text) {
    final lower = text.toLowerCase();
    return text.contains('أوميغا') ||
        text.contains('اوميغا') ||
        lower.contains('omega') ||
        text.contains('فيتامين') ||
        text.contains('مكمل') ||
        text.contains('Omega-3');
  }
}
