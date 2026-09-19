/// PC-1.15 — سياق يومي قصير الأمد (جلسة)، بلا دفتر دائم.
library;

enum DailyContextCategory {
  sleep,
  energy,
  stressLoad,
  study,
  exam,
  work,
  scheduleLoad,
  activity,
  restNeed,
  healthConcern,
  emotionalState,
  personalPriority,
  unknownDailyContext,
}

enum DailyContextTiming {
  today,
  yesterday,
  tonight,
  tomorrow,
  thisMorning,
  thisAfternoon,
  thisEvening,
  thisWeek,
  currentPeriod,
  unknown,
}

enum DailyContextSubjectKind {
  accountOwner,
  otherPerson,
  unknown,
}

enum DailyContextPriority {
  urgentMedicalSafety,
  mentalHealthSafety,
  activeHealthConcern,
  immediateFunctionalNeed,
  restSleepNeed,
  explicitUserGoal,
  emotionalLoad,
  activityWellness,
  lowerOptimization,
  none,
}

enum DailyContextConfidence {
  explicitUserReport,
  clarified,
  unknown,
}

/// إشارة سياق يومي — ليست تشخيصاً ولا سمة شخصية.
class DailyContextSignal {
  const DailyContextSignal({
    required this.category,
    required this.state,
    required this.timing,
    this.source = 'userReported',
    this.subject = DailyContextSubjectKind.accountOwner,
    this.confidence = DailyContextConfidence.explicitUserReport,
    required this.createdAt,
    required this.expiresAt,
  });

  final DailyContextCategory category;
  final String state;
  final DailyContextTiming timing;
  final String source;
  final DailyContextSubjectKind subject;
  final DailyContextConfidence confidence;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isExpired([DateTime? now]) =>
      (now ?? DateTime.now()).isAfter(expiresAt);

  DailyContextSignal copyWith({
    String? state,
    DailyContextTiming? timing,
    DateTime? expiresAt,
  }) {
    return DailyContextSignal(
      category: category,
      state: state ?? this.state,
      timing: timing ?? this.timing,
      source: source,
      subject: subject,
      confidence: confidence,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, Object?> debugMap() => {
        'category': category.name,
        'timing': timing.name,
        'subjectKind': subject.name,
        'expired': isExpired(),
        // بلا قيم نوم/مزاج/امتحان نصية.
      };
}

/// مخزن جلسة لإشارات اليوم — RAM فقط.
class DailyLifeContext {
  const DailyLifeContext({
    this.signals = const [],
    this.lastPriority = DailyContextPriority.none,
    this.hasHighLoad = false,
    this.deferFollowUpSurfacing = false,
    this.explicitFocusCategory,
    this.updatedAt,
  });

  final List<DailyContextSignal> signals;
  final DailyContextPriority lastPriority;
  final bool hasHighLoad;
  final bool deferFollowUpSurfacing;
  final DailyContextCategory? explicitFocusCategory;
  final DateTime? updatedAt;

  static const empty = DailyLifeContext();

  bool get isEmpty => signals.isEmpty;

  List<DailyContextSignal> activeSignals([DateTime? now]) => signals
      .where((s) => !s.isExpired(now))
      .toList(growable: false);

  DailyLifeContext copyWith({
    List<DailyContextSignal>? signals,
    DailyContextPriority? lastPriority,
    bool? hasHighLoad,
    bool? deferFollowUpSurfacing,
    DailyContextCategory? explicitFocusCategory,
    bool clearExplicitFocus = false,
    DateTime? updatedAt,
  }) {
    return DailyLifeContext(
      signals: signals ?? this.signals,
      lastPriority: lastPriority ?? this.lastPriority,
      hasHighLoad: hasHighLoad ?? this.hasHighLoad,
      deferFollowUpSurfacing:
          deferFollowUpSurfacing ?? this.deferFollowUpSurfacing,
      explicitFocusCategory: clearExplicitFocus
          ? null
          : (explicitFocusCategory ?? this.explicitFocusCategory),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> debugMap() => {
        'dailySignalCount': activeSignals().length,
        'dailyCategories': [
          for (final s in activeSignals()) s.category.name,
        ],
        'priorityCategory': lastPriority.name,
        'hasHighLoad': hasHighLoad,
        'subjectKind': activeSignals().isEmpty
            ? DailyContextSubjectKind.unknown.name
            : activeSignals().first.subject.name,
        'contextUpdated': updatedAt != null,
        'contextExpired': activeSignals().isEmpty && signals.isNotEmpty,
        // بلا ساعات نوم / تفاصيل امتحان / مدد.
      };
}

/// عقود مستقبلية — غير مفعّلة.
class DailyCompanionContract {
  const DailyCompanionContract();
  bool get morningCheckInEnabled => false;
  bool get eveningReflectionEnabled => false;
  bool get dailyPlanFeatureEnabled => false;
  bool get calendarIntegrationEnabled => false;
  bool get appleHealthIntegrationEnabled => false;
  bool get wearableIntegrationEnabled => false;
}

abstract class DailyPlan {
  String get planId;
}

abstract class MorningCheckIn {
  String get checkInId;
}

abstract class EveningReflection {
  String get reflectionId;
}
