/// اختيار جنس الملف — اختيار المستخدم فقط، بلا استدلال.
enum ProfileSexSelection {
  male,
  female,
  preferNotToSpecify,
}

/// سياق المستخدم الاختياري.
enum ProfileUserContext {
  student,
  employee,
  selfEmployed,
  other,
  preferNotToSpecify,
}

/// ملف Personal Companion — طبقة هوية دائمة محلية (PC-1.1).
///
/// لا يحتوي: حالات صحية، حساسية، أدوية، ملفات عائلة، ذكريات محادثة.
class PersonalCompanionProfile {
  const PersonalCompanionProfile({
    required this.profileId,
    required this.ownerKey,
    this.preferredName,
    this.profilePhotoUrl,
    this.birthDate,
    this.birthYear,
    this.sexSelection,
    this.userContext,
    this.profileEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String profileId;
  final String ownerKey;
  final String? preferredName;

  /// مرجع صورة اختياري — بلا تحليل سمات.
  final String? profilePhotoUrl;

  /// تاريخ ميلاد كامل إن وُجد (مفضّل على العمر الثابت).
  final DateTime? birthDate;

  /// سنة ميلاد تقريبية إن لم يتوفر birthDate.
  final int? birthYear;

  final ProfileSexSelection? sexSelection;
  final ProfileUserContext? userContext;

  /// تعطيل التخصيص دون حذف البيانات.
  final bool profileEnabled;

  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  /// عمر محسوب ديناميكياً — ليس حقلاً مخزّناً.
  int? currentAge({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (birthDate != null) {
      final b = birthDate!;
      if (b.isAfter(n)) return null;
      var age = n.year - b.year;
      final hadBirthday = n.month > b.month ||
          (n.month == b.month && n.day >= b.day);
      if (!hadBirthday) age -= 1;
      if (age < 0 || age > 130) return null;
      return age;
    }
    if (birthYear != null) {
      if (birthYear! > n.year || birthYear! < n.year - 130) return null;
      final age = n.year - birthYear!;
      if (age < 0 || age > 130) return null;
      return age;
    }
    return null;
  }

  /// اسم فعّال للتخصيص إن كان الملف مفعّلاً.
  String? get effectivePreferredName {
    if (!profileEnabled) return null;
    final n = preferredName?.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  /// Phase 3A — الاسم الثلاثي / اسم العرض (نفس preferredName السلطوي).
  String? get fullName => effectivePreferredName;
  String? get displayName => effectivePreferredName;

  /// Phase 3A — عمر مشتق (ليس حقلاً مخزّناً).
  int? get ageYears => currentAge();

  /// Phase 3A — جنس الملف إن وُجد.
  ProfileSexSelection? get sex => sexSelection;

  PersonalCompanionProfile copyWith({
    String? preferredName,
    String? profilePhotoUrl,
    DateTime? birthDate,
    int? birthYear,
    ProfileSexSelection? sexSelection,
    ProfileUserContext? userContext,
    bool? profileEnabled,
    DateTime? updatedAt,
    bool clearPreferredName = false,
    bool clearProfilePhotoUrl = false,
    bool clearBirthDate = false,
    bool clearBirthYear = false,
    bool clearSexSelection = false,
    bool clearUserContext = false,
  }) {
    return PersonalCompanionProfile(
      profileId: profileId,
      ownerKey: ownerKey,
      preferredName:
          clearPreferredName ? null : (preferredName ?? this.preferredName),
      profilePhotoUrl: clearProfilePhotoUrl
          ? null
          : (profilePhotoUrl ?? this.profilePhotoUrl),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      sexSelection:
          clearSexSelection ? null : (sexSelection ?? this.sexSelection),
      userContext: clearUserContext ? null : (userContext ?? this.userContext),
      profileEnabled: profileEnabled ?? this.profileEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'schemaVersion': schemaVersion,
        'profileId': profileId,
        'ownerKey': ownerKey,
        'preferredName': preferredName,
        'profilePhotoUrl': profilePhotoUrl,
        'birthDate': birthDate?.toIso8601String().split('T').first,
        'birthYear': birthYear,
        'sexSelection': sexSelection?.name,
        'userContext': userContext?.name,
        'profileEnabled': profileEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PersonalCompanionProfile.fromStorageMap(Map<String, dynamic> m) {
    DateTime? parseDate(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s.trim());
    }

    ProfileSexSelection? sex;
    final sexRaw = m['sexSelection']?.toString();
    if (sexRaw != null) {
      for (final v in ProfileSexSelection.values) {
        if (v.name == sexRaw) sex = v;
      }
    }
    ProfileUserContext? ctx;
    final ctxRaw = m['userContext']?.toString();
    if (ctxRaw != null) {
      for (final v in ProfileUserContext.values) {
        if (v.name == ctxRaw) ctx = v;
      }
    }

    return PersonalCompanionProfile(
      profileId: m['profileId']?.toString() ?? '',
      ownerKey: m['ownerKey']?.toString() ?? '',
      preferredName: m['preferredName']?.toString(),
      profilePhotoUrl: m['profilePhotoUrl']?.toString(),
      birthDate: parseDate(m['birthDate']?.toString()),
      birthYear: m['birthYear'] is int
          ? m['birthYear'] as int
          : int.tryParse('${m['birthYear'] ?? ''}'),
      sexSelection: sex,
      userContext: ctx,
      profileEnabled: m['profileEnabled'] != false,
      createdAt: parseDate(m['createdAt']?.toString()) ?? DateTime.now(),
      updatedAt: parseDate(m['updatedAt']?.toString()) ?? DateTime.now(),
      schemaVersion: m['schemaVersion'] is int
          ? m['schemaVersion'] as int
          : int.tryParse('${m['schemaVersion'] ?? ''}') ??
              currentSchemaVersion,
    );
  }

  /// ميتاداتا آمنة — حضور الحقول فقط، بلا قيم.
  Map<String, Object?> debugPresenceMap() => {
        'profileLoaded': true,
        'profileEnabled': profileEnabled,
        'schemaVersion': schemaVersion,
        'hasPreferredName': effectivePreferredName != null,
        'hasProfilePhotoUrl': (profilePhotoUrl ?? '').isNotEmpty,
        'hasBirthDate': birthDate != null,
        'hasBirthYear': birthYear != null,
        'hasSexSelection': sexSelection != null,
        'hasUserContext': userContext != null,
        'hasComputedAge': currentAge() != null,
        // لا قيم: اسم، ميلاد، جنس، صورة، سياق
      };
}
