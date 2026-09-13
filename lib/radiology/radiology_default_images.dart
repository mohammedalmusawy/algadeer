import '../branding/ghadeer_brand_mark.dart';

/// صور افتراضية لمراكز الأشعة.
class RadiologyDefaultImages {
  RadiologyDefaultImages._();

  static const List<({String id, String label, String url})> all = [
    (
      id: 'rad_ghadeer_logo',
      label: 'الشعار المعتمد',
      url: GhadeerBranding.officialLogoAsset,
    ),
    (
      id: 'rad_chest',
      label: 'أشعة صدر',
      url: 'assets/radiology/chest_xray.png',
    ),
  ];

  static bool isAssetPath(String path) => path.trim().startsWith('assets/');

  static String? matchIdForUrl(String url) {
    final u = GhadeerBranding.normalizeEntityImageUrl(url.trim());
    if (u.isEmpty) return null;
    for (final item in all) {
      if (u == item.url) return item.id;
    }
    return null;
  }

  static String displayUrl({required String imageUrl, String centerId = ''}) {
    final existing = GhadeerBranding.normalizeEntityImageUrl(imageUrl.trim());
    if (existing.isNotEmpty) return existing;
    if (all.isEmpty) return '';
    final pool = all.where((e) => e.id != 'rad_ghadeer_logo').toList();
    final source = pool.isEmpty ? all : pool;
    if (centerId.isEmpty) return source.first.url;
    final idx = centerId.hashCode.abs() % source.length;
    return source[idx].url;
  }
}
