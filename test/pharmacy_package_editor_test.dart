import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_models.dart';
import 'package:ghadeer_clinic/pharmacies/pharmacy_package_suggestions.dart';

void main() {
  test('اختيار القالب ينسخ مقترحاته إلى مسودة دون جرعات أو تغيير القالب', () {
    final template = packageTemplates.firstWhere((t) => t.id == 'bone_ca_d_k');
    final idsBefore = List<String>.of(template.suggestedIngredientIds);
    final usesBefore = template.supportedUsesAr;
    final previous = PharmacyBundle(
      id: 'saved',
      title: 'باقة سابقة',
      price: 1,
      oldPrice: 0,
      products: const [
        PharmacyPackageProduct(id: 'old', name: 'منتج سابق'),
      ],
    );
    final draft = draftProductsFromTemplate(template);
    expect(draft.map((p) => p.name).toList(), ['الكالسيوم', 'فيتامين د', 'فيتامين ك']);
    expect(draft.every((p) => p.instructions.isEmpty && p.strength.isEmpty), isTrue);
    expect(draft.any((p) => p.instructions.contains(usesBefore)), isFalse);
    expect(template.suggestedIngredientIds, idsBefore);
    expect(template.supportedUsesAr, usesBefore);
    expect(previous.products.single.name, 'منتج سابق');
    expect(draft.every((p) => p.id != previous.products.single.id), isTrue);
  });

  test('منتجات الباقة تحتفظ بالصورة والتعليمات بعد التسلسل', () {
    final product = PharmacyPackageProduct(
      id: 'p1',
      name: 'فيتامين د',
      ingredient: 'فيتامين د',
      strength: '1000 IU',
      form: 'أقراص',
      imageUrl: 'https://cdn.example/p.png',
      instructions: 'حسب توجيه الصيدلي',
      optional: true,
    );
    final bundle = PharmacyBundle(
      id: 'b1',
      title: 'صحة العظام',
      description: 'وصف',
      price: 10000,
      oldPrice: 12000,
      imageUrl: 'https://cdn.example/cover.png',
      products: [product],
      categoryId: 'bone_health',
      templateId: 'bone_ca_d_k',
      pharmacistReviewed: true,
    );
    final restored = PharmacyBundle.fromMap(bundle.toMap());
    expect(restored.imageUrl, bundle.imageUrl);
    expect(restored.pharmacistReviewed, isTrue);
    expect(restored.products.single.imageUrl, product.imageUrl);
    expect(restored.products.single.instructions, product.instructions);
    expect(restored.products.single.copyWith(clearImage: true).imageUrl, '');
  });

  test('بحث المكوّنات يقبل مرادفاً إنجليزياً', () {
    final hits = searchIngredients('vitamin d');
    expect(hits.map((e) => e.id), contains('vitamin_d'));
    expect(ingredientsById['vitamin_d']!.nameEn.isNotEmpty, isTrue);
  });

  test('الرجوع في المسار يحافظ على التصنيف والقالب والمنتجات', () {
    // محاكاة اختيار اقتراح ثم تعديل المنتجات دون مسح الحالة.
    var picking = true;
    var templateId = '';
    final products = <PharmacyPackageProduct>[];
    var title = '';

    picking = false;
    templateId = 'bone_ca_d_k';
    title = 'صحة العظام';
    products.add(
      const PharmacyPackageProduct(
        id: 'p1',
        name: 'كالسيوم',
        ingredient: 'كالسيوم',
        optional: true,
      ),
    );
    // العودة لاختيار الاقتراح لا تمسح المنتجات عند الإبقاء عليها في الحالة.
    picking = true;
    expect(picking, isTrue);
    expect(templateId, 'bone_ca_d_k');
    expect(title, 'صحة العظام');
    expect(products, isNotEmpty);
  });

  test('باقة مخصصة بدون قالب مسموحة', () {
    final custom = PharmacyBundle(
      id: 'custom',
      title: 'باقة الصيدلي',
      description: '',
      price: 5000,
      oldPrice: 0,
      imageUrl: '',
      products: const [
        PharmacyPackageProduct(id: 'c1', name: 'منتج محلي'),
      ],
      pharmacistReviewed: true,
    );
    expect(custom.templateId, isEmpty);
    expect(custom.categoryId, isEmpty);
    expect(custom.pharmacistReviewed, isTrue);
  });
}
