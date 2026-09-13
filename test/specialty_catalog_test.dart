import 'package:flutter_test/flutter_test.dart';

import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';

void main() {
  test('matches common Iraqi specialty names', () {
    expect(SpecialtyCatalog.match('طب الأطفال')?.id, 'pediatrics');
    expect(SpecialtyCatalog.match('أخصائي أنف وأذن')?.id, 'ent');
    expect(SpecialtyCatalog.match('جراحة عامة')?.id, 'general_surgery');
    expect(SpecialtyCatalog.match('القلب')?.icon, isNotNull);
  });

  test('home shortcuts prefer popular specialties with doctors', () {
    final shortcuts = SpecialtyCatalog.homeShortcuts(const [
      'طب الأطفال',
      'طب الأطفال',
      'الجلدية',
      'اختصاص نادر جدًا',
    ], limit: 3);
    expect(shortcuts.first, 'طب الأطفال');
    expect(shortcuts, contains('الجلدية'));
  });

  test('counts group synonym specialties', () {
    final counts = SpecialtyCatalog.countBySpecialty(const [
      'الأطفال',
      'طب الأطفال',
      'باطنية',
    ]);
    expect(counts['طب الأطفال'], 2);
    expect(counts['الباطنية'], 1);
  });
}
