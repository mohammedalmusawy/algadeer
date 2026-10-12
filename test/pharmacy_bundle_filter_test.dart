import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_bundle_filter.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';

/// زر التصفية وزر العروض والبحث بصفحة الصيدلية كانت تعطي «قريباً» فقط.
void main() {
  const vitD = PharmacyBundle(
    id: 'd',
    title: 'باقة فيتامين د',
    price: 15000,
    oldPrice: 20000,
    categoryId: 'bone_health',
    supplements: ['فيتامين D3', 'كالسيوم'],
  );
  const iron = PharmacyBundle(
    id: 'iron',
    title: 'باقة الحديد',
    price: 10000,
    oldPrice: 0,
    isPopular: false,
    categoryId: 'pregnancy_preconception',
    products: [
      PharmacyPackageProduct(id: 'p1', name: 'Ferrous', ingredient: 'حديد'),
    ],
  );
  const sport = PharmacyBundle(
    id: 's',
    title: 'باقة الرياضيين',
    price: 0,
    oldPrice: 5000,
  );
  const all = [vitD, iron, sport];

  test('search matches title, supplements and product ingredients', () {
    expect(PharmacyBundleFilter.search(all, 'كالسيوم').map((b) => b.id), [
      'd',
    ]);
    expect(PharmacyBundleFilter.search(all, 'حديد').map((b) => b.id), [
      'iron',
    ]);
    expect(PharmacyBundleFilter.search(all, '  ').length, 3);
    expect(PharmacyBundleFilter.search(all, 'شي ما موجود'), isEmpty);
  });

  test('search ignores hamza, taa marbuta and diacritics', () {
    expect(
      PharmacyBundleFilter.search(all, 'باقه الرياضيين').map((b) => b.id),
      ['s'],
    );
    expect(PharmacyBundleFilter.normalize('أَحمد'), 'احمد');
  });

  test('offers keep only real discounts with a price', () {
    expect(PharmacyBundleFilter.offers(all).map((b) => b.id), ['d']);
  });

  test('popular and category filters', () {
    expect(PharmacyBundleFilter.popular(all).map((b) => b.id), ['d', 's']);
    expect(
      PharmacyBundleFilter.byCategory(all, 'bone_health').map((b) => b.id),
      ['d'],
    );
    final cats = PharmacyBundleFilter.categoriesIn(all).map((c) => c.id);
    expect(cats, containsAll(['bone_health', 'pregnancy_preconception']));
    expect(cats.length, 2);
  });
}
