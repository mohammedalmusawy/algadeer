/// PC-1.11 — أساس المتابعة والالتزامات الموحّد.
///
/// MEMORY ≠ PERMISSION ≠ COMMITMENT ≠ SCHEDULE ≠ NOTIFICATION

enum FollowUpSubjectKind {
  accountOwner,
  persistentPerson,
}

/// مرجع موضوع الالتزام — personId سلطوي للعائلة.
class FollowUpSubjectRef {
  const FollowUpSubjectRef._({
    required this.kind,
    this.persistentPersonId,
  });

  final FollowUpSubjectKind kind;
  final String? persistentPersonId;

  static const accountOwner = FollowUpSubjectRef._(
    kind: FollowUpSubjectKind.accountOwner,
  );

  factory FollowUpSubjectRef.persistentPerson(String personId) {
    assert(personId.isNotEmpty);
    return FollowUpSubjectRef._(
      kind: FollowUpSubjectKind.persistentPerson,
      persistentPersonId: personId,
    );
  }

  bool get isAccountOwner => kind == FollowUpSubjectKind.accountOwner;

  bool matches(FollowUpSubjectRef other) {
    if (kind != other.kind) return false;
    if (kind == FollowUpSubjectKind.accountOwner) return true;
    return persistentPersonId != null &&
        persistentPersonId == other.persistentPersonId;
  }

  Map<String, Object?> toStorageMap() => {
        'kind': kind.name,
        'persistentPersonId': persistentPersonId,
      };

  static FollowUpSubjectRef? fromStorageMap(Map<String, dynamic> m) {
    final k = m['kind']?.toString() ?? '';
    if (k == FollowUpSubjectKind.accountOwner.name) {
      return FollowUpSubjectRef.accountOwner;
    }
    if (k == FollowUpSubjectKind.persistentPerson.name) {
      final id = m['persistentPersonId']?.toString() ?? '';
      if (id.isEmpty) return null;
      return FollowUpSubjectRef.persistentPerson(id);
    }
    return null;
  }

  Map<String, Object?> debugMap() => {
        'subjectKind': kind.name,
        'hasPersistentPerson': persistentPersonId != null,
        // بلا personId.
      };
}

enum FollowUpDomain {
  chronicHealth,
  healthCheck,
  doctorVisit,
  labResult,
  labTest,
  preventive,
  personalGoal,
  generalCommitment,
}

enum FollowUpStatus {
  active,
  paused,
  completed,
  cancelled,
}

enum FollowUpPermissionState {
  none,
  pending,
  granted,
  declined,
  revoked,
}

enum FollowUpTimingIntent {
  later,
  tomorrow,
  afterAWeek,
  nextVisit,
  whenUserReturns,
  whenResultAvailable,
  customDate,
  unspecified,
}

enum FollowUpSourceType {
  explicitUserCommand,
  chronicCareOptIn,
  draftFromMemory,
  unknown,
}

/// التزام متابعة موحّد — منفصل عن الذاكرة والتشخيص.
class FollowUpCommitment {
  const FollowUpCommitment({
    required this.commitmentId,
    required this.subjectRef,
    required this.domain,
    required this.topicKey,
    required this.status,
    required this.permissionState,
    required this.createdAt,
    required this.updatedAt,
    this.displayTopic = '',
    this.lastAskedAt,
    this.lastAnsweredAt,
    this.lastSkippedAt,
    this.consecutiveSkips = 0,
    this.notBeforeAt,
    this.dueWindow,
    this.timingIntent = FollowUpTimingIntent.unspecified,
    this.sourceType = FollowUpSourceType.unknown,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String commitmentId;
  final FollowUpSubjectRef subjectRef;
  final FollowUpDomain domain;
  final String topicKey;
  final FollowUpStatus status;
  final FollowUpPermissionState permissionState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String displayTopic;
  final DateTime? lastAskedAt;
  final DateTime? lastAnsweredAt;
  final DateTime? lastSkippedAt;
  final int consecutiveSkips;
  final DateTime? notBeforeAt;
  final String? dueWindow;
  final FollowUpTimingIntent timingIntent;
  final FollowUpSourceType sourceType;
  final int schemaVersion;

  bool get isActiveFollowUp =>
      status == FollowUpStatus.active &&
      permissionState == FollowUpPermissionState.granted;

  FollowUpCommitment copyWith({
    FollowUpStatus? status,
    FollowUpPermissionState? permissionState,
    String? displayTopic,
    DateTime? updatedAt,
    DateTime? lastAskedAt,
    DateTime? lastAnsweredAt,
    DateTime? lastSkippedAt,
    int? consecutiveSkips,
    DateTime? notBeforeAt,
    String? dueWindow,
    FollowUpTimingIntent? timingIntent,
    bool clearLastAsked = false,
    bool clearNotBefore = false,
  }) {
    return FollowUpCommitment(
      commitmentId: commitmentId,
      subjectRef: subjectRef,
      domain: domain,
      topicKey: topicKey,
      status: status ?? this.status,
      permissionState: permissionState ?? this.permissionState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayTopic: displayTopic ?? this.displayTopic,
      lastAskedAt: clearLastAsked ? null : (lastAskedAt ?? this.lastAskedAt),
      lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
      lastSkippedAt: lastSkippedAt ?? this.lastSkippedAt,
      consecutiveSkips: consecutiveSkips ?? this.consecutiveSkips,
      notBeforeAt: clearNotBefore ? null : (notBeforeAt ?? this.notBeforeAt),
      dueWindow: dueWindow ?? this.dueWindow,
      timingIntent: timingIntent ?? this.timingIntent,
      sourceType: sourceType,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'commitmentId': commitmentId,
        'subjectRef': subjectRef.toStorageMap(),
        'domain': domain.name,
        'topicKey': topicKey,
        'status': status.name,
        'permissionState': permissionState.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'displayTopic': displayTopic,
        'lastAskedAt': lastAskedAt?.toIso8601String(),
        'lastAnsweredAt': lastAnsweredAt?.toIso8601String(),
        'lastSkippedAt': lastSkippedAt?.toIso8601String(),
        'consecutiveSkips': consecutiveSkips,
        'notBeforeAt': notBeforeAt?.toIso8601String(),
        'dueWindow': dueWindow,
        'timingIntent': timingIntent.name,
        'sourceType': sourceType.name,
        'schemaVersion': schemaVersion,
      };

  static FollowUpCommitment? fromStorageMap(Map<String, dynamic> m) {
    final id = m['commitmentId']?.toString() ?? '';
    final topic = m['topicKey']?.toString() ?? '';
    if (id.isEmpty || topic.isEmpty) return null;
    final subRaw = m['subjectRef'];
    if (subRaw is! Map) return null;
    final subject = FollowUpSubjectRef.fromStorageMap(
      Map<String, dynamic>.from(subRaw),
    );
    if (subject == null) return null;

    FollowUpDomain domain = FollowUpDomain.generalCommitment;
    for (final v in FollowUpDomain.values) {
      if (v.name == m['domain']?.toString()) domain = v;
    }
    FollowUpStatus status = FollowUpStatus.active;
    for (final v in FollowUpStatus.values) {
      if (v.name == m['status']?.toString()) status = v;
    }
    FollowUpPermissionState perm = FollowUpPermissionState.none;
    for (final v in FollowUpPermissionState.values) {
      if (v.name == m['permissionState']?.toString()) perm = v;
    }
    FollowUpTimingIntent timing = FollowUpTimingIntent.unspecified;
    for (final v in FollowUpTimingIntent.values) {
      if (v.name == m['timingIntent']?.toString()) timing = v;
    }
    FollowUpSourceType source = FollowUpSourceType.unknown;
    for (final v in FollowUpSourceType.values) {
      if (v.name == m['sourceType']?.toString()) source = v;
    }

    DateTime? parse(Object? s) {
      if (s == null) return null;
      try {
        return DateTime.parse(s.toString());
      } catch (_) {
        return null;
      }
    }

    final created = parse(m['createdAt']);
    final updated = parse(m['updatedAt']);
    if (created == null || updated == null) return null;

    return FollowUpCommitment(
      commitmentId: id,
      subjectRef: subject,
      domain: domain,
      topicKey: topic,
      status: status,
      permissionState: perm,
      createdAt: created,
      updatedAt: updated,
      displayTopic: m['displayTopic']?.toString() ?? '',
      lastAskedAt: parse(m['lastAskedAt']),
      lastAnsweredAt: parse(m['lastAnsweredAt']),
      lastSkippedAt: parse(m['lastSkippedAt']),
      consecutiveSkips: (m['consecutiveSkips'] as num?)?.toInt() ?? 0,
      notBeforeAt: parse(m['notBeforeAt']),
      dueWindow: m['dueWindow']?.toString(),
      timingIntent: timing,
      sourceType: source,
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugMap() => {
        'followUpDomain': domain.name,
        'status': status.name,
        'permissionState': permissionState.name,
        ...subjectRef.debugMap(),
        'consecutiveSkips': consecutiveSkips,
        // بلا topic/personId/محتوى.
      };
}

/// مخزن محلي لكل الالتزامات.
class FollowUpStore {
  const FollowUpStore({
    required this.ownerKey,
    this.commitments = const [],
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String ownerKey;
  final List<FollowUpCommitment> commitments;
  final int schemaVersion;

  FollowUpStore copyWith({List<FollowUpCommitment>? commitments}) {
    return FollowUpStore(
      ownerKey: ownerKey,
      commitments: commitments ?? this.commitments,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'ownerKey': ownerKey,
        'schemaVersion': schemaVersion,
        'commitments': [for (final c in commitments) c.toStorageMap()],
      };

  static FollowUpStore? fromStorageMap(Map<String, dynamic> m) {
    final owner = m['ownerKey']?.toString() ?? '';
    if (owner.isEmpty) return null;
    final list = <FollowUpCommitment>[];
    final raw = m['commitments'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final c = FollowUpCommitment.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (c != null) list.add(c);
        }
      }
    }
    return FollowUpStore(
      ownerKey: owner,
      commitments: List.unmodifiable(list),
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugMap() => {
        'followUpStoreLoaded': true,
        'commitmentCount': commitments.length,
      };
}
