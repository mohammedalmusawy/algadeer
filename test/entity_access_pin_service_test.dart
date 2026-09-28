import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/services/entity_access_pin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EntityAccessPinService.instance.debugReloadFromPrefs();
  });

  test('validatePinFormat allows flexible length (not fixed 6)', () {
    expect(EntityAccessPinService.validatePinFormat('Ab12'), isNull);
    expect(EntityAccessPinService.validatePinFormat('Ab12!@'), isNull);
    expect(EntityAccessPinService.validatePinFormat('12345678'), isNull);
    expect(EntityAccessPinService.validatePinFormat('123'), isNotNull);
    expect(EntityAccessPinService.validatePinFormat('12 456'), isNotNull);
  });

  test('set and verify entity pin; admin can be set separately', () async {
    final s = EntityAccessPinService.instance;
    await s.setAdminPin('AdminSecret99');
    await s.setEntityPin(
      EntityAccessPinService.pharmacyKey('rehab'),
      'Ph@rm',
    );

    expect(await s.verifyAdmin('AdminSecret99'), isTrue);
    expect(await s.verifyAdmin('wrong1'), isFalse);
    expect(
      await s.verifyEntity(
        EntityAccessPinService.pharmacyKey('rehab'),
        'Ph@rm',
      ),
      isTrue,
    );
    expect(
      await s.verifyEntity(
        EntityAccessPinService.pharmacyKey('rehab'),
        'xxxxxx',
      ),
      isFalse,
    );
  });

  test('verifyEntityOrAdmin accepts admin pin silently', () async {
    final s = EntityAccessPinService.instance;
    final key = EntityAccessPinService.labKey('hayat');
    await s.setAdminPin('MasterPin2026');
    await s.setEntityPin(key, 'LabPin');

    expect(await s.verifyEntityOrAdmin(key, 'LabPin'), isTrue);
    expect(await s.verifyEntityOrAdmin(key, 'MasterPin2026'), isTrue);
    expect(await s.verifyEntityOrAdmin(key, 'nope'), isFalse);
  });

  test('forgot pin WhatsApp message mentions Ghadeer and entity', () {
    final msg = EntityAccessPinService.forgotPinWhatsAppMessage(
      entityTitle: 'صيدلية رحاب',
      entityKey: 'pharmacy:rehab',
    );
    expect(msg, contains('نسيت الرقم السري'));
    expect(msg, contains('منصة الغدير'));
    expect(msg, contains('صيدلية رحاب'));
    expect(
      EntityAccessPinService.adminSupportWhatsAppDigits,
      '9647822202288',
    );
  });

  test('session stays unlocked until clearSession (exit settings)', () {
    final s = EntityAccessPinService.instance;
    final key = EntityAccessPinService.pharmacyKey('rehab');

    expect(s.hasValidSession(key), isFalse);
    s.grantSession(key);
    expect(s.hasValidSession(key), isTrue);
    s.clearSession(key);
    expect(s.hasValidSession(key), isFalse);
  });
}
