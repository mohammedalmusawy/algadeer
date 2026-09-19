import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/voice_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceSettingsService', () {
    late VoiceSettingsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = VoiceSettingsService();
      service.setPrefsForTesting(prefs);
    });

    test('default gender is male (ذكر)', () async {
      expect(await service.getGender(), AssistantVoiceGender.male);
    });

    test('default auto play is off', () async {
      expect(await service.getAutoPlayResponses(), isFalse);
    });

    test('persists gender locally', () async {
      await service.setGender(AssistantVoiceGender.female);
      expect(await service.getGender(), AssistantVoiceGender.female);

      await service.setGender(AssistantVoiceGender.male);
      expect(await service.getGender(), AssistantVoiceGender.male);
    });

    test('persists auto play locally', () async {
      await service.setAutoPlayResponses(true);
      expect(await service.getAutoPlayResponses(), isTrue);

      await service.setAutoPlayResponses(false);
      expect(await service.getAutoPlayResponses(), isFalse);
    });
  });

  group('AssistantVoiceGender', () {
    test('fromStorage defaults to male', () {
      expect(
        AssistantVoiceGender.fromStorage(null),
        AssistantVoiceGender.male,
      );
      expect(
        AssistantVoiceGender.fromStorage('unknown'),
        AssistantVoiceGender.male,
      );
    });

    test('labels in Arabic', () {
      expect(AssistantVoiceGender.male.labelAr, 'ذكر');
      expect(AssistantVoiceGender.female.labelAr, 'أنثى');
    });
  });
}
