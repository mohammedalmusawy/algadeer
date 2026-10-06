import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/clinic_doctor_list_card.dart';
import 'package:ghadeer_clinic/doctors/doctor_card_tap.dart';
import 'package:ghadeer_clinic/doctors/doctor_week_schedule.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const doctor = DoctorItem(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'دكتور سامي',
    specialty: 'باطنية',
    location: 'الشطرة',
    available: true,
    phone: '07800000000',
    whatsapp: '07800000000',
    imageUrl: '',
    ghadeerBadge: false,
    bio: 'نبذة',
    services: '',
    shortDescription: 'نبذة',
    workingDays: 'السبت',
    workingHours: 'السبت مساءً، الأحد عطلة',
    bookingStatus: 'available',
    absenceFrom: '',
    absenceTo: '',
  );

  test('خمس نقرات للمختبر والصيدلية لا تكتمل قبل الخامسة', () {
    final taps = RapidTapMachine(requiredTaps: 5);
    final start = DateTime(2026, 10, 2, 12);
    for (var i = 0; i < 4; i++) {
      expect(
        taps.register(start.add(Duration(milliseconds: 80 * i))),
        isFalse,
      );
    }
    expect(
      taps.register(start.add(const Duration(milliseconds: 320))),
      isTrue,
    );
  });

  test('ثلاث نقرات متتالية تكتمل ونقرة متأخرة تبدأ من جديد', () {
    final taps = RapidTapMachine();
    final start = DateTime(2026, 10, 2, 12);
    expect(taps.register(start), isFalse);
    expect(
      taps.register(start.add(const Duration(milliseconds: 120))),
      isFalse,
    );
    expect(
      taps.register(start.add(const Duration(milliseconds: 240))),
      isTrue,
    );

    final spaced = RapidTapMachine();
    expect(spaced.register(start), isFalse);
    expect(
      spaced.register(start.add(const Duration(milliseconds: 500))),
      isFalse,
    );
    expect(
      spaced.register(start.add(const Duration(milliseconds: 620))),
      isFalse,
    );
  });

  test('جدول الدوام يُكتب بصيغة البطاقة الحالية', () {
    final formatted = formatDoctorWeek({
      for (final day in doctorWeekDayOrder) day: day == 'الأحد' ? 'off' : 'evening',
    });
    final parsed = parseDoctorWeekSchedule(
      workingDays: formatted.days,
      workingHours: formatted.hours,
    );
    final sunday = parsed.firstWhere((entry) => entry.day == 'الأحد');
    final saturday = parsed.firstWhere((entry) => entry.day == 'السبت');
    expect(sunday.isOff, isTrue);
    expect(saturday.status, 'مساءً');
    expect(formatted.days.contains('الأحد'), isFalse);
  });

  testWidgets('نقرة واحدة تفتح البطاقة وثلاث نقرات لا تفتحها', (tester) async {
    var opens = 0;
    var triples = 0;
    await tester.pumpWidget(
      _cardHarness(
        doctor: doctor,
        onOpen: () => opens += 1,
        onTriple: () => triples += 1,
        onFavorite: () {},
      ),
    );

    await tester.tap(find.text('دكتور سامي'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(opens, 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opens, 1);
    expect(triples, 0);
  });

  testWidgets('ثلاث نقرات سريعة تفتح الدخول ولا تفتح الملف', (tester) async {
    var opens = 0;
    var triples = 0;
    await tester.pumpWidget(
      _cardHarness(
        doctor: doctor,
        onOpen: () => opens += 1,
        onTriple: () => triples += 1,
        onFavorite: () {},
      ),
    );

    await tester.tap(find.text('دكتور سامي'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('دكتور سامي'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('دكتور سامي'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(triples, 1);
    expect(opens, 0);
  });

  testWidgets('المفضلة والتمرير لا يفتحان البطاقة', (tester) async {
    var opens = 0;
    var favorites = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: 220,
            child: ListView(
              children: [
                ClinicDoctorListCard(
                  doctor: doctor,
                  isFavorite: false,
                  onOpenProfile: () => opens += 1,
                  onToggleFavorite: () => favorites += 1,
                  onTripleTap: () {},
                ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    expect(favorites, 1);
    expect(opens, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opens, 0);
  });
}

Widget _cardHarness({
  required DoctorItem doctor,
  required VoidCallback onOpen,
  required VoidCallback onTriple,
  required VoidCallback onFavorite,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: ClinicDoctorListCard(
          doctor: doctor,
          isFavorite: false,
          onOpenProfile: onOpen,
          onToggleFavorite: onFavorite,
          onTripleTap: onTriple,
        ),
      ),
    ),
  );
}
