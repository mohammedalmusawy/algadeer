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
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIn0.local',
    );
  });

  const doctor = DoctorItem(
    id: 'test-1',
    name: 'الدكتور علي ناصر السعيدي',
    specialty: 'أخصائي طب الأطفال والخدج وحديثي الولادة',
    location: 'بغداد',
    available: true,
    phone: '',
    whatsapp: '',
    imageUrl: '',
    ghadeerBadge: true,
    bio: '',
    shortDescription: '',
    workingDays: '',
    workingHours: '',
    bookingStatus: 'available',
    absenceFrom: '',
    absenceTo: '',
  );

  testWidgets(
    'Name uses د. sits under branding and wraps on mobile width',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorProfilePage(
            doctor: doctor,
            isFavorite: false,
            onToggleFavorite: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('hero_doctor_name_specialty')), findsOneWidget);
      expect(find.textContaining('د. علي ناصر السعيدي'), findsOneWidget);
      expect(find.text('الدكتور علي ناصر السعيدي'), findsNothing);

      final brand = find.text('عيادة الغدير');
      final name = find.textContaining('د. علي ناصر السعيدي');
      final specialty = find.textContaining('أخصائي طب الأطفال');

      final brandBottom = tester.getBottomLeft(brand).dy;
      final nameTop = tester.getTopLeft(name).dy;
      final nameSize = tester.getSize(name);

      expect(nameTop, greaterThan(brandBottom + 8));
      expect(specialty, findsOneWidget);
      expect(
        tester.getTopLeft(specialty).dy,
        greaterThan(tester.getBottomLeft(name).dy - 1),
      );
      expect(find.text('بورد'), findsNothing);
      expect(find.text('خبرة طويلة'), findsNothing);
      // ضمن عمود الرجوع/الشعار — ليس ممتدًا نحو صورة الطبيب.
      expect(nameSize.height, greaterThan(28));
      expect(nameSize.width, lessThanOrEqualTo(300));
      expect(tester.getTopLeft(name).dx, lessThan(40));
    },
  );

  testWidgets(
    'Consultant name stays full with specialty under it and no chips',
    (tester) async {
      final view = tester.view;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      const consultant = DoctorItem(
        id: 'test-2',
        name: 'الدكتور الاستشاري علي فليح جودة',
        specialty: 'اختصاص الاذن والانف والحنجرة',
        location: 'بغداد',
        available: true,
        phone: '',
        whatsapp: '',
        imageUrl: '',
        ghadeerBadge: false,
        bio: '',
        shortDescription: '',
        workingDays: '',
        workingHours: '',
        bookingStatus: 'available',
        absenceFrom: '',
        absenceTo: '',
        yearsExperience: 12,
        ageGroup: 'للكبار والصغار',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorProfilePage(
            doctor: consultant,
            isFavorite: false,
            onToggleFavorite: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final name = find.text('الدكتور الاستشاري علي فليح جودة');
      final specialty = find.text('اختصاص الاذن والانف والحنجرة');

      expect(name, findsOneWidget);
      expect(specialty, findsOneWidget);
      expect(find.text('بورد'), findsNothing);
      expect(find.text('دبلوم'), findsNothing);
      expect(find.text('خبرة طويلة'), findsNothing);
      expect(
        tester.getTopLeft(specialty).dy,
        greaterThan(tester.getBottomLeft(name).dy - 1),
      );
    },
  );
}
