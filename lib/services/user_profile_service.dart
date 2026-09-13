import 'package:shared_preferences/shared_preferences.dart';

/// اسم المستخدم المحلي (اختياري) — للمساعد الذكي والمناداة.
class UserProfileService {
  UserProfileService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const nameKey = 'user_display_name';
  static const onboardingDoneKey = 'user_name_onboarding_done';

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<bool> isOnboardingDone() async {
    final p = await _ensure();
    return p.getBool(onboardingDoneKey) ?? false;
  }

  Future<String?> getDisplayName() async {
    final p = await _ensure();
    final n = p.getString(nameKey)?.trim() ?? '';
    return n.isEmpty ? null : n;
  }

  Future<void> saveDisplayName(String? name) async {
    final p = await _ensure();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      await p.remove(nameKey);
    } else {
      await p.setString(nameKey, trimmed);
    }
    await p.setBool(onboardingDoneKey, true);
  }

  Future<void> skipOnboarding() async {
    final p = await _ensure();
    await p.setBool(onboardingDoneKey, true);
  }

  /// يضيف مناداة بالاسم في بداية الرد إن وُجد اسم.
  static String addressByName(String text, String? name) {
    final body = text.trim();
    if (body.isEmpty) return body;
    final n = name?.trim() ?? '';
    if (n.isEmpty) return body;
    // لا نكرر إن كان الاسم موجودًا في البداية.
    if (body.startsWith(n) || body.startsWith('يا $n') || body.startsWith('أهلًا $n')) {
      return body;
    }
    return 'يا $n، $body';
  }
}
