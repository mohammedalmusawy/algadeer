import 'health_guidance_models.dart';

/// صياغة ردود مستخدم موجزة وغير تشخيصية.
class HealthGuidanceResponseBuilder {
  const HealthGuidanceResponseBuilder();

  String build(HealthGuidanceDecision decision) {
    switch (decision.type) {
      case HealthGuidanceDecisionType.needMoreInformation:
        return decision.nextQuestion?.prompt ??
            'أحتاج معلومة إضافية قبل التوجيه.';
      case HealthGuidanceDecisionType.specialtyDirection:
        final name = decision.destination?.displayNameAr ?? 'اختصاص مناسب';
        return 'حسب المعلومات اللي ذكرتها، ممكن أوجّهك إلى اختصاص $name للتقييم. '
            'مو تشخيص.';
      case HealthGuidanceDecisionType.generalEvaluation:
        return 'حسب المعلومات المتوفرة، الأنسب تقييم طبي عام. '
            'مو تشخيص، وتقدر تبحث عن طبيب باطنية أو طب عام إن تحب.';
      case HealthGuidanceDecisionType.urgentEvaluation:
        return decision.safetyMessage ??
            'الأعراض التي ذكرتها قد تحتاج تقييماً طبياً عاجلاً. '
                'لا تعتمد على التطبيق وحده في هذه الحالة.';
      case HealthGuidanceDecisionType.emergencyEvaluation:
        return decision.safetyMessage ??
            'الأعراض التي ذكرتها قد تستدعي رعاية طبية طارئة. '
                'يُفضّل طلب المساعدة الطبية فوراً وعدم تأخير التقييم.';
      case HealthGuidanceDecisionType.unableToDetermine:
        return 'ما تكفي المعلومات حالياً لتوجيه آمن. '
            'تقدر توضّح أكثر أو تبحث مباشرة عن خدمة في الغدير.';
    }
  }

  HealthGuidanceDecision withMessage(HealthGuidanceDecision d) {
    if (d.userMessage.trim().isNotEmpty) return d;
    return HealthGuidanceDecision(
      type: d.type,
      destination: d.destination,
      nextQuestion: d.nextQuestion,
      missingFact: d.missingFact,
      safetyMessage: d.safetyMessage,
      userMessage: build(d),
      matchedRuleId: d.matchedRuleId,
      rationaleCode: d.rationaleCode,
      allowCommercialOffers: d.allowCommercialOffers,
      suggestShowSpecialtyDoctors: d.suggestShowSpecialtyDoctors,
    );
  }
}
