import 'family_sensitive_health_models.dart';

class FamilySensitiveHealthStorageException implements Exception {
  FamilySensitiveHealthStorageException([this.message = 'storage_failed']);
  final String message;
  @override
  String toString() => 'FamilySensitiveHealthStorageException: $message';
}

/// مستودع صحة العائلة الحسّاسة — محلي أولاً.
abstract class FamilySensitiveHealthRepository {
  Future<FamilySensitiveHealthStore?> loadStore();
  Future<FamilySensitiveHealthStore> saveStore(FamilySensitiveHealthStore store);
  Future<void> clearStore();
}
