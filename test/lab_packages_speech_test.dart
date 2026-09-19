import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/voice/arabic_speech_numbers.dart';
import 'package:ghadeer_clinic/voice/lab_packages_speech.dart';

void main() {
  group('ArabicSpeechNumbers', () {
    test('reads common IQD prices without digits', () {
      expect(ArabicSpeechNumbers.moneyIq(25000), 'خمسة وعشرين ألف دينار');
      expect(ArabicSpeechNumbers.moneyIq(75000), 'خمسة وسبعين ألف دينار');
      expect(ArabicSpeechNumbers.toWords(100000), 'مائة ألف');
      expect(ArabicSpeechNumbers.percent(25), 'خمسة وعشرين بالمئة');
    });

    test('ordinals for packages', () {
      expect(ArabicSpeechNumbers.ordinal(1), 'الأولى');
      expect(ArabicSpeechNumbers.ordinal(2), 'الثانية');
    });
  });

  test('builds arabic speech for lab packages with spoken prices', () {
    const packages = [
      LabPackageItem(
        id: '1',
        labId: 'lab',
        name: 'باقة الفحص الشامل',
        description: 'تشمل تحاليل الدم والسكر',
        oldPrice: 100000,
        newPrice: 75000,
        analysesCount: 12,
      ),
      LabPackageItem(
        id: '2',
        labId: 'lab',
        name: 'باقة الكبد',
        newPrice: 40000,
        analysesCount: 5,
      ),
    ];

    final text = LabPackagesSpeech.build(
      labName: 'مختبر الغدير',
      packages: packages,
    );

    expect(text, contains('مختبر الغدير'));
    expect(text, isNot(contains('مختبر مختبر')));
    expect(text, contains('اثنان من الباقات'));
    expect(text, contains('باقة الأولى'));
    expect(text, contains('باقة الفحص الشامل'));
    expect(text, contains('خمسة وسبعين ألف دينار'));
    expect(text, contains('مائة ألف دينار'));
    expect(text, isNot(contains('75,000')));
    expect(text, isNot(contains('75000')));
    expect(text, contains('باقة الكبد'));
    expect(text, contains('اثنا عشر'));
  });

  test('buildOne includes analysis names and spoken price', () {
    final package = LabPackageItem(
      id: '1',
      labId: 'lab',
      name: 'باقة الكبد',
      newPrice: 40000,
      analyses: [
        AnalysisItem.fromName('ALT'),
        AnalysisItem.fromName('AST'),
      ],
    );

    final text = LabPackagesSpeech.buildOne(
      package,
      labName: 'مختبر النور',
    );

    expect(text, contains('مختبر النور'));
    expect(text, contains('باقة الكبد'));
    expect(text, contains('أربعين ألف دينار'));
    expect(text, contains('التحاليل المشمولة'));
    expect(text, contains('ALT'));
    expect(text, contains('AST'));
    expect(text, isNot(contains('40,000')));
  });
}
