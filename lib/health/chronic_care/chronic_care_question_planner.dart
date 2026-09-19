import 'chronic_care_condition_registry.dart';
import 'chronic_care_models.dart';

/// يختار سؤالاً واحداً نافعاً — بلا تكرار للمعلوم.
class ChronicCareQuestionPlanner {
  const ChronicCareQuestionPlanner({
    ChronicCareConditionRegistry? registry,
  }) : _registry = registry ?? const ChronicCareConditionRegistry();

  final ChronicCareConditionRegistry _registry;

  ChronicCareQuestionKind? nextQuestion({
    required String conditionKey,
    required ChronicCareFollowUpState state,
    required ChronicCareStore store,
  }) {
    if (state.reducedPressure && state.consecutiveSkips >= 2) {
      return null;
    }
    final def = _registry.byKey(conditionKey);
    if (def == null) return null;

    for (final q in def.followUpQuestionOrder) {
      if (state.answeredQuestionKinds.contains(q.name)) continue;
      if (q == ChronicCareQuestionKind.lastMeasurement &&
          store.measurements.any((m) => m.conditionKey == conditionKey)) {
        continue;
      }
      if (q == ChronicCareQuestionKind.controlStatus &&
          state.userControlStatus != ChronicUserControlStatus.unknown) {
        continue;
      }
      return q;
    }
    return null;
  }

  String promptFor(ChronicCareQuestionKind kind, String displayName) {
    switch (kind) {
      case ChronicCareQuestionKind.recentStatus:
        return 'شلون مستوى $displayName عندك هالفترة؟';
      case ChronicCareQuestionKind.lastMeasurement:
        return 'متى آخر مرة قست $displayName؟';
      case ChronicCareQuestionKind.lastFollowUp:
        return 'متى آخر متابعة أو فحص متعلق ب$displayName؟';
      case ChronicCareQuestionKind.controlStatus:
        return 'حسب إحساسك، $displayName مضبوط، مو مضبوط، لو متقلب؟';
      case ChronicCareQuestionKind.doctorFollowUp:
        return 'هل تتابع حالياً مع طبيب بخصوص $displayName؟';
      case ChronicCareQuestionKind.measurementContextClarification:
        return 'هذا القياس كان صايم لو بعد الأكل؟';
    }
  }
}
