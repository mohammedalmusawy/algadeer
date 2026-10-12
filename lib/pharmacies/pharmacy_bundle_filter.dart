import 'pharmacy_models.dart';
import 'pharmacy_package_suggestions.dart' as suggestions;

/// تصفية باقات الصيدلية محلياً: بحث نصي، عروض، الأكثر طلباً، وتصنيف.
/// منطق نقي بلا واجهة حتى يُختبر مباشرة.
abstract final class PharmacyBundleFilter {
  /// توحيد الحروف العربية الشائعة حتى «فيتامين» = «فيتامين» بأي همزة/تاء.
  static String normalize(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp('[ً-ْـ]'), '');
    s = s
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _haystack(PharmacyBundle b) => normalize(
    [
      b.title,
      b.subtitle,
      b.description,
      b.note,
      ...b.supplements,
      ...b.optionalSupplements,
      for (final p in b.products) ...[p.name, p.ingredient, p.form],
    ].join(' '),
  );

  /// كل كلمة في البحث لازم تظهر في الباقة (اسم، وصف، مكوّن، منتج).
  static List<PharmacyBundle> search(List<PharmacyBundle> all, String query) {
    final words = normalize(
      query,
    ).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return List.of(all);
    return [
      for (final b in all)
        if (words.every(_haystack(b).contains)) b,
    ];
  }

  static bool hasDiscount(PharmacyBundle b) =>
      b.price > 0 && b.oldPrice > b.price;

  static List<PharmacyBundle> offers(List<PharmacyBundle> all) =>
      [for (final b in all) if (hasDiscount(b)) b];

  static List<PharmacyBundle> popular(List<PharmacyBundle> all) =>
      [for (final b in all) if (b.isPopular) b];

  static List<PharmacyBundle> byCategory(
    List<PharmacyBundle> all,
    String categoryId,
  ) => [for (final b in all) if (b.categoryId == categoryId) b];

  /// التصنيفات الموجودة فعلاً في باقات هذه الصيدلية فقط (بلا خيارات فارغة).
  static List<suggestions.PharmacySuggestionCategory> categoriesIn(
    List<PharmacyBundle> all,
  ) {
    final ids = {for (final b in all) b.categoryId}..remove('');
    return [
      for (final c in suggestions.categories)
        if (ids.contains(c.id)) c,
    ];
  }
}
