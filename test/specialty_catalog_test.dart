import 'package:flutter_test/flutter_test.dart';

import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';

void main() {
  test('matches common Iraqi specialty names', () {
    expect(SpecialtyCatalog.match('طب الأطفال')?.id, 'pediatrics');
    expect(SpecialtyCatalog.match('أخصائي أنف وأذن')?.id, 'ent');
    expect(SpecialtyCatalog.match('جراحة عامة')?.id, 'general_surgery');
    expect(SpecialtyCatalog.match('القلب')?.icon, isNotNull);
  });

  test('home shortcuts prefer curated chip order', () {
    final shortcuts = SpecialtyCatalog.homeShortcuts(const [
      'طب الأطفال',
      'طب الأطفال',
      'الجلدية',
      'اختصاص نادر جدًا',
    ], limit: 3);
    // الترتيب من homeChipIds الثابت (الجراحة أولاً) وليس من كثافة الأطباء.
    expect(shortcuts.first, SpecialtyCatalog.all
        .firstWhere((s) => s.id == SpecialtyCatalog.homeChipIds.first)
        .nameAr);
    expect(shortcuts, hasLength(3));
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
