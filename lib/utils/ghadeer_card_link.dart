import 'package:share_plus/share_plus.dart';

/// نوع البطاقة داخل رابط المشاركة.
enum GhadeerCardKind {
  doctor('doctor'),
  lab('lab'),
  radiology('radiology'),
  pharmacy('pharmacy'),
  physio('physio'),
  supply('supply'),

  /// عوينات / تجميل / تمريض منزلي (جدول service_centers).
  center('center');

  const GhadeerCardKind(this.path);

  final String path;

  static GhadeerCardKind? fromPath(String raw) {
    final p = raw.trim().toLowerCase();
    for (final k in values) {
      if (k.path == p) return k;
    }
    return null;
  }
}

/// مرجع بطاقة مستخرج من رابط.
class GhadeerCardRef {
  const GhadeerCardRef(this.kind, this.id);

  final GhadeerCardKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is GhadeerCardRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'GhadeerCardRef(${kind.path}, $id)';
}

/// رابط مشاركة واحد لكل البطاقات:
/// `https://<الموقع>/c/<النوع>/<المعرّف>`
///
/// - التطبيق منزّل (أندرويد): الرابط يفتح التطبيق مباشرة على البطاقة.
/// - مو منزّل: صفحة صغيرة (web/open.html) تقترح التنزيل وزر «افتح بالتطبيق».
/// - `ghadeerclinic://<النوع>/<المعرّف>` يفتح التطبيق من تلك الصفحة (آيفون وأندرويد).
abstract final class GhadeerCardLink {
  /// موقع Netlify المنشور. غيّره هنا فقط إذا تبدّل الدومين.
  static const webBase = 'https://frolicking-sawine-d5ecbb.netlify.app';
  static const appScheme = 'ghadeerclinic';
  static const androidPackage = 'com.mohammed.ghadeer';

  /// يشتغل بعد نشر التطبيق على Google Play.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';

  /// حدّثه برقم التطبيق بعد نشره على App Store.
  static const appStoreUrl = 'https://apps.apple.com/app/id000000000';

  static String url(GhadeerCardKind kind, String id) =>
      '$webBase/c/${kind.path}/${Uri.encodeComponent(id.trim())}';

  static String appUrl(GhadeerCardKind kind, String id) =>
      '$appScheme://${kind.path}/${Uri.encodeComponent(id.trim())}';

  /// يقرأ الروابط الجديدة والقديمة (`#/doctor/id`, `#/lab/id`, `?doctor=`).
  static GhadeerCardRef? parse(Uri uri) {
    GhadeerCardRef? make(String kind, String id) {
      final k = GhadeerCardKind.fromPath(kind);
      final clean = Uri.decodeComponent(id.split('?').first.trim());
      if (k == null || clean.isEmpty) return null;
      return GhadeerCardRef(k, clean);
    }

    try {
      if (uri.scheme == appScheme) {
        final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (uri.host.isNotEmpty && segs.isNotEmpty) {
          return make(uri.host, segs.first);
        }
        if (segs.length >= 2) return make(segs[0], segs[1]);
        return null;
      }
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.length >= 3 && segs[0] == 'c') return make(segs[1], segs[2]);
      if (segs.length >= 2) {
        final r = make(segs[0], segs[1]);
        if (r != null) return r;
      }
      final frag = uri.fragment.replaceFirst(RegExp(r'^/'), '');
      final fs = frag.split('/').where((s) => s.isNotEmpty).toList();
      if (fs.length >= 3 && fs[0] == 'c') return make(fs[1], fs[2]);
      if (fs.length >= 2) {
        final r = make(fs[0], fs[1]);
        if (r != null) return r;
      }
      final q = uri.queryParameters;
      for (final k in GhadeerCardKind.values) {
        final v = q[k.path];
        if (v != null && v.trim().isNotEmpty) {
          return GhadeerCardRef(k, v.trim());
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// نص المشاركة: الاسم، وصف قصير، والرابط.
  static String shareText({
    required GhadeerCardKind kind,
    required String id,
    required String name,
    String subtitle = '',
  }) {
    final lines = <String>[
      name.trim(),
      if (subtitle.trim().isNotEmpty) subtitle.trim(),
      '',
      'افتح البطاقة بتطبيق الغدير:',
      url(kind, id),
    ];
    return lines.join('\n');
  }

  static Future<void> share({
    required GhadeerCardKind kind,
    required String id,
    required String name,
    String subtitle = '',
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: shareText(kind: kind, id: id, name: name, subtitle: subtitle),
        subject: '$name — منصة الغدير',
      ),
    );
  }
}
