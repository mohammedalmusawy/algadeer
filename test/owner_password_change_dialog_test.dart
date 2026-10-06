import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_card_access_client.dart';
import 'package:ghadeer_clinic/doctors/doctor_card_editor_page.dart';
import 'package:ghadeer_clinic/labs/lab_owner_editor_page.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_owner_editor_page.dart';

DoctorCardSession _owner(String type) {
  return DoctorCardSession(
    entityType: type,
    entityId: type == 'doctor'
        ? '11111111-1111-4111-8111-111111111111'
        : type == 'lab'
            ? '33333333-3333-4333-8333-333333333333'
            : 'rehab',
    role: 'owner',
    token: 'session-token',
    expiresAt: 1,
    permissions: const ['bio'],
  );
}

Future<void> _openAndCancel(WidgetTester tester) async {
  expect(find.text('كلمة المرور الحالية'), findsNothing);
  await tester.scrollUntilVisible(
    find.text('تغيير كلمة المرور'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('تغيير كلمة المرور'));
  await tester.pumpAndSettle();
  expect(find.text('كلمة المرور الحالية'), findsOneWidget);
  expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
  expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
  expect(find.text('حفظ'), findsWidgets);
  expect(find.text('إلغاء'), findsOneWidget);
  await tester.enterText(find.widgetWithText(TextField, 'كلمة المرور الحالية'), 'secret-old');
  await tester.tap(find.text('إلغاء'));
  await tester.pumpAndSettle();
  expect(find.text('كلمة المرور الحالية'), findsNothing);
}

void main() {
  testWidgets('إلغاء تغيير كلمة الطبيب يبقي النبذة ويمسح حقول كلمة المرور', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: DoctorCardEditorPage(
          session: _owner('doctor'),
          doctor: const DoctorItem(
            id: '11111111-1111-4111-8111-111111111111',
            name: 'طبيب',
            specialty: 'باطنية',
            location: 'الناصرية',
            available: true,
            phone: '1',
            whatsapp: '1',
            imageUrl: '',
            ghadeerBadge: false,
            bio: 'نبذة أصلية',
            shortDescription: 'نبذة أصلية',
            workingDays: '',
            workingHours: '',
            bookingStatus: 'available',
            absenceFrom: '',
            absenceTo: '',
          ),
        ),
      ),
    );

    final bio = find.widgetWithText(TextField, 'النبذة');
    await tester.enterText(bio, 'نبذة لم تُحفظ');
    await _openAndCancel(tester);
    expect(tester.widget<TextField>(bio).controller?.text, 'نبذة لم تُحفظ');
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'كلمة المرور الحالية')).controller?.text,
      isEmpty,
    );
  });

  testWidgets('إلغاء تغيير كلمة المختبر يبقي الشعار', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: LabOwnerEditorPage(
          session: _owner('lab'),
          lab: const LabItem(id: '33333333-3333-4333-8333-333333333333', name: 'مختبر'),
        ),
      ),
    );
    final slogan = find.widgetWithText(TextField, 'الشعار');
    await tester.enterText(slogan, 'شعار لم يُحفظ');
    await _openAndCancel(tester);
    expect(tester.widget<TextField>(slogan).controller?.text, 'شعار لم يُحفظ');
  });

  testWidgets('إلغاء تغيير كلمة الصيدلية يبقي الشعار', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyOwnerEditorPage(
          session: _owner('pharmacy'),
          pharmacy: const PharmacyItem(
            id: 'rehab',
            name: 'صيدلية',
            address: 'عنوان',
            phone: '1',
            whatsapp: '1',
            tags: [],
            openFrom: '8',
            openTo: '10',
            isOpenNow: true,
          ),
        ),
      ),
    );
    final slogan = find.widgetWithText(TextField, 'الشعار');
    await tester.enterText(slogan, 'شعار الصيدلية');
    await _openAndCancel(tester);
    expect(tester.widget<TextField>(slogan).controller?.text, 'شعار الصيدلية');
  });

  testWidgets('تأكيد كلمة المرور غير المتطابق لا يغلق الحوار', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: LabOwnerEditorPage(
          session: _owner('lab'),
          lab: const LabItem(id: '33333333-3333-4333-8333-333333333333', name: 'مختبر'),
        ),
      ),
    );
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'كلمة المرور الجديدة'), 'password-1');
    await tester.enterText(find.widgetWithText(TextField, 'تأكيد كلمة المرور'), 'password-2');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'حفظ'),
      ),
    );
    await tester.pump();
    expect(find.text('التأكيد غير متطابق'), findsOneWidget);
    expect(find.text('تغيير كلمة المرور'), findsWidgets);
  });
}
