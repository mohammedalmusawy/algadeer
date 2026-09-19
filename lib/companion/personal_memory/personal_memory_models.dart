/// PC-1.12 — ذاكرة الأهداف والاهتمامات والتفضيلات (صاحب الحساب فقط).
///
/// منفصلة عن PersonalCompanionProfile وعن الصحة الحسّاسة وعن Follow-up.

enum PersonalMemoryType {
  goal,
  interest,
  preference,
}

enum PersonalMemoryStatus {
  active,
  completed,
  paused,
  archived,
}

enum PersonalMemoryConsentState {
  none,
  pending,
  granted,
  declined,
  revoked,
}

enum PersonalMemorySourceType {
  explicitRememberCommand,
  explicitConfirmation,
  unknown,
}

enum PersonalGoalCategory {
  learning,
  education,
  fitness,
  sleepRoutine,
  work,
  contentCreation,
  technology,
  languageLearning,
  personalOrganization,
  other,
}

enum PersonalInterestCategory {
  technology,
  programming,
  radiology,
  contentCreation,
  photography,
  design,
  languageLearning,
  fitness,
  other,
}

enum PersonalPreferenceDomain {
  explanationLanguage,
  explanationStyle,
  modalityTextPreferred,
  other,
}

/// سجل ذاكرة شخصية موحّد الشكل — بدون نص محادثة خام.
class CompanionPersonalMemoryRecord {
  const CompanionPersonalMemoryRecord({
    required this.memoryId,
    required this.ownerKey,
    required this.memoryType,
    required this.canonicalKey,
    required this.displayLabel,
    required this.status,
    required this.consentState,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.category = 'other',
    this.goalState,
    this.targetContext,
    this.preferenceDomain,
    this.lastConfirmedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String memoryId;
  final String ownerKey;
  final PersonalMemoryType memoryType;
  final String canonicalKey;
  final String displayLabel;
  final PersonalMemoryStatus status;
  final PersonalMemoryConsentState consentState;
  final PersonalMemorySourceType sourceType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final String? goalState;
  final String? targetContext;
  final String? preferenceDomain;
  final DateTime? lastConfirmedAt;
  final int schemaVersion;

  bool get isActive => status == PersonalMemoryStatus.active;

  CompanionPersonalMemoryRecord copyWith({
    String? displayLabel,
    PersonalMemoryStatus? status,
    PersonalMemoryConsentState? consentState,
    String? category,
    String? goalState,
    String? targetContext,
    String? preferenceDomain,
    DateTime? updatedAt,
    DateTime? lastConfirmedAt,
  }) {
    return CompanionPersonalMemoryRecord(
      memoryId: memoryId,
      ownerKey: ownerKey,
      memoryType: memoryType,
      canonicalKey: canonicalKey,
      displayLabel: displayLabel ?? this.displayLabel,
      status: status ?? this.status,
      consentState: consentState ?? this.consentState,
      sourceType: sourceType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      goalState: goalState ?? this.goalState,
      targetContext: targetContext ?? this.targetContext,
      preferenceDomain: preferenceDomain ?? this.preferenceDomain,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'memoryId': memoryId,
        'ownerKey': ownerKey,
        'memoryType': memoryType.name,
        'canonicalKey': canonicalKey,
        'displayLabel': displayLabel,
        'status': status.name,
        'consentState': consentState.name,
        'sourceType': sourceType.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'category': category,
        'goalState': goalState,
        'targetContext': targetContext,
        'preferenceDomain': preferenceDomain,
        'lastConfirmedAt': lastConfirmedAt?.toIso8601String(),
        'schemaVersion': schemaVersion,
      };

  static CompanionPersonalMemoryRecord? fromStorageMap(Map<String, dynamic> m) {
    final id = m['memoryId']?.toString() ?? '';
    final owner = m['ownerKey']?.toString() ?? '';
    final key = m['canonicalKey']?.toString() ?? '';
    final label = m['displayLabel']?.toString() ?? '';
    if (id.isEmpty || owner.isEmpty || key.isEmpty || label.isEmpty) return null;

    PersonalMemoryType type = PersonalMemoryType.goal;
    for (final v in PersonalMemoryType.values) {
      if (v.name == m['memoryType']?.toString()) type = v;
    }
    PersonalMemoryStatus status = PersonalMemoryStatus.active;
    for (final v in PersonalMemoryStatus.values) {
      if (v.name == m['status']?.toString()) status = v;
    }
    PersonalMemoryConsentState consent = PersonalMemoryConsentState.granted;
    for (final v in PersonalMemoryConsentState.values) {
      if (v.name == m['consentState']?.toString()) consent = v;
    }
    PersonalMemorySourceType source = PersonalMemorySourceType.unknown;
    for (final v in PersonalMemorySourceType.values) {
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

    return CompanionPersonalMemoryRecord(
      memoryId: id,
      ownerKey: owner,
      memoryType: type,
      canonicalKey: key,
      displayLabel: label,
      status: status,
      consentState: consent,
      sourceType: source,
      createdAt: created,
      updatedAt: updated,
      category: m['category']?.toString() ?? 'other',
      goalState: m['goalState']?.toString(),
      targetContext: m['targetContext']?.toString(),
      preferenceDomain: m['preferenceDomain']?.toString(),
      lastConfirmedAt: parse(m['lastConfirmedAt']),
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugMap() => {
        'memoryType': memoryType.name,
        'category': category,
        'status': status.name,
        // بلا محتوى / memoryId.
      };
}

class CompanionPersonalMemoryStore {
  const CompanionPersonalMemoryStore({
    required this.ownerKey,
    this.records = const [],
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String ownerKey;
  final List<CompanionPersonalMemoryRecord> records;
  final int schemaVersion;

  CompanionPersonalMemoryStore copyWith({
    List<CompanionPersonalMemoryRecord>? records,
  }) {
    return CompanionPersonalMemoryStore(
      ownerKey: ownerKey,
      records: records ?? this.records,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'ownerKey': ownerKey,
        'schemaVersion': schemaVersion,
        'records': [for (final r in records) r.toStorageMap()],
      };

  static CompanionPersonalMemoryStore? fromStorageMap(Map<String, dynamic> m) {
    final owner = m['ownerKey']?.toString() ?? '';
    if (owner.isEmpty) return null;
    final list = <CompanionPersonalMemoryRecord>[];
    final raw = m['records'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final r = CompanionPersonalMemoryRecord.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (r != null) list.add(r);
        }
      }
    }
    return CompanionPersonalMemoryStore(
      ownerKey: owner,
      records: List.unmodifiable(list),
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, Object?> debugMap() => {
        'personalMemoryStoreLoaded': true,
        'recordCount': records.length,
      };
}

/// مرشّح قبل الحفظ — ليس سجلاً دائماً بعد.
class PersonalMemoryCandidate {
  const PersonalMemoryCandidate({
    required this.memoryType,
    required this.canonicalKey,
    required this.displayLabel,
    required this.category,
    this.preferenceDomain,
    this.targetContext,
    this.requiresExtraConfirm = false,
    this.replacesCanonicalKeys = const [],
  });

  final PersonalMemoryType memoryType;
  final String canonicalKey;
  final String displayLabel;
  final String category;
  final String? preferenceDomain;
  final String? targetContext;
  final bool requiresExtraConfirm;
  final List<String> replacesCanonicalKeys;
}
