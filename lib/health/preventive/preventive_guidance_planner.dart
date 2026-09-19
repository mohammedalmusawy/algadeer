import 'preventive_evidence_metadata.dart';
import 'preventive_guidance_catalog_source.dart';
import 'preventive_guidance_context.dart';
import 'preventive_guidance_eligibility.dart';
import 'preventive_guidance_models.dart';

/// مخطّط القواعد — يختار 1–3 اقتراحات عالية القيمة.
class PreventiveGuidancePlanner {
  PreventiveGuidancePlanner({
    PreventiveGuidanceCatalogSource? catalog,
    PreventiveGuidanceEligibility? eligibility,
  })  : _catalog = catalog ?? LocalPreventiveGuidanceCatalog(),
        _eligibility = eligibility ?? const PreventiveGuidanceEligibility();

  final PreventiveGuidanceCatalogSource _catalog;
  final PreventiveGuidanceEligibility _eligibility;

  static const maxSuggestions = 3;
  static const maxSuggestionsUnderStress = 1;

  Future<PreventiveGuidancePlan> plan({
    required PreventiveGuidanceContext context,
    PreventiveGuidanceSession session = PreventiveGuidanceSession.inactive,
    bool requestMore = false,
  }) async {
    if (!context.catalogAvailable) {
      return PreventiveGuidancePlan.empty;
    }

    List<PreventiveGuidanceRule> rules;
    try {
      rules = await _catalog.loadActiveRules();
    } catch (_) {
      return PreventiveGuidancePlan.empty;
    }

    if (rules.isEmpty) return PreventiveGuidancePlan.empty;

    final topic = context.requestTopic;
    var eligible = _eligibility.filterEligible(
      rules: rules,
      context: context,
      topicFilter: _topicFilterFor(topic),
    );

    // لا نُطلق كل قواعد العمر 45+ — نرتّب حسب الأولوية والموضوع
    eligible = _rankAndDedupe(eligible, topic, context);

    // استبعاد ما سبّق تسليمه إلا عند طلب المزيد
    if (!requestMore && session.deliveredRuleIds.isNotEmpty) {
      eligible = eligible
          .where((r) => !session.deliveredRuleIds.contains(r.ruleId))
          .toList(growable: false);
    }

    final limit = context.emotionalOverload
        ? maxSuggestionsUnderStress
        : maxSuggestions;

    final selected = eligible.take(limit).toList(growable: false);
    if (selected.isEmpty && !requestMore) {
      // fallback عام آمن
      final general = _eligibility.filterEligible(
        rules: rules,
        context: context.copyWithTopic(PreventiveGuidanceTopic.general),
      );
      final ranked = _rankAndDedupe(
        general,
        PreventiveGuidanceTopic.general,
        context,
      );
      final fallback = ranked
          .where((r) => !session.deliveredRuleIds.contains(r.ruleId))
          .take(limit)
          .toList(growable: false);
      if (fallback.isEmpty) return PreventiveGuidancePlan.empty;
      return PreventiveGuidancePlan(
        selectedRuleIds: fallback.map((r) => r.ruleId).toList(),
        personalizationLevel: _eligibility.highestLevel(fallback),
        topic: topic,
        hasMore: ranked.length > fallback.length,
        intent: context.intent,
      );
    }

    final hasMore = eligible.length > selected.length;

    return PreventiveGuidancePlan(
      selectedRuleIds: selected.map((r) => r.ruleId).toList(),
      personalizationLevel: _eligibility.highestLevel(selected),
      topic: topic,
      hasMore: hasMore,
      intent: context.intent,
    );
  }

  PreventiveGuidanceTopic? _topicFilterFor(PreventiveGuidanceTopic topic) {
    switch (topic) {
      case PreventiveGuidanceTopic.general:
      case PreventiveGuidanceTopic.ageAppropriate:
        return null;
      default:
        return topic;
    }
  }

  List<PreventiveGuidanceRule> _rankAndDedupe(
    List<PreventiveGuidanceRule> rules,
    PreventiveGuidanceTopic topic,
    PreventiveGuidanceContext context,
  ) {
    final seen = <PreventiveGuidanceType>{};
    final sorted = List<PreventiveGuidanceRule>.from(rules)
      ..sort((a, b) {
        final topicBoostA = a.topic == topic ? 10 : 0;
        final topicBoostB = b.topic == topic ? 10 : 0;
        return (b.priority + topicBoostB).compareTo(a.priority + topicBoostA);
      });

    final out = <PreventiveGuidanceRule>[];
    for (final r in sorted) {
      // لا تكرار نوع واحد في نفس الرد
      if (seen.contains(r.guidanceType)) continue;
      // age 45 لا يعني كل قواعد الفحص — فقط ما ينطبق
      if (context.computedAge != null &&
          context.computedAge! >= 45 &&
          r.ruleId == 'prev_screening_age_contextual' &&
          topic != PreventiveGuidanceTopic.screening &&
          topic != PreventiveGuidanceTopic.ageAppropriate) {
        continue;
      }
      seen.add(r.guidanceType);
      out.add(r);
    }
    return out;
  }
}

extension on PreventiveGuidanceContext {
  PreventiveGuidanceContext copyWithTopic(PreventiveGuidanceTopic t) {
    return PreventiveGuidanceContext(
      computedAge: computedAge,
      sexSelection: sexSelection,
      userContext: userContext,
      permittedConditionKeys: permittedConditionKeys,
      emotionalCategory: emotionalCategory,
      emotionalOverload: emotionalOverload,
      requestTopic: t,
      intent: intent,
      catalogAvailable: catalogAvailable,
    );
  }
}
