import '../personal_companion_profile.dart';
import 'family_person_profile.dart';
import 'family_person_profile_repository.dart';
import 'local_family_person_profile_repository.dart';

/// خدمة ملفات الأشخاص — CRUD محلي، بلا بيانات صحية.
class FamilyPersonProfileService {
  FamilyPersonProfileService({
    FamilyPersonProfileRepository? repository,
  }) : _repo = repository ?? LocalFamilyPersonProfileRepository();

  final FamilyPersonProfileRepository _repo;

  FamilyPersonProfileRepository get repository => _repo;

  Future<List<FamilyPersonProfile>> loadEnabledProfiles() async {
    final all = await _repo.loadAll();
    return all.where((p) => p.profileEnabled).toList(growable: false);
  }

  Future<List<FamilyPersonProfile>> loadAllProfiles() => _repo.loadAll();

  Future<FamilyPersonProfile?> findById(String id) => _repo.findById(id);

  Future<FamilyPersonProfile> createProfile({
    required PersonRelationship relationship,
    String? preferredName,
    int? birthYear,
    DateTime? birthDate,
    ProfileSexSelection? sexSelection,
  }) async {
    final now = DateTime.now();
    return _repo.create(
      FamilyPersonProfile(
        personId: '',
        ownerKey: '',
        relationship: relationship,
        preferredName: preferredName,
        birthYear: birthYear,
        birthDate: birthDate,
        sexSelection: sexSelection,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<FamilyPersonProfile> updateProfile(FamilyPersonProfile profile) {
    return _repo.update(
      profile.copyWith(updatedAt: DateTime.now()),
    );
  }

  Future<FamilyPersonProfile> disableProfile(String personId) async {
    final p = await _repo.findById(personId);
    if (p == null) throw StateError('not found');
    return updateProfile(p.copyWith(profileEnabled: false));
  }

  Future<void> deleteProfile(String personId) => _repo.deleteById(personId);

  int countProfiles(List<FamilyPersonProfile> profiles) => profiles.length;
}
