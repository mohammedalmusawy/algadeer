import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفضلة الصيدلية كانت تُنسى عند الخروج من البطاقة؛ الآن تُحفظ على الجهاز.
void main() {
  const pharmacy = PharmacyItem(
    id: 'ph-fav-1',
    name: 'صيدلية تجربة',
    address: 'الشطرة',
    phone: '07700000000',
    whatsapp: '07700000000',
    tags: [],
    openFrom: '8',
    openTo: '10',
    isOpenNow: true,
  );

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: PharmacyProfilePage(pharmacy: pharmacy)),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('favorite toggle is saved and restored on reopen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpProfile(tester);

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(PharmacyProfilePageFavorites.key),
      contains('ph-fav-1'),
    );

    await tester.pumpWidget(const SizedBox());
    await pumpProfile(tester);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('saved favorite shows filled heart on first open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      PharmacyProfilePageFavorites.key: ['ph-fav-1'],
    });
    await pumpProfile(tester);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
