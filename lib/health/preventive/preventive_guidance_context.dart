import '../../companion/personal_companion_profile.dart';
import '../emotional_support/emotional_support_models.dart';
import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'preventive_guidance_models.dart';

/// سياق توجيه وقائي — يُبنى من مصادر مسموحة فقط.
class PreventiveGuidanceContext {
  const PreventiveGuidanceContext({
    this.computedAge,
    this.sexSelection,
    this.userContext,
    this.permittedConditionKeys = const {},
    this.emotionalCategory = EmotionalSignalCategory.neutral,
    this.emotionalOverload = false,
    this.requestTopic = PreventiveGuidanceTopic.general,
    this.intent = PreventiveIntent.none,
    this.catalogAvailable = true,
  });

  final int? computedAge;
  final ProfileSexSelection? sexSelection;
  final ProfileUserContext? userContext;
  final Set<String> permittedConditionKeys;
  final EmotionalSignalCategory emotionalCategory;
  final bool emotionalOverload;
  final PreventiveGuidanceTopic requestTopic;
  final PreventiveIntent intent;
  final bool catalogAvailable;

  bool get hasKnownAge => computedAge != null;
  bool get isStudent => userContext == ProfileUserContext.student;
  bool get isEmployee => userContext == ProfileUserContext.employee;
  bool get isSelfEmployed => userContext == ProfileUserContext.selfEmployed;

  bool hasCondition(String key) => permittedConditionKeys.contains(key);

  Set<String> contextTags() {
    final tags = <String>{};
    if (isStudent) tags.add('student');
    if (isEmployee) tags.add('employee');
    if (isSelfEmployed) tags.add('selfEmployed');
    if (hasKnownAge) tags.add('knownAge');
    if (permittedConditionKeys.isNotEmpty) tags.add('healthContext');
    return tags;
  }

  /// بلا عمر/حالات في الخرج.
  Map<String, Object?> debugMap() => {
        'preventiveIntent': intent.name,
        'guidanceTopic': requestTopic.name,
        'hasKnownAge': hasKnownAge,
        'hasHealthContext': permittedConditionKeys.isNotEmpty,
        'emotionalOverload': emotionalOverload,
        'catalogAvailable': catalogAvailable,
      };
}

/// يبني السياق من ملف مرفق + حالات مسموحة.
class PreventiveGuidanceContextBuilder {
  const PreventiveGuidanceContextBuilder();

  PreventiveGuidanceContext build({
    PersonalCompanionProfile? profile,
    List<HealthConditionRecord> permittedConditions = const [],
    EmotionalSignalCategory emotionalCategory =
        EmotionalSignalCategory.neutral,
    PreventiveGuidanceTopic requestTopic = PreventiveGuidanceTopic.general,
    PreventiveIntent intent = PreventiveIntent.none,
    bool catalogAvailable = true,
    DateTime? now,
  }) {
    final overload = emotionalCategory == EmotionalSignalCategory.overwhelmed ||
        emotionalCategory == EmotionalSignalCategory.examStress ||
        emotionalCategory == EmotionalSignalCategory.stress;

    final keys = permittedConditions
        .map((c) => c.canonicalConditionKey)
        .toSet();

    return PreventiveGuidanceContext(
      computedAge: profile?.currentAge(now: now),
      sexSelection: profile?.sexSelection,
      userContext: profile?.userContext,
      permittedConditionKeys: keys,
      emotionalCategory: emotionalCategory,
      emotionalOverload: overload,
      requestTopic: requestTopic,
      intent: intent,
      catalogAvailable: catalogAvailable,
    );
  }
}
