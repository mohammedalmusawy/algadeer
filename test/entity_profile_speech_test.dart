import 'package:flutter_test/flutter_test.dart';

import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/voice/entity_profile_speech.dart';

void main() {
  test('pharmacyBundles يقرأ اسم الصيدلية وعدد الباقات', () {
    final text = EntityProfileSpeech.pharmacyBundles(
      pharmacyName: 'الشفاء',
      bundles: const [
        PharmacyBundle(
          id: '1',
          title: 'باقة الحديد',
          price: 25000,
          oldPrice: 0,
          subtitle: 'حديد وفولات',
        ),
        PharmacyBundle(
          id: '2',
          title: 'باقة المناعة',
          price: 30000,
          oldPrice: 0,
        ),
      ],
    );
    expect(text, contains('صيدلية الشفاء'));
    expect(text, contains('باقة الحديد'));
    expect(text, contains('باقة المناعة'));
    expect(text, isNot(contains('25000')));
  });

  test('placeProfile يبني نبذة للمستلزمات والعلاج', () {
    final text = EntityProfileSpeech.placeProfile(
      name: 'الغدير',
      kindLabel: 'مركز',
      slogan: 'حركة أفضل',
      description: 'تأهيل وعلاج طبيعي.',
      address: 'الكرادة',
      isOpenNow: true,
      tags: const ['علاج طبيعي', 'تأهيل'],
    );
    expect(text, contains('مركز الغدير'));
    expect(text, contains('مفتوح الآن'));
    expect(text, contains('الكرادة'));
    expect(text, contains('علاج طبيعي'));
  });
}
