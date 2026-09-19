/// PC-1.7 — بيانات وصفية للمصدر والمراجعة — منفصلة عن العرض المحلي.
library;

import 'preventive_guidance_models.dart';

/// قاعدة توجيه وقائي مراجَعة — لا تُعدَّل من واجهة إدارية عشوائية.
class PreventiveGuidanceRule {
  const PreventiveGuidanceRule({
    required this.ruleId,
    required this.topic,
    required this.sourceOrganization,
    required this.sourceReference,
    required this.sourceVersionOrDate,
    required this.reviewedAt,
    required this.applicablePopulation,
    required this.guidanceType,
    required this.personalizationLevel,
    required this.presentationKey,
    this.minimumAge,
    this.maximumAge,
    this.requiredContext = const {},
    this.excludedContext = const {},
    this.requiredConditionKeys = const {},
    this.excludedConditionKeys = const {},
    this.priority = 50,
    this.isActive = true,
  });

  final String ruleId;
  final PreventiveGuidanceTopic topic;
  final String sourceOrganization;
  final String sourceReference;
  final String sourceVersionOrDate;
  final DateTime reviewedAt;
  final String applicablePopulation;
  final int? minimumAge;
  final int? maximumAge;
  final Set<String> requiredContext;
  final Set<String> excludedContext;
  final Set<String> requiredConditionKeys;
  final Set<String> excludedConditionKeys;
  final PreventiveGuidanceType guidanceType;
  final PreventivePersonalizationLevel personalizationLevel;
  final int priority;
  final bool isActive;

  /// مفتاح العرض المحلي — منفصل عن الدليل.
  final String presentationKey;

  Map<String, Object?> evidenceMap() => {
        'ruleId': ruleId,
        'topic': topic.name,
        'sourceOrganization': sourceOrganization,
        'sourceReference': sourceReference,
        'sourceVersionOrDate': sourceVersionOrDate,
        'reviewedAt': reviewedAt.toIso8601String(),
        'applicablePopulation': applicablePopulation,
        'guidanceType': guidanceType.name,
        'personalizationLevel': personalizationLevel.name,
        'priority': priority,
        'isActive': isActive,
      };
}
