import '../companion/people/subject_binding/subject_binding_models.dart';
import 'follow_up_models.dart';

/// أهلية إنشاء/استخدام التزام — حدود عائلية وذاكرة≠متابعة.
class FollowUpEligibilityPolicy {
  const FollowUpEligibilityPolicy();

  /// تشخيص/قياس/بحث لا يُنشئ التزاماً تلقائياً.
  bool mayAutoCreateFromMemoryOrDiagnosis() => false;

  bool mayAutoCreateFromMeasurement() => false;

  bool mayAutoCreateFromDoctorSearch() => false;

  bool mayAutoCreateFromPreventiveAdvice() => false;

  /// صحة العائلة وحدها لا تفوّض متابعة.
  bool familyHealthMemoryAuthorizesFollowUp() => false;

  /// متابعة مزمنة عائلية معطّلة في PC-1.11.
  bool familyChronicFollowUpEnabled() => false;

  bool mayCreateForSubject({
    required FollowUpSubjectRef subject,
    required FollowUpDomain domain,
  }) {
    if (subject.isAccountOwner) return true;
    // SubjectRef مدعوم معمارياً، لكن سلوك المتابعة المزمنة العائلية معطّل.
    if (domain == FollowUpDomain.chronicHealth) {
      return familyChronicFollowUpEnabled();
    }
    // التزامات عامة (زيارة/تحليل/هدف) لشخص دائم مسموحة عند أمر صريح لاحق.
    return subject.kind == FollowUpSubjectKind.persistentPerson;
  }

  FollowUpSubjectRef? subjectFromResolved(
    ResolvedConversationSubject resolved,
  ) {
    if (resolved.isAccountOwner ||
        resolved.subjectKind == ConversationSubjectKind.accountOwner) {
      return FollowUpSubjectRef.accountOwner;
    }
    if (resolved.hasPersistentBinding &&
        resolved.persistentPersonId != null) {
      return FollowUpSubjectRef.persistentPerson(resolved.persistentPersonId!);
    }
    return null;
  }
}
