import '../../search/arabic_text_utils.dart';
import 'personalization_models.dart';

/// ميزانية حقائق التخصيص — حتمية.
class PersonalizationBudgetPolicy {
  const PersonalizationBudgetPolicy();

  PersonalizationBudget budgetFor({
    required PersonalizationPurpose purpose,
    required bool containsSensitive,
  }) {
    if (purpose == PersonalizationPurpose.none ||
        purpose == PersonalizationPurpose.disabledByUser ||
        purpose == PersonalizationPurpose.providerDiscovery) {
      return PersonalizationBudget.zero;
    }
    if (containsSensitive ||
        purpose == PersonalizationPurpose.healthGuidance ||
        purpose == PersonalizationPurpose.chronicCare) {
      return PersonalizationBudget.sensitivePreferMinimal;
    }
    return PersonalizationBudget.standard;
  }

  List<PersonalizationCandidate> applyBudget({
    required List<PersonalizationCandidate> candidates,
    required PersonalizationBudget budget,
  }) {
    if (budget.maxFacts <= 0) return const [];
    final out = <PersonalizationCandidate>[];
    var sensitiveUsed = 0;
    for (final c in candidates) {
      if (out.length >= budget.maxFacts) break;
      if (c.sensitive) {
        if (sensitiveUsed >= budget.maxSensitiveFacts) continue;
        sensitiveUsed++;
      }
      out.add(c);
    }
    return List.unmodifiable(out);
  }
}

/// سياسة صلة — الغرض يحدد ما يُسمح بطلبه.
class PersonalizationRelevancePolicy {
  const PersonalizationRelevancePolicy();

  PersonalizationPurpose purposeForQuery(
    String query, {
    String planKindName = '',
    String intentName = '',
  }) {
    final n = ArabicTextUtils.normalize(query);

    if (_disablePersonalization(n)) {
      return PersonalizationPurpose.disabledByUser;
    }

    if (_explicitMemoryQuery(n)) {
      return PersonalizationPurpose.explicitMemoryQuery;
    }

    if (RegExp(r'(?:صداع|الم|ألم|سكر|ضغط|ربو|صحتي|عندي\s*عرض)').hasMatch(n) ||
        planKindName == 'healthGuidance') {
      return PersonalizationPurpose.healthGuidance;
    }
    if (RegExp(r'(?:مزمن|قياس\s*السكر|متابعه\s*السكر|متابعة\s*السكر)')
        .hasMatch(n)) {
      return PersonalizationPurpose.chronicCare;
    }
    if (RegExp(r'(?:وقائي|تحصين|فحص\s*دوري|عمري)').hasMatch(n)) {
      return PersonalizationPurpose.preventiveGuidance;
    }
    if (RegExp(r'(?:تابع|نكمل|نرجع\s*لموضوع)').hasMatch(n)) {
      return PersonalizationPurpose.followUpContinuation;
    }
    if (RegExp(r'(?:طبيب|دكتور|مختبر|باقه|باقة|رقم)').hasMatch(n) ||
        intentName.contains('findDoctor') ||
        intentName.contains('findLab') ||
        planKindName.contains('Doctor') ||
        planKindName.contains('Lab')) {
      return PersonalizationPurpose.providerDiscovery;
    }
    if (RegExp(r'(?:ريلز|محتوي|محتوى|مونتاج|تصوير)').hasMatch(n)) {
      return PersonalizationPurpose.contentSupport;
    }
    if (RegExp(r'(?:اتعلم|تعلم|flutter|فلتر|امتحان|دراس)').hasMatch(n)) {
      return PersonalizationPurpose.learningSupport;
    }
    if (RegExp(r'(?:هدفي|هدف)').hasMatch(n)) {
      return PersonalizationPurpose.goalSupport;
    }
    if (RegExp(r'(?:نكمل|رجعنا|موضوع)').hasMatch(n)) {
      return PersonalizationPurpose.conversationContinuity;
    }
    return PersonalizationPurpose.answerCurrentQuestion;
  }

  bool isSourceRelevant({
    required PersonalizationSource source,
    required PersonalizationPurpose purpose,
  }) {
    switch (purpose) {
      case PersonalizationPurpose.disabledByUser:
      case PersonalizationPurpose.none:
        return false;
      case PersonalizationPurpose.providerDiscovery:
        return source == PersonalizationSource.conversationContext;
      case PersonalizationPurpose.learningSupport:
      case PersonalizationPurpose.goalSupport:
      case PersonalizationPurpose.contentSupport:
        return source == PersonalizationSource.companionProfile ||
            source == PersonalizationSource.personalMemory ||
            source == PersonalizationSource.conversationContext;
      case PersonalizationPurpose.healthGuidance:
      case PersonalizationPurpose.chronicCare:
      case PersonalizationPurpose.preventiveGuidance:
        return source == PersonalizationSource.sensitiveHealth ||
            source == PersonalizationSource.familySensitiveHealth ||
            source == PersonalizationSource.chronicCare ||
            source == PersonalizationSource.companionProfile ||
            source == PersonalizationSource.conversationContext;
      case PersonalizationPurpose.followUpContinuation:
        return source == PersonalizationSource.followUp ||
            source == PersonalizationSource.personalMemory ||
            source == PersonalizationSource.conversationContext;
      case PersonalizationPurpose.explicitMemoryQuery:
        return source == PersonalizationSource.personalMemory ||
            source == PersonalizationSource.companionProfile;
      case PersonalizationPurpose.answerCurrentQuestion:
      case PersonalizationPurpose.conversationContinuity:
        return source == PersonalizationSource.companionProfile ||
            source == PersonalizationSource.personalMemory ||
            source == PersonalizationSource.followUp ||
            source == PersonalizationSource.conversationContext;
    }
  }

  bool ageRelevant(PersonalizationPurpose purpose) =>
      purpose == PersonalizationPurpose.preventiveGuidance ||
      purpose == PersonalizationPurpose.healthGuidance;

  bool studentContextRelevant(PersonalizationPurpose purpose, String query) {
    final n = ArabicTextUtils.normalize(query);
    if (purpose == PersonalizationPurpose.providerDiscovery) return false;
    return purpose == PersonalizationPurpose.learningSupport &&
        RegExp(r'(?:امتحان|دراس|مذاكره|مذاكرة)').hasMatch(n);
  }

  bool _disablePersonalization(String n) => RegExp(
        r'(?:جاوبني\s*بدون\s*تخصيص)|'
        r'(?:لا\s*تستخدم\s*معلوماتي\s*القديمه)|'
        r'(?:بهذا\s*الموضوع\s*لا\s*تعتمد)|'
        r'(?:بدون\s*تخصيص)',
      ).hasMatch(n);

  bool _explicitMemoryQuery(String n) => RegExp(
        r'(?:شنو\s*كان\s*هدفي)|'
        r'(?:شنو\s*اهدافي)|'
        r'(?:استخدم\s*اللي\s*تعرفه\s*عني)|'
        r'(?:شنو\s*تعرف\s*عني)',
      ).hasMatch(n);

  bool requestsUseMemory(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(r'استخدم\s*اللي\s*تعرفه\s*عني').hasMatch(n);
  }

  bool requestsNoPersonalization(String query) {
    final n = ArabicTextUtils.normalize(query);
    return _disablePersonalization(n);
  }

  bool looksLikeMemoryCorrection(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(
      r'(?:بطلت|مو\s*(?:flutter|فلتر)|صرت\s*اتعلم|بدل\s*(?:هدف|اهتمام))',
    ).hasMatch(n);
  }

  bool looksLikeTemporaryPreferenceOverride(String query) {
    final n = ArabicTextUtils.normalize(query);
    return RegExp(r'(?:هسه|اليوم)\s*(?:اختصر|باختصار|مختصر)').hasMatch(n);
  }
}
