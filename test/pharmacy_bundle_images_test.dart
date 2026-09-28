import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_catalog_bundles.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_order_message.dart';

void main() {
  group('pharmacy catalog packages', () {
    test('catalog has 35 packages with supplements', () {
      expect(PharmacyCatalogBundles.all, hasLength(35));
      expect(
        PharmacyCatalogBundles.all.every((b) => b.supplements.isNotEmpty),
        isTrue,
      );
      expect(
        PharmacyCatalogBundles.all.any((b) => b.id == 'immune'),
        isTrue,
      );
      expect(
        PharmacyCatalogBundles.all.any((b) => b.id == 'pregnancy'),
        isTrue,
      );
    });

    test('mergeWithCatalog keeps admin edits and adds missing packages', () {
      const saved = [
        PharmacyBundle(
          id: 'immune',
          title: 'مخصص',
          price: 1000,
          oldPrice: 2000,
          imageUrl: 'https://example.com/x.jpg',
          isVisible: false,
          supplements: ['Zinc'],
        ),
      ];
      final merged = PharmaciesCatalog.mergeWithCatalog(saved);
      expect(merged.length, PharmacyCatalogBundles.all.length);
      final immune = merged.firstWhere((b) => b.id == 'immune');
      expect(immune.title, 'مخصص');
      expect(immune.price, 1000);
      expect(immune.imageUrl, 'https://example.com/x.jpg');
      expect(immune.isVisible, isFalse);
      expect(immune.supplements, ['Zinc']);
      expect(merged.any((b) => b.id == 'joints'), isTrue);
    });

    test('visibleOnly hides invisible packages from customer views', () {
      final all = [
        const PharmacyBundle(
          id: 'a',
          title: 'ظاهرة',
          price: 1,
          oldPrice: 2,
          imageUrl: 'https://example.com/a.jpg',
          isVisible: true,
          supplements: ['Vitamin C'],
        ),
        const PharmacyBundle(
          id: 'b',
          title: 'مخفية',
          price: 1,
          oldPrice: 2,
          imageUrl: 'https://example.com/b.jpg',
          isVisible: false,
          supplements: ['Zinc'],
        ),
      ];
      final visible = PharmaciesCatalog.visibleOnly(all);
      expect(visible, hasLength(1));
      expect(visible.single.id, 'a');
    });

    test('popularForStrip ignores hidden packages', () {
      final many = [
        for (var i = 0; i < 8; i++)
          PharmacyBundle(
            id: 'b$i',
            title: 'باقة $i',
            price: i,
            oldPrice: i + 1,
            isPopular: true,
            isVisible: i != 0,
            imageUrl: 'https://example.com/$i.jpg',
            supplements: const ['Vitamin D3'],
          ),
      ];
      final strip = PharmaciesCatalog.popularForStrip(many);
      expect(strip.every((b) => b.isVisible), isTrue);
      expect(strip.any((b) => b.id == 'b0'), isFalse);
      expect(strip.length, lessThanOrEqualTo(PharmaciesCatalog.stripPopularLimit));
    });
  });

  group('pharmacy order message', () {
    test('build includes Ghadeer attribution, package and supplements', () {
      final msg = PharmacyOrderMessage.build(
        pharmacyName: 'صيدلية رحاب',
        packageName: 'باقة دعم المناعة',
        supplements: const ['Vitamin D3', 'Vitamin C', 'Zinc'],
        optionalIncluded: const ['Magnesium'],
        subtitle: 'D3 · C · Zinc',
        note: 'حسب تقييم الصيدلي',
      );
      expect(msg, contains('طلب من منصة الغدير'));
      expect(msg, contains('صيدلية رحاب'));
      expect(msg, contains('باقة دعم المناعة'));
      expect(msg, contains('Vitamin D3'));
      expect(msg, contains('Magnesium'));
      expect(msg, contains('تفاصيل المكملات'));
      expect(msg, contains('حسب تقييم الصيدلي'));
    });

    test('buildFromBundle includes package name and details', () {
      const b = PharmacyBundle(
        id: 'immune',
        title: 'باقة دعم المناعة',
        subtitle: 'فيتامينات المناعة',
        price: 38000,
        oldPrice: 50000,
        imageUrl: 'https://example.com/i.jpg',
        supplements: ['Vitamin D3', 'Vitamin C', 'Zinc'],
        note: 'اختياري حسب التقييم',
      );
      final msg = PharmacyOrderMessage.buildFromBundle(
        pharmacyName: 'صيدلية رحاب',
        bundle: b,
      );
      expect(msg, contains('باقة دعم المناعة'));
      expect(msg, contains('فيتامينات المناعة'));
      expect(msg, contains('Vitamin C'));
      expect(msg, contains('38,000'));
      expect(msg, contains('منصة الغدير'));
    });

    test('custom package marked as custom', () {
      final msg = PharmacyOrderMessage.build(
        pharmacyName: 'صيدلية',
        packageName: 'اختر باقتك بنفسك',
        supplements: const ['Omega-3'],
        isCustom: true,
      );
      expect(msg, contains('مخصصة'));
    });

    test('new packages default to visible', () {
      const b = PharmacyBundle(
        id: 'x',
        title: 'باقة',
        price: 0,
        oldPrice: 0,
      );
      expect(b.isVisible, isTrue);
      final fromMap = PharmacyBundle.fromMap({
        'id': 'y',
        'title': 'ب',
        'price': 1,
        'oldPrice': 2,
      });
      expect(fromMap.isVisible, isTrue);
    });
  });

  group('legacy enrich', () {
    test('enrichBundle fills missing image from catalog sample', () {
      const bare = PharmacyBundle(
        id: 'immune',
        title: 'باقة المناعة',
        price: 38000,
        oldPrice: 50000,
      );
      final enriched = PharmaciesCatalog.enrichBundle(bare);
      expect(enriched.imageUrl, isNotEmpty);
      expect(enriched.supplements, isNotEmpty);
    });

    test('enrichBundle keeps admin imageUrl', () {
      const custom = PharmacyBundle(
        id: 'immune',
        title: 'باقة المناعة',
        price: 1,
        oldPrice: 2,
        imageUrl: 'https://example.com/custom.jpg',
      );
      final enriched = PharmaciesCatalog.enrichBundle(custom);
      expect(enriched.imageUrl, 'https://example.com/custom.jpg');
    });

    test('fromMap tolerates legacy pharmacy without offer fields', () {
      final p = PharmacyItem.fromMap({
        'id': 'rehab',
        'name': 'صيدلية رحاب',
        'address': 'الشطرة',
        'phone': '0780',
        'whatsapp': '964',
        'tags': ['أدوية عامة'],
        'openFrom': '8',
        'openTo': '11',
        'isOpenNow': true,
        'bundles': [
          {'id': 'bones', 'title': 'باقة', 'price': 1, 'oldPrice': 2},
        ],
      });
      expect(p.offerImageUrl, isEmpty);
      expect(p.bundles.single.isVisible, isTrue);
      final enriched = PharmaciesCatalog.enrichBundle(p.bundles.single);
      expect(enriched.imageUrl, isNotEmpty);
      expect(enriched.supplements, isNotEmpty);
    });
  });
}
