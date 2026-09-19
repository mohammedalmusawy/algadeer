import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/voice/text_to_speech_service.dart';
import 'package:ghadeer_clinic/voice/voice_response_controller.dart';
import 'package:ghadeer_clinic/voice/voice_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تسجيل استدعاءات speak/stop للتحقق من عدم القطع التلقائي.
class _RecordingTts implements TextToSpeechService {
  final List<String> ops = [];
  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  @override
  bool get isSpeaking => _speaking.value;

  @override
  Listenable get speakingListenable => _speaking;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(
    String text, {
    AssistantVoiceGender? genderOverride,
  }) async {
    // يحاكي السياسة الصحيحة: لا stop تلقائي قبل speak إن لم يكن يتكلم.
    ops.add('speak:${text.trim()}');
    _speaking.value = true;
  }

  @override
  Future<void> stop() async {
    ops.add('stop');
    _speaking.value = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoiceSettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'voice_assistant_gender': 'female',
      'voice_auto_play_responses': true,
    });
    final prefs = await SharedPreferences.getInstance();
    settings = VoiceSettingsService();
    settings.setPrefsForTesting(prefs);
  });

  group('TTS interruption hotfix', () {
    test('single voice reply → one speak, no automatic stop', () async {
      final tts = _RecordingTts();
      final voice = VoiceResponseController(tts: tts, settings: settings);

      const sentence = 'وجدت لك طبيب أطفال مناسب';
      await voice.speak(sentence);

      expect(tts.ops, ['speak:$sentence']);
      expect(tts.ops.where((e) => e == 'stop'), isEmpty);
    });

    test('explicit stop after speak records stop once', () async {
      final tts = _RecordingTts();
      final voice = VoiceResponseController(tts: tts, settings: settings);

      await voice.speak('وجدت لك طبيب أطفال مناسب');
      await voice.stop();

      expect(tts.ops, ['speak:وجدت لك طبيب أطفال مناسب', 'stop']);
    });

    test('stop while idle does not call engine stop', () async {
      final tts = _RecordingTts();
      final voice = VoiceResponseController(tts: tts, settings: settings);

      await voice.stop();
      expect(tts.ops, isEmpty);
    });

    test('typed source still disallows auto speak', () {
      expect(QueryInputSource.typed.allowsAutoSpeak, isFalse);
      expect(QueryInputSource.voice.allowsAutoSpeak, isTrue);
    });

    test('new intentional speak may replace previous via controller', () async {
      final tts = _RecordingTts();
      final voice = VoiceResponseController(tts: tts, settings: settings);

      await voice.speak('الجملة الأولى');
      if (voice.isSpeaking) {
        await voice.stop();
      }
      await voice.speak('الجملة الثانية');

      expect(tts.ops, ['speak:الجملة الأولى', 'stop', 'speak:الجملة الثانية']);
    });
  });
}
