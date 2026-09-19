import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../companion/visitor_identity_service.dart';
import 'sensitive_health_profile_models.dart';
import 'sensitive_health_profile_repository.dart';

/// تخزين محلي أولاً — نفس منطق PC-1.1 الأمني.
///
/// لا جدول سحابي: visitor_key لا يدعم ملكية RLS آمنة لكل مستخدم.
class LocalSensitiveHealthProfileRepository
    implements SensitiveHealthProfileRepository {
  LocalSensitiveHealthProfileRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;

  /// مفتاح منفصل عن ملف الهوية الشخصي.
  static const storageKey = 'pc_sensitive_health_profile_v1';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<SensitiveHealthProfile?> loadProfile() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SensitiveHealthProfile.fromStorageMap(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SensitiveHealthProfile> createEmptyProfile() async {
    final owner = await _identity.ownerKey();
    final now = DateTime.now();
    final profile = SensitiveHealthProfile(
      profileId: 'shp_${now.millisecondsSinceEpoch}',
      ownerKey: owner,
      conditions: const [],
      healthPersonalizationEnabled: true,
      createdAt: now,
      updatedAt: now,
    );
    return saveProfile(profile);
  }

  @override
  Future<SensitiveHealthProfile> saveProfile(
    SensitiveHealthProfile profile,
  ) async {
    final p = await _ensure();
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await p.setString(storageKey, jsonEncode(updated.toStorageMap()));
    return updated;
  }

  @override
  Future<void> deleteProfile() async {
    final p = await _ensure();
    await p.remove(storageKey);
  }
}
