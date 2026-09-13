import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

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

/// TTS على الجهاز عبر flutter_tts — لا يعتمد على AI Provider.
class DeviceTextToSpeechService implements TextToSpeechService {
  DeviceTextToSpeechService({
    FlutterTts? tts,
    VoiceSettingsService? settings,
  })  : _tts = tts ?? FlutterTts(),
        _settings = settings ?? VoiceSettingsService();

  final FlutterTts _tts;
  final VoiceSettingsService _settings;
  final ValueNotifier<bool> _speaking = ValueNotifier(false);
  bool _initialized = false;
  List<dynamic>? _cachedVoices;

  @override
  bool get isSpeaking => _speaking.value;

  @override
  Listenable get speakingListenable => _speaking;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => _speaking.value = true);
      _tts.setCompletionHandler(() => _speaking.value = false);
      _tts.setCancelHandler(() => _speaking.value = false);
      _tts.setErrorHandler((msg) {
        debugPrint('TTS plugin error: $msg');
        _speaking.value = false;
      });
      if (!kIsWeb) {
        // native-only tuning happens in _applyVoiceProfile
      }
    } catch (e, st) {
      debugPrint('TTS initialize failed: $e\n$st');
    }
  }

  Future<void> _applyVoiceProfile(AssistantVoiceGender gender) async {
    if (kIsWeb) return;

    try {
      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(0.45);

      final pitch = gender == AssistantVoiceGender.female ? 1.15 : 0.92;
      await _tts.setPitch(pitch);
    } catch (e, st) {
      debugPrint('TTS voice profile language/pitch failed: $e\n$st');
    }

    try {
      _cachedVoices ??= await _tts.getVoices;
      final voicesRaw = _cachedVoices;
      if (voicesRaw is! List) return;

      Map<String, String>? preferred;
      Map<String, String>? neutralArabic;
      Map<String, String>? anyArabic;

      Map<String, String> voiceMap(Map<String, dynamic> map) => {
            if (map['name'] != null) 'name': map['name'].toString(),
            if (map['locale'] != null) 'locale': map['locale'].toString(),
          };

      for (final entry in voicesRaw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);

        final locale =
            '${map['locale'] ?? map['language'] ?? ''}'.toLowerCase();
        if (!locale.startsWith('ar')) continue;

        final candidate = voiceMap(map);
        anyArabic ??= candidate;

        final nameLower = '${map['name'] ?? ''}'.toLowerCase();
        final genderField =
            '${map['gender'] ?? map['voiceGender'] ?? ''}'.toLowerCase();

        final isFemaleHint = genderField.contains('female') ||
            genderField.contains('woman') ||
            nameLower.contains('female') ||
            nameLower.contains('woman') ||
            nameLower.contains('sara') ||
            nameLower.contains('zira') ||
            nameLower.contains('amira') ||
            nameLower.contains('layla') ||
            nameLower.contains('laila') ||
            nameLower.contains('noura') ||
            nameLower.contains('hoda') ||
            nameLower.contains('salma') ||
            nameLower.contains('maja') ||
            nameLower.contains('tessa');

        final isMaleHint = (genderField.contains('male') &&
                !genderField.contains('female')) ||
            nameLower.contains('maged') ||
            nameLower.contains('tarik') ||
            nameLower.contains('nawfal') ||
            nameLower.contains('oustaz') ||
            nameLower.contains('rocko') ||
            nameLower.contains('sami') ||
            (nameLower.contains('male') && !nameLower.contains('female'));

        if (gender == AssistantVoiceGender.female) {
          if (isFemaleHint) preferred ??= candidate;
          if (!isMaleHint) neutralArabic ??= candidate;
        } else {
          if (isMaleHint && !isFemaleHint) preferred ??= candidate;
          if (!isFemaleHint) neutralArabic ??= candidate;
        }
      }

      // preferred gender → neutral arabic → any arabic. لا يرمي Error.
      final picked = preferred ?? neutralArabic ?? anyArabic;
      if (picked != null && picked['name']?.isNotEmpty == true) {
        await _tts.setVoice(picked);
      }
    } catch (e, st) {
      debugPrint('TTS getVoices/setVoice failed: $e\n$st');
    }
  }

  @override
  Future<void> speak(String text, {AssistantVoiceGender? genderOverride}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await initialize();
    await stop();

    final gender = genderOverride ?? await _settings.getGender();
    await _applyVoiceProfile(gender);

    try {
      if (kIsWeb) {
        try {
          await _tts.setLanguage('ar-SA');
        } catch (_) {
          try {
            await _tts.setLanguage('ar');
          } catch (_) {}
        }
      }
      _speaking.value = true;
      await _tts.speak(trimmed);
    } catch (e, st) {
      _speaking.value = false;
      debugPrint('TTS speak failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e, st) {
      debugPrint('TTS stop failed: $e\n$st');
    }
    _speaking.value = false;
  }

  void dispose() {
    try {
      unawaited(_tts.stop());
    } catch (_) {}
    _speaking.dispose();
  }
}
