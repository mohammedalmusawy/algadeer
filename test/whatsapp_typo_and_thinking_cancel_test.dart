import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';

void main() {
  group('واتساب بأخطاء إملائية + إنجليزي', () {
    final resolver = RuleBasedIntentResolver();

    test('وتساب / whatsapp / مارسل → messageDoctor باسم نظيف', () {
      for (final q in const [
        'أرسل رسالة وتساب لدكتور ناجي',
        'ارسل رسالة whatsapp لدكتور ناجي',
        'whatsapp دكتور ناجي',
        'ارسل رسالة مارسل واتساب لدكتور ناجي',
      ]) {
        final c = VoiceContactCommand.tryParse(q);
        final i = resolver.resolve(q);
        expect(c?.kind, VoiceContactKind.whatsapp, reason: q);
        expect(i.intent, AssistantIntent.messageDoctor, reason: q);
        expect(i.entities.doctorName, 'ناجي', reason: q);
        expect(i.entities.doctorName, isNot(contains('رسال')), reason: q);
      }
    });
  });

  group('أخطاء إملائية صغيرة لاسم الطبيب', () {
    test('توكن واحد قريب يطابق', () {
      final exact = const DoctorNameMatcher().score(
        doctorName: 'ناجي عبد الله الركابي',
        query: 'ناجي',
        doctorId: 'naji',
      );
      expect(exact.score, greaterThanOrEqualTo(80));

      final typo = const DoctorNameMatcher().score(
        doctorName: 'ناجي عبد الله الركابي',
        query: ArabicTextUtils.normalize('ناحي'),
        doctorId: 'naji',
      );
      expect(typo.score, greaterThanOrEqualTo(80));
    });
  });

  group('إيقاف التفكير', () {
    test('زر إلغاء التفكير موجود في الواجهة', () {
      final widgets =
          File('lib/search/conversation/smart_brain_chat_widgets.dart')
              .readAsStringSync();
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      expect(widgets.contains('smart_brain_thinking_cancel'), isTrue);
      expect(page.contains('_cancelInFlightTurn'), isTrue);
    });
  });
}
