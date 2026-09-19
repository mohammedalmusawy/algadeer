/// PC-1.6 — دعم نفسي/عاطفي على مستوى الجلسة فقط.
///
/// ليس تشخيصاً نفسياً، وليس ملفاً دائماً، وليس علاجاً نفسياً.
library;

enum EmotionalSignalCategory {
  neutral,
  fear,
  worry,
  stress,
  examStress,
  sadness,
  frustration,
  healthAnxiety,
  procedureFear,
  resultAnxiety,
  overwhelmed,
  loneliness,
  unknownDistress,
}

enum EmotionalIntensity {
  mild,
  moderate,
  strong,
  unknown,
}

enum EmotionalSupportStrategy {
  none,
  acknowledgeCalmNextStep,
  reduceTaskSize,
  examOrganize,
  resultAnxietyNoPrediction,
  procedureCalmPrep,
  acknowledgeAndSolve,
  supportiveOptionalQuestion,
  oneThingAtATime,
  crisisSafety,
}

/// إشارة عاطفية منظمة — حالة محادثة، ليس تشخيصاً.
class EmotionalSignal {
  const EmotionalSignal({
    required this.category,
    this.intensity = EmotionalIntensity.unknown,
    this.aboutOtherPerson = false,
    this.hasTaskIntent = false,
  });

  final EmotionalSignalCategory category;
  final EmotionalIntensity intensity;
  final bool aboutOtherPerson;
  final bool hasTaskIntent;

  static const neutral = EmotionalSignal(
    category: EmotionalSignalCategory.neutral,
  );

  bool get isDistress =>
      category != EmotionalSignalCategory.neutral &&
      category != EmotionalSignalCategory.unknownDistress;

  Map<String, Object?> debugMap() => {
        'emotionalSignalPresent':
            category != EmotionalSignalCategory.neutral,
        'signalCategory': category.name,
        // بلا نص خام.
      };
}

/// سياق جلسة فقط — لا تخزين دائم.
class EmotionalSupportContext {
  const EmotionalSupportContext({
    this.signal = EmotionalSignal.neutral,
    this.strategy = EmotionalSupportStrategy.none,
    this.mentalSafetyTriggered = false,
    this.enabled = true,
  });

  final EmotionalSignal signal;
  final EmotionalSupportStrategy strategy;
  final bool mentalSafetyTriggered;

  /// تفعيل طبقة الدعم (جلسة).
  final bool enabled;

  static const inactive = EmotionalSupportContext(enabled: false);

  EmotionalSupportContext copyWith({
    EmotionalSignal? signal,
    EmotionalSupportStrategy? strategy,
    bool? mentalSafetyTriggered,
    bool? enabled,
  }) {
    return EmotionalSupportContext(
      signal: signal ?? this.signal,
      strategy: strategy ?? this.strategy,
      mentalSafetyTriggered:
          mentalSafetyTriggered ?? this.mentalSafetyTriggered,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> debugMap() => {
        ...signal.debugMap(),
        'supportStrategy': strategy.name,
        'mentalSafetyTriggered': mentalSafetyTriggered,
      };
}

class EmotionalSupportTurnResult {
  const EmotionalSupportTurnResult({
    required this.context,
    this.prefixMessage = '',
    this.standaloneMessage = '',
    this.crisis = false,
    this.askGentleClarification = false,
    this.textFirstOnly = true,
  });

  final EmotionalSupportContext context;
  final String prefixMessage;
  final String standaloneMessage;
  final bool crisis;
  final bool askGentleClarification;
  final bool textFirstOnly;

  bool get hasPrefix => prefixMessage.trim().isNotEmpty;
  bool get hasStandalone => standaloneMessage.trim().isNotEmpty;
}
