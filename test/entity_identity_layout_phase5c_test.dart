// Phase 5C — الصيدليات والتجهيزات والعلاج الطبيعي والمراكز (عوينات، تجميل،
// تمريض) صارت بنفس هوية الطبيب والمختبر: الصورة يمين، الكتابة يسار،
// والرجوع أعلى اليمين، بدون overflow على الموبايل.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/centers/service_center_models.dart';
import 'package:ghadeer_clinic/centers/service_center_profile_page.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_profile_page.dart';
import 'package:ghadeer_clinic/physio/physio_models.dart';
import 'package:ghadeer_clinic/physio/physio_profile_page.dart';
import 'package:ghadeer_clinic/supplies/supply_models.dart';
import 'package:ghadeer_clinic/supplies/supply_profile_page.dart';
import 'package:ghadeer_clinic/widgets/entity_contact_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> expectUnifiedIdentity(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final name = find.byKey(const Key('identity_card_name'));
    final photo = find.byKey(const Key('identity_card_photo'));
    final back = find.byType(GhadeerBackButton).first;
    expect(name, findsOneWidget);
    expect(photo, findsOneWidget);
    // الصورة يمين والكتابة يسارها — مثل هوية الطبيب.
    expect(tester.getCenter(photo).dx, greaterThan(180));
    expect(tester.getCenter(name).dx, lessThan(180));
    expect(
      tester.getTopRight(name).dx,
      lessThanOrEqualTo(tester.getTopLeft(photo).dx),
    );
    // الرجوع أعلى اليمين.
    expect(tester.getCenter(back).dx, greaterThan(180));
    expect(tester.getTopLeft(back).dy, lessThan(120));
    // اسم التطبيق مرة وحدة، و«عيادة الغدير» ما تطلع على صفحة جهة ثانية.
    expect(find.text('منصة الغدير'), findsOneWidget);
    expect(find.text('عيادة الغدير'), findsNothing);
    expect(find.textContaining('في منصة الغدير'), findsNothing);
  }

  testWidgets('الصيدلية', (tester) async {
    await expectUnifiedIdentity(
      tester,
      const PharmacyProfilePage(
        pharmacy: PharmacyItem(
          id: 'ph-layout',
          name: 'صيدلية الشفاء',
          address: 'الشطرة - شارع الأطباء',
          phone: '07700000000',
          whatsapp: '07700000000',
          tags: [],
          openFrom: '8 صباحاً',
          openTo: '10 مساءً',
          isOpenNow: true,
        ),
      ),
    );
  });

  testWidgets('العلاج الطبيعي', (tester) async {
    await expectUnifiedIdentity(
      tester,
      PhysioProfilePage(center: PhysioCatalog.items.first),
    );
  });

  testWidgets('التجهيزات', (tester) async {
    await expectUnifiedIdentity(
      tester,
      SupplyProfilePage(vendor: SuppliesCatalog.items.first),
    );
  });

  testWidgets('العوينات', (tester) async {
    await expectUnifiedIdentity(
      tester,
      const ServiceCenterProfilePage(
        center: ServiceCenter(
          id: 'optics-layout',
          kind: ServiceCenterKind.optics,
          name: 'عوينات الشطرة',
          address: 'الشطرة',
          hours: '٩ صباحاً حتى ١ ظهراً',
        ),
      ),
    );
  });
}
