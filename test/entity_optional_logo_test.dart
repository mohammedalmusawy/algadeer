import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/doctor_item.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/physio/physio_models.dart';
import 'package:ghadeer_clinic/services/entity_logos_store.dart';
import 'package:ghadeer_clinic/supplies/supply_models.dart';
import 'package:ghadeer_clinic/widgets/entity_optional_logo.dart';

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('مسار الشعار موحّد للإدارة والمالك', () {
    final admin = entityLogoObjectPath(
      folder: 'doctors',
      entityId: '11111111-1111-4111-8111-111111111111',
      png: true,
      fileId: 'logo1',
    );
    expect(
      admin,
      'doctors/11111111-1111-4111-8111-111111111111/logos/logo1.png',
    );
    expect(
      entityLogoObjectPath(
        folder: 'labs',
        entityId: 'lab-a',
        png: false,
        fileId: 'x',
      ),
      'labs/lab-a/logos/x.jpg',
    );
    expect(
      entityLogoObjectPath(
        folder: 'pharmacies',
        entityId: 'rehab',
        png: true,
        fileId: 'm',
      ),
      'pharmacies/rehab/logos/m.png',
    );
    expect(
      entityLogoObjectPath(
        folder: 'service-centers',
        entityId: 'sc_optics_1',
        png: true,
        fileId: 'm',
      ),
      'service-centers/sc_optics_1/logos/m.png',
    );
    expect(
      entityLogoObjectPath(
        folder: 'physio',
        entityId: 'ph_1',
        png: true,
        fileId: 'm',
      ),
      'physio/ph_1/logos/m.png',
    );
    expect(
      entityLogoObjectPath(
        folder: 'supplies',
        entityId: 's_1',
        png: false,
        fileId: 'm',
      ),
      'supplies/s_1/logos/m.jpg',
    );
    expect(
      entityLogoObjectPath(
        folder: 'radiology',
        entityId: 'rad1',
        png: true,
        fileId: 'm',
      ),
      'radiology/rad1/logos/m.png',
    );
  });

  test('الشعار يُحفظ مستقلاً عن الصورة ويعود بعد إعادة القراءة', () {
    final doctor = DoctorItem.fromMap({
      'doctor_name': 'طبيب',
      'specialty': 'عيون',
      'image_url': 'https://cdn.example/face.jpg',
      'logo_url': 'https://cdn.example/logo.png',
      'id': 'd1',
      'booking_status': 'available',
    });
    expect(doctor.imageUrl, contains('face.jpg'));
    expect(doctor.logoUrl, 'https://cdn.example/logo.png');
    final again = DoctorItem.fromMap({
      'doctor_name': doctor.name,
      'image_url': doctor.imageUrl,
      'logo_url': doctor.logoUrl,
      'id': doctor.id,
      'booking_status': 'available',
    });
    expect(again.imageUrl, doctor.imageUrl);
    expect(again.logoUrl, doctor.logoUrl);

    final lab = LabItem(
      id: 'l1',
      name: 'مختبر',
      imageUrl: 'https://cdn.example/lab.jpg',
      logoUrl: '',
    );
    expect(lab.toMap()['image_url'], contains('lab.jpg'));
    expect(lab.toMap()['logo_url'], isNull);
    final withLogo = LabItem(
      id: 'l1',
      name: 'مختبر',
      imageUrl: lab.imageUrl,
      logoUrl: 'https://cdn.example/mark.png',
    );
    expect(withLogo.toMap()['logo_url'], 'https://cdn.example/mark.png');
    expect(withLogo.toMap()['image_url'], lab.imageUrl);
  });

  test('شعار العلاج الطبيعي والمستلزمات من المصدر المشترك يغطي المحلي', () {
    const localPhysio = PhysioCenter(
      id: 'ph_1',
      name: 'مركز',
      address: 'أ',
      phone: '',
      whatsapp: '',
      services: ['علاج'],
      openFrom: '9',
      openTo: '5',
      isOpenNow: true,
      logoUrl: 'data:local',
    );
    final merged = EntityLogosStore.applyLogos(
      items: const [localPhysio],
      logos: const {'ph_1': 'https://cdn.example/physio-logo.png'},
      idOf: (p) => p.id,
      withLogo: (p, url) => p.copyWith(logoUrl: url),
      clearMissing: true,
    );
    expect(merged.single.logoUrl, 'https://cdn.example/physio-logo.png');

    final cleared = EntityLogosStore.applyLogos(
      items: merged,
      logos: const {},
      idOf: (p) => p.id,
      withLogo: (p, url) => p.copyWith(logoUrl: url),
      clearMissing: true,
    );
    expect(cleared.single.logoUrl, isEmpty);

    const supply = SupplyVendor(
      id: 's_1',
      name: 'محل',
      address: 'ب',
      phone: '',
      whatsapp: '',
      categories: ['مستلزمات'],
      openFrom: '9',
      openTo: '9',
      isOpenNow: true,
    );
    final supplyMerged = EntityLogosStore.applyLogos(
      items: const [supply],
      logos: const {'s_1': 'https://cdn.example/supply-logo.png'},
      idOf: (p) => p.id,
      withLogo: (p, url) => p.copyWith(logoUrl: url),
    );
    expect(supplyMerged.single.logoUrl, 'https://cdn.example/supply-logo.png');
    expect(supplyMerged.single.imageUrl, isEmpty);
  });

  testWidgets('الموبايل: صورة وبدونها، شعار وبدونه، بلا تغطية للاسم', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpCard({required bool image, required bool logo}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: _ProviderCard(
                showImage: image,
                logoUrl: logo ? _png : '',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCard(image: true, logo: false);
    expect(find.text('د. أحمد'), findsOneWidget);
    expect(find.byKey(const Key('entity_optional_logo')), findsNothing);
    expect(find.byKey(const Key('provider_portrait')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpCard(image: false, logo: false);
    expect(find.text('د. أحمد'), findsOneWidget);
    expect(find.byKey(const Key('entity_optional_logo')), findsNothing);
    expect(find.byKey(const Key('provider_portrait')), findsNothing);
    expect(tester.takeException(), isNull);

    await pumpCard(image: true, logo: true);
    expect(find.byKey(const Key('entity_optional_logo')), findsOneWidget);
    expect(find.byKey(const Key('provider_portrait')), findsOneWidget);
    final name = tester.getRect(find.text('د. أحمد'));
    final mark = tester.getRect(find.byKey(const Key('entity_optional_logo')));
    final photo = tester.getRect(find.byKey(const Key('provider_portrait')));
    expect(mark.overlaps(name), isFalse);
    expect(mark.overlaps(photo), isFalse);
    expect(mark.width, 72);
    expect(mark.height, 56);
    expect(tester.takeException(), isNull);

    await pumpCard(image: false, logo: true);
    expect(find.byKey(const Key('entity_optional_logo')), findsOneWidget);
    expect(find.byKey(const Key('provider_portrait')), findsNothing);
    expect(
      tester
          .getRect(find.byKey(const Key('entity_optional_logo')))
          .overlaps(tester.getRect(find.text('د. أحمد'))),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.showImage, required this.logoUrl});

  final bool showImage;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (logoUrl.trim().isNotEmpty) ...[
                  EntityOptionalLogo(url: logoUrl),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'د. أحمد',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (showImage)
            const SizedBox(
              key: Key('provider_portrait'),
              width: 120,
              height: 160,
              child: ColoredBox(color: Color(0xFFD7E7EA)),
            ),
        ],
      ),
    );
  }
}
