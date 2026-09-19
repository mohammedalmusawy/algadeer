import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'personal_companion_profile.dart';
import 'personal_companion_profile_repository.dart';
import 'visitor_identity_service.dart';

/// تخزين محلي آمن للملف — PC-1.1.
///
/// قرار أمني: لا جدول سحابي لأن visitor_key لا يدعم RLS لكل مستخدم.
/// المزامنة السحابية تتطلب auth.uid() لاحقاً.
class LocalPersonalCompanionProfileRepository
    implements PersonalCompanionProfileRepository {
  LocalPersonalCompanionProfileRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;

  static const storageKey = 'pc_companion_profile_v1';

  /// مفتاح الاسم القديم — يُقرأ للترحيل فقط.
  static const legacyDisplayNameKey = 'user_display_name';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<PersonalCompanionProfile?> loadProfile() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return _tryMigrateLegacyName(p);
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final profile = PersonalCompanionProfile.fromStorageMap(map);
      if (profile.profileId.isEmpty || profile.ownerKey.isEmpty) {
        return null;
      }
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<PersonalCompanionProfile?> _tryMigrateLegacyName(
    SharedPreferences p,
  ) async {
    final legacy = p.getString(legacyDisplayNameKey)?.trim() ?? '';
    if (legacy.isEmpty) return null;
    // ترحيل صامت لمرة واحدة: إنشاء ملف بالاسم القديم.
    return createProfile(preferredName: legacy);
  }

  @override
  Future<PersonalCompanionProfile> createProfile({
    String? preferredName,
    bool profileEnabled = true,
  }) async {
    final p = await _ensure();
    final owner = await _identity.ownerKey();
    final now = DateTime.now();
    final profile = PersonalCompanionProfile(
      profileId: 'pcp_${now.millisecondsSinceEpoch}',
      ownerKey: owner,
      preferredName: preferredName?.trim().isEmpty == true
          ? null
          : preferredName?.trim(),
      profileEnabled: profileEnabled,
      createdAt: now,
      updatedAt: now,
    );
    await _persist(p, profile);
    await _mirrorLegacyName(p, profile.preferredName);
    return profile;
  }

  @override
  Future<PersonalCompanionProfile> updateProfile(
    PersonalCompanionProfile profile,
  ) async {
    _validateBirth(profile);
    final p = await _ensure();
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await _persist(p, updated);
    await _mirrorLegacyName(p, updated.preferredName);
    return updated;
  }

  @override
  Future<PersonalCompanionProfile> clearOptionalField(
    PersonalCompanionProfile profile,
    ProfileOptionalField field,
  ) async {
    final cleared = switch (field) {
      ProfileOptionalField.preferredName =>
        profile.copyWith(clearPreferredName: true),
      ProfileOptionalField.profilePhotoUrl =>
        profile.copyWith(clearProfilePhotoUrl: true),
      ProfileOptionalField.birthDate =>
        profile.copyWith(clearBirthDate: true),
      ProfileOptionalField.birthYear =>
        profile.copyWith(clearBirthYear: true),
      ProfileOptionalField.sexSelection =>
        profile.copyWith(clearSexSelection: true),
      ProfileOptionalField.userContext =>
        profile.copyWith(clearUserContext: true),
    };
    return updateProfile(cleared);
  }

  @override
  Future<PersonalCompanionProfile> disableProfile(
    PersonalCompanionProfile profile,
  ) async {
    return updateProfile(profile.copyWith(profileEnabled: false));
  }

  @override
  Future<void> deleteProfile() async {
    final p = await _ensure();
    await p.remove(storageKey);
    // حذف صريح: أزل مرآة الاسم أيضاً حتى لا يُعاد الترحيل تلقائياً.
    await p.remove(legacyDisplayNameKey);
  }

  Future<void> _persist(
    SharedPreferences p,
    PersonalCompanionProfile profile,
  ) async {
    await p.setString(storageKey, jsonEncode(profile.toStorageMap()));
  }

  /// مرآة توافق: يحافظ على user_display_name متزامناً أثناء الانتقال.
  Future<void> _mirrorLegacyName(
    SharedPreferences p,
    String? preferredName,
  ) async {
    final n = preferredName?.trim() ?? '';
    if (n.isEmpty) {
      await p.remove(legacyDisplayNameKey);
    } else {
      await p.setString(legacyDisplayNameKey, n);
    }
  }

  void _validateBirth(PersonalCompanionProfile profile) {
    final now = DateTime.now();
    if (profile.birthDate != null) {
      final b = profile.birthDate!;
      if (b.isAfter(now)) {
        throw ProfileValidationException('future_birth_date');
      }
      final age = profile.currentAge(now: now);
      if (age == null) {
        throw ProfileValidationException('invalid_birth_date');
      }
    }
    if (profile.birthYear != null) {
      final y = profile.birthYear!;
      if (y > now.year || y < now.year - 130) {
        throw ProfileValidationException('invalid_birth_year');
      }
    }
  }
}
