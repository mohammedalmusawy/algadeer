import '../people/subject_binding/subject_binding_models.dart';
import 'personalization_models.dart';

/// جدار خصوصية التخصيص — لا يتجاوز سياسات الصحة.
class PersonalizationPrivacyPolicy {
  const PersonalizationPrivacyPolicy();

  PersonalizationSubjectKind mapSubject(ResolvedConversationSubject resolved) {
    switch (resolved.subjectKind) {
      case ConversationSubjectKind.accountOwner:
        return PersonalizationSubjectKind.accountOwner;
      case ConversationSubjectKind.persistentPerson:
        return PersonalizationSubjectKind.persistentFamilyPerson;
      case ConversationSubjectKind.temporaryOtherPerson:
        return PersonalizationSubjectKind.temporaryOtherPerson;
      case ConversationSubjectKind.ambiguousPerson:
        return PersonalizationSubjectKind.ambiguous;
      case ConversationSubjectKind.unknownPerson:
        return PersonalizationSubjectKind.unknown;
    }
  }

  bool mayUseOwnerPersonalMemory(PersonalizationSubjectKind subject) =>
      subject == PersonalizationSubjectKind.accountOwner ||
      subject == PersonalizationSubjectKind.unknown;

  bool mayUseOwnerHealth(PersonalizationSubjectKind subject) =>
      subject == PersonalizationSubjectKind.accountOwner;

  bool mayUseFamilyHealth({
    required PersonalizationSubjectKind subject,
    required PersonalizationPurpose purpose,
    required bool hasPersistentPerson,
    required bool healthRelevant,
  }) {
    if (subject != PersonalizationSubjectKind.persistentFamilyPerson) {
      return false;
    }
    if (!hasPersistentPerson) return false;
    if (!healthRelevant) return false;
    return purpose == PersonalizationPurpose.healthGuidance ||
        purpose == PersonalizationPurpose.chronicCare ||
        purpose == PersonalizationPurpose.preventiveGuidance;
  }

  bool blocksSensitiveRetrieval(PersonalizationSubjectKind subject) =>
      subject == PersonalizationSubjectKind.ambiguous ||
      subject == PersonalizationSubjectKind.temporaryOtherPerson;

  /// لا تكشف الذاكرة المحجوبة في نص الرفض.
  String blockedWithoutLeakMessage() => '';
}
