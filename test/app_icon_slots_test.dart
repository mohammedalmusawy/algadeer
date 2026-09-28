import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/branding/app_icon_slots.dart';

void main() {
  test('logo is never an editable icon slot', () {
    for (final slot in AppIconSlots.all) {
      expect(slot.id.startsWith('brand.logo'), isFalse);
      expect(slot.id, isNot('logo'));
    }
    expect(AppIconSlots.home, isNotEmpty);
    expect(AppIconSlots.nav.length, 5);
    expect(AppIconSlots.specialties, isNotEmpty);
  });

  test('home service ids map to slots', () {
    expect(AppIconSlots.homeSlotIdForService('doctors'), 'home.doctors');
    expect(AppIconSlots.byId('home.labs')?.titleAr, 'المختبرات');
  });
}
