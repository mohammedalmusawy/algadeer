import 'personal_memory_models.dart';

class PersonalMemoryStorageException implements Exception {
  PersonalMemoryStorageException([this.message = 'storage_failed']);
  final String message;
  @override
  String toString() => 'PersonalMemoryStorageException: $message';
}

abstract class PersonalMemoryRepository {
  Future<CompanionPersonalMemoryStore?> loadStore();
  Future<CompanionPersonalMemoryStore> saveStore(
    CompanionPersonalMemoryStore store,
  );
  Future<void> clearStore();
}
