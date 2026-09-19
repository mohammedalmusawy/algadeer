import 'preventive_evidence_metadata.dart';
import 'preventive_guidance_context.dart';
import 'preventive_guidance_models.dart';

/// أهلية القواعد — لا if(age>=45) في الواجهة.
class PreventiveGuidanceEligibility {
  const PreventiveGuidanceEligibility();

  bool isEligible({
    required PreventiveGuidanceRule rule,
    required PreventiveGuidanceContext context,
  }) {
    if (!rule.isActive) return false;

    // العمر: لا نخترع عمراً — نفلتر فقط إذا العمر معروف
    final ageRequiredTopic =
        context.requestTopic == PreventiveGuidanceTopic.ageAppropriate ||
            context.requestTopic == PreventiveGuidanceTopic.screening;
    if (ageRequiredTopic && context.computedAge == null) {
      return false;
    }
    if (rule.minimumAge != null && context.computedAge != null) {
      if (context.computedAge! < rule.minimumAge!) return false;
    }
    if (rule.maximumAge != null && context.computedAge != null) {
      if (context.computedAge! > rule.maximumAge!) return false;
    }

    // سياق المستخدم
    final tags = context.contextTags();
    if (rule.requiredContext.isNotEmpty) {
      if (!rule.requiredContext.every(tags.contains)) return false;
    }
    if (rule.excludedContext.isNotEmpty) {
      if (rule.excludedContext.any(tags.contains)) return false;
    }

    // حالات مسموحة فقط
    if (rule.requiredConditionKeys.isNotEmpty) {
      if (!rule.requiredConditionKeys
          .every(context.permittedConditionKeys.contains)) {
        return false;
      }
    }
    if (rule.excludedConditionKeys.isNotEmpty) {
      if (rule.excludedConditionKeys
          .any(context.permittedConditionKeys.contains)) {
        return false;
      }
    }

    return true;
  }

  List<PreventiveGuidanceRule> filterEligible({
    required List<PreventiveGuidanceRule> rules,
    required PreventiveGuidanceContext context,
    PreventiveGuidanceTopic? topicFilter,
  }) {
    return rules.where((r) {
      if (topicFilter != null &&
          r.topic != topicFilter &&
          topicFilter != PreventiveGuidanceTopic.general &&
          topicFilter != PreventiveGuidanceTopic.ageAppropriate) {
        // ageAppropriate يشمل bp_awareness و screening
        if (topicFilter == PreventiveGuidanceTopic.ageAppropriate &&
            r.topic != PreventiveGuidanceTopic.ageAppropriate &&
            r.topic != PreventiveGuidanceTopic.screening) {
          return false;
        } else if (topicFilter != PreventiveGuidanceTopic.ageAppropriate) {
          return false;
        }
      }
      return isEligible(rule: r, context: context);
    }).toList(growable: false);
  }

  PreventivePersonalizationLevel highestLevel(
    List<PreventiveGuidanceRule> rules,
  ) {
    if (rules.any((r) =>
        r.personalizationLevel ==
        PreventivePersonalizationLevel.clinicianRequired)) {
      return PreventivePersonalizationLevel.clinicianRequired;
    }
    if (rules.any((r) =>
        r.personalizationLevel ==
        PreventivePersonalizationLevel.healthContextual)) {
      return PreventivePersonalizationLevel.healthContextual;
    }
    if (rules.any((r) =>
        r.personalizationLevel == PreventivePersonalizationLevel.contextual)) {
      return PreventivePersonalizationLevel.contextual;
    }
    return PreventivePersonalizationLevel.general;
  }
}
