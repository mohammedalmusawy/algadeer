import 'local_personal_memory_repository.dart';
import 'personal_memory_models.dart';
import 'personal_memory_repository.dart';

/// خدمة الذاكرة الشخصية — صاحب الحساب فقط.
class PersonalMemoryService {
  PersonalMemoryService({
    PersonalMemoryRepository? repository,
  }) : _repo = repository ?? LocalPersonalMemoryRepository();

  final PersonalMemoryRepository _repo;

  PersonalMemoryRepository get repository => _repo;

  Future<CompanionPersonalMemoryStore?> loadStore() => _repo.loadStore();

  Future<CompanionPersonalMemoryStore> ensureStore() async {
    final existing = await _repo.loadStore();
    if (existing != null) return existing;
    String owner = 'local';
    if (_repo is LocalPersonalMemoryRepository) {
      owner = await (_repo as LocalPersonalMemoryRepository).ownerKey();
    }
    return _repo.saveStore(CompanionPersonalMemoryStore(ownerKey: owner));
  }

  Future<List<CompanionPersonalMemoryRecord>> listAll() async {
    final store = await loadStore();
    return store?.records ?? const [];
  }

  Future<List<CompanionPersonalMemoryRecord>> listByType(
    PersonalMemoryType type, {
    bool activeOnly = false,
  }) async {
    final all = await listAll();
    return all
        .where(
          (r) =>
              r.memoryType == type &&
              (!activeOnly || r.status == PersonalMemoryStatus.active),
        )
        .toList(growable: false);
  }

  Future<CompanionPersonalMemoryRecord?> findByCanonicalKey(
    String key, {
    PersonalMemoryType? type,
  }) async {
    final all = await listAll();
    for (final r in all) {
      if (r.canonicalKey == key &&
          (type == null || r.memoryType == type) &&
          r.status != PersonalMemoryStatus.archived) {
        return r;
      }
    }
    return null;
  }

  Future<List<CompanionPersonalMemoryRecord>> findAmbiguous({
    required PersonalMemoryType type,
    required String needle,
  }) async {
    final n = needle.trim().toLowerCase();
    final all = await listByType(type);
    return all
        .where(
          (r) =>
              r.displayLabel.toLowerCase().contains(n) ||
              r.canonicalKey.toLowerCase().contains(n),
        )
        .toList(growable: false);
  }

  Future<CompanionPersonalMemoryRecord> upsertCandidate(
    PersonalMemoryCandidate candidate,
  ) async {
    final store = await ensureStore();
    final now = DateTime.now();
    final existing = await findByCanonicalKey(
      candidate.canonicalKey,
      type: candidate.memoryType,
    );
    final list = [...store.records];
    if (existing != null) {
      final idx = list.indexWhere((r) => r.memoryId == existing.memoryId);
      list[idx] = existing.copyWith(
        displayLabel: candidate.displayLabel,
        status: PersonalMemoryStatus.active,
        consentState: PersonalMemoryConsentState.granted,
        category: candidate.category,
        preferenceDomain: candidate.preferenceDomain,
        targetContext: candidate.targetContext,
        updatedAt: now,
        lastConfirmedAt: now,
      );
    } else {
      list.add(
        CompanionPersonalMemoryRecord(
          memoryId: 'pm_${now.microsecondsSinceEpoch}',
          ownerKey: store.ownerKey,
          memoryType: candidate.memoryType,
          canonicalKey: candidate.canonicalKey,
          displayLabel: candidate.displayLabel,
          status: PersonalMemoryStatus.active,
          consentState: PersonalMemoryConsentState.granted,
          sourceType: PersonalMemorySourceType.explicitRememberCommand,
          createdAt: now,
          updatedAt: now,
          category: candidate.category,
          preferenceDomain: candidate.preferenceDomain,
          targetContext: candidate.targetContext,
          lastConfirmedAt: now,
          goalState: candidate.memoryType == PersonalMemoryType.goal
              ? 'active'
              : null,
        ),
      );
    }
    await _repo.saveStore(store.copyWith(records: list));
    for (final oldKey in candidate.replacesCanonicalKeys) {
      final old = await findByCanonicalKey(oldKey, type: candidate.memoryType);
      if (old != null && old.canonicalKey != candidate.canonicalKey) {
        await deleteById(old.memoryId);
      }
    }
    return (await findByCanonicalKey(
      candidate.canonicalKey,
      type: candidate.memoryType,
    ))!;
  }

  Future<CompanionPersonalMemoryRecord?> updateStatus(
    String memoryId,
    PersonalMemoryStatus status,
  ) async {
    final store = await loadStore();
    if (store == null) return null;
    final list = [...store.records];
    final idx = list.indexWhere((r) => r.memoryId == memoryId);
    if (idx < 0) return null;
    list[idx] = list[idx].copyWith(
      status: status,
      goalState: status.name,
      updatedAt: DateTime.now(),
    );
    await _repo.saveStore(store.copyWith(records: list));
    return list[idx];
  }

  Future<bool> deleteById(String memoryId) async {
    final store = await loadStore();
    if (store == null) return false;
    final next =
        store.records.where((r) => r.memoryId != memoryId).toList(growable: false);
    if (next.length == store.records.length) return false;
    await _repo.saveStore(store.copyWith(records: next));
    return true;
  }

  Future<int> deleteAllOfType(PersonalMemoryType type) async {
    final store = await loadStore();
    if (store == null) return 0;
    final before = store.records.length;
    final next =
        store.records.where((r) => r.memoryType != type).toList(growable: false);
    await _repo.saveStore(store.copyWith(records: next));
    return before - next.length;
  }
}
