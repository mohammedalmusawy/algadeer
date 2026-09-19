import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/arabic_speech_numbers.dart';

void main() {
  test('edge number forms', () {
    expect(ArabicSpeechNumbers.toWords(0), 'صفر');
    expect(ArabicSpeechNumbers.toWords(1), 'واحد');
    expect(ArabicSpeechNumbers.toWords(2), 'اثنان');
    expect(ArabicSpeechNumbers.toWords(11), 'أحد عشر');
    expect(ArabicSpeechNumbers.toWords(21), 'واحد وعشرين');
    expect(ArabicSpeechNumbers.toWords(2000), 'ألفان');
    expect(ArabicSpeechNumbers.toWords(3000), 'ثلاثة آلاف');
    expect(ArabicSpeechNumbers.toWords(25000), 'خمسة وعشرين ألف');
    expect(ArabicSpeechNumbers.toWords(40000), 'أربعين ألف');
    expect(ArabicSpeechNumbers.toWords(101000), 'مائة وواحد ألف');
    expect(ArabicSpeechNumbers.toWords(125000), 'مائة وخمسة وعشرين ألف');
  });
}
