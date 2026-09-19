import 'personal_companion_profile.dart';
import 'personal_companion_profile_repository.dart';
import 'local_personal_companion_profile_repository.dart';

/// خدمة ملف Personal Companion — CRUD + سياسات PC-1.1.
///
/// المصدر السلطوي للاسم المفضّل. [UserProfileService] يفوّض إليها.
class PersonalCompanionProfileService {
  PersonalCompanionProfileService({
    PersonalCompanionProfileRepository? repository,
  }) : _repo = repository ?? LocalPersonalCompanionProfileRepository();

  final PersonalCompanionProfileRepository _repo;

  PersonalCompanionProfileRepository get repository => _repo;

  Future<PersonalCompanionProfile?> loadProfile() => _repo.loadProfile();

  Future<PersonalCompanionProfile> ensureProfile({
    String? preferredName,
  }) async {
    final existing = await _repo.loadProfile();
    if (existing != null) return existing;
    return _repo.createProfile(preferredName: preferredName);
  }

  Future<PersonalCompanionProfile> createEmptyProfile() =>
      _repo.createProfile();

  Future<PersonalCompanionProfile> savePreferredName(String? name) async {
    final current = await ensureProfile();
    return _repo.updateProfile(
      current.copyWith(
        preferredName: name,
        clearPreferredName: name == null || name.trim().isEmpty,
      ),
    );
  }

  Future<String?> preferredNameForPersonalization() async {
    try {
      final p = await _repo.loadProfile();
      return p?.effectivePreferredName;
    } catch (_) {
      // فشل المستودع لا يكسر Smart Brain.
      return null;
    }
  }

  Future<PersonalCompanionProfile> setSexSelection(
    ProfileSexSelection? sex,
  ) async {
    final current = await ensureProfile();
    return _repo.updateProfile(
      current.copyWith(
        sexSelection: sex,
        clearSexSelection: sex == null,
      ),
    );
  }

  Future<PersonalCompanionProfile> setUserContext(
    ProfileUserContext? context,
  ) async {
    final current = await ensureProfile();
    return _repo.updateProfile(
      current.copyWith(
        userContext: context,
        clearUserContext: context == null,
      ),
    );
  }

  Future<PersonalCompanionProfile> setBirthDate(DateTime? date) async {
    final current = await ensureProfile();
    // عند تعيين birthDate الكامل نفضّل مسح birthYear المتعارض اختيارياً.
    return _repo.updateProfile(
      current.copyWith(
        birthDate: date,
        clearBirthDate: date == null,
        clearBirthYear: date != null,
      ),
    );
  }

  Future<PersonalCompanionProfile> setBirthYear(int? year) async {
    final current = await ensureProfile();
    return _repo.updateProfile(
      current.copyWith(
        birthYear: year,
        clearBirthYear: year == null,
        clearBirthDate: year != null,
      ),
    );
  }

  Future<PersonalCompanionProfile> setProfilePhotoUrl(String? url) async {
    final current = await ensureProfile();
    return _repo.updateProfile(
      current.copyWith(
        profilePhotoUrl: url,
        clearProfilePhotoUrl: url == null || url.trim().isEmpty,
      ),
    );
  }

  Future<PersonalCompanionProfile> clearField(ProfileOptionalField field) async {
    final current = await ensureProfile();
    return _repo.clearOptionalField(current, field);
  }

  Future<PersonalCompanionProfile> disable() async {
    final current = await ensureProfile();
    return _repo.disableProfile(current);
  }

  Future<PersonalCompanionProfile> enable() async {
    final current = await ensureProfile();
    return _repo.updateProfile(current.copyWith(profileEnabled: true));
  }

  /// حذف صريح فقط.
  Future<void> deleteProfileExplicitly() => _repo.deleteProfile();

  /// سياسة: لا استدلال جنس.
  bool mayInferSexFromName() => false;
  bool mayInferSexFromTtsVoice() => false;
  bool mayInferSexFromPhoto() => false;

  /// سياسة: لا تحليل صورة للسمات.
  bool mayAnalyzeProfilePhotoForAttributes() => false;

  Map<String, Object?> debugPresence({PersonalCompanionProfile? profile}) {
    if (profile == null) {
      return {
        'profileLoaded': false,
        'profileEnabled': false,
      };
    }
    return profile.debugPresenceMap();
  }
}
