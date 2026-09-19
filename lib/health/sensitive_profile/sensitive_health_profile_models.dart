/// PC-1.4 — ملف الصحة الحسّاس (منفصل عن PersonalCompanionProfile).
///
/// لا تشخيص طبي، لا توصية دواء، لا متابعة مزمنة في هذه الخطوة.

enum HealthDiagnosisStatus {
  diagnosed,
  userReportedEstablished,
  uncertain,
  symptomOnly,
}

enum HealthDiagnosisSource {
  clinicianAttributed,
  selfReported,
  observation,
  unknown,
}

enum HealthConditionCurrentStatus {
  active,
  historical,
  unknown,
}

enum HealthConsentState {
  none,
  pending,
  granted,
  declined,
  revoked,
}

/// مفاتيح حالات مستقبلية جاهزة — بدون محرك متابعة في PC-1.4.
enum HealthCanonicalConditionKey {
  diabetes,
  hypertension,
  asthma,
  other,
}

/// سجل حالة صحية واحدة — جاهز للتمديد (قياسات/متابعة لاحقاً).
class HealthConditionRecord {
  const HealthConditionRecord({
    required this.id,
    required this.canonicalConditionKey,
    required this.displayName,
    required this.diagnosisStatus,
    required this.diagnosisSource,
    this.approximateSince,
    this.currentStatus = HealthConditionCurrentStatus.active,
    this.consentState = HealthConsentState.granted,
    required this.createdAt,
    required this.updatedAt,
    this.followUpPermission = false,
    // —— خطافات مستقبلية فقط (غير مفعّلة) ——
    this.lastMeasurement,
    this.lastLabFollowUp,
    this.controlStatus,
    this.followUpPreference,
    this.followUpSchedule,
  });

  final String id;
  final String canonicalConditionKey;
  final String displayName;
  final HealthDiagnosisStatus diagnosisStatus;
  final HealthDiagnosisSource diagnosisSource;
  final String? approximateSince;
  final HealthConditionCurrentStatus currentStatus;
  final HealthConsentState consentState;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// موافقة التذكّر ≠ موافقة المتابعة الاستباقية.
  final bool followUpPermission;

  /// خطافات PC لاحقة — لا تُستخدم في PC-1.4.
  final String? lastMeasurement;
  final String? lastLabFollowUp;
  final String? controlStatus;
  final String? followUpPreference;
  final String? followUpSchedule;

  bool get isPersistableEstablished =>
      diagnosisStatus == HealthDiagnosisStatus.diagnosed ||
      diagnosisStatus == HealthDiagnosisStatus.userReportedEstablished;

  HealthConditionRecord copyWith({
    String? displayName,
    HealthDiagnosisStatus? diagnosisStatus,
    HealthDiagnosisSource? diagnosisSource,
    String? approximateSince,
    HealthConditionCurrentStatus? currentStatus,
    HealthConsentState? consentState,
    DateTime? updatedAt,
    bool? followUpPermission,
    bool clearApproximateSince = false,
  }) {
    return HealthConditionRecord(
      id: id,
      canonicalConditionKey: canonicalConditionKey,
      displayName: displayName ?? this.displayName,
      diagnosisStatus: diagnosisStatus ?? this.diagnosisStatus,
      diagnosisSource: diagnosisSource ?? this.diagnosisSource,
      approximateSince:
          clearApproximateSince ? null : (approximateSince ?? this.approximateSince),
      currentStatus: currentStatus ?? this.currentStatus,
      consentState: consentState ?? this.consentState,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      followUpPermission: followUpPermission ?? this.followUpPermission,
      lastMeasurement: lastMeasurement,
      lastLabFollowUp: lastLabFollowUp,
      controlStatus: controlStatus,
      followUpPreference: followUpPreference,
      followUpSchedule: followUpSchedule,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'id': id,
        'canonicalConditionKey': canonicalConditionKey,
        'displayName': displayName,
        'diagnosisStatus': diagnosisStatus.name,
        'diagnosisSource': diagnosisSource.name,
        'approximateSince': approximateSince,
        'currentStatus': currentStatus.name,
        'consentState': consentState.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'followUpPermission': followUpPermission,
        // خطافات مستقبلية — تُحفظ فارغة إن وُجدت لاحقاً
        'lastMeasurement': lastMeasurement,
        'lastLabFollowUp': lastLabFollowUp,
        'controlStatus': controlStatus,
        'followUpPreference': followUpPreference,
        'followUpSchedule': followUpSchedule,
      };

  static HealthConditionRecord? fromStorageMap(Map<String, dynamic> m) {
    final id = m['id']?.toString() ?? '';
    final key = m['canonicalConditionKey']?.toString() ?? '';
    final name = m['displayName']?.toString() ?? '';
    if (id.isEmpty || key.isEmpty || name.isEmpty) return null;

    HealthDiagnosisStatus status = HealthDiagnosisStatus.userReportedEstablished;
    for (final v in HealthDiagnosisStatus.values) {
      if (v.name == m['diagnosisStatus']?.toString()) status = v;
    }
    HealthDiagnosisSource source = HealthDiagnosisSource.selfReported;
    for (final v in HealthDiagnosisSource.values) {
      if (v.name == m['diagnosisSource']?.toString()) source = v;
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

    return HealthConditionRecord(
      id: id,
      canonicalConditionKey: key,
      displayName: name,
      diagnosisStatus: status,
      diagnosisSource: source,
      approximateSince: m['approximateSince']?.toString(),
      currentStatus: cur,
      consentState: consent,
      createdAt: created,
      updatedAt: updated,
      followUpPermission: m['followUpPermission'] == true,
      lastMeasurement: m['lastMeasurement']?.toString(),
      lastLabFollowUp: m['lastLabFollowUp']?.toString(),
      controlStatus: m['controlStatus']?.toString(),
      followUpPreference: m['followUpPreference']?.toString(),
      followUpSchedule: m['followUpSchedule']?.toString(),
    );
  }

  /// حضور فقط — بلا أسماء حالات في الخرج العام.
  Map<String, Object?> debugPresenceMap() => {
        'hasConditionRecord': true,
        'consentState': consentState.name,
        'followUpPermission': followUpPermission,
      };
}

/// ملف الصحة الحسّاس لصاحب الحساب فقط.
class SensitiveHealthProfile {
  const SensitiveHealthProfile({
    required this.profileId,
    required this.ownerKey,
    this.conditions = const [],
    this.healthPersonalizationEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String profileId;
  final String ownerKey;
  final List<HealthConditionRecord> conditions;
  final bool healthPersonalizationEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  /// خطافات أنواع مستقبلية (حدود نظيفة فقط).
  /// allergies / medications / procedures — غير مُنفَّذة في PC-1.4.
  List<Never> get allergiesPlaceholder => const [];
  List<Never> get medicationsPlaceholder => const [];
  List<Never> get proceduresPlaceholder => const [];

  SensitiveHealthProfile copyWith({
    List<HealthConditionRecord>? conditions,
    bool? healthPersonalizationEnabled,
    DateTime? updatedAt,
  }) {
    return SensitiveHealthProfile(
      profileId: profileId,
      ownerKey: ownerKey,
      conditions: conditions ?? this.conditions,
      healthPersonalizationEnabled:
          healthPersonalizationEnabled ?? this.healthPersonalizationEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'profileId': profileId,
        'ownerKey': ownerKey,
        'conditions': [
          for (final c in conditions) c.toStorageMap(),
        ],
        'healthPersonalizationEnabled': healthPersonalizationEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  static SensitiveHealthProfile? fromStorageMap(Map<String, dynamic> m) {
    final id = m['profileId']?.toString() ?? '';
    final owner = m['ownerKey']?.toString() ?? '';
    if (id.isEmpty || owner.isEmpty) return null;
    DateTime created;
    DateTime updated;
    try {
      created = DateTime.parse(m['createdAt']?.toString() ?? '');
      updated = DateTime.parse(m['updatedAt']?.toString() ?? '');
    } catch (_) {
      return null;
    }
    final rawList = m['conditions'];
    final list = <HealthConditionRecord>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          final rec = HealthConditionRecord.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (rec != null) list.add(rec);
        }
      }
    }
    return SensitiveHealthProfile(
      profileId: id,
      ownerKey: owner,
      conditions: List.unmodifiable(list),
      healthPersonalizationEnabled: m['healthPersonalizationEnabled'] != false,
      createdAt: created,
      updatedAt: updated,
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'healthProfileLoaded': true,
        'recordCount': conditions.length,
        'healthPersonalizationEnabled': healthPersonalizationEnabled,
        // بلا أسماء حالات.
      };
}

/// مرشّح قبل الموافقة — ليس سجلاً دائماً بعد.
class HealthConditionCandidate {
  const HealthConditionCandidate({
    required this.canonicalConditionKey,
    required this.displayName,
    required this.diagnosisStatus,
    required this.diagnosisSource,
    this.approximateSince,
  });

  final String canonicalConditionKey;
  final String displayName;
  final HealthDiagnosisStatus diagnosisStatus;
  final HealthDiagnosisSource diagnosisSource;
  final String? approximateSince;

  bool get isEligibleForPersistence =>
      diagnosisStatus == HealthDiagnosisStatus.diagnosed ||
      diagnosisStatus == HealthDiagnosisStatus.userReportedEstablished;
}

// EmotionalSupportContext نُقل إلى:
// package:ghadeer_clinic/health/emotional_support/emotional_support_models.dart

