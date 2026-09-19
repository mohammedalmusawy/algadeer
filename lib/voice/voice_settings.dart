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
        return 'أنثى';
      case AssistantVoiceGender.male:
        return 'ذكر';
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

  /// مفاتيح قديمة محتملة لمعرّف صوت محرك TTS — قد تشير لـ Samantha/إنجليزي.
  static const legacyVoiceIdentityKeys = <String>[
    'voice_tts_voice_name',
    'voice_tts_locale',
    'voice_tts_voice_id',
    'voice_female_voice_name',
    'voice_female_locale',
    'assistant_tts_voice',
    'assistant_tts_locale',
  ];

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// يُبطل أي تفضيل صوت إنجليزي/معرّف قديم مخزَّن — الجنس ذكر/أنثى يبقى.
  Future<bool> migrateInvalidLegacyVoicePrefs() async {
    final prefs = await _ensurePrefs();
    var cleared = false;
    for (final key in legacyVoiceIdentityKeys) {
      if (!prefs.containsKey(key)) continue;
      final raw = prefs.get(key)?.toString().toLowerCase() ?? '';
      final looksEnglish =
          raw.contains('samantha') ||
          raw.contains('karen') ||
          raw.startsWith('en') ||
          raw.contains('en-us') ||
          raw.contains('en_us') ||
          raw.contains('en-gb');
      // امسح المعرّفات القديمة دائمًا — الاختيار يُعاد اكتشافه من أصوات الجهاز.
      await prefs.remove(key);
      cleared = true;
      debugPrint(
        'VoiceSettings: cleared legacy key=$key englishHint=$looksEnglish',
      );
    }
    return cleared;
  }

  /// الافتراضي: ولد
  Future<AssistantVoiceGender> getGender() async {
    await migrateInvalidLegacyVoicePrefs();
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
