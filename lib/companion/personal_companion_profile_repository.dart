import 'personal_companion_profile.dart';

/// مستودع ملف Personal Companion — منفصل عن Memory/Health/Family.
abstract class PersonalCompanionProfileRepository {
  Future<PersonalCompanionProfile?> loadProfile();
  Future<PersonalCompanionProfile> createProfile({
    String? preferredName,
    bool profileEnabled = true,
  });
  Future<PersonalCompanionProfile> updateProfile(
    PersonalCompanionProfile profile,
  );
  Future<PersonalCompanionProfile> clearOptionalField(
    PersonalCompanionProfile profile,
    ProfileOptionalField field,
  );
  Future<PersonalCompanionProfile> disableProfile(
    PersonalCompanionProfile profile,
  );
  Future<void> deleteProfile();
}

enum ProfileOptionalField {
  preferredName,
  profilePhotoUrl,
  birthDate,
  birthYear,
  sexSelection,
  userContext,
}

/// خطأ تحقق إدخال الملف (ميلاد مستقبلي، إلخ).
class ProfileValidationException implements Exception {
  ProfileValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
