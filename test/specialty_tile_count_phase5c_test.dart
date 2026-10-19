// Phase 5C — عدد الأطباء تحت أيقونة الاختصاص = عدد القائمة لما تدخلها،
// والرجوع من قائمة الاختصاص يرجعك لصفحة الاختصاصات مو للرئيسية.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/all_specialties_page.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/doctors/specialty_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _doctors = [
  'جراحة العظام والمفاصل والكسور',
  'م. اختصاص جراحة العظام والمفاصل والكسور والفقرات',
  'العظام والكسور',
  'المفاصل',
  'طب الأطفال',
  'الجراحة العامة',
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('العدد تحت كل أيقونة = طول القائمة لما تدخلها', () {
    final counts = SpecialtyCatalog.countByTile(_doctors);
    for (final tile in SpecialtyCatalog.tilesForDoctors(_doctors)) {
      final listed = _doctors.where(
        (d) => SpecialtyCatalog.doctorMatchesTile(d, tile),
      );
      expect(counts[tile] ?? 0, listed.length, reason: tile);
    }
  });

  test('طبيب «العظام والمفاصل» يطلع بالعظام وبالمفاصل، والعدد صحيح', () {
    final counts = SpecialtyCatalog.countByTile(_doctors);
    final ortho = SpecialtyCatalog.match('العظام')!.nameAr;
    final joints = SpecialtyCatalog.match('المفاصل')!.nameAr;
    // خانة «العظام والكسور والمفاصل» تضم طبيب «المفاصل» هم (اسمها بيه المفاصل):
    // ٣ عظام + ١ مفاصل = ٤، وخانة «المفاصل» = ٣.
    expect(counts[ortho], 4);
    expect(counts[joints], 3);
    expect(counts[SpecialtyCatalog.match('طب الأطفال')!.nameAr], 1);
  });

  test('متوفر اليوم والطلب ينحسبون بنفس القاعدة', () {
    final rows = [
      for (final d in _doctors) {'specialty': d, 'profile_views': 1},
    ];
    final stats = SpecialtyStats.fromDoctorRows(rows);
    final joints = SpecialtyCatalog.match('المفاصل')!.nameAr;
    expect(stats.demand[joints], greaterThanOrEqualTo(3));
  });

  testWidgets('الرجوع من قائمة الاختصاص يرجع للاختصاصات', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AllSpecialtiesPage(
                      doctorSpecialties: const ['طب الأطفال'],
                      onSpecialtySelected: (s) => navKey.currentState!.push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(body: Text('قائمة $s')),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('الرئيسية'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    expect(find.text('الاختصاصات الطبية'), findsOneWidget);

    await tester.tap(find.text('1 طبيب'));
    await tester.pumpAndSettle();
    expect(find.textContaining('قائمة'), findsOneWidget);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('الاختصاصات الطبية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
