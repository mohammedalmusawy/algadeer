import 'local_sensitive_health_profile_repository.dart';
import 'sensitive_health_profile_models.dart';
import 'sensitive_health_profile_repository.dart';

/// خدمة ملف الصحة الحسّاس — المصدر السلطوي الوحيد لهذا المجال.
class SensitiveHealthProfileService {
  SensitiveHealthProfileService({
    SensitiveHealthProfileRepository? repository,
  }) : _repo = repository ?? LocalSensitiveHealthProfileRepository();

  final SensitiveHealthProfileRepository _repo;

  SensitiveHealthProfileRepository get repository => _repo;

  Future<SensitiveHealthProfile?> loadProfile() => _repo.loadProfile();

  Future<SensitiveHealthProfile> ensureProfile() async {
    final existing = await _repo.loadProfile();
    if (existing != null) return existing;
    return _repo.createEmptyProfile();
  }

  Future<SensitiveHealthProfile> upsertConditions(
    List<HealthConditionRecord> records,
  ) async {
    final current = await ensureProfile();
    final byKey = <String, HealthConditionRecord>{
      for (final c in current.conditions) c.canonicalConditionKey: c,
    };
    final now = DateTime.now();
    for (final r in records) {
      final existing = byKey[r.canonicalConditionKey];
      if (existing != null) {
        byKey[r.canonicalConditionKey] = existing.copyWith(
          displayName: r.displayName,
          diagnosisStatus: r.diagnosisStatus,
          diagnosisSource: r.diagnosisSource,
          approximateSince: r.approximateSince,
          consentState: HealthConsentState.granted,
          updatedAt: now,
          followUpPermission: false,
        );
      } else {
        byKey[r.canonicalConditionKey] = r;
      }
    }
    return _repo.saveProfile(
      current.copyWith(
        conditions: List.unmodifiable(byKey.values.toList()),
        updatedAt: now,
      ),
    );
  }

  Future<SensitiveHealthProfile> removeConditionByKey(String canonicalKey) async {
    final current = await ensureProfile();
    final next = current.conditions
        .where((c) => c.canonicalConditionKey != canonicalKey)
        .toList(growable: false);
    return _repo.saveProfile(
      current.copyWith(conditions: next, updatedAt: DateTime.now()),
    );
  }

  Future<SensitiveHealthProfile> disablePersonalization() async {
    final current = await ensureProfile();
    return _repo.saveProfile(
      current.copyWith(
        healthPersonalizationEnabled: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<SensitiveHealthProfile> enablePersonalization() async {
    final current = await ensureProfile();
    return _repo.saveProfile(
      current.copyWith(
        healthPersonalizationEnabled: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<SensitiveHealthProfile> setFollowUpPermission({
    required String canonicalConditionKey,
    required bool enabled,
  }) async {
    final current = await ensureProfile();
    final next = current.conditions.map((c) {
      if (c.canonicalConditionKey != canonicalConditionKey) return c;
      return c.copyWith(
        followUpPermission: enabled,
        updatedAt: DateTime.now(),
      );
    }).toList(growable: false);
    return _repo.saveProfile(
      current.copyWith(conditions: next, updatedAt: DateTime.now()),
    );
  }

  Future<HealthConditionRecord?> findCondition(String canonicalKey) async {
    final p = await loadProfile();
    if (p == null) return null;
    for (final c in p.conditions) {
      if (c.canonicalConditionKey == canonicalKey) return c;
    }
    return null;
  }

  Future<void> deleteProfileExplicitly() => _repo.deleteProfile();

  Map<String, Object?> debugPresence({SensitiveHealthProfile? profile}) {
    if (profile == null) {
      return {
        'healthProfileLoaded': false,
        'recordCount': 0,
      };
    }
    return profile.debugPresenceMap();
  }
}
