import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/physio/physio_models.dart';
import 'package:ghadeer_clinic/physio/physio_profile_page.dart';
import 'package:ghadeer_clinic/services/directory_shared_table.dart';
import 'package:ghadeer_clinic/supplies/supply_models.dart';
import 'package:ghadeer_clinic/supplies/supply_profile_page.dart';
import 'package:ghadeer_clinic/widgets/directory_owner_editor_page.dart';
import 'package:ghadeer_clinic/widgets/owner_access_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// قفل المالك صار بكل الأقسام: العلاج الطبيعي والتجهيزات والأشعة، وبياناتهم
/// تنحفظ بالدليل المشترك بدل جهاز الإدارة فقط.
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
    final r = tester.getRect(lock);
    expect(r.top, lessThan(120));
    expect(r.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  }

  testWidgets('physio: lock sits in the top bar', (tester) async {
    await phone(tester, PhysioProfilePage(center: PhysioCatalog.items.first));
    expectLockAtTop(tester);
  });

  testWidgets('supplies: lock sits in the top bar', (tester) async {
    await phone(tester, SupplyProfilePage(vendor: SuppliesCatalog.items.first));
    expectLockAtTop(tester);
  });

  group('حقول المالك', () {
    const physio = OwnerCardData(
      id: 'physio_shatra',
      name: 'مركز',
      contentRevision: 3,
      logoFolder: 'physio',
      splitHours: true,
      supportsMapUrl: false,
    );
    const radiology = OwnerCardData(
      id: 'r1',
      name: 'أشعة',
      contentRevision: 1,
      logoFolder: 'radiology',
      supportsServices: false,
    );

    Map<String, dynamic> build(
      OwnerCardData card,
      Set<String> perms, {
      String services = '',
      String openFrom = '',
      String openTo = '',
      String hours = '',
    }) => ownerCardFields(
      allows: perms.contains,
      card: card,
      logoUrl: '',
      bio: ' نبذة ',
      services: services,
      hours: hours,
      openFrom: openFrom,
      openTo: openTo,
      phone: '0770',
      whatsapp: '0780',
      address: 'الشطرة',
      mapUrl: 'https://maps.example',
    );

    test('يرسل بس الحقول المسموحة', () {
      final f = build(physio, {'bio', 'hours'}, openFrom: '4', openTo: '9');
      expect(f.keys.toSet(), {'bio', 'hours'});
      expect(f['bio'], 'نبذة');
      expect(f['hours'], '4 - 9');
    });

    test('العلاج الطبيعي: خدمات بأسطر وبدون رابط خريطة', () {
      final f = build(physio, {
        'services',
        'location',
      }, services: 'تأهيل\nمساج، علاج');
      expect(f['services'], ['تأهيل', 'مساج', 'علاج']);
      expect(f.containsKey('mapUrl'), isFalse);
      expect(f['address'], 'الشطرة');
    });

    test('الأشعة: بلا خدمات ودوام نص حر', () {
      final f = build(radiology, {
        'services',
        'hours',
        'location',
      }, hours: '8 صباحاً - 8 مساءً');
      expect(f.containsKey('services'), isFalse);
      expect(f['hours'], '8 صباحاً - 8 مساءً');
      expect(f['mapUrl'], 'https://maps.example');
    });
  });

  group('الدليل المشترك', () {
    test('الملف المشترك فوك نسخة الجهاز، والشعار الفارغ ما يمسح', () {
      final base = PhysioCatalog.items.first.toMap();
      final merged = DirectorySharedTable.mergeRow(
        {...base, 'logoUrl': 'https://logo'},
        {
          'id': base['id'],
          'name': 'اسم جديد',
          'is_active': false,
          'content_revision': 4,
          'profile': {'description': 'من المالك', 'logoUrl': ''},
        },
      );
      final center = PhysioCenter.fromMap(merged);
      expect(center.name, 'اسم جديد');
      expect(center.description, 'من المالك');
      expect(center.logoUrl, 'https://logo');
      expect(center.isActive, isFalse);
      expect(center.contentRevision, 4);
    });

    test('بدون Supabase (اختبار/بدون نت) ما يكسر التحميل', () async {
      const table = DirectorySharedTable('supply_vendors');
      expect(await table.fetch(), isNull);
      final v = SupplyVendor.fromMap(
        DirectorySharedTable.mergeRow(SuppliesCatalog.items.first.toMap(), {
          'id': SuppliesCatalog.items.first.id,
          'profile': {
            'categories': ['كراسي'],
          },
        }),
      );
      expect(v.categories, ['كراسي']);
      expect(v.contentRevision, 1);
    });
  });
}
