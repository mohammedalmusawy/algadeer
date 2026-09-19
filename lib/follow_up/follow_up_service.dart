import 'follow_up_due_policy.dart';
import 'follow_up_eligibility_policy.dart';
import 'follow_up_models.dart';
import 'follow_up_repository.dart';
import 'local_follow_up_repository.dart';

/// خدمة الالتزامات — السلطة العامة لـ WHETHER/WHEN للعودة.
class FollowUpService {
  FollowUpService({
    FollowUpRepository? repository,
    FollowUpDuePolicy? duePolicy,
    FollowUpEligibilityPolicy? eligibility,
  })  : _repo = repository ?? LocalFollowUpRepository(),
        _due = duePolicy ?? const FollowUpDuePolicy(),
        _eligibility = eligibility ?? const FollowUpEligibilityPolicy();

  final FollowUpRepository _repo;
  final FollowUpDuePolicy _due;
  final FollowUpEligibilityPolicy _eligibility;

  FollowUpRepository get repository => _repo;
  FollowUpDuePolicy get duePolicy => _due;
  FollowUpEligibilityPolicy get eligibility => _eligibility;

  Future<FollowUpStore?> loadStore() => _repo.loadStore();

  Future<FollowUpStore> ensureStore() async {
    final existing = await _repo.loadStore();
    if (existing != null) return existing;
    String owner = 'local';
    if (_repo is LocalFollowUpRepository) {
      owner = await (_repo as LocalFollowUpRepository).ownerKey();
    }
    return _repo.saveStore(FollowUpStore(ownerKey: owner));
  }

  Future<List<FollowUpCommitment>> listAll() async {
    final store = await loadStore();
    return store?.commitments ?? const [];
  }

  Future<List<FollowUpCommitment>> listActive({
    FollowUpSubjectRef? subject,
  }) async {
    final all = await listAll();
    return all
        .where(
          (c) =>
              c.status == FollowUpStatus.active &&
              (subject == null || c.subjectRef.matches(subject)),
        )
        .toList(growable: false);
  }

  Future<FollowUpCommitment?> findByTopic({
    required FollowUpSubjectRef subject,
    required FollowUpDomain domain,
    required String topicKey,
  }) async {
    final all = await listAll();
    for (final c in all) {
      if (c.subjectRef.matches(subject) &&
          c.domain == domain &&
          c.topicKey == topicKey &&
          c.status != FollowUpStatus.cancelled) {
        return c;
      }
    }
    return null;
  }

  Future<FollowUpCommitment?> findById(String id) async {
    final all = await listAll();
    for (final c in all) {
      if (c.commitmentId == id) return c;
    }
    return null;
  }

  Future<FollowUpCommitment> upsertCommitment(FollowUpCommitment draft) async {
    if (!_eligibility.mayCreateForSubject(
      subject: draft.subjectRef,
      domain: draft.domain,
    )) {
      throw FollowUpStorageException('subject_domain_not_allowed');
    }
    final store = await ensureStore();
    final now = DateTime.now();
    final list = [...store.commitments];
    final byId = list.indexWhere((c) => c.commitmentId == draft.commitmentId);
    if (byId >= 0) {
      list[byId] = draft.copyWith(updatedAt: now);
    } else {
      final same = list.indexWhere(
        (c) =>
            c.subjectRef.matches(draft.subjectRef) &&
            c.domain == draft.domain &&
            c.topicKey == draft.topicKey &&
            c.status != FollowUpStatus.cancelled &&
            c.status != FollowUpStatus.completed,
      );
      if (same >= 0) {
        final prev = list[same];
        list[same] = FollowUpCommitment(
          commitmentId: prev.commitmentId,
          subjectRef: draft.subjectRef,
          domain: draft.domain,
          topicKey: draft.topicKey,
          status: draft.status,
          permissionState: draft.permissionState,
          createdAt: prev.createdAt,
          updatedAt: now,
          displayTopic: draft.displayTopic.isNotEmpty
              ? draft.displayTopic
              : prev.displayTopic,
          lastAskedAt: draft.lastAskedAt ?? prev.lastAskedAt,
          lastAnsweredAt: draft.lastAnsweredAt ?? prev.lastAnsweredAt,
          lastSkippedAt: draft.lastSkippedAt ?? prev.lastSkippedAt,
          consecutiveSkips: draft.consecutiveSkips != 0
              ? draft.consecutiveSkips
              : prev.consecutiveSkips,
          notBeforeAt: draft.notBeforeAt ?? prev.notBeforeAt,
          dueWindow: draft.dueWindow ?? prev.dueWindow,
          timingIntent: draft.timingIntent,
          sourceType: draft.sourceType,
        );
      } else {
        list.add(draft.copyWith(updatedAt: now));
      }
    }
    await _repo.saveStore(store.copyWith(commitments: list));
    final saved = list.firstWhere(
      (c) =>
          c.commitmentId == draft.commitmentId ||
          (c.subjectRef.matches(draft.subjectRef) &&
              c.domain == draft.domain &&
              c.topicKey == draft.topicKey &&
              c.status != FollowUpStatus.cancelled),
    );
    return saved;
  }

  Future<FollowUpCommitment> create({
    required FollowUpSubjectRef subject,
    required FollowUpDomain domain,
    required String topicKey,
    required String displayTopic,
    FollowUpPermissionState permission =
        FollowUpPermissionState.granted,
    FollowUpStatus status = FollowUpStatus.active,
    FollowUpTimingIntent timing = FollowUpTimingIntent.whenUserReturns,
    FollowUpSourceType source = FollowUpSourceType.explicitUserCommand,
    DateTime? notBeforeAt,
  }) async {
    final now = DateTime.now();
    final c = FollowUpCommitment(
      commitmentId: 'fu_${now.microsecondsSinceEpoch}',
      subjectRef: subject,
      domain: domain,
      topicKey: topicKey,
      status: status,
      permissionState: permission,
      createdAt: now,
      updatedAt: now,
      displayTopic: displayTopic,
      timingIntent: timing,
      sourceType: source,
      notBeforeAt: notBeforeAt,
    );
    return upsertCommitment(c);
  }

  /// مزامنة من PC-1.5 — التزام WHETHER للمزمن.
  Future<FollowUpCommitment> syncChronicOptIn({
    required String conditionKey,
    required String displayTopic,
  }) {
    return create(
      subject: FollowUpSubjectRef.accountOwner,
      domain: FollowUpDomain.chronicHealth,
      topicKey: conditionKey,
      displayTopic: displayTopic,
      permission: FollowUpPermissionState.granted,
      status: FollowUpStatus.active,
      source: FollowUpSourceType.chronicCareOptIn,
      timing: FollowUpTimingIntent.whenUserReturns,
    );
  }

  Future<FollowUpCommitment?> syncChronicOptOut(String conditionKey) async {
    final existing = await findByTopic(
      subject: FollowUpSubjectRef.accountOwner,
      domain: FollowUpDomain.chronicHealth,
      topicKey: conditionKey,
    );
    if (existing == null) return null;
    return updateStatus(
      existing.commitmentId,
      status: FollowUpStatus.paused,
      permission: FollowUpPermissionState.revoked,
    );
  }

  Future<FollowUpCommitment?> updateStatus(
    String id, {
    FollowUpStatus? status,
    FollowUpPermissionState? permission,
  }) async {
    final c = await findById(id);
    if (c == null) return null;
    final next = c.copyWith(
      status: status,
      permissionState: permission,
      updatedAt: DateTime.now(),
    );
    return upsertCommitment(next);
  }

  Future<FollowUpCommitment?> recordAsked(String id) async {
    final c = await findById(id);
    if (c == null) return null;
    return upsertCommitment(
      c.copyWith(lastAskedAt: DateTime.now(), updatedAt: DateTime.now()),
    );
  }

  Future<FollowUpCommitment?> recordAnswered(String id) async {
    final c = await findById(id);
    if (c == null) return null;
    return upsertCommitment(
      c.copyWith(
        lastAnsweredAt: DateTime.now(),
        consecutiveSkips: 0,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<FollowUpCommitment?> recordSkipped(String id) async {
    final c = await findById(id);
    if (c == null) return null;
    return upsertCommitment(
      c.copyWith(
        lastSkippedAt: DateTime.now(),
        consecutiveSkips: c.consecutiveSkips + 1,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<bool> deleteCommitment(String id) async {
    final store = await loadStore();
    if (store == null) return false;
    final next = store.commitments
        .where((c) => c.commitmentId != id)
        .toList(growable: false);
    if (next.length == store.commitments.length) return false;
    await _repo.saveStore(store.copyWith(commitments: next));
    return true;
  }

  Future<FollowUpCommitment?> complete(String id) =>
      updateStatus(id, status: FollowUpStatus.completed);

  Future<FollowUpCommitment?> pause(String id) =>
      updateStatus(id, status: FollowUpStatus.paused);

  Future<FollowUpCommitment?> resume(String id) => updateStatus(
        id,
        status: FollowUpStatus.active,
        permission: FollowUpPermissionState.granted,
      );

  Future<FollowUpCommitment?> cancel(String id) =>
      updateStatus(id, status: FollowUpStatus.cancelled);

  bool maySurfaceReturn(FollowUpCommitment c, FollowUpDueContext ctx) =>
      _due.isDue(c, ctx);

  Future<List<FollowUpCommitment>> dueCommitments(
    FollowUpDueContext ctx,
  ) async {
    final all = await listAll();
    return all.where((c) => _due.isDue(c, ctx)).toList(growable: false);
  }
}
