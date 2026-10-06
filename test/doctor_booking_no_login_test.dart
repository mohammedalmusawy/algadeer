import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_profile_page.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIn0.local',
    );
  });

  testWidgets('زر الحجز يعمل بدون تسجيل دخول جديد', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const doctor = DoctorItem(
      id: 'book-1',
      name: 'الدكتور سامي',
      specialty: 'باطنية',
      location: 'الشطرة',
      available: true,
      phone: '07800000000',
      whatsapp: '07800000000',
      imageUrl: '',
      ghadeerBadge: false,
      bio: '',
      shortDescription: '',
      workingDays: 'السبت',
      workingHours: 'مساءً',
      bookingStatus: 'available',
      absenceFrom: '',
      absenceTo: '',
      showBookingButton: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DoctorProfilePage(
            doctor: doctor,
            isFavorite: false,
            onToggleFavorite: _noop,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('doctor-booking-button')), findsOneWidget);
    expect(find.text('سجّل الدخول'), findsNothing);
    expect(find.textContaining('البريد'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('doctor-booking-button')));
    await tester.tap(find.byKey(const Key('doctor-booking-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('يمكنك الحجز عبر الاتصال أو واتساب حسب حالة الطبيب'),
      findsOneWidget,
    );
    expect(find.text('سجّل الدخول'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('حضور مباشر يبقي الاتصال وواتساب بدون حساب', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const doctor = DoctorItem(
      id: 'walk-1',
      name: 'الدكتورة هدى',
      specialty: 'أطفال',
      location: 'الشطرة',
      available: true,
      phone: '07811111111',
      whatsapp: '07811111111',
      imageUrl: '',
      ghadeerBadge: false,
      bio: '',
      shortDescription: '',
      workingDays: 'السبت',
      workingHours: 'مساءً',
      bookingStatus: 'walk_in_only',
      absenceFrom: '',
      absenceTo: '',
      showBookingButton: true,
      showCallButton: true,
      showWhatsAppButton: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DoctorProfilePage(
            doctor: doctor,
            isFavorite: false,
            onToggleFavorite: _noop,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('doctor-call-button')), findsOneWidget);
    expect(find.byKey(const Key('doctor-whatsapp-button')), findsOneWidget);

    final call = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('doctor-call-button')),
        matching: find.byType(InkWell),
      ),
    );
    expect(call.onTap, isNotNull);

    final wa = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('doctor-whatsapp-button')),
        matching: find.byType(InkWell),
      ),
    );
    expect(wa.onTap, isNotNull);
    expect(find.text('سجّل الدخول'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('doctor-booking-button')));
    await tester.tap(find.byKey(const Key('doctor-booking-button')));
    await tester.pump();
    expect(find.textContaining('حضور'), findsWidgets);
  });

  testWidgets('غير متاح للموعد يبقي الاتصال ويوضح الحالة بلا حساب', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const doctor = DoctorItem(
      id: 'off-1',
      name: 'الدكتور سامي',
      specialty: 'باطنية',
      location: 'الشطرة',
      available: false,
      phone: '07800000000',
      whatsapp: '07800000000',
      imageUrl: '',
      ghadeerBadge: false,
      bio: '',
      shortDescription: '',
      workingDays: 'السبت',
      workingHours: 'مساءً',
      bookingStatus: 'unavailable',
      absenceFrom: '',
      absenceTo: '',
      showBookingButton: true,
      showCallButton: true,
      showWhatsAppButton: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DoctorProfilePage(
            doctor: doctor,
            isFavorite: false,
            onToggleFavorite: _noop,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final call = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('doctor-call-button')),
        matching: find.byType(InkWell),
      ),
    );
    expect(call.onTap, isNotNull);
    final wa = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('doctor-whatsapp-button')),
        matching: find.byType(InkWell),
      ),
    );
    expect(wa.onTap, isNotNull);
    expect(find.text('سجّل الدخول'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('doctor-booking-button')));
    await tester.tap(find.byKey(const Key('doctor-booking-button')));
    await tester.pump();
    expect(find.textContaining('غير متاح'), findsWidgets);
  });

  testWidgets('إجازة تبقي الاتصال وتوضح الحالة عند الموعد', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const doctor = DoctorItem(
      id: 'leave-1',
      name: 'الدكتور سامي',
      specialty: 'باطنية',
      location: 'الشطرة',
      available: true,
      phone: '07800000000',
      whatsapp: '07800000000',
      imageUrl: '',
      ghadeerBadge: false,
      bio: '',
      shortDescription: '',
      workingDays: 'السبت',
      workingHours: 'مساءً',
      bookingStatus: 'available',
      absenceFrom: '2020-01-01',
      absenceTo: '2099-12-31',
      showBookingButton: true,
      showCallButton: true,
      showWhatsAppButton: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DoctorProfilePage(
            doctor: doctor,
            isFavorite: false,
            onToggleFavorite: _noop,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final call = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('doctor-call-button')),
        matching: find.byType(InkWell),
      ),
    );
    expect(call.onTap, isNotNull);
    final wa = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('doctor-whatsapp-button')),
        matching: find.byType(InkWell),
      ),
    );
    expect(wa.onTap, isNotNull);
    expect(find.text('سجّل الدخول'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('doctor-booking-button')));
    await tester.tap(find.byKey(const Key('doctor-booking-button')));
    await tester.pump();
    expect(find.textContaining('إجازة'), findsWidgets);
  });
}

void _noop() {}
