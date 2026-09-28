import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';

void main() {
  group('package visibility hide/show', () {
    test('lab package copyWith toggles isActive for hide', () {
      const pkg = LabPackageItem(
        id: 'p1',
        labId: 'l1',
        name: 'باقة دم',
        isActive: true,
      );
      final hidden = pkg.copyWith(isActive: false);
      expect(hidden.isActive, isFalse);
      expect(hidden.name, 'باقة دم');
      expect(pkg.copyWith(isActive: true).isActive, isTrue);
    });

    test('lab package fromMap reads is_active for admin/owner hide', () {
      final shown = LabPackageItem.fromMap({
        'id': 'a',
        'lab_id': 'l',
        'package_name': 'باقة',
        'is_active': true,
      });
      final hidden = LabPackageItem.fromMap({
        'id': 'b',
        'lab_id': 'l',
        'package_name': 'باقة',
        'is_active': false,
      });
      expect(shown.isActive, isTrue);
      expect(hidden.isActive, isFalse);
      expect(shown.toMap()['is_active'], isTrue);
      expect(hidden.toMap()['is_active'], isFalse);
    });

    test('pharmacy bundle isVisible hide works for admin and owner', () {
      const b = PharmacyBundle(
        id: 'immune',
        title: 'باقة',
        price: 1,
        oldPrice: 2,
        isVisible: true,
        imageUrl: 'https://example.com/x.jpg',
        supplements: ['Zinc'],
      );
      expect(b.copyWith(isVisible: false).isVisible, isFalse);
      final visible = PharmaciesCatalog.visibleOnly([
        b,
        b.copyWith(isVisible: false),
      ]);
      expect(visible, hasLength(1));
      expect(visible.single.isVisible, isTrue);
    });
  });
}
