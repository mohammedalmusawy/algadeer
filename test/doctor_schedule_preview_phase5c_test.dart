// Phase 5C — معاينة الدوام بالمحرّر: تطلع نفس الملخص اللي بصفحة الطبيب،
// وتنبّه إذا ما يطلع دوام (مثل مشكلة د. ناجي).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_schedule_preview.dart';
import 'package:ghadeer_clinic/doctors/doctor_week_schedule.dart';

Future<void> _pump(WidgetTester tester, String hours) async {
  tester.view.physicalSize = const Size(360, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: DoctorSchedulePreview(workingHours: hours)),
      ),
    ),
  );
}

void main() {
  testWidgets('جدول المحرّر (٦ أيام مساءً والجمعة عطلة)', (tester) async {
    final week = formatDoctorWeek({
      for (final d in doctorWeekDayOrder) d: d == 'الجمعة' ? 'off' : 'evening',
    });
    await _pump(tester, week.hours);
    expect(find.text('يومياً مساءً'), findsOneWidget);
    expect(find.text('عطلة: الجمعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('فترة مختلفة ليوم تطلع ملاحظة', (tester) async {
    await _pump(tester, 'يومياً مساءً، الجمعة صباحاً');
    expect(find.text('يومياً مساءً'), findsOneWidget);
    expect(find.text('الجمعة صباحًا'), findsOneWidget);
  });

  testWidgets('نص ما ينقرأ ← تنبيه بدل ما يطلع فارغ', (tester) async {
    await _pump(tester, 'حسب الموعد');
    expect(find.text('ما يطلع دوام — اختر فترة لكل يوم'), findsOneWidget);
  });
}
