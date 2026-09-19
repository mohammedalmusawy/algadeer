import 'package:ghadeer_clinic/companion/people/family_person_profile.dart';
import 'package:ghadeer_clinic/companion/personal_companion_profile.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_models.dart';

/// مسار عمر موحّد واحد — ليس مخزناً مستقلاً.
///
/// ترتيب الأسبقية:
/// explicitCurrentAge (دورة حالية)
/// > exactBirthDateDerived
/// > birthYearDerived
/// > approximateAge (محادثة/جلسة)
/// > unknown
///
/// لا يُستنتج العمر من الاسم/الصوت/الصورة/أسلوب الكتابة.
class AgeAuthorityResolver {
  const AgeAuthorityResolver();

  /// يستخرج عمراً صريحاً من العبارة إن وُجد (مثل «عمري 16»).
  int? parseExplicitAgeYears(String query) {
    final n = ArabicTextUtils.normalize(query);
    final m = RegExp(r'(?:عمري|عمره|عمرها|عمر)\s*(\d{1,2})').firstMatch(n);
    if (m == null) return null;
    final v = int.tryParse(m.group(1)!);
    if (v == null || v < 1 || v > 120) return null;
    return v;
  }

  /// عمر موضوع الجلسة: «عمره 8» أو «8 سنوات».
  /// لا يقبل رقماً عارياً، ولا «عمري» (عمر المالك).
  int? parseSessionSubjectAgeYears(String query) {
    final n = ArabicTextUtils.normalize(query.trim());
    if (n.isEmpty) return null;
    if (RegExp(r'(?:^|\s)عمري(?:\s|$)').hasMatch(n)) return null;
    final labeled = RegExp(r'(?:عمره|عمرها|عمر)\s*(\d{1,2})').firstMatch(n);
    if (labeled != null) {
      final v = int.tryParse(labeled.group(1)!);
      if (v != null && v >= 1 && v <= 120) return v;
    }
    final unit = RegExp(
      r'(?:^|\s)(\d{1,2})\s*(?:سنه|سنة|سنوات|سنين)(?:\s|$)',
    ).firstMatch(' $n ');
    if (unit == null) return null;
    final v = int.tryParse(unit.group(1)!);
    if (v == null || v < 1 || v > 120) return null;
    return v;
  }

  AgeResolution resolve({
    int? explicitAgeFromUtterance,
    DateTime? birthDate,
    int? birthYear,
    int? approximateAgeYears,
    DateTime? now,
  }) {
    if (explicitAgeFromUtterance != null &&
        explicitAgeFromUtterance >= 1 &&
        explicitAgeFromUtterance <= 120) {
      return AgeResolution(
        ageYears: explicitAgeFromUtterance,
        provenance: AgeProvenance.explicitCurrentAge,
      );
    }

    final clock = now ?? DateTime.now();
    if (birthDate != null) {
      var years = clock.year - birthDate.year;
      if (clock.month < birthDate.month ||
          (clock.month == birthDate.month && clock.day < birthDate.day)) {
        years -= 1;
      }
      if (years >= 0 && years <= 120) {
        return AgeResolution(
          ageYears: years,
          provenance: AgeProvenance.exactBirthDateDerived,
        );
      }
    }

    if (birthYear != null && birthYear >= 1900 && birthYear <= clock.year) {
      final years = clock.year - birthYear;
      if (years >= 0 && years <= 120) {
        return AgeResolution(
          ageYears: years,
          provenance: AgeProvenance.birthYearDerived,
        );
      }
    }

    if (approximateAgeYears != null &&
        approximateAgeYears >= 1 &&
        approximateAgeYears <= 120) {
      return AgeResolution(
        ageYears: approximateAgeYears,
        provenance: AgeProvenance.approximateAge,
      );
    }

    return AgeResolution.unknown;
  }

  AgeResolution resolveFromOwnerProfile(
    PersonalCompanionProfile? profile, {
    int? explicitAgeFromUtterance,
    DateTime? now,
  }) {
    return resolve(
      explicitAgeFromUtterance: explicitAgeFromUtterance,
      birthDate: profile?.birthDate,
      birthYear: profile?.birthYear,
      now: now,
    );
  }

  AgeResolution resolveFromFamilyPerson(
    FamilyPersonProfile? person, {
    int? explicitAgeFromUtterance,
    DateTime? now,
  }) {
    if (person == null) {
      return resolve(explicitAgeFromUtterance: explicitAgeFromUtterance, now: now);
    }
    return resolve(
      explicitAgeFromUtterance: explicitAgeFromUtterance,
      birthDate: person.birthDate,
      birthYear: person.birthYear,
      now: now,
    );
  }
}
