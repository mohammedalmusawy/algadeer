import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_all_bundles_page.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// البحث وزر التصفية بصفحة الصيدلية يفتحون نتائج حقيقية بدل «قريباً».
void main() {
  const pharmacy = PharmacyItem(
    id: 'ph-search-1',
    name: 'صيدلية تجربة',
    address: 'الشطرة',
    phone: '07700000000',
    whatsapp: '07700000000',
    tags: [],
    openFrom: '8',
    openTo: '10',
    isOpenNow: true,
    hasSupplements: true,
    bundles: [
      PharmacyBundle(
        id: 'zz-offer',
        title: 'باقة زنك تجريبية',
        price: 9000,
        oldPrice: 12000,
      ),
    ],
  );

  Future<void> pumpProfile(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: PharmacyProfilePage(pharmacy: pharmacy)),
    );
    await tester.pump();
  }

  testWidgets('submitting product search opens filtered bundles page', (
    tester,
  ) async {
    await pumpProfile(tester);
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'زنك');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byType(PharmacyAllBundlesPage), findsOneWidget);
    expect(find.text('نتائج «زنك»'), findsOneWidget);
    expect(find.text('باقة زنك تجريبية'), findsWidgets);
  });

  testWidgets('filter button opens sheet instead of coming-soon snack', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.tap(find.byTooltip('تصفية الباقات'));
    await tester.pumpAndSettle();

    expect(find.text('العروض (بيها خصم)'), findsOneWidget);
    expect(find.textContaining('قريباً'), findsNothing);

    await tester.tap(find.text('العروض (بيها خصم)'));
    await tester.pumpAndSettle();
    expect(find.byType(PharmacyAllBundlesPage), findsOneWidget);
    expect(find.text('باقة زنك تجريبية'), findsWidgets);
  });
}
