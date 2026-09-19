/// PC-1.8 — ملف شخص عائلة/قريب — هوية فقط، بلا بيانات صحية.
library;

import '../personal_companion_profile.dart';

/// علاقة صريحة من المستخدم — لا استنتاج من الاسم.
enum PersonRelationship {
  son,
  daughter,
  child,
  mother,
  father,
  wife,
  husband,
  spouse,
  brother,
  sister,
  familyMember,
  otherPerson,
}

/// مرجع حساب المالك — مفهومي فقط، ليس PersonProfile.
class AccountOwnerRef {
  const AccountOwnerRef();
}

/// مرجع شخص دائم — للربط الجلسة/المستقبل.
class PersistentPersonRef {
  const PersistentPersonRef(this.personId);
  final String personId;
}

/// ملف شخص — هوية وسياق فقط.
class FamilyPersonProfile {
  const FamilyPersonProfile({
    required this.personId,
    required this.ownerKey,
    required this.relationship,
    this.preferredName,
    this.birthDate,
    this.birthYear,
    this.sexSelection,
    this.profileEnabled = true,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String personId;
  final String ownerKey;
  final PersonRelationship relationship;
  final String? preferredName;
  final DateTime? birthDate;
  final int? birthYear;
  final ProfileSexSelection? sexSelection;
  final bool profileEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  /// عمر محسوب — لا يُخزَّن ثابتاً.
  int? currentAge({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (birthDate != null) {
      final b = birthDate!;
      if (b.isAfter(n)) return null;
      var age = n.year - b.year;
      final hadBirthday =
          n.month > b.month || (n.month == b.month && n.day >= b.day);
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

  String? get effectiveName {
    final n = preferredName?.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  bool get isChildRelationship =>
      relationship == PersonRelationship.son ||
      relationship == PersonRelationship.daughter ||
      relationship == PersonRelationship.child;

  FamilyPersonProfile copyWith({
    PersonRelationship? relationship,
    String? preferredName,
    DateTime? birthDate,
    int? birthYear,
    ProfileSexSelection? sexSelection,
    bool? profileEnabled,
    DateTime? updatedAt,
    bool clearPreferredName = false,
    bool clearBirthDate = false,
    bool clearBirthYear = false,
    bool clearSexSelection = false,
  }) {
    return FamilyPersonProfile(
      personId: personId,
      ownerKey: ownerKey,
      relationship: relationship ?? this.relationship,
      preferredName:
          clearPreferredName ? null : (preferredName ?? this.preferredName),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      sexSelection:
          clearSexSelection ? null : (sexSelection ?? this.sexSelection),
      profileEnabled: profileEnabled ?? this.profileEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, Object?> toStorageMap() => {
        'schemaVersion': schemaVersion,
        'personId': personId,
        'ownerKey': ownerKey,
        'relationship': relationship.name,
        'preferredName': preferredName,
        'birthDate': birthDate?.toIso8601String().split('T').first,
        'birthYear': birthYear,
        'sexSelection': sexSelection?.name,
        'profileEnabled': profileEnabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static FamilyPersonProfile? fromStorageMap(Map<String, dynamic> m) {
    DateTime? parseDate(String? s) {
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s.trim());
    }

    PersonRelationship? rel;
    for (final v in PersonRelationship.values) {
      if (v.name == m['relationship']?.toString()) rel = v;
    }
    if (rel == null) return null;

    ProfileSexSelection? sex;
    final sexRaw = m['sexSelection']?.toString();
    if (sexRaw != null) {
      for (final v in ProfileSexSelection.values) {
        if (v.name == sexRaw) sex = v;
      }
    }

    final id = m['personId']?.toString() ?? '';
    final owner = m['ownerKey']?.toString() ?? '';
    if (id.isEmpty || owner.isEmpty) return null;

    return FamilyPersonProfile(
      personId: id,
      ownerKey: owner,
      relationship: rel,
      preferredName: m['preferredName']?.toString(),
      birthDate: parseDate(m['birthDate']?.toString()),
      birthYear: m['birthYear'] is int
          ? m['birthYear'] as int
          : int.tryParse('${m['birthYear'] ?? ''}'),
      sexSelection: sex,
      profileEnabled: m['profileEnabled'] != false,
      createdAt: parseDate(m['createdAt']?.toString()) ?? DateTime.now(),
      updatedAt: parseDate(m['updatedAt']?.toString()) ?? DateTime.now(),
      schemaVersion: m['schemaVersion'] is int
          ? m['schemaVersion'] as int
          : int.tryParse('${m['schemaVersion'] ?? ''}') ?? currentSchemaVersion,
    );
  }

  Map<String, Object?> debugPresenceMap() => {
        'personProfilePresent': true,
        'relationshipType': relationship.name,
        'profileEnabled': profileEnabled,
        'hasPreferredName': effectiveName != null,
        'hasBirthDate': birthDate != null,
        'hasBirthYear': birthYear != null,
        'hasComputedAge': currentAge() != null,
      };
}
