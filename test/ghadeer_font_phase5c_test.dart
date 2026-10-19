// Phase 5C — خط الغدير الموحّد IBM Plex Sans Arabic: الثيم يستخدمه، والصفحات
// الرئيسية ما يطلع منها شي برا الشاشة بالخط الحقيقي (مو خط الاختبار الافتراضي)
// على أصغر عرض موبايل.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/centers/service_center_kind.dart';
import 'package:ghadeer_clinic/doctors/all_specialties_page.dart';
import 'package:ghadeer_clinic/centers/service_center_models.dart';
import 'package:ghadeer_clinic/centers/service_center_profile_page.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_profile_page.dart';
import 'package:ghadeer_clinic/physio/physio_models.dart';
import 'package:ghadeer_clinic/physio/physio_profile_page.dart';
import 'package:ghadeer_clinic/supplies/supply_models.dart';
import 'package:ghadeer_clinic/supplies/supply_profile_page.dart';
import 'package:ghadeer_clinic/theme/ghadeer_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ByteData> _font(String weight) async {
  final bytes = await File('assets/fonts/IBMPlexSansArabic-$weight.ttf')
      .readAsBytes();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

void main() {
  setUpAll(() async {
    final loader = FontLoader(GhadeerTokens.fontFamily);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(_font(w));
    }
    await loader.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('الثيم يستخدم خط الغدير', () {
    final theme = GhadeerTokens.theme();
    expect(theme.textTheme.bodyMedium?.fontFamily, GhadeerTokens.fontFamily);
    expect(theme.textTheme.titleLarge?.fontFamily, GhadeerTokens.fontFamily);
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      expect(
        File('assets/fonts/IBMPlexSansArabic-$w.ttf').existsSync(),
        isTrue,
        reason: w,
      );
    }
  });

  final pages = <String, Widget>{
    'الصيدلية': const PharmacyProfilePage(
      pharmacy: PharmacyItem(
        id: 'ph-font',
        name: 'صيدلية الشفاء الكبرى للأدوية والمستلزمات',
        address: 'الشطرة - شارع الأطباء مقابل المستشفى',
        phone: '07700000000',
        whatsapp: '07700000000',
        tags: [],
        openFrom: '8 صباحاً',
        openTo: '11 مساءً',
        isOpenNow: true,
      ),
    ),
    'العلاج الطبيعي': PhysioProfilePage(center: PhysioCatalog.items.first),
    'التجهيزات': SupplyProfilePage(vendor: SuppliesCatalog.items.first),
    'التمريض': const ServiceCenterProfilePage(
      center: ServiceCenter(
        id: 'nurse-font',
        kind: ServiceCenterKind.nursing,
        name: 'الممرض علي حسن',
        hours: 'يومياً من 4 عصراً حتى 10 ليلاً',
        address: 'الشطرة',
      ),
    ),
  };

  for (final entry in pages.entries) {
    testWidgets('${entry.key}: ماكو overflow بالخط الحقيقي على 320', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: GhadeerTokens.theme(), home: entry.value),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('«الأكثر طلباً» سطر واحد بالخط الحقيقي (جان ينقص)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: GhadeerTokens.theme(),
        home: AllSpecialtiesPage(
          doctorSpecialties: const ['طب الأطفال', 'الباطنية'],
          onSpecialtySelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final chip = find.text('الأكثر طلبًا');
    expect(chip, findsOneWidget);
    // سطر واحد: الارتفاع أقل من سطرين.
    expect(tester.getSize(chip).height, lessThan(26));
  });
}
