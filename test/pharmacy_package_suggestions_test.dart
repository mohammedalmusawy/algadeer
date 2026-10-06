import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_catalog_bundles.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_package_suggestions.dart';

void main() {
  test('إصدار الكتالوج >= 1', () {
    expect(pharmacyPackageSuggestionCatalogVersion, greaterThanOrEqualTo(1));
  });

  test('الفيتامينات الـ13 موجودة', () {
    const expected = [
      'vitamin_a',
      'vitamin_c',
      'vitamin_d',
      'vitamin_e',
      'vitamin_k',
      'vitamin_b1',
      'vitamin_b2',
      'vitamin_b3',
      'vitamin_b5',
      'vitamin_b6',
      'vitamin_b7',
      'vitamin_b9',
      'vitamin_b12',
    ];
    for (final id in expected) {
      expect(ingredientsById.containsKey(id), isTrue, reason: id);
      expect(
        ingredientsById[id]!.kind,
        PharmacyIngredientKind.vitamin,
        reason: id,
      );
    }
  });

  test('كل تصنيف له قالب واحد على الأقل', () {
    for (final cat in categories) {
      expect(
        templatesForCategory(cat.id),
        isNotEmpty,
        reason: cat.id,
      );
    }
  });

  test('بحث المكوّنات يجد «فيتامين د»', () {
    final hits = searchIngredients('فيتامين د');
    expect(hits.map((e) => e.id), contains('vitamin_d'));
  });

  test('بحث المكوّنات يقبل مرادفاً إنجليزياً', () {
    final hits = searchIngredients('vitamin d');
    expect(hits.map((e) => e.id), contains('vitamin_d'));
    expect(ingredientsById['vitamin_d']!.nameEn.isNotEmpty, isTrue);
  });

  test('templatesForCategory يفلتر حسب التصنيف', () {
    final bone = templatesForCategory('bone_health');
    expect(bone, isNotEmpty);
    expect(bone.every((t) => t.categoryId == 'bone_health'), isTrue);
    expect(
      templatesForCategory('bone_health').length,
      lessThan(packageTemplates.length),
    );
  });

  test('معرّفات المكوّنات في القوالب موجودة في الكتالوج', () {
    for (final t in packageTemplates) {
      for (final id in t.suggestedIngredientIds) {
        expect(
          ingredientsById.containsKey(id),
          isTrue,
          reason: '${t.id} -> $id',
        );
      }
    }
  });

  test('existingCatalogPackageTitles يطابق عناوين PharmacyCatalogBundles', () {
    final titles = existingCatalogPackageTitles();
    final expected =
        PharmacyCatalogBundles.all.map((b) => b.title).toList(growable: false);
    expect(titles, expected);
    expect(titles.length, 35);
  });
}
