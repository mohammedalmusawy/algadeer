import '../branding/ghadeer_brand_mark.dart';

/// صور افتراضية للمختبرات — أيقونات محلية من ملفات المشروع.
class LabDefaultImages {
  LabDefaultImages._();

  static const List<({String id, String label, String url})> all = [
    (
      id: 'lab_microscope',
      label: 'مجهر',
      url: 'assets/labs/defaults/lab_microscope.png',
    ),
    (
      id: 'lab_test_tubes',
      label: 'أنابيب فحص',
      url: 'assets/labs/defaults/lab_test_tubes.png',
    ),
    (
      id: 'lab_flask',
      label: 'دورق مختبر',
      url: 'assets/labs/defaults/lab_flask.png',
    ),
    (
      id: 'lab_report',
      label: 'تقرير مختبر',
      url: 'assets/labs/defaults/lab_report.png',
    ),
    (
      id: 'lab_pipette_slide',
      label: 'عينة شريحة',
      url: 'assets/labs/defaults/lab_pipette_slide.png',
    ),
    (
      id: 'lab_kit_3d',
      label: 'أجهزة مختبر',
      url: 'assets/labs/defaults/lab_kit_3d.png',
    ),
    (
      id: 'lab_blood_sample',
      label: 'عينة دم',
      url: 'assets/labs/defaults/lab_blood_sample.jpg',
    ),
    (
      id: 'lab_blood_draw',
      label: 'سحب دم',
      url: 'assets/labs/defaults/lab_blood_draw.png',
    ),
    (
      id: 'lab_ghadeer_logo',
      label: 'الشعار المعتمد',
      url: GhadeerBranding.officialLogoAsset,
    ),
  ];

  static bool isAssetPath(String path) {
    final p = path.trim();
    return p.startsWith('assets/');
  }

  static String? matchIdForUrl(String url) {
    final u = GhadeerBranding.normalizeEntityImageUrl(url.trim());
    if (u.isEmpty) return null;
    for (final item in all) {
      if (u == item.url) return item.id;
      final marker = item.url.split('?').first;
      if (u == item.url || u.startsWith(marker)) return item.id;
    }
    return null;
  }

  /// إن وُجدت صورة محفوظة تُستخدم، وإلا صورة افتراضية ثابتة حسب معرف المختبر.
  static String displayUrl({required String imageUrl, String labId = ''}) {
    final existing = GhadeerBranding.normalizeEntityImageUrl(imageUrl.trim());
    if (existing.isNotEmpty) return existing;
    if (all.isEmpty) return '';
    // لا نستخدم لوغو الغدير كافتراضي عشوائي لصورة المختبر.
    final pool = all.where((e) => e.id != 'lab_ghadeer_logo').toList();
    final source = pool.isEmpty ? all : pool;
    if (labId.isEmpty) return source.first.url;
    final idx = labId.hashCode.abs() % source.length;
    return source[idx].url;
  }
}
