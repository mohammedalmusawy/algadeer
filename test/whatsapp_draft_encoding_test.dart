import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/utils/clinic_contact_message.dart';
import 'package:ghadeer_clinic/utils/contact_launch.dart';

void main() {
  test('مسودة واتساب بلا � ورقم الوجهة لا يتغيّر', () {
    final msg = ClinicContactMessage.whatsAppPrefill(
      patientFullName: 'محمد',
      providerTitle: 'ناجي',
    );
    expect(msg.contains('\uFFFD'), isFalse);
    expect(msg.contains('🌿'), isFalse);
    expect(msg.contains('🙏'), isFalse);
    expect(msg, contains('السلام عليكم'));
    expect(msg, contains('د. ناجي'));

    final dirty = ClinicContactMessage.render(
      template: 'مرحبا� {طبيب}',
      providerTitle: 'سامي',
    );
    expect(dirty.contains('\uFFFD'), isFalse);
    expect(dirty, contains('د. سامي'));

    final uri = clinicWhatsAppUri('07801234567', message: msg)!;
    expect(uri.host, 'wa.me');
    expect(uri.path, contains('9647801234567'));
    expect(uri.queryParameters['text'], isNot(contains('\uFFFD')));
  });
}
