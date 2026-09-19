import 'memory_candidate.dart';

/// مستودع ذاكرة شخصية مستقبلي — عقد فقط.
///
/// PC-0.4:
/// - لا تنفيذ مستودع بعيد
/// - لا تنفيذ تفضيلات محلية دائمة
/// - لا يُنشأ في الإنتاج
/// - لا يكتب بيانات
abstract class PersonalMemoryRepository {
  Future<List<MemoryCandidate>> list();
  Future<void> create(MemoryCandidate candidate);
  Future<void> update(MemoryCandidate candidate);
  Future<void> delete(String id);
  Future<void> disableUse(String id);
}

/// حارس يمنع تفعيل مستودع حقيقي قبل Personal Companion.
class PersonalMemoryRepositoryGuard {
  const PersonalMemoryRepositoryGuard();

  /// الإنتاج يجب ألا يملك مثيلاً مفعّلاً في PC-0.4.
  bool get isProductionRepositoryEnabled => false;

  Never denyInstantiation(String reason) {
    throw UnsupportedError(
      'PersonalMemoryRepository must not be used in PC-0.4: $reason',
    );
  }
}
