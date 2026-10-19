// Phase 5D — قسم «دوام اليوم» بالرئيسية وشبكة الأقسام على قد النص.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/home/home_phase1_sections.dart';
import 'package:ghadeer_clinic/home/home_today_doctors.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';
import 'package:ghadeer_clinic/theme/ghadeer_tokens.dart';

DoctorItem _doc(
  String id, {
  String hours = '',
  String booking = 'available',
  String from = '',
  String to = '',
}) => DoctorItem(
  id: id,
  name: 'د. $id',
  specialty: 'باطنية',
  location: 'الشطرة',
  available: true,
  phone: '',
  whatsapp: '',
  imageUrl: '',
  ghadeerBadge: false,
  bio: '',
  shortDescription: '',
  workingDays: '',
  workingHours: hours,
  bookingStatus: booking,
  absenceFrom: from,
  absenceTo: to,
);

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  theme: GhadeerTokens.theme(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  ),
);

void main() {
  // الاثنين 19 أكتوبر 2026، الساعة 1 الظهر ببغداد.
  final monday = DateTime.utc(2026, 10, 19, 10);

  test('يختار بس اللي جدولهم يثبت دوام اليوم', () {
    final picked = HomeTodayDoctors.pick([
      _doc('a', hours: 'يومياً مساءً'),
      _doc('b', hours: 'يومياً مساءً عدا الاثنين'), // عطلة اليوم
      _doc('c'), // بلا جدول — ما نخمن
      _doc('d', hours: 'يومياً صباحًا', booking: 'walk_in_only'),
      _doc('e', hours: 'يومياً مساءً', booking: 'full'),
      _doc('f', hours: 'يومياً مساءً', from: '2026-10-18', to: '2026-10-20'),
    ], nowUtc: monday);
    expect(picked.map((d) => d.id), ['a', 'd']);
  });

  test('ما يزيد على الحد', () {
    final many = [
      for (var i = 0; i < 30; i++) _doc('x$i', hours: 'يومياً مساءً'),
    ];
    expect(
      HomeTodayDoctors.pick(many, nowUtc: monday).length,
      HomeTodayDoctors.maxItems,
    );
  });

  testWidgets('ماكو أحد دوامه اليوم ← القسم ما يطلع', (tester) async {
    await tester.pumpWidget(
      _app(
        HomeTodayDoctors(
          doctors: [_doc('b', hours: 'يومياً مساءً عدا الاثنين')],
          nowUtc: monday,
          onOpen: (_) {},
          onSeeAll: () {},
        ),
      ),
    );
    expect(find.text('دوام اليوم'), findsNothing);
  });

  for (final scale in [1.0, 1.4]) {
    testWidgets('البطاقة تفتح الملف والشارة بالفترة (خط ×$scale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <String>[];
      var all = 0;
      await tester.pumpWidget(
        _app(
          HomeTodayDoctors(
            doctors: [
              _doc('a', hours: 'يومياً مساءً'),
              _doc('d', hours: 'يومياً صباحًا', booking: 'walk_in_only'),
            ],
            nowUtc: monday,
            onOpen: (d) => opened.add(d.id),
            onSeeAll: () => all++,
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('دوام اليوم'), findsOneWidget);
      expect(find.text('مساءً'), findsOneWidget);
      expect(find.text('حضوري فقط · صباحًا'), findsOneWidget);
      // ما نگول «موجود الآن» أبد.
      expect(find.textContaining('الآن'), findsNothing);
      await tester.tap(find.text('د. a'));
      await tester.tap(find.text('كل الاختصاصات'));
      expect(opened, ['a']);
      expect(all, 1);
    });
  }

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('شبكة الأقسام بعرض $width وخط ×$scale بدون قص', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(HomePhase1ServicesGrid(onOpen: (_) {}), scale: scale),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
