import '../sensitive_profile/sensitive_health_profile_models.dart';

/// PC-1.10 — سجل حالة صحية حسّاسة لشخص عائلة دائم.
///
/// الملكية: [persistentPersonId] فقط — لا اسم ولا علاقة.
class FamilyHealthConditionRecord {
  const FamilyHealthConditionRecord({
    required this.recordId,
    required this.persistentPersonId,
    required this.canonicalConditionKey,
    required this.displayName,
    required this.diagnosisStatus,
    required this.sourceType,
    required this.consentState,
    this.approximateSince,
    this.currentStatus = HealthConditionCurrentStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String recordId;
  final String persistentPersonId;
  final String canonicalConditionKey;
  final String displayName;
  final HealthDiagnosisStatus diagnosisStatus;
  final HealthDiagnosisSource sourceType;
  final HealthConsentState consentState;
  final String? approximateSince;
  final HealthConditionCurrentStatus currentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  bool get isPersistableEstablished =>
      diagnosisStatus == HealthDiagnosisStatus.diagnosed ||
      diagnosisStatus == HealthDiagnosisStatus.userReportedEstablished;

  FamilyHealthConditionRecord copyWith({
    String? displayName,
    HealthDiagnosisStatus? diagnosisStatus,
    HealthDiagnosisSource? sourceType,
    HealthConsentState? consentState,
    String? approximateSince,
    HealthConditionCurrentStatus? currentStatus,
    DateTime? updatedAt,
    bool clearApproximateSince = false,
  }) {
    return FamilyHealthConditionRecord(
      recordId: recordId,
      persistentPersonId: persistentPersonId,
      canonicalConditionKey: canonicalConditionKey,
      displayName: displayName ?? this.displayName,
      diagnosisStatus: diagnosisStatus ?? this.diagnosisStatus,
      sourceType: sourceType ?? this.sourceType,
      consentState: consentState ?? this.consentState,
      approximateSince: clearApproximateSince
          ? null
          : (approximateSince ?? this.approximateSince),
      currentStatus: currentStatus ?? this.currentStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'recordId': recordId,
        'persistentPersonId': persistentPersonId,
        'canonicalConditionKey': canonicalConditionKey,
        'displayName': displayName,
        'diagnosisStatus': diagnosisStatus.name,
        'sourceType': sourceType.name,
        'consentState': consentState.name,
        'approximateSince': approximateSince,
        'currentStatus': currentStatus.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  static FamilyHealthConditionRecord? fromStorageMap(Map<String, dynamic> m) {
    final id = m['recordId']?.toString() ?? '';
    final personId = m['persistentPersonId']?.toString() ?? '';
    final key = m['canonicalConditionKey']?.toString() ?? '';
    final name = m['displayName']?.toString() ?? '';
    if (id.isEmpty || personId.isEmpty || key.isEmpty || name.isEmpty) {
      return null;
    }

    HealthDiagnosisStatus status = HealthDiagnosisStatus.userReportedEstablished;
    for (final v in HealthDiagnosisStatus.values) {
      if (v.name == m['diagnosisStatus']?.toString()) status = v;
    }
    HealthDiagnosisSource source = HealthDiagnosisSource.selfReported;
    for (final v in HealthDiagnosisSource.values) {
      if (v.name == m['sourceType']?.toString() ||
          v.name == m['diagnosisSource']?.toString()) {
        source = v;
      }
    }
    HealthConditionCurrentStatus cur = HealthConditionCurrentStatus.active;
    for (final v in HealthConditionCurrentStatus.values) {
      if (v.name == m['currentStatus']?.toString()) cur = v;
    }
    HealthConsentState consent = HealthConsentState.granted;
    for (final v in HealthConsentState.values) {
      if (v.name == m['consentState']?.toString()) consent = v;
    }

    DateTime created;
    DateTime updated;
    try {
      created = DateTime.parse(m['createdAt']?.toString() ?? '');
      updated = DateTime.parse(m['updatedAt']?.toString() ?? '');
    } catch (_) {
      return null;
    }

    return FamilyHealthConditionRecord(
      recordId: id,
      persistentPersonId: personId,
      canonicalConditionKey: key,
      displayName: name,
      diagnosisStatus: status,
      sourceType: source,
      consentState: consent,
      approximateSince: m['approximateSince']?.toString(),
      currentStatus: cur,
      createdAt: created,
      updatedAt: updated,
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'hasFamilyConditionRecord': true,
        'consentState': consentState.name,
      };
}

/// ملف صحة حسّاس لشخص عائلة واحد (هوية منفصلة).
class FamilySensitiveHealthProfile {
  const FamilySensitiveHealthProfile({
    required this.persistentPersonId,
    this.conditions = const [],
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String persistentPersonId;
  final List<FamilyHealthConditionRecord> conditions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  /// خطافات مستقبلية فقط — غير منفّذة في PC-1.10.
  List<Never> get chronicCarePlaceholder => const [];
  List<Never> get measurementsPlaceholder => const [];
  List<Never> get medicationsPlaceholder => const [];
  List<Never> get allergiesPlaceholder => const [];
  List<Never> get followUpPermissionPlaceholder => const [];

  FamilySensitiveHealthProfile copyWith({
    List<FamilyHealthConditionRecord>? conditions,
    DateTime? updatedAt,
  }) {
    return FamilySensitiveHealthProfile(
      persistentPersonId: persistentPersonId,
      conditions: conditions ?? this.conditions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'persistentPersonId': persistentPersonId,
        'conditions': [for (final c in conditions) c.toStorageMap()],
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  static FamilySensitiveHealthProfile? fromStorageMap(Map<String, dynamic> m) {
    final personId = m['persistentPersonId']?.toString() ?? '';
    if (personId.isEmpty) return null;
    DateTime created;
    DateTime updated;
    try {
      created = DateTime.parse(m['createdAt']?.toString() ?? '');
      updated = DateTime.parse(m['updatedAt']?.toString() ?? '');
    } catch (_) {
      return null;
    }
    final list = <FamilyHealthConditionRecord>[];
    final raw = m['conditions'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final rec = FamilyHealthConditionRecord.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (rec != null) list.add(rec);
        }
      }
    }
    return FamilySensitiveHealthProfile(
      persistentPersonId: personId,
      conditions: List.unmodifiable(list),
      createdAt: created,
      updatedAt: updated,
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'familyHealthProfileLoaded': true,
        'recordCount': conditions.length,
      };
}

/// مخزن محلي لكل الأشخاص — مفصول عن ملف المالك الصحي.
class FamilySensitiveHealthStore {
  const FamilySensitiveHealthStore({
    required this.ownerKey,
    this.profiles = const {},
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String ownerKey;
  final Map<String, FamilySensitiveHealthProfile> profiles;
  final int schemaVersion;

  int get totalRecordCount {
    var n = 0;
    for (final p in profiles.values) {
      n += p.conditions.length;
    }
    return n;
  }

  List<String> get personIdsWithHealth =>
      profiles.entries.where((e) => e.value.conditions.isNotEmpty).map((e) => e.key).toList();

  FamilySensitiveHealthStore copyWith({
    Map<String, FamilySensitiveHealthProfile>? profiles,
  }) {
    return FamilySensitiveHealthStore(
      ownerKey: ownerKey,
      profiles: profiles ?? this.profiles,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'ownerKey': ownerKey,
        'schemaVersion': schemaVersion,
        'profiles': {
          for (final e in profiles.entries) e.key: e.value.toStorageMap(),
        },
      };

  static FamilySensitiveHealthStore? fromStorageMap(Map<String, dynamic> m) {
    final owner = m['ownerKey']?.toString() ?? '';
    if (owner.isEmpty) return null;
    final map = <String, FamilySensitiveHealthProfile>{};
    final raw = m['profiles'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final key = e.key.toString();
        if (e.value is Map) {
          final p = FamilySensitiveHealthProfile.fromStorageMap(
            Map<String, dynamic>.from(e.value as Map),
          );
          if (p != null) map[key] = p;
        }
      }
    }
    return FamilySensitiveHealthStore(
      ownerKey: owner,
      profiles: Map.unmodifiable(map),
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'familyHealthStoreLoaded': true,
        'recordCount': totalRecordCount,
        'personCountWithHealth': personIdsWithHealth.length,
      };
}
