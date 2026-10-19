import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/all_specialties_page.dart';
import 'package:ghadeer_clinic/doctors/specialty_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خانتا «الأكثر طلباً» و«متوفر اليوم» كانتا ما تغيّران شي.
/// هسه: الطلب الحقيقي للناس، واختصاصات بيها طبيب دوامه اليوم.
const _hours =
    'السبت: مساءً، الأحد: مساءً، الاثنين: مساءً، الثلاثاء: مساءً، '
    'الأربعاء: مساءً، الخميس: مساءً، الجمعة: عطلة';

/// الأحد 20 أيلول 2026 — 12 ظهرًا بتوقيت بغداد.
final _sunday = DateTime.utc(2026, 9, 20, 9);

final _rows = <Map<String, dynamic>>[
  {
    'specialty': 'طب الأطفال',
    'profile_views': 10,
    'working_hours': _hours,
    'booking_status': 'available',
  },
  {
    'specialty': 'طب الأطفال',
    'profile_views': 2,
    'working_hours': _hours,
    'booking_status': 'available',
    'absence_from': '2026-09-19',
    'absence_to': '2026-09-22',
  },
  {
    'specialty': 'جلدية',
    'profile_views': 100,
    'call_taps': 10,
    'working_hours': 'السبت: مساءً',
    'booking_status': 'available',
  },
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('الطلب الحقيقي والمتوفر اليوم لكل اختصاص', () {
    final stats = SpecialtyStats.fromDoctorRows(_rows, nowUtc: _sunday);
    final peds = SpecialtyStats.keyFor('طب الأطفال');
    final derma = SpecialtyStats.keyFor('جلدية');
    // 10 + 2 مشاهدات للأطفال؛ 100 + 10 اتصالات×3 للجلدية.
    expect(stats.demand[peds], 12);
    expect(stats.demand[derma], 130);
    // طبيب أطفال واحد دوامه اليوم (الثاني مجاز)، والجلدية عطلة الأحد.
    expect(stats.availableToday[peds], 1);
    expect(stats.availableToday[derma], isNull);
  });

  testWidgets('الخانات تغيّر الترتيب والقائمة فعلاً', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AllSpecialtiesPage(
          doctorSpecialties: const ['طب الأطفال', 'طب الأطفال', 'جلدية'],
          onSpecialtySelected: (_) {},
          stats: SpecialtyStats.fromDoctorRows(_rows, nowUtc: _sunday),
        ),
      ),
    );
    await tester.pump();

    // ترتيب القراءة بالشبكة (RTL): الصف الأعلى أولاً، وبنفس الصف الأيمن أولاً.
    bool before(String a, String b) {
      final pa = tester.getCenter(find.text(a));
      final pb = tester.getCenter(find.text(b));
      if ((pa.dy - pb.dy).abs() > 4) return pa.dy < pb.dy;
      return pa.dx > pb.dx;
    }

    // الكل: الترتيب الثابت (الأطفال قبل الجلدية).
    expect(before('2 طبيب', '1 طبيب'), isTrue);

    // الأكثر طلباً: الجلدية أولاً لأن الناس تطلبها أكثر.
    await tester.ensureVisible(find.text('الأكثر طلبًا'));
    await tester.pump();
    await tester.tap(find.text('الأكثر طلبًا'));
    await tester.pump();
    expect(before('1 طبيب', '2 طبيب'), isTrue);

    // متوفر اليوم: الأطفال بس، والجلدية تختفي.
    await tester.ensureVisible(find.text('متوفر اليوم'));
    await tester.pump();
    await tester.tap(find.text('متوفر اليوم'));
    await tester.pump();
    expect(find.text('1 متوفر اليوم'), findsOneWidget);
    expect(find.text('1 طبيب'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
