import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/utils/contact_launch.dart';

void main() {
  test('اتصال يستخدم tel كما هو', () {
    expect(clinicTelUri('07800000000').toString(), 'tel:07800000000');
    // رموز الاتجاه المخفية والمسافات من قاعدة البيانات تُشال من رابط الاتصال.
    expect(
      clinicTelUri('\u202D0787 540 4000\u202C').toString(),
      'tel:07875404000',
    );
    expect(clinicTelUri('+964 787 540 4000').toString(), 'tel:+9647875404000');
  });

  test('واتساب العراقي يتحول إلى wa.me بـ 964', () {
    expect(clinicWhatsAppDigits('07801112233'), '9647801112233');
    expect(
      clinicWhatsAppUri('07801112233')!.toString(),
      'https://wa.me/9647801112233',
    );
    expect(
      clinicWhatsAppUri('+964 780 111 2233', message: 'هلا')!.toString(),
      contains('https://wa.me/9647801112233?text='),
    );
  });

  test('عنوان بلا رابط يصبح بحث خرائط وليس uri نسبي', () {
    final uri = clinicMapUri('الكرادة، الشطرة');
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['query'], 'الكرادة، الشطرة');
  });

  test('رابط خرائط http يبقى كما هو', () {
    expect(
      clinicMapUri('https://maps.google.com/?q=x').toString(),
      'https://maps.google.com/?q=x',
    );
  });

  test('روابط غير http مرفوضة للإعلان', () {
    expect(isExternalHttpUrl('javascript:alert(1)'), isFalse);
    expect(isExternalHttpUrl('https://example.com/offer'), isTrue);
    expect(isExternalHttpUrl(''), isFalse);
  });
}
