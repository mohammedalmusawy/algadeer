import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/voice_specialty_search_command.dart';

void main() {
  test('parses ابحثلي عن طبيب جملة عصبية', () {
    final cmd = VoiceSpecialtySearchCommand.tryParse(
      'ابحثلي عن طبيب جملة عصبية',
    );
    expect(cmd, isNotNull);
    expect(cmd!.resolvedSpecialtyName, 'الجملة العصبية');
    expect(cmd.specialtyQuery.toLowerCase(), contains('جملة'));
  });

  test('parses أطباء الأطفال', () {
    final cmd = VoiceSpecialtySearchCommand.tryParse('أطباء الأطفال');
    expect(cmd, isNotNull);
    expect(cmd!.resolvedSpecialtyName, 'طب الأطفال');
  });

  test('ignores call commands', () {
    expect(
      VoiceSpecialtySearchCommand.tryParse('اتصل بالدكتور علي'),
      isNull,
    );
  });

  test('ignores plain doctor name search', () {
    expect(
      VoiceSpecialtySearchCommand.tryParse('الدكتور علي ناصر'),
      isNull,
    );
    expect(
      VoiceSpecialtySearchCommand.tryParse('دكتور ناجي'),
      isNull,
    );
  });
}
