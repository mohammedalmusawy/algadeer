import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'arabic_voice_selector.dart';
import 'macos_arabic_tts_channel.dart';
import 'voice_settings.dart';

/// طبقة TTS مستقلة — قابلة للاستبدال (جهاز، Edge، مزود خارجي).
abstract class TextToSpeechService {
  Future<void> initialize();

  Future<void> speak(String text, {AssistantVoiceGender? genderOverride});

  Future<void> stop();

  bool get isSpeaking;

  /// للواجهات — تحديث عند بدء/انتهاء النطق.
  Listenable get speakingListenable;
}

/// TTS على الجهاز عبر flutter_tts — عربي فقط، بدون Samantha وبدون أنثى مزيفة بـ pitch.
/// على macOS يُدمَج اكتشاف Spoken Content / Siri Voice 2 (Soha) عبر قناة أصلية.
class DeviceTextToSpeechService implements TextToSpeechService {
  DeviceTextToSpeechService({FlutterTts? tts, VoiceSettingsService? settings})
    : _tts = tts ?? FlutterTts(),
      _settings = settings ?? VoiceSettingsService();

  final FlutterTts _tts;
  final VoiceSettingsService _settings;
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  bool _initialized = false;
  List<dynamic>? _cachedVoices;
  List<Map<String, dynamic>>? _cachedMacExtraVoices;
  AssistantVoiceGender? _lastAppliedGender;
  ArabicTtsVoiceChoice? _lastChoice;
  String? _lastDiagnostic;
  int _utteranceEpoch = 0;
  bool _usingNativeMacSpeak = false;

  ArabicTtsVoiceChoice? get lastAppliedChoice => _lastChoice;
  String? get lastDiagnostic => _lastDiagnostic;

  /// هل آخر اختيار أنثى كان صوتًا أنثويًا عربيًا حقيقيًا؟
  bool get lastFemaleWasGenuine =>
      _lastChoice?.isGenuineFemale == true &&
      _lastChoice?.reason == 'genuine_arabic_female';

  /// يجهّز Soha/Samer حسب الجنس قبل أي نطق — بدون flutter_tts/إنجليزي.
  /// يرجع null إن لم يكن صوت Siri العربي جاهزًا (تخطَّ الترحيب بأمان).
  Future<ArabicTtsVoiceChoice?> prepareArabicSiriVoice(
    AssistantVoiceGender gender,
  ) async {
    await initialize();
    _cachedVoices = null;
    _cachedMacExtraVoices = null;
    _lastAppliedGender = gender;
    debugPrint('TTS PREPARE SIRI for ${_lastAppliedGender?.name}');

    final maps = await _loadVoiceMaps(forceRefresh: true);
    _lastDiagnostic = ArabicTtsVoiceSelector.formatDiagnostic(maps);
    debugPrint(
      'TTS PREPARE SIRI:\n$_lastDiagnostic',
    );

    final choice = ArabicTtsVoiceSelector.select(voices: maps, gender: gender);
    _lastChoice = choice;
    if (choice == null) {
      debugPrint('TTS PREPARE SIRI: no choice for ${gender.name}');
      return null;
    }

    final id = choice.identifier.toLowerCase();
    final ready = switch (gender) {
      AssistantVoiceGender.female =>
        choice.isGenuineFemale &&
            id.contains('soha') &&
            MacOSArabicTtsChannel.needsSystemVoiceSpeak(choice.identifier),
      AssistantVoiceGender.male =>
        choice.isGenuineMale &&
            id.contains('samer') &&
            MacOSArabicTtsChannel.needsSystemVoiceSpeak(choice.identifier),
    };

    debugPrint(
      'TTS PREPARE SIRI result ready=$ready '
      'name=${choice.name} id=${choice.identifier} reason=${choice.reason}',
    );
    if (!ready) {
      _lastChoice = null;
      return null;
    }
    // لا نستدعي setLanguage/setVoice على flutter_tts هنا — يمنع مسار إنجليزي.
    return choice;
  }

  /// ينطق جملة واحدة عبر مسار Siri المحضَّر فقط (بدون الإنجليزية).
  Future<bool> speakPreparedSiriUtterance(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final choice = _lastChoice;
    if (choice == null ||
        !MacOSArabicTtsChannel.needsSystemVoiceSpeak(choice.identifier)) {
      debugPrint(
        'TTS speakPreparedSiri ABORT: no prepared Siri voice '
        '(refusing English/flutter_tts fallback)',
      );
      return false;
    }

    final epoch = ++_utteranceEpoch;
    final scalars = trimmed.runes
        .take(24)
        .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
        .join(' ');
    debugPrint(
      'TTS speakPreparedSiri START id=${choice.identifier} '
      'text="$trimmed" len=${trimmed.length} '
      'transport=macos_say_stdin_utf8 scalars=[$scalars]',
    );

    try {
      _usingNativeMacSpeak = true;
      _speaking.value = true;
      final ok = await MacOSArabicTtsChannel.speak(
        text: trimmed,
        identifier: choice.identifier,
      );
      if (epoch != _utteranceEpoch) {
        debugPrint(
          'TTS speakPreparedSiri INTERRUPTED by stop/epoch '
          'id=${choice.identifier}',
        );
        await MacOSArabicTtsChannel.stop();
        return false;
      }
      debugPrint(
        'TTS speakPreparedSiri END ok=$ok id=${choice.identifier}',
      );
      return ok;
    } catch (e, st) {
      debugPrint('TTS speakPreparedSiri FAILED: $e\n$st');
      return false;
    } finally {
      _usingNativeMacSpeak = false;
      _speaking.value = false;
    }
  }

  @override
  bool get isSpeaking => _speaking.value;

  @override
  Listenable get speakingListenable => _speaking;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _settings.migrateInvalidLegacyVoicePrefs();
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        if (!_usingNativeMacSpeak) _speaking.value = true;
      });
      _tts.setCompletionHandler(() {
        if (!_usingNativeMacSpeak) _speaking.value = false;
      });
      _tts.setCancelHandler(() {
        if (!_usingNativeMacSpeak) _speaking.value = false;
      });
      _tts.setErrorHandler((msg) {
        debugPrint('TTS plugin error: $msg');
        if (!_usingNativeMacSpeak) _speaking.value = false;
      });
    } catch (e, st) {
      debugPrint('TTS initialize failed: $e\n$st');
    }
  }

  /// تشخيص مؤقت: يعيد كتلة نصية بكل الأصوات العربية المكتشفة.
  Future<String> diagnoseArabicVoices() async {
    await initialize();
    final maps = await _loadVoiceMaps(forceRefresh: true);
    final block = ArabicTtsVoiceSelector.formatDiagnostic(maps);
    final femaleSel = ArabicTtsVoiceSelector.select(
      voices: maps,
      gender: AssistantVoiceGender.female,
    );
    final maleSel = ArabicTtsVoiceSelector.select(
      voices: maps,
      gender: AssistantVoiceGender.male,
    );
    final full = StringBuffer()
      ..writeln(block)
      ..writeln(
        'SELECTED FEMALE: '
        '${femaleSel == null ? '[none]' : 'name=${femaleSel.name} / locale=${femaleSel.locale} / identifier=${femaleSel.identifier} / gender=${femaleSel.platformGender} / reason=${femaleSel.reason} / genuineFemale=${femaleSel.isGenuineFemale}'}',
      )
      ..writeln(
        'SELECTED MALE: '
        '${maleSel == null ? '[none]' : 'name=${maleSel.name} / locale=${maleSel.locale} / identifier=${maleSel.identifier} / gender=${maleSel.platformGender} / reason=${maleSel.reason}'}',
      );
    if (femaleSel?.isGenuineFemale != true) {
      full.writeln(
        'NO ARABIC FEMALE VOICE INSTALLED/AVAILABLE ON THIS DEVICE.',
      );
    }
    _lastDiagnostic = full.toString();
    debugPrint(
      '\n========== TTS VOICE DIAGNOSTIC ==========\n$_lastDiagnostic',
    );
    debugPrint('========== END TTS VOICE DIAGNOSTIC ==========\n');
    return _lastDiagnostic!;
  }

  Future<List<Map<String, dynamic>>> _loadVoiceMaps({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _cachedVoices = null;
      _cachedMacExtraVoices = null;
    }
    _cachedVoices ??= await _tts.getVoices;
    final voicesRaw = _cachedVoices;
    final maps = <Map<String, dynamic>>[];
    if (voicesRaw is List) {
      for (final entry in voicesRaw) {
        if (entry is Map) maps.add(Map<String, dynamic>.from(entry));
      }
    }

    if (MacOSArabicTtsChannel.isSupported) {
      _cachedMacExtraVoices ??=
          await MacOSArabicTtsChannel.discoverArabicVoices();
      final seen = <String>{
        for (final m in maps)
          '${m['identifier'] ?? m['id'] ?? ''}'.toLowerCase(),
      };
      for (final extra in _cachedMacExtraVoices!) {
        final id = '${extra['identifier'] ?? extra['id'] ?? ''}'.toLowerCase();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        maps.add(extra);
      }
    }
    return maps;
  }

  Future<void> _applyVoiceProfile(AssistantVoiceGender gender) async {
    if (kIsWeb) {
      await _setArabicLanguage('ar-SA');
      try {
        await _tts.setSpeechRate(0.9);
        await _tts.setPitch(1.0);
      } catch (_) {}
      return;
    }

    // Always refresh discovery so Siri Voice 1/2 stay available after gender flips.
    _cachedVoices = null;
    _cachedMacExtraVoices = null;
    _lastAppliedGender = gender;

    try {
      await _tts.setVolume(1.0);
      final rate = defaultTargetPlatform == TargetPlatform.android
          ? 0.48
          : 0.40;
      await _tts.setSpeechRate(rate);
    } catch (e, st) {
      debugPrint('TTS volume/rate failed: $e\n$st');
    }

    final maps = await _loadVoiceMaps();
    _lastDiagnostic = ArabicTtsVoiceSelector.formatDiagnostic(maps);
    debugPrint(
      '\n========== TTS VOICE DIAGNOSTIC ==========\n$_lastDiagnostic',
    );

    final choice = ArabicTtsVoiceSelector.select(voices: maps, gender: gender);
    _lastChoice = choice;

    debugPrint(
      'TTS RUNTIME requestedGender=${gender.name} '
      'resolvedName=${choice?.name} resolvedLocale=${choice?.locale} '
      'resolvedId=${choice?.identifier} reason=${choice?.reason} '
      'platformGender=${choice?.platformGender}',
    );

    if (gender == AssistantVoiceGender.female &&
        (choice == null || !choice.isGenuineFemale)) {
      debugPrint(
        'NO ARABIC FEMALE VOICE INSTALLED/AVAILABLE ON THIS DEVICE. '
        'Keeping Arabic via male/default Arabic voice — NOT pretending female.',
      );
    }

    if (choice == null) {
      debugPrint('TTS: no Arabic voice — setLanguage(ar-SA) only.');
      await _setArabicLanguage('ar-SA');
      await _tts.setPitch(1.0);
      debugPrint('========== END TTS VOICE DIAGNOSTIC ==========\n');
      return;
    }

    try {
      await _setArabicLanguage(choice.locale);
      debugPrint(
        'SELECTED ${gender.name.toUpperCase()}: '
        'name=${choice.name} / locale=${choice.locale} / '
        'identifier=${choice.identifier} / gender=${choice.platformGender} / '
        'reason=${choice.reason} / genuineFemale=${choice.isGenuineFemale}',
      );
      // أصوات Siri العصبية لا تُضبط عبر flutter_tts.setVoice — تُنطق لاحقًا أصليًا.
      if (!MacOSArabicTtsChannel.needsSystemVoiceSpeak(choice.identifier)) {
        await _tts.setVoice(choice.toFlutterVoiceMap());
      }
    } catch (e, st) {
      debugPrint('TTS setVoice/language failed: $e\n$st');
      await _setArabicLanguage('ar-SA');
    }

    // لا نرفع pitch لتمويه صوت ذكر كأنثى.
    try {
      await _tts.setPitch(1.0);
    } catch (_) {}
    debugPrint('========== END TTS VOICE DIAGNOSTIC ==========\n');
  }

  Future<void> _setArabicLanguage(String preferred) async {
    final candidates = <String>[
      preferred,
      preferred.replaceAll('_', '-'),
      preferred.replaceAll('-', '_'),
      'ar-SA',
      'ar_SA',
      'ar-001',
      'ar_001',
      'ar',
    ];
    final tried = <String>{};
    for (final id in candidates) {
      if (id.isEmpty || !tried.add(id)) continue;
      if (!ArabicTtsVoiceSelector.isArabicLocale(id) && id != 'ar') continue;
      try {
        await _tts.setLanguage(id);
        return;
      } catch (_) {}
    }
  }

  @override
  Future<void> speak(
    String text, {
    AssistantVoiceGender? genderOverride,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await initialize();

    final epoch = ++_utteranceEpoch;
    if (_speaking.value) {
      await _stopEngine();
      if (epoch != _utteranceEpoch) return;
    }

    final gender = genderOverride ?? await _settings.getGender();
    await _applyVoiceProfile(gender);
    if (epoch != _utteranceEpoch) return;

    final choice = _lastChoice;
    final useNativeMac =
        choice != null &&
        MacOSArabicTtsChannel.needsSystemVoiceSpeak(choice.identifier);

    debugPrint(
      'TTS RUNTIME speakPath=${useNativeMac ? "macos_spoken_content_say" : "flutter_tts"} '
      'gender=${gender.name} identifier=${choice?.identifier}',
    );

    try {
      if (epoch != _utteranceEpoch) return;
      _speaking.value = true;
      if (useNativeMac) {
        _usingNativeMacSpeak = true;
        final rate = defaultTargetPlatform == TargetPlatform.android
            ? 0.48
            : 0.40;
        final ok = await MacOSArabicTtsChannel.speak(
          text: trimmed,
          identifier: choice.identifier,
          rate: rate,
        );
        if (epoch != _utteranceEpoch) {
          await MacOSArabicTtsChannel.stop();
        }
        if (!ok) {
          debugPrint(
            'TTS native macOS speak failed for ${choice.identifier}; '
            'not falling back to English.',
          );
        }
      } else {
        _usingNativeMacSpeak = false;
        await _tts.speak(trimmed);
      }
      if (epoch != _utteranceEpoch) {
        _speaking.value = false;
      } else if (useNativeMac) {
        _speaking.value = false;
      }
    } catch (e, st) {
      _speaking.value = false;
      debugPrint('TTS speak failed: $e\n$st');
      rethrow;
    } finally {
      if (useNativeMac) _usingNativeMacSpeak = false;
    }
  }

  @override
  Future<void> stop() async {
    debugPrint(
      'TTS stop() called — epoch will bump; '
      'nativeSpeaking=$_usingNativeMacSpeak speaking=${_speaking.value}',
    );
    _utteranceEpoch++;
    await _stopEngine();
  }

  Future<void> _stopEngine() async {
    if (!_speaking.value && !_usingNativeMacSpeak) return;
    try {
      if (_usingNativeMacSpeak || MacOSArabicTtsChannel.isSupported) {
        await MacOSArabicTtsChannel.stop();
      }
      await _tts.stop();
    } catch (e, st) {
      debugPrint('TTS stop failed: $e\n$st');
    }
    _usingNativeMacSpeak = false;
    _speaking.value = false;
  }

  void dispose() {
    _utteranceEpoch++;
    try {
      if (_usingNativeMacSpeak) {
        unawaited(MacOSArabicTtsChannel.stop());
      }
      if (_speaking.value) {
        unawaited(_tts.stop());
      }
    } catch (_) {}
    _usingNativeMacSpeak = false;
    _speaking.value = false;
    _speaking.dispose();
  }
}
