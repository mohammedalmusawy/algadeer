import 'package:ghadeer_clinic/companion/people/subject_binding/subject_binding_models.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/unified_brain/age_authority_resolver.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_models.dart';

/// Phase 3C — جسر آمن: ملف المالك → سياق الجلسة فقط عند تأكيد أن الموضوع هو المالك.
///
/// لا يُنشئ context/profile ثانياً.
/// لا يُعدّل الملف المخزَّن.
/// لا يسرّب العمر/الجنس إلى طفل/أم/أب/عائلة.
class OwnerProfileContextBridge {
  const OwnerProfileContextBridge({
    AgeAuthorityResolver ageResolver = const AgeAuthorityResolver(),
  }) : _age = ageResolver;

  final AgeAuthorityResolver _age;

  /// هل يجوز استخدام عمر/جنس PersonalCompanionProfile كملاذ سياقي؟
  bool mayApplyOwnerProfile({
    required HealthSubjectContext subject,
    required ResolvedConversationSubject resolved,
  }) {
    // موضوع معروف غير المالك → ممنوع دائماً.
    if (subject.isKnown && subject.type != HealthSubjectType.self) {
      return false;
    }
    // ذات مؤكدة.
    if (subject.type == HealthSubjectType.self) {
      return true;
    }
    // مالك الحساب مربوط صراحةً والموضوع ليس شخصاً آخر.
    if (resolved.isAccountOwner &&
        (!subject.isKnown || subject.type == HealthSubjectType.self)) {
      return true;
    }
    // موضوع مجهول → لا نفترض المالك تلقائياً (أسلم).
    return false;
  }

  /// عمر المالك عبر [AgeAuthorityResolver] القائم — بدون سلطة عمر منافسة.
  AgeResolution resolveAge({
    required PersonalCompanionProfile? profile,
    int? explicitAgeFromUtterance,
    DateTime? now,
  }) {
    return _age.resolveFromOwnerProfile(
      profile,
      explicitAgeFromUtterance: explicitAgeFromUtterance,
      now: now,
    );
  }

  /// جنس الملف — ذكر/أنثى فقط، ولا يُستنتج من أعراض.
  ProfileSexSelection? resolveSex({
    required PersonalCompanionProfile? profile,
  }) {
    final sex = profile?.sexSelection;
    if (sex == ProfileSexSelection.male ||
        sex == ProfileSexSelection.female) {
      return sex;
    }
    return null;
  }

  /// يenrich موضوع الجلسة بعمر/جنس المالك عند الجواز فقط — بدون مسح حقائق صريحة.
  HealthSubjectContext enrichSubjectIfAllowed({
    required HealthSubjectContext subject,
    required ResolvedConversationSubject resolved,
    required PersonalCompanionProfile? profile,
    DateTime? now,
  }) {
    if (!mayApplyOwnerProfile(subject: subject, resolved: resolved)) {
      // إزالة تلميح جنس المالك إن تسرّب لموضوع غير ذات.
      if (subject.type != HealthSubjectType.self &&
          subject.reservedSexHint != null) {
        return subject.copyWith(clearReservedSexHint: true);
      }
      return subject;
    }

    var next = subject;
    if (next.ageYears == null) {
      final age = resolveAge(profile: profile, now: now);
      if (age.ageYears != null) {
        next = next.copyWith(ageYears: age.ageYears);
      }
    }
    if (next.reservedSexHint == null) {
      final sex = resolveSex(profile: profile);
      if (sex != null) {
        next = next.copyWith(reservedSexHint: sex.name);
      }
    }
    return next;
  }
}
