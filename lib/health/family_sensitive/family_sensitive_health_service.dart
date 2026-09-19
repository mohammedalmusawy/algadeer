import '../sensitive_profile/sensitive_health_profile_models.dart';
import 'family_sensitive_health_models.dart';
import 'family_sensitive_health_repository.dart';
import 'local_family_sensitive_health_repository.dart';

/// خدمة صحة العائلة الحسّاسة — مصدر سلطوي حسب personId.
class FamilySensitiveHealthService {
  FamilySensitiveHealthService({
    FamilySensitiveHealthRepository? repository,
  }) : _repo = repository ?? LocalFamilySensitiveHealthRepository();

  final FamilySensitiveHealthRepository _repo;

  FamilySensitiveHealthRepository get repository => _repo;

  Future<FamilySensitiveHealthStore?> loadStore() => _repo.loadStore();

  Future<FamilySensitiveHealthStore> ensureStore() async {
    final existing = await _repo.loadStore();
    if (existing != null) return existing;
    String owner = 'local';
    if (_repo is LocalFamilySensitiveHealthRepository) {
      owner = await (_repo as LocalFamilySensitiveHealthRepository).ownerKey();
    }
    final store = FamilySensitiveHealthStore(ownerKey: owner);
    return _repo.saveStore(store);
  }

  Future<FamilySensitiveHealthProfile?> loadForPerson(String personId) async {
    if (personId.isEmpty) return null;
    final store = await loadStore();
    return store?.profiles[personId];
  }

  Future<int> countForPerson(String personId) async {
    final p = await loadForPerson(personId);
    return p?.conditions.length ?? 0;
  }

  Future<bool> hasHealthForPerson(String personId) async {
    return (await countForPerson(personId)) > 0;
  }

  Future<List<String>> personIdsWithHealth() async {
    final store = await loadStore();
    return store?.personIdsWithHealth ?? const [];
  }

  Future<FamilySensitiveHealthProfile> upsertConditions({
    required String persistentPersonId,
    required List<HealthConditionCandidate> candidates,
  }) async {
    if (persistentPersonId.isEmpty) {
      throw FamilySensitiveHealthStorageException('missing_person_id');
    }
    final store = await ensureStore();
    final now = DateTime.now();
    final existing = store.profiles[persistentPersonId];
    final byKey = <String, FamilyHealthConditionRecord>{
      for (final c in existing?.conditions ?? const <FamilyHealthConditionRecord>[])
        c.canonicalConditionKey: c,
    };

    for (final cand in candidates) {
      if (!cand.isEligibleForPersistence) continue;
      final prev = byKey[cand.canonicalConditionKey];
      if (prev != null) {
        byKey[cand.canonicalConditionKey] = prev.copyWith(
          displayName: cand.displayName,
          diagnosisStatus: cand.diagnosisStatus,
          sourceType: cand.diagnosisSource,
          approximateSince: cand.approximateSince,
          consentState: HealthConsentState.granted,
          updatedAt: now,
        );
      } else {
        byKey[cand.canonicalConditionKey] = FamilyHealthConditionRecord(
          recordId:
              'fhc_${cand.canonicalConditionKey}_${now.microsecondsSinceEpoch}',
          persistentPersonId: persistentPersonId,
          canonicalConditionKey: cand.canonicalConditionKey,
          displayName: cand.displayName,
          diagnosisStatus: cand.diagnosisStatus,
          sourceType: cand.diagnosisSource,
          consentState: HealthConsentState.granted,
          approximateSince: cand.approximateSince,
          createdAt: now,
          updatedAt: now,
        );
      }
    }

    final profile = FamilySensitiveHealthProfile(
      persistentPersonId: persistentPersonId,
      conditions: List.unmodifiable(byKey.values.toList()),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final nextProfiles = Map<String, FamilySensitiveHealthProfile>.from(
      store.profiles,
    )..[persistentPersonId] = profile;

    await _repo.saveStore(store.copyWith(profiles: nextProfiles));
    return profile;
  }

  Future<FamilySensitiveHealthProfile?> removeCondition({
    required String persistentPersonId,
    required String canonicalKey,
  }) async {
    final store = await loadStore();
    final existing = store?.profiles[persistentPersonId];
    if (store == null || existing == null) return null;
    final next = existing.conditions
        .where((c) => c.canonicalConditionKey != canonicalKey)
        .toList(growable: false);
    final profile = existing.copyWith(
      conditions: next,
      updatedAt: DateTime.now(),
    );
    final nextProfiles = Map<String, FamilySensitiveHealthProfile>.from(
      store.profiles,
    );
    if (next.isEmpty) {
      nextProfiles.remove(persistentPersonId);
    } else {
      nextProfiles[persistentPersonId] = profile;
    }
    await _repo.saveStore(store.copyWith(profiles: nextProfiles));
    return next.isEmpty ? null : profile;
  }

  Future<void> deleteAllForPerson(String persistentPersonId) async {
    final store = await loadStore();
    if (store == null) return;
    if (!store.profiles.containsKey(persistentPersonId)) return;
    final next = Map<String, FamilySensitiveHealthProfile>.from(store.profiles)
      ..remove(persistentPersonId);
    await _repo.saveStore(store.copyWith(profiles: next));
  }

  /// يُستدعى فقط بعد تأكيد حذف ملف الشخص مع الصحة.
  Future<void> cascadeDeleteForPerson(String persistentPersonId) =>
      deleteAllForPerson(persistentPersonId);

  Map<String, Object?> debugPresence({FamilySensitiveHealthStore? store}) {
    if (store == null) {
      return {'familyHealthStoreLoaded': false, 'recordCount': 0};
    }
    return store.debugPresenceMap();
  }
}
