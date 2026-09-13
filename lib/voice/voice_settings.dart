import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نوع صوت المساعد — محلي فقط، غير مرتبط بمزود AI.
enum AssistantVoiceGender {
  male,
  female;

  String get storageValue => name;

  String get labelAr {
    switch (this) {
      case AssistantVoiceGender.female:
        return 'بنت';
      case AssistantVoiceGender.male:
        return 'ولد';
    }
  }

  static AssistantVoiceGender fromStorage(String? raw) {
    if (raw == 'female') return AssistantVoiceGender.female;
    return AssistantVoiceGender.male;
  }
}

/// إعدادات الصوت المحلية (SharedPreferences).
class VoiceSettingsService {
  VoiceSettingsService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  static const _keyGender = 'voice_assistant_gender';
  static const _keyAutoPlay = 'voice_auto_play_responses';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// الافتراضي: ولد
  Future<AssistantVoiceGender> getGender() async {
    final prefs = await _ensurePrefs();
    return AssistantVoiceGender.fromStorage(prefs.getString(_keyGender));
  }

  /// هل المستخدم حدّد جنس الصوت صراحةً؟
  /// إذا لم يكن موجودًا، نعتبره "أول استخدام" ونظهر اختيار بسيط.
  Future<bool> isGenderExplicitlySet() async {
    final prefs = await _ensurePrefs();
    return prefs.containsKey(_keyGender);
  }

  Future<void> setGender(AssistantVoiceGender gender) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_keyGender, gender.storageValue);
  }

  /// الافتراضي: OFF
  Future<bool> getAutoPlayResponses() async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_keyAutoPlay) ?? false;
  }

  Future<void> setAutoPlayResponses(bool value) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_keyAutoPlay, value);
  }

  @visibleForTesting
  void setPrefsForTesting(SharedPreferences prefs) {
    _prefs = prefs;
  }
}
