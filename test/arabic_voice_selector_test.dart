import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/arabic_voice_selector.dart';
import 'package:ghadeer_clinic/voice/voice_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ArabicTtsVoiceSelector genuine gender', () {
    final macLikeVoices = <Map<String, dynamic>>[
      {
        'name': 'Samantha',
        'locale': 'en-US',
        'identifier': 'com.apple.speech.synthesis.voice.Samantha',
        'gender': 'female',
      },
      {
        'name': 'Majed',
        'locale': 'ar-001',
        'identifier': 'com.apple.voice.compact.ar-001.Maged',
        'gender': 'male',
        'quality': 1,
      },
      {
        'name': 'Majed',
        'locale': 'ar-001',
        'identifier': 'com.apple.voice.super-compact.ar-001.Maged',
        'gender': 'male',
        'quality': 1,
      },
    ];

    test('this-Mac style: no genuine Arabic female; never English', () {
      final females = ArabicTtsVoiceSelector.femaleCandidates(macLikeVoices);
      expect(females, isEmpty);

      final choice = ArabicTtsVoiceSelector.select(
        voices: macLikeVoices,
        gender: AssistantVoiceGender.female,
      );
      expect(choice, isNotNull);
      expect(choice!.isGenuineFemale, isFalse);
      expect(choice.reason, 'no_arabic_female_available');
      expect(choice.name.toLowerCase(), contains('majed'));
      expect(choice.locale.toLowerCase(), contains('ar'));
      expect(choice.name.toLowerCase(), isNot(contains('samantha')));
    });

    test('male selects Majed only when Siri Voice 1 unavailable', () {
      final choice = ArabicTtsVoiceSelector.select(
        voices: macLikeVoices,
        gender: AssistantVoiceGender.male,
      );
      expect(choice, isNotNull);
      expect(choice!.identifier.toLowerCase(), contains('maged'));
      expect(choice.isGenuineMale, isTrue);
      expect(choice.reason, 'arabic_male_fallback');
    });

    test('genuine Arabic female selected when platform gender=female', () {
      final withLaila = [
        ...macLikeVoices,
        {
          'name': 'Laila',
          'locale': 'ar-SA',
          'identifier': 'com.apple.voice.compact.ar-SA.Laila',
          'gender': 'female',
          'quality': 2,
        },
      ];
      final choice = ArabicTtsVoiceSelector.select(
        voices: withLaila,
        gender: AssistantVoiceGender.female,
      );
      expect(choice!.isGenuineFemale, isTrue);
      expect(choice.reason, 'genuine_arabic_female');
      expect(choice.name.toLowerCase(), contains('laila'));
    });

    test('Siri Voice 2 female + Voice 1 male; Majed fallback only', () {
      final withSiri = [
        ...macLikeVoices,
        {
          'name': 'Soha',
          'locale': 'ar-SA',
          'identifier':
              'com.apple.ttsbundle.gryphon-neural_Soha_ar-SA_premium',
          'gender': 'female',
          'quality': 'premium',
          'source': 'spoken_content',
        },
        {
          'name': 'Samer',
          'locale': 'ar-SA',
          'identifier':
              'com.apple.ttsbundle.gryphon-neural_Samer_ar-SA_premium',
          'gender': 'male',
          'quality': 'premium',
          'source': 'asset',
        },
      ];
      final female = ArabicTtsVoiceSelector.select(
        voices: withSiri,
        gender: AssistantVoiceGender.female,
      );
      expect(female!.isGenuineFemale, isTrue);
      expect(
        female.identifier,
        'com.apple.ttsbundle.gryphon-neural_Soha_ar-SA_premium',
      );

      final male = ArabicTtsVoiceSelector.select(
        voices: withSiri,
        gender: AssistantVoiceGender.male,
      );
      expect(male!.isGenuineMale, isTrue);
      expect(
        male.identifier,
        'com.apple.ttsbundle.gryphon-neural_Samer_ar-SA_premium',
      );
      expect(male.reason, 'genuine_arabic_male_siri');
      expect(male.identifier.toLowerCase(), isNot(contains('maged')));
      expect(male.identifier.toLowerCase(), isNot(contains('soha')));
    });

    test('name-only Laila without gender is NOT treated as genuine female', () {
      final ambiguous = <Map<String, dynamic>>[
        {
          'name': 'Laila',
          'locale': 'ar-SA',
          'identifier': 'com.apple.voice.compact.ar-SA.Laila',
          // no gender field
        },
        {
          'name': 'Majed',
          'locale': 'ar-001',
          'identifier': 'com.apple.voice.compact.ar-001.Maged',
          'gender': 'male',
        },
      ];
      final females = ArabicTtsVoiceSelector.femaleCandidates(ambiguous);
      expect(females, isEmpty);
      final choice = ArabicTtsVoiceSelector.select(
        voices: ambiguous,
        gender: AssistantVoiceGender.female,
      );
      expect(choice!.isGenuineFemale, isFalse);
      expect(choice.reason, 'no_arabic_female_available');
    });

    test('diagnostic mentions no female when only Majed', () {
      final text = ArabicTtsVoiceSelector.formatDiagnostic(macLikeVoices);
      expect(text, contains('AVAILABLE ARABIC TTS VOICES:'));
      expect(text, contains('Majed'));
      expect(text, contains('NO ARABIC FEMALE VOICE'));
    });
  });

  group('VoiceSettingsService legacy migration', () {
    test('clears Samantha legacy keys and keeps gender', () async {
      SharedPreferences.setMockInitialValues({
        'voice_assistant_gender': 'female',
        'voice_tts_voice_name': 'Samantha',
        'voice_tts_locale': 'en-US',
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = VoiceSettingsService();
      settings.setPrefsForTesting(prefs);
      await settings.migrateInvalidLegacyVoicePrefs();
      expect(prefs.getString('voice_tts_voice_name'), isNull);
      expect(await settings.getGender(), AssistantVoiceGender.female);
    });
  });
}
