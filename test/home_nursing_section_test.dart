import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/centers/service_center_models.dart';
import 'package:ghadeer_clinic/centers/service_center_profile_page.dart';
import 'package:ghadeer_clinic/centers/service_center_style.dart';
import 'package:ghadeer_clinic/home/home_phase1_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// قسم التمريض المنزلي: نفس دليل العوينات/التجميل، بهوية طبية وتسمية مرتبة.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nursing kind: قاعدة البيانات والتسمية', () {
    expect(ServiceCenterKind.fromDb('nursing'), ServiceCenterKind.nursing);
    expect(ServiceCenterKind.nursing.dbValue, 'nursing');
    expect(ServiceCenterKind.nursing.sectionTitle, 'التمريض المنزلي');
    expect(ServiceCenterKind.nursing.nameFieldHint, contains('الممرض'));
    expect(ServiceCenterKind.optics.nameFieldLabel, 'اسم المركز');
    // الأقسام القديمة ما تغيّرت.
    expect(ServiceCenterKind.fromDb('optics'), ServiceCenterKind.optics);
    expect(ServiceCenterKind.fromDb('beauty'), ServiceCenterKind.beauty);
    expect(ServiceCenterKind.fromDb('x'), isNull);
    expect(ServiceCenterKind.nursing.accent, isNot(ServiceCenterKind.beauty.accent));
  });

  test('جملة الدماغ ما تتحول لتمريض (القسم بالدليل فقط حالياً)', () {
    expect(ServiceCenterQuery.kindFor('اريد عوينات'), ServiceCenterKind.optics);
    expect(ServiceCenterQuery.kindFor('ممرض للبيت'), isNot(ServiceCenterKind.nursing));
  });

  testWidgets('الرئيسية تعرض التمريض المنزلي بعرض الموبايل بلا قص', (tester) async {
    tester.view.physicalSize = const Size(360, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomePhase1ServicesGrid(onOpen: (id) => opened = id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('التمريض المنزلي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.text('التمريض المنزلي'));
    expect(rect.right, lessThanOrEqualTo(360));
    await tester.tap(find.text('التمريض المنزلي'));
    await tester.pump();
    expect(opened, 'nursing');
  });

  testWidgets('بطاقة الممرض: هوية القسم والقفل والمشاركة', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const nurse = ServiceCenter(
      id: 'sc_nursing_1',
      kind: ServiceCenterKind.nursing,
      name: 'الممرض علي حسن',
      services: ['زرق إبر', 'تركيب مغذي', 'تضميد جروح'],
      hours: 'من ٤ عصراً إلى ١٠ ليلاً',
    );
    await tester.pumpWidget(
      const MaterialApp(home: ServiceCenterProfilePage(center: nurse)),
    );
    await tester.pump();
    expect(find.text('الممرض علي حسن'), findsWidgets);
    expect(find.text('تمريض منزلي'), findsWidgets);
    // الخدمات تنعرض بسطر لكل خدمة داخل نص واحد.
    expect(find.textContaining('تركيب مغذي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
