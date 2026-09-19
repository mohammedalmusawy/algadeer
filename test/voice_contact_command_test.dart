import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';

void main() {
  group('VoiceContactCommand.call', () {
    test('parses doctor call', () {
      final cmd = VoiceContactCommand.tryParse('اتصل بالدكتور علي ناصر');
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.call);
      expect(cmd.targetQuery, contains('علي'));
      expect(cmd.targetQuery.toLowerCase(), isNot(contains('اتصل')));
    });

    test('parses lab call', () {
      final cmd = VoiceContactCommand.tryParse('اتصل بمختبر الغدير');
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.call);
      expect(cmd.targetQuery, contains('الغدير'));
    });

    test('ignores normal search', () {
      expect(VoiceContactCommand.tryParse('الدكتور علي ناصر'), isNull);
      expect(VoiceContactCommand.tryParse('تحليل الدم'), isNull);
    });
  });

  group('VoiceContactCommand.whatsapp', () {
    test('parses whatsapp target', () {
      final cmd = VoiceContactCommand.tryParse('واتساب الدكتور علي');
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.whatsapp);
      expect(cmd.targetQuery, contains('علي'));
    });

    test('parses whatsapp with message', () {
      final cmd = VoiceContactCommand.tryParse(
        'رسالة واتساب لمختبر الغدير: أريد موعد باقة',
      );
      expect(cmd, isNotNull);
      expect(cmd!.kind, VoiceContactKind.whatsapp);
      expect(cmd.targetQuery, contains('الغدير'));
      expect(cmd.message, contains('موعد'));
    });
  });
}
