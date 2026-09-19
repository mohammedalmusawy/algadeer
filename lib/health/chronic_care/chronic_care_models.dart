/// PC-1.5 — Chronic Care Companion (أساس عام، ليس دماغ مرض منفصل).

enum ChronicUserControlStatus {
  unknown,
  userReportsControlled,
  userReportsNotControlled,
  userReportsVariable,
}

enum ChronicMeasurementType {
  bloodGlucose,
  fastingGlucose,
  postMealGlucose,
  hba1c,
  bloodPressure,
}

enum ChronicMeasurementContext {
  unknown,
  fasting,
  postMeal,
  random,
  resting,
}

enum ChronicTimelineEventType {
  measurement,
  labFollowUp,
  doctorFollowUp,
  userStatusUpdate,
  followUpPreferenceChanged,
}

enum ChronicCareFlowStatus {
  inactive,
  offeringFollowUpPermission,
  awaitingPermissionAnswer,
  activeFollowUp,
  waitingForAnswer,
  paused,
  reducedPressure,
}

enum ChronicCareQuestionKind {
  recentStatus,
  lastMeasurement,
  lastFollowUp,
  controlStatus,
  doctorFollowUp,
  measurementContextClarification,
}

enum ChronicRelativeTiming {
  today,
  yesterday,
  aboutAWeekAgo,
  aboutAMonthAgo,
  aboutThreeMonthsAgo,
  unknown,
}

/// تعريف حالة مزمنة في السجل — قواعد وليس محرك محادثة منفصل.
class ChronicCareConditionDefinition {
  const ChronicCareConditionDefinition({
    required this.canonicalKey,
    required this.displayNameAr,
    required this.aliases,
    required this.supportedMeasurementTypes,
    required this.followUpQuestionOrder,
  });

  final String canonicalKey;
  final String displayNameAr;
  final List<String> aliases;
  final List<ChronicMeasurementType> supportedMeasurementTypes;
  final List<ChronicCareQuestionKind> followUpQuestionOrder;
}

/// قياس يبلّغ عنه المستخدم — بلا تفسير سريري.
class ChronicCareMeasurement {
  const ChronicCareMeasurement({
    required this.id,
    required this.conditionKey,
    required this.measurementType,
    required this.numericValues,
    this.unit,
    this.measurementContext = ChronicMeasurementContext.unknown,
    this.measuredAt,
    this.relativeTiming,
    required this.reportedAt,
    this.source = 'userReported',
    this.notesCategory,
    required this.createdAt,
  });

  final String id;
  final String conditionKey;
  final ChronicMeasurementType measurementType;

  /// لضغط الدم: [systolic, diastolic]. للسكر: [value].
  final List<double> numericValues;
  final String? unit;
  final ChronicMeasurementContext measurementContext;
  final DateTime? measuredAt;
  final ChronicRelativeTiming? relativeTiming;
  final DateTime reportedAt;
  final String source;
  final String? notesCategory;
  final DateTime createdAt;

  Map<String, Object?> toStorageMap() => {
        'id': id,
        'conditionKey': conditionKey,
        'measurementType': measurementType.name,
        'numericValues': numericValues,
        'unit': unit,
        'measurementContext': measurementContext.name,
        'measuredAt': measuredAt?.toIso8601String(),
        'relativeTiming': relativeTiming?.name,
        'reportedAt': reportedAt.toIso8601String(),
        'source': source,
        'notesCategory': notesCategory,
        'createdAt': createdAt.toIso8601String(),
      };

  static ChronicCareMeasurement? fromStorageMap(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final key = m['conditionKey']?.toString() ?? '';
    if (id.isEmpty || key.isEmpty) return null;
    ChronicMeasurementType type = ChronicMeasurementType.bloodGlucose;
    for (final v in ChronicMeasurementType.values) {
      if (v.name == m['measurementType']?.toString()) type = v;
    }
    ChronicMeasurementContext ctx = ChronicMeasurementContext.unknown;
    for (final v in ChronicMeasurementContext.values) {
      if (v.name == m['measurementContext']?.toString()) ctx = v;
    }
    ChronicRelativeTiming? rel;
    for (final v in ChronicRelativeTiming.values) {
      if (v.name == m['relativeTiming']?.toString()) rel = v;
    }
    final rawVals = m['numericValues'];
    final vals = <double>[];
    if (rawVals is List) {
      for (final x in rawVals) {
        if (x is num) vals.add(x.toDouble());
      }
    }
    DateTime reported;
    DateTime created;
    try {
      reported = DateTime.parse(m['reportedAt']?.toString() ?? '');
      created = DateTime.parse(m['createdAt']?.toString() ?? '');
    } catch (_) {
      return null;
    }
    DateTime? measured;
    final ma = m['measuredAt']?.toString();
    if (ma != null && ma.isNotEmpty) {
      try {
        measured = DateTime.parse(ma);
      } catch (_) {}
    }
    return ChronicCareMeasurement(
      id: id,
      conditionKey: key,
      measurementType: type,
      numericValues: vals,
      unit: m['unit']?.toString(),
      measurementContext: ctx,
      measuredAt: measured,
      relativeTiming: rel,
      reportedAt: reported,
      source: m['source']?.toString() ?? 'userReported',
      notesCategory: m['notesCategory']?.toString(),
      createdAt: created,
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'measurementTypePresent': measurementType.name,
        'hasNumericValues': numericValues.isNotEmpty,
        // بلا قيم.
      };
}

class ChronicCareTimelineEvent {
  const ChronicCareTimelineEvent({
    required this.id,
    required this.conditionKey,
    required this.type,
    required this.createdAt,
    this.measurementId,
    this.controlStatus,
    this.relativeTiming,
    this.occurredAt,
    this.categoryNote,
  });

  final String id;
  final String conditionKey;
  final ChronicTimelineEventType type;
  final DateTime createdAt;
  final String? measurementId;
  final ChronicUserControlStatus? controlStatus;
  final ChronicRelativeTiming? relativeTiming;
  final DateTime? occurredAt;

  /// فئة قصيرة فقط — ليس نص محادثة خام.
  final String? categoryNote;

  Map<String, Object?> toStorageMap() => {
        'id': id,
        'conditionKey': conditionKey,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'measurementId': measurementId,
        'controlStatus': controlStatus?.name,
        'relativeTiming': relativeTiming?.name,
        'occurredAt': occurredAt?.toIso8601String(),
        'categoryNote': categoryNote,
      };

  static ChronicCareTimelineEvent? fromStorageMap(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final key = m['conditionKey']?.toString() ?? '';
    if (id.isEmpty || key.isEmpty) return null;
    ChronicTimelineEventType type = ChronicTimelineEventType.userStatusUpdate;
    for (final v in ChronicTimelineEventType.values) {
      if (v.name == m['type']?.toString()) type = v;
    }
    ChronicUserControlStatus? ctrl;
    for (final v in ChronicUserControlStatus.values) {
      if (v.name == m['controlStatus']?.toString()) ctrl = v;
    }
    ChronicRelativeTiming? rel;
    for (final v in ChronicRelativeTiming.values) {
      if (v.name == m['relativeTiming']?.toString()) rel = v;
    }
    DateTime created;
    try {
      created = DateTime.parse(m['createdAt']?.toString() ?? '');
    } catch (_) {
      return null;
    }
    DateTime? occurred;
    final oa = m['occurredAt']?.toString();
    if (oa != null && oa.isNotEmpty) {
      try {
        occurred = DateTime.parse(oa);
      } catch (_) {}
    }
    return ChronicCareTimelineEvent(
      id: id,
      conditionKey: key,
      type: type,
      createdAt: created,
      measurementId: m['measurementId']?.toString(),
      controlStatus: ctrl,
      relativeTiming: rel,
      occurredAt: occurred,
      categoryNote: m['categoryNote']?.toString(),
    );
  }
}

/// حالة متابعة لكل حالة مزمنة — منفصلة عن سجل التشخيص.
class ChronicCareFollowUpState {
  const ChronicCareFollowUpState({
    required this.conditionKey,
    this.userControlStatus = ChronicUserControlStatus.unknown,
    this.lastAskedAt,
    this.lastAnsweredAt,
    this.lastSkippedAt,
    this.consecutiveSkips = 0,
    this.answeredQuestionKinds = const {},
    this.pendingQuestion,
    this.reducedPressure = false,
  });

  final String conditionKey;
  final ChronicUserControlStatus userControlStatus;
  final DateTime? lastAskedAt;
  final DateTime? lastAnsweredAt;
  final DateTime? lastSkippedAt;
  final int consecutiveSkips;
  final Set<String> answeredQuestionKinds;
  final ChronicCareQuestionKind? pendingQuestion;
  final bool reducedPressure;

  ChronicCareFollowUpState copyWith({
    ChronicUserControlStatus? userControlStatus,
    DateTime? lastAskedAt,
    DateTime? lastAnsweredAt,
    DateTime? lastSkippedAt,
    int? consecutiveSkips,
    Set<String>? answeredQuestionKinds,
    ChronicCareQuestionKind? pendingQuestion,
    bool? reducedPressure,
    bool clearPendingQuestion = false,
  }) {
    return ChronicCareFollowUpState(
      conditionKey: conditionKey,
      userControlStatus: userControlStatus ?? this.userControlStatus,
      lastAskedAt: lastAskedAt ?? this.lastAskedAt,
      lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
      lastSkippedAt: lastSkippedAt ?? this.lastSkippedAt,
      consecutiveSkips: consecutiveSkips ?? this.consecutiveSkips,
      answeredQuestionKinds:
          answeredQuestionKinds ?? this.answeredQuestionKinds,
      pendingQuestion: clearPendingQuestion
          ? null
          : (pendingQuestion ?? this.pendingQuestion),
      reducedPressure: reducedPressure ?? this.reducedPressure,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'conditionKey': conditionKey,
        'userControlStatus': userControlStatus.name,
        'lastAskedAt': lastAskedAt?.toIso8601String(),
        'lastAnsweredAt': lastAnsweredAt?.toIso8601String(),
        'lastSkippedAt': lastSkippedAt?.toIso8601String(),
        'consecutiveSkips': consecutiveSkips,
        'answeredQuestionKinds': answeredQuestionKinds.toList(),
        'pendingQuestion': pendingQuestion?.name,
        'reducedPressure': reducedPressure,
      };

  static ChronicCareFollowUpState? fromStorageMap(Map<String, dynamic> m) {
    final key = m['conditionKey']?.toString() ?? '';
    if (key.isEmpty) return null;
    ChronicUserControlStatus status = ChronicUserControlStatus.unknown;
    for (final v in ChronicUserControlStatus.values) {
      if (v.name == m['userControlStatus']?.toString()) status = v;
    }
    ChronicCareQuestionKind? pending;
    for (final v in ChronicCareQuestionKind.values) {
      if (v.name == m['pendingQuestion']?.toString()) pending = v;
    }
    DateTime? parse(String? s) {
      if (s == null || s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final answered = <String>{};
    final raw = m['answeredQuestionKinds'];
    if (raw is List) {
      for (final x in raw) {
        answered.add(x.toString());
      }
    }
    return ChronicCareFollowUpState(
      conditionKey: key,
      userControlStatus: status,
      lastAskedAt: parse(m['lastAskedAt']?.toString()),
      lastAnsweredAt: parse(m['lastAnsweredAt']?.toString()),
      lastSkippedAt: parse(m['lastSkippedAt']?.toString()),
      consecutiveSkips: (m['consecutiveSkips'] as num?)?.toInt() ?? 0,
      answeredQuestionKinds: answered,
      pendingQuestion: pending,
      reducedPressure: m['reducedPressure'] == true,
    );
  }
}

/// مخزن زمني محلي لصاحب الحساب فقط.
class ChronicCareStore {
  const ChronicCareStore({
    this.ownerKey = '',
    this.measurements = const [],
    this.timeline = const [],
    this.followUpByCondition = const {},
    this.updatedAt,
  });

  final String ownerKey;
  final List<ChronicCareMeasurement> measurements;
  final List<ChronicCareTimelineEvent> timeline;
  final Map<String, ChronicCareFollowUpState> followUpByCondition;
  final DateTime? updatedAt;

  static const empty = ChronicCareStore();

  ChronicCareStore copyWith({
    String? ownerKey,
    List<ChronicCareMeasurement>? measurements,
    List<ChronicCareTimelineEvent>? timeline,
    Map<String, ChronicCareFollowUpState>? followUpByCondition,
    DateTime? updatedAt,
  }) {
    return ChronicCareStore(
      ownerKey: ownerKey ?? this.ownerKey,
      measurements: measurements ?? this.measurements,
      timeline: timeline ?? this.timeline,
      followUpByCondition: followUpByCondition ?? this.followUpByCondition,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'ownerKey': ownerKey,
        'measurements': [for (final m in measurements) m.toStorageMap()],
        'timeline': [for (final e in timeline) e.toStorageMap()],
        'followUpByCondition': {
          for (final e in followUpByCondition.entries)
            e.key: e.value.toStorageMap(),
        },
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  static ChronicCareStore fromStorageMap(Map<String, dynamic> m) {
    final measurements = <ChronicCareMeasurement>[];
    final rawM = m['measurements'];
    if (rawM is List) {
      for (final item in rawM) {
        if (item is Map) {
          final parsed = ChronicCareMeasurement.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (parsed != null) measurements.add(parsed);
        }
      }
    }
    final timeline = <ChronicCareTimelineEvent>[];
    final rawT = m['timeline'];
    if (rawT is List) {
      for (final item in rawT) {
        if (item is Map) {
          final parsed = ChronicCareTimelineEvent.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (parsed != null) timeline.add(parsed);
        }
      }
    }
    final follow = <String, ChronicCareFollowUpState>{};
    final rawF = m['followUpByCondition'];
    if (rawF is Map) {
      rawF.forEach((k, v) {
        if (v is Map) {
          final parsed = ChronicCareFollowUpState.fromStorageMap(
            Map<String, dynamic>.from(v),
          );
          if (parsed != null) follow[k.toString()] = parsed;
        }
      });
    }
    return ChronicCareStore(
      ownerKey: m['ownerKey']?.toString() ?? '',
      measurements: List.unmodifiable(measurements),
      timeline: List.unmodifiable(timeline),
      followUpByCondition: Map.unmodifiable(follow),
      updatedAt: DateTime.tryParse(m['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'timelineEventCount': timeline.length,
        'measurementCountPresent': measurements.isNotEmpty,
        'followUpConditionCount': followUpByCondition.length,
        // بلا قيم حسّاسة.
      };
}

/// جلسة محادثة متابعة مزمنة (RAM + مؤشر تخزين).
class ChronicCareSession {
  const ChronicCareSession({
    this.status = ChronicCareFlowStatus.inactive,
    this.activeConditionKey,
    this.pendingPermissionConditionKey,
    this.pendingQuestion,
    this.awaitingMeasurementContext = false,
    this.draftGlucoseValue,
  });

  final ChronicCareFlowStatus status;
  final String? activeConditionKey;
  final String? pendingPermissionConditionKey;
  final ChronicCareQuestionKind? pendingQuestion;
  final bool awaitingMeasurementContext;
  final double? draftGlucoseValue;

  static const inactive = ChronicCareSession();

  bool get isActive =>
      status == ChronicCareFlowStatus.activeFollowUp ||
      status == ChronicCareFlowStatus.waitingForAnswer ||
      status == ChronicCareFlowStatus.awaitingPermissionAnswer ||
      status == ChronicCareFlowStatus.offeringFollowUpPermission;

  ChronicCareSession copyWith({
    ChronicCareFlowStatus? status,
    String? activeConditionKey,
    String? pendingPermissionConditionKey,
    ChronicCareQuestionKind? pendingQuestion,
    bool? awaitingMeasurementContext,
    double? draftGlucoseValue,
    bool clearActive = false,
    bool clearPendingPermission = false,
    bool clearPendingQuestion = false,
    bool clearDraftGlucose = false,
  }) {
    return ChronicCareSession(
      status: status ?? this.status,
      activeConditionKey:
          clearActive ? null : (activeConditionKey ?? this.activeConditionKey),
      pendingPermissionConditionKey: clearPendingPermission
          ? null
          : (pendingPermissionConditionKey ?? this.pendingPermissionConditionKey),
      pendingQuestion: clearPendingQuestion
          ? null
          : (pendingQuestion ?? this.pendingQuestion),
      awaitingMeasurementContext:
          awaitingMeasurementContext ?? this.awaitingMeasurementContext,
      draftGlucoseValue: clearDraftGlucose
          ? null
          : (draftGlucoseValue ?? this.draftGlucoseValue),
    );
  }

  Map<String, Object?> debugMap() => {
        'chronicFlowState': status.name,
        'hasActiveCondition': activeConditionKey != null,
        'hasPendingQuestion': pendingQuestion != null,
        'awaitingMeasurementContext': awaitingMeasurementContext,
        // بلا مفاتيح/قيم حسّاسة في السجلات العامة إن أمكن — نُبقي boolean فقط.
      };
}
