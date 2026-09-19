import 'package:shared_preferences/shared_preferences.dart';

import '../companion/local_personal_companion_profile_repository.dart';
import '../companion/personal_companion_profile_service.dart';

/// اسم المستخدم المحلي (اختياري) — للمساعد الذكي والمناداة.
///
/// PC-1.1: المصدر السلطوي للاسم هو PersonalCompanionProfile.preferredName
/// عبر [PersonalCompanionProfileService]. هذا الصنف واجهة توافق تحافظ على
/// استدعاءات onboarding/settings/greeting دون سلطة مزدوجة.
class UserProfileService {
  UserProfileService({
    SharedPreferences? prefs,
    PersonalCompanionProfileService? companion,
  })  : _prefs = prefs,
        _companion = companion ??
            PersonalCompanionProfileService(
              repository: LocalPersonalCompanionProfileRepository(prefs: prefs),
            );

  SharedPreferences? _prefs;
  final PersonalCompanionProfileService _companion;

  static const nameKey = 'user_display_name';
  static const onboardingDoneKey = 'user_name_onboarding_done';

  PersonalCompanionProfileService get companion => _companion;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isOnboardingDone() async {
    final p = await _ensure();
    return p.getBool(onboardingDoneKey) ?? false;
  }

  /// الاسم السلطوي للتخصيص/الترحيب — من الملف الشخصي إن وُجد ومُفعّل،
  /// مع ترحيل تلقائي من [nameKey] القديم.
  Future<String?> getDisplayName() async {
    try {
      final fromCompanion = await _companion.preferredNameForPersonalization();
      if (fromCompanion != null) return fromCompanion;
      final profile = await _companion.loadProfile();
      if (profile != null && !profile.profileEnabled) return null;
    } catch (_) {
      // استمر للمسار القديم.
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
    final p = await _ensure();
    await p.setBool(onboardingDoneKey, true);
  }

  Future<void> skipOnboarding() async {
    final p = await _ensure();
    await p.setBool(onboardingDoneKey, true);
  }

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
