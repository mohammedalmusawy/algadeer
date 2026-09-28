import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/voice_input_service.dart';

void main() {
  group('اتصل دكتور ناجي — صوت vs كتابة', () {
    test('النية واحدة للصيغ الشائعة', () {
      final r = RuleBasedIntentResolver();
      for (final q in const [
        'اتصل دكتور ناجي',
        'اتصل بدكتور ناجي',
        'اتصل بالدكتور ناجي',
      ]) {
        final contact = VoiceContactCommand.tryParse(q);
        final intent = r.resolve(q);
        expect(contact?.targetQuery, 'ناجي', reason: q);
        expect(intent.intent, AssistantIntent.callDoctor, reason: q);
        expect(intent.entities.doctorName, 'ناجي', reason: q);
        expect(intent.requiresContext, isFalse, reason: q);
      }
    });

    test('إطلاق الاتصال لا ينتظر TTS (announce لا يحجب launch)', () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      expect(
        page.contains('await _voice.speak(\'جاري الاتصال'),
        isFalse,
        reason: 'يجب ألا يُنتظر نطق «جاري الاتصال» قبل tel:',
      );
      expect(page.contains('launchClinicCall(result.effectivePhone)'), isTrue);
      expect(
        page.contains("unawaited(_voice.speak('جاري الاتصال بـ \${result.title}'))"),
        isTrue,
      );
    });

    test('مهلة الصمت كافية لجملة اتصال قصيرة', () {
      expect(
        VoiceInputService().silenceAfterSpeech,
        greaterThanOrEqualTo(const Duration(milliseconds: 3500)),
      );
    });
  });
}
