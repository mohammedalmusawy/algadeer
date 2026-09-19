import '../../health/subject/health_subject_models.dart';
import 'family_person_profile.dart';
import 'person_reference_resolver.dart';

/// ربط جلسة صحية بشخص دائم — PC-1.8.
class PersonIdentityLink {
  const PersonIdentityLink({
    required this.personId,
    required this.relationship,
    this.preferredName,
  });

  final String personId;
  final PersonRelationship relationship;
  final String? preferredName;

  PersistentPersonRef get persistentRef => PersistentPersonRef(personId);

  HealthSubjectContext applyToSubject(HealthSubjectContext subject) {
    return subject.copyWith(
      linkedPersonId: personId,
      type: _resolver.toHealthSubjectType(relationship),
    );
  }

  static const _resolver = PersonReferenceResolver();

  static PersonIdentityLink? fromProfile(FamilyPersonProfile profile) {
    return PersonIdentityLink(
      personId: profile.personId,
      relationship: profile.relationship,
      preferredName: profile.effectiveName,
    );
  }
}
