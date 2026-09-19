import 'follow_up_models.dart';

class FollowUpStorageException implements Exception {
  FollowUpStorageException([this.message = 'storage_failed']);
  final String message;
  @override
  String toString() => 'FollowUpStorageException: $message';
}

abstract class FollowUpRepository {
  Future<FollowUpStore?> loadStore();
  Future<FollowUpStore> saveStore(FollowUpStore store);
  Future<void> clearStore();
}
