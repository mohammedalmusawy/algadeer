import 'package:shared_preferences/shared_preferences.dart';

import '../companion/local_personal_companion_profile_repository.dart';
import '../companion/personal_companion_profile_service.dart';
import '../companion/personal_profile_foundation.dart';

/// اسم المستخدم المحلي (اختياري) — للمساعد الذكي والمناداة.
///
/// PC-1.1: المصدر السلطوي للاسم هو PersonalCompanionProfile.preferredName
/// عبر [PersonalCompanionProfileService]. هذا الصنف واجهة توافق تحافظ على
/// استدعاءات onboarding/settings/greeting دون سلطة مزدوجة.
///
/// Phase 3A: الميلاد/الجنس عبر [foundation] / companion فقط — ليس أعمدة سحابية.
class UserProfileService {
  UserProfileService({
    SharedPreferences? prefs,
    PersonalCompanionProfileService? companion,
    PersonalProfileFoundation? foundation,
  })  : _prefs = prefs,
        _companion = companion ??
            PersonalCompanionProfileService(
              repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
            ),
        _foundation = foundation;

  SharedPreferences? _prefs;
  final PersonalCompanionProfileService _companion;
  PersonalProfileFoundation? _foundation;

  static const nameKey = 'user_display_name';
  static const onboardingDoneKey = 'user_name_onboarding_done';

  PersonalCompanionProfileService get companion => _companion;

  PersonalProfileFoundation get foundation =>
      _foundation ??= PersonalProfileFoundation(profiles: _companion);

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isOnboardingDone() async {
    final p = await _ensure();
    return p.getBool(onboardingDoneKey) ?? false;
  }

  /// الاسم السلطوي للتخصيص/الترحيب — من الملف الشخصي إن وُجد ومُفعّل،
  /// مع ترحيل تلقائي من [nameKey] السابق.
  Future<String?> getDisplayName() async {
    try {
      final fromCompanion = await _companion.preferredNameForPersonalization();
      if (fromCompanion != null) return fromCompanion;
      final profile = await _companion.loadProfile();
      if (profile != null && !profile.profileEnabled) return null;
    } catch (_) {
      // استمر للمسار السابق.
    }
    final p = await _ensure();
    final n = p.getString(nameKey)?.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  Future<void> saveDisplayName(String? name) async {
    final trimmed = name?.trim() ?? '';
    try {
      await _companion.savePreferredName(trimmed.isEmpty ? null : trimmed);
    } catch (_) {
      final p = await _ensure();
      if (trimmed.isEmpty) {
        await p.remove(nameKey);
      } else {
        await p.setString(nameKey, trimmed);
      }
    }
    await markFirstLaunchFinished();
  }

  /// يغلق بوابة أول تشغيل بعد حفظ الملف الأساسي أو التخطي.
  Future<void> markFirstLaunchFinished() async {
    final p = await _ensure();
    await p.setBool(onboardingDoneKey, true);
  }

  Future<void> skipOnboarding() => markFirstLaunchFinished();

  static String addressByName(String text, String? name) {
    final body = text.trim();
    if (body.isEmpty) return body;
    final n = name?.trim() ?? '';
    if (n.isEmpty) return body;
    if (body.startsWith(n) ||
        body.startsWith('يا $n') ||
        body.startsWith('أهلًا $n') ||
        body.startsWith('مرحبا $n') ||
        body.startsWith('مرحباً $n')) {
      return body;
    }
    return 'يا $n، $body';
  }

  static String forSpeechWithoutNameAddress(String text) {
    var body = text.trim();
    if (body.isEmpty) return body;
    body = body.replaceFirst(
      RegExp(
        r'^(?:يا|أهلًا|اهلا|مرحبًا|مرحباً|مرحبا)\s+[^،,\n]{1,40}\s*[،,]\s*',
      ),
      '',
    );
    return body.trim();
  }
}
