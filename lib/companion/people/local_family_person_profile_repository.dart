import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../visitor_identity_service.dart';
import 'family_person_profile.dart';
import 'family_person_profile_repository.dart';

class LocalFamilyPersonProfileRepository
    implements FamilyPersonProfileRepository {
  LocalFamilyPersonProfileRepository({
    SharedPreferences? prefs,
    VisitorIdentityService? identity,
  })  : _prefs = prefs,
        _identity = identity ?? VisitorIdentityService(prefs: prefs);

  SharedPreferences? _prefs;
  final VisitorIdentityService _identity;
  int _idSeq = 0;

  static const storageKey = 'pc_family_people_profiles_v1';

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
    _identity.setPrefsForTesting(prefs);
  }

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<FamilyPersonProfile>> loadAll() async {
    final p = await _ensure();
    final raw = p.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <FamilyPersonProfile>[];
      for (final item in list) {
        if (item is Map) {
          final profile = FamilyPersonProfile.fromStorageMap(
            Map<String, dynamic>.from(item),
          );
          if (profile != null) out.add(profile);
        }
      }
      return List.unmodifiable(out);
    } catch (_) {
      return const [];
    }
  }

  Future<List<FamilyPersonProfile>> _saveAll(
    List<FamilyPersonProfile> profiles,
  ) async {
    final p = await _ensure();
    final encoded = jsonEncode([
      for (final pr in profiles) pr.toStorageMap(),
    ]);
    await p.setString(storageKey, encoded);
    return profiles;
  }

  @override
  Future<FamilyPersonProfile?> findById(String personId) async {
    final all = await loadAll();
    for (final pr in all) {
      if (pr.personId == personId) return pr;
    }
    return null;
  }

  @override
  Future<FamilyPersonProfile> create(FamilyPersonProfile profile) async {
    final owner = await _identity.ownerKey();
    final all = await loadAll();
    _idSeq += 1;
    final next = FamilyPersonProfile(
      personId: profile.personId.isNotEmpty
          ? profile.personId
          : 'person_${DateTime.now().microsecondsSinceEpoch}_$_idSeq',
      ownerKey: owner,
      relationship: profile.relationship,
      preferredName: profile.preferredName,
      birthDate: profile.birthDate,
      birthYear: profile.birthYear,
      sexSelection: profile.sexSelection,
      profileEnabled: profile.profileEnabled,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
    );
    await _saveAll([...all, next]);
    return next;
  }

  @override
  Future<FamilyPersonProfile> update(FamilyPersonProfile profile) async {
    final all = await loadAll();
    final idx = all.indexWhere((p) => p.personId == profile.personId);
    if (idx < 0) throw StateError('person not found');
    final next = List<FamilyPersonProfile>.from(all)..[idx] = profile;
    await _saveAll(next);
    return profile;
  }

  @override
  Future<void> deleteById(String personId) async {
    final all = await loadAll();
    await _saveAll(all.where((p) => p.personId != personId).toList());
  }

  @override
  Future<void> clearAll() async {
    final p = await _ensure();
    await p.remove(storageKey);
  }
}
