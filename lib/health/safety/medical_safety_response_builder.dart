import 'medical_safety_models.dart';

/// صياغة ردود سلامة — قصيرة، هادئة، غير تشخيصية، غير تجارية.
class MedicalSafetyResponseBuilder {
  const MedicalSafetyResponseBuilder();

  static const urgentDefault =
      'الأعراض التي ذكرتها قد تحتاج تقييماً طبياً عاجلاً. '
      'إذا كانت شديدة أو مستمرة، لا تعتمد على التطبيق وحده واطلب '
      'الرعاية الطبية العاجلة.';

  static const emergencyDefault =
      'الأعراض التي ذكرتها قد تستدعي رعاية طبية طارئة. '
      'يُفضّل طلب المساعدة الطبية فوراً وعدم تأخير التقييم.';

  /// لا طمأنة كاذبة عند عدم المطابقة.
  String? messageFor(MedicalSafetyDecision decision) {
    switch (decision.status) {
      case MedicalSafetyStatus.noRedFlagDetected:
        // عمداً لا رسالة «أنت بخير» / «ماكو خطر».
        return null;
      case MedicalSafetyStatus.needSafetyInformation:
        return decision.nextQuestion?.prompt ?? decision.userMessage;
      case MedicalSafetyStatus.urgentEvaluation:
        return decision.userMessage.trim().isNotEmpty
            ? decision.userMessage
            : urgentDefault;
      case MedicalSafetyStatus.emergencyEvaluation:
        return decision.userMessage.trim().isNotEmpty
            ? decision.userMessage
            : emergencyDefault;
    }
  }

  MedicalSafetyDecision withMessage(MedicalSafetyDecision d) {
    final msg = messageFor(d);
    if (msg == null || msg == d.userMessage) return d;
    return MedicalSafetyDecision(
      status: d.status,
      matchedRuleId: d.matchedRuleId,
      responseCode: d.responseCode,
      userMessage: msg,
      nextQuestion: d.nextQuestion,
      missingFact: d.missingFact,
      suppressCommercialContent: d.suppressCommercialContent,
      interruptConversation: d.interruptConversation,
      responseCategory: d.responseCategory,
    );
  }
}
