import 'sensitive_health_profile_models.dart';

/// مستودع ملف الصحة الحسّاس — منفصل عن PersonalCompanion / analytics.
abstract class SensitiveHealthProfileRepository {
  Future<SensitiveHealthProfile?> loadProfile();
  Future<SensitiveHealthProfile> createEmptyProfile();
  Future<SensitiveHealthProfile> saveProfile(SensitiveHealthProfile profile);
  Future<void> deleteProfile();
}

/// فشل تخزين — لا يُترجم إلى «تم الحفظ».
class SensitiveHealthStorageException implements Exception {
  SensitiveHealthStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}
