import 'sensitive_health_profile_models.dart';
import 'sensitive_health_profile_service.dart';

/// غرض الاسترجاع — تقليل البيانات إلزامي.
enum HealthRetrievalPurpose {
  unrelatedEntitySearch,
  generalChat,
  healthConversation,
  diabetesRelated,
  hypertensionRelated,
  asthmaRelated,
  showHealthProfile,
}

/// سياسة استرجاع محدودة الغرض — لا حقن لكل محادثة.
class SensitiveHealthRetrievalPolicy {
  const SensitiveHealthRetrievalPolicy();

  Future<List<HealthConditionRecord>> retrieveRelevant({
    required SensitiveHealthProfileService service,
    required HealthRetrievalPurpose purpose,
    String? queryHint,
  }) async {
    if (purpose == HealthRetrievalPurpose.unrelatedEntitySearch ||
        purpose == HealthRetrievalPurpose.generalChat) {
      return const [];
    }

    try {
      final profile = await service.loadProfile();
      if (profile == null || !profile.healthPersonalizationEnabled) {
        return const [];
      }
      if (purpose == HealthRetrievalPurpose.showHealthProfile) {
        return List.unmodifiable(profile.conditions);
      }

      final keys = <String>{};
      switch (purpose) {
        case HealthRetrievalPurpose.diabetesRelated:
          keys.add(HealthCanonicalConditionKey.diabetes.name);
        case HealthRetrievalPurpose.hypertensionRelated:
          keys.add(HealthCanonicalConditionKey.hypertension.name);
        case HealthRetrievalPurpose.asthmaRelated:
          keys.add(HealthCanonicalConditionKey.asthma.name);
        case HealthRetrievalPurpose.healthConversation:
          // محادثة صحية عامة: لا نُفرغ كل السجلات إلا إذا أشار الاستعلام
          final q = (queryHint ?? '').toLowerCase();
          if (q.contains('سكر')) {
            keys.add(HealthCanonicalConditionKey.diabetes.name);
          }
          if (q.contains('ضغط')) {
            keys.add(HealthCanonicalConditionKey.hypertension.name);
          }
          if (q.contains('ربو')) {
            keys.add(HealthCanonicalConditionKey.asthma.name);
          }
          // بدون إشارة: لا حقن
          if (keys.isEmpty) return const [];
        default:
          return const [];
      }

      return profile.conditions
          .where((c) => keys.contains(c.canonicalConditionKey))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  HealthRetrievalPurpose purposeForQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) return HealthRetrievalPurpose.generalChat;
    if (RegExp(r'(?:مختبر|باقه|باقة|تحليل|طبيب\s*انف|أنف)').hasMatch(q) &&
        !RegExp(r'(?:سكر|ضغط|ربو|صحت)').hasMatch(q)) {
      return HealthRetrievalPurpose.unrelatedEntitySearch;
    }
    if (RegExp(r'سكر').hasMatch(q)) {
      return HealthRetrievalPurpose.diabetesRelated;
    }
    if (RegExp(r'ضغط').hasMatch(q)) {
      return HealthRetrievalPurpose.hypertensionRelated;
    }
    if (RegExp(r'ربو').hasMatch(q)) {
      return HealthRetrievalPurpose.asthmaRelated;
    }
    if (RegExp(r'(?:صحت|عرض|الم|ألم|ضيق)').hasMatch(q)) {
      return HealthRetrievalPurpose.healthConversation;
    }
    return HealthRetrievalPurpose.generalChat;
  }
}
