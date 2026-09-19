import 'package:shared_preferences/shared_preferences.dart';

import 'companion_onboarding_models.dart';

/// تفضيل onboarding محلي — منفصل عن الملف الشخصي وعن الذاكرة الصحية.
class CompanionOnboardingPreferenceStore {
  CompanionOnboardingPreferenceStore({SharedPreferences? prefs})
      : _prefs = prefs;

  SharedPreferences? _prefs;

  static const prefsKey = 'pc_onboarding_pref_v1';

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
  }

  Future<CompanionOnboardingPreferenceKind> load() async {
    final p = await _ensure();
    final raw = p.getString(prefsKey)?.trim() ?? '';
    for (final v in CompanionOnboardingPreferenceKind.values) {
      if (v.name == raw) return v;
    }
    return CompanionOnboardingPreferenceKind.none;
  }

  Future<void> save(CompanionOnboardingPreferenceKind kind) async {
    final p = await _ensure();
    if (kind == CompanionOnboardingPreferenceKind.none) {
      await p.remove(prefsKey);
    } else {
      await p.setString(prefsKey, kind.name);
    }
  }
}
