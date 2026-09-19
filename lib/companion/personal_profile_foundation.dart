import 'personal_companion_profile.dart';
import 'personal_companion_profile_repository.dart';
import 'personal_companion_profile_service.dart';

/// Phase 3A — واجهة نظيفة فوق [PersonalCompanionProfile] القائم.
///
/// لا نظام ملف ثانٍ. الاسم الثلاثي يُخزَّن في [PersonalCompanionProfile.preferredName]
/// (سلطة الاسم الحالية). العمر يُشتق من birthDate ثم birthYear — ليس حقل عمر ثابت.
///
/// لا يخزّن أعراضاً/أمراضاً ولا يكتب إلى ConversationContext/healthSubject.
class PersonalProfileFoundation {
  PersonalProfileFoundation({
    PersonalCompanionProfileService? profiles,
  }) : _profiles = profiles ?? PersonalCompanionProfileService();

  final PersonalCompanionProfileService _profiles;

  PersonalCompanionProfileService get profiles => _profiles;

  Future<PersonalCompanionProfile?> load() => _profiles.loadProfile();

  /// اسم العرض / الاسم الثلاثي (نفس preferredName القائم).
  Future<String?> displayName() async {
    final p = await load();
    return p?.effectivePreferredName;
  }

  Future<String?> fullName() => displayName();

  Future<int?> ageYears({DateTime? now}) async {
    final p = await load();
    return p?.currentAge(now: now);
  }

  Future<ProfileSexSelection?> sex() async {
    final p = await load();
    return p?.sexSelection;
  }

  /// ملف أساسي مكتمل: اسم + (ميلاد أو سنة) + جنس ذكر/أنثى.
  Future<bool> isBasicProfileComplete() async {
    final p = await load();
    return isProfileBasicallyComplete(p);
  }

  static bool isProfileBasicallyComplete(PersonalCompanionProfile? p) {
    if (p == null || !p.profileEnabled) return false;
    final name = p.effectivePreferredName;
    if (name == null || name.isEmpty) return false;
    if (p.birthDate == null && p.birthYear == null) return false;
    if (p.currentAge() == null) return false;
    final sex = p.sexSelection;
    return sex == ProfileSexSelection.male ||
        sex == ProfileSexSelection.female;
  }

  /// حفظ الحد الأدنى المطلوب لـ Phase 3A.
  Future<PersonalCompanionProfile> saveBasicProfile({
    required String fullName,
    DateTime? birthDate,
    int? birthYear,
    int? ageYears,
    required ProfileSexSelection sex,
    DateTime? now,
  }) async {
    final name = fullName.trim();
    if (name.isEmpty) {
      throw ProfileValidationException('empty_full_name');
    }
    if (sex != ProfileSexSelection.male &&
        sex != ProfileSexSelection.female) {
      throw ProfileValidationException('invalid_sex');
    }

    final clock = now ?? DateTime.now();
    DateTime? resolvedDate = birthDate;
    int? resolvedYear = birthYear;

    if (resolvedDate == null && resolvedYear == null && ageYears != null) {
      if (ageYears < 1 || ageYears > 120) {
        throw ProfileValidationException('invalid_age');
      }
      resolvedYear = clock.year - ageYears;
    }

    if (resolvedDate == null && resolvedYear == null) {
      throw ProfileValidationException('missing_birth');
    }

    // تحقق مبكر قبل الكتابة.
    if (resolvedDate != null) {
      if (resolvedDate.isAfter(clock)) {
        throw ProfileValidationException('future_birth_date');
      }
      final probe = PersonalCompanionProfile(
        profileId: 'probe',
        ownerKey: 'probe',
        birthDate: resolvedDate,
        createdAt: clock,
        updatedAt: clock,
      );
      if (probe.currentAge(now: clock) == null) {
        throw ProfileValidationException('invalid_birth_date');
      }
    }
    if (resolvedYear != null) {
      if (resolvedYear > clock.year || resolvedYear < clock.year - 130) {
        throw ProfileValidationException('invalid_birth_year');
      }
    }

    await _profiles.savePreferredName(name);
    if (resolvedDate != null) {
      await _profiles.setBirthDate(resolvedDate);
    } else {
      await _profiles.setBirthYear(resolvedYear);
    }
    return _profiles.setSexSelection(sex);
  }

  /// يفسّر حقل «تاريخ الميلاد / العمر» البسيط.
  ///
  /// - تاريخ ISO أو yyyy-mm-dd → birthDate
  /// - 4 أرقام (1900–السنة الحالية) → birthYear
  /// - 1–3 أرقام (1–120) → ageYears
  static ParsedBirthInput? parseBirthOrAgeInput(
    String raw, {
    DateTime? now,
  }) {
    final t = raw.trim();
    if (t.isEmpty) return null;

    final date = DateTime.tryParse(t);
    if (date != null && t.contains('-')) {
      return ParsedBirthInput(birthDate: date);
    }

    final digits = RegExp(r'^(\d{1,4})$').firstMatch(t);
    if (digits != null) {
      final v = int.parse(digits.group(1)!);
      final clock = now ?? DateTime.now();
      if (t.length == 4) {
        if (v > clock.year || v < clock.year - 130) return null;
        return ParsedBirthInput(birthYear: v);
      }
      if (v >= 1 && v <= 120) {
        return ParsedBirthInput(ageYears: v);
      }
    }
    return null;
  }
}

class ParsedBirthInput {
  const ParsedBirthInput({
    this.birthDate,
    this.birthYear,
    this.ageYears,
  });

  final DateTime? birthDate;
  final int? birthYear;
  final int? ageYears;
}
