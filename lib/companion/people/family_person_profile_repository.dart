import 'family_person_profile.dart';

abstract class FamilyPersonProfileRepository {
  Future<List<FamilyPersonProfile>> loadAll();

  Future<FamilyPersonProfile?> findById(String personId);

  Future<FamilyPersonProfile> create(FamilyPersonProfile profile);

  Future<FamilyPersonProfile> update(FamilyPersonProfile profile);

  Future<void> deleteById(String personId);

  Future<void> clearAll();
}
