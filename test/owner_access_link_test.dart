import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/centers/service_center_models.dart';
import 'package:ghadeer_clinic/centers/service_center_profile_page.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_profile_page.dart';
import 'package:ghadeer_clinic/widgets/owner_access_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// دخول صاحب البطاقة كان نقرات مخفية على الاسم فقط؛ الآن قفل 🔒 ثابت
/// بالشريط العلوي جنب المشاركة — نفس المكان بكل البطاقات.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
  }

  void expectLockAtTop(WidgetTester tester) {
    final lock = find.byKey(OwnerAccess.key);
    expect(lock, findsOneWidget);
    expect(find.byTooltip(OwnerAccess.tooltip), findsOneWidget);
    // بأعلى الشاشة بلا تمرير، وداخل عرض الموبايل.
    final r = tester.getRect(lock);
    expect(r.top, lessThan(120));
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  }

  testWidgets('optics/beauty: lock sits in the top bar without scrolling', (
    tester,
  ) async {
    const center = ServiceCenter(
      id: 'sc_owner_lock_test',
      kind: ServiceCenterKind.optics,
      name: 'عوينات تجربة',
      displayOrder: 0,
      contentRevision: 1,
    );
    await phone(tester, const ServiceCenterProfilePage(center: center));
    expectLockAtTop(tester);
  });

  testWidgets('pharmacy: lock sits in the top bar without scrolling', (
    tester,
  ) async {
    const pharmacy = PharmacyItem(
      id: 'ph-owner-lock',
      name: 'صيدلية تجربة',
      address: 'الشطرة',
      phone: '07700000000',
      whatsapp: '07700000000',
      tags: [],
      openFrom: '8',
      openTo: '10',
      isOpenNow: true,
    );
    await phone(tester, const PharmacyProfilePage(pharmacy: pharmacy));
    expectLockAtTop(tester);
  });

  testWidgets('lock needs three quick taps; one or two do nothing', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: OwnerAccess.faint(onTap: () => opened++)),
        ),
      ),
    );
    final lock = find.byKey(OwnerAccess.key);
    await tester.tap(lock);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, 0);
    await tester.tap(lock);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, 0);
    await tester.tap(lock);
    await tester.pump();
    expect(opened, 1);
    // نقرتين ثم توقف طويل ثم نقرة: ما تنحسب ثلاثة.
    await tester.tap(lock);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(lock);
    // الماكنة تستخدم ساعة حقيقية، فننتظر وقتاً حقيقياً.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await tester.pump();
    await tester.tap(lock);
    await tester.pump();
    expect(opened, 1);
  });
}
