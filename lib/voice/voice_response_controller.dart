import 'dart:async';

import 'package:flutter/foundation.dart';

import 'text_to_speech_service.dart';
import 'voice_settings.dart';

/// تشغيل / إيقاف / إعادة الرد الصوتي — منفصل عن AI Logic.
class VoiceResponseController extends ChangeNotifier {
  VoiceResponseController({
    TextToSpeechService? tts,
    VoiceSettingsService? settings,
  })  : _tts = tts ?? DeviceTextToSpeechService(),
        _settings = settings ?? VoiceSettingsService() {
    _tts.speakingListenable.addListener(_onSpeakingChanged);
  }

  final TextToSpeechService _tts;
  final VoiceSettingsService _settings;

  String? _lastText;
  String? _lastError;

  String? get lastText => _lastText;
  String? get lastError => _lastError;
  bool get isSpeaking => _tts.isSpeaking;

  void _onSpeakingChanged() {
    notifyListeners();
  }

  /// يتحقق من إعداد التشغيل التلقائي قبل النطق — يرجع true إذا بدأ النطق.
  Future<bool> speakIfAutoEnabled(String text) async {
    final auto = await _settings.getAutoPlayResponses();
    if (!auto) return false;
    await speak(text);
    return true;
  }

  Future<void> speak(String text) async {
    _lastError = null;
    _lastText = text.trim();
    if (_lastText!.isEmpty) {
      _lastError = 'لا يوجد نص للنطق';
      notifyListeners();
      return;
    }

    try {
      await _tts.speak(_lastText!);
    } catch (e, st) {
      debugPrint('VoiceResponseController.speak failed: $e\n$st');
      _lastError = 'تعذّر تشغيل الصوت';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e, st) {
      debugPrint('VoiceResponseController.stop failed: $e\n$st');
    }
  }

  Future<void> replay() async {
    if (_lastText == null || _lastText!.isEmpty) {
      _lastError = 'لا يوجد رد سابق لإعادة التشغيل';
      notifyListeners();
      return;
    }
    await speak(_lastText!);
  }

  @override
  void dispose() {
    _tts.speakingListenable.removeListener(_onSpeakingChanged);
    unawaited(stop());
    final tts = _tts;
    if (tts is DeviceTextToSpeechService) {
      tts.dispose();
    }
    super.dispose();
  }
}
