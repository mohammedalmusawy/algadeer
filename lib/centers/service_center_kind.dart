import '../search/arabic_text_utils.dart';

/// قسم دليل: بصريات أو تجميل. ليس اختصاص طبيب.
enum ServiceCenterKind {
  optics,
  beauty;

  String get dbValue => name;

  String get sectionTitle => switch (this) {
        ServiceCenterKind.optics => 'العوينات وفحص البصر',
        ServiceCenterKind.beauty => 'مراكز التجميل',
      };

  String get shortLabel => switch (this) {
        ServiceCenterKind.optics => 'بصريات',
        ServiceCenterKind.beauty => 'تجميل',
      };

  String get emptyVisitorsMessage => switch (this) {
        ServiceCenterKind.optics =>
          'لا توجد مراكز عوينات أو فحص بصر مضافة بعد.',
        ServiceCenterKind.beauty => 'لا توجد مراكز تجميل مضافة بعد.',
      };

  String get unavailableMessage =>
      'تعذر تحميل المراكز. تأكد من تنفيذ جدول service_centers ثم أعد المحاولة.';

  static ServiceCenterKind? fromDb(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'optics':
        return ServiceCenterKind.optics;
      case 'beauty':
        return ServiceCenterKind.beauty;
      default:
        return null;
    }
  }
}

/// يميّز جملة القسم عن طبيب العيون وعن اختصاص التجميل.
class ServiceCenterQuery {
  const ServiceCenterQuery._();

  static final _eyeDoctor = RegExp(
    r'(?:طبيب|دكتور|دكتوره|طبيبه|اختصاص|اخصائي|استشاري)\s*(?:ال)?عيون|'
    r'اطباء\s*(?:ال)?عيون',
  );

  static final _optics = RegExp(
    r'عوين\S*|نظار\S*|فحص\s*(?:ال)?بصر|فحص\s*نظر|بصريات|عدسات|'
    r'مراكز?\s*(?:ال)?بصريات',
  );

  static final _beautyDoctor = RegExp(
    r'(?:طبيب|دكتور|دكتوره|طبيبه|جراح|جراحه|اختصاص|اخصائي|استشاري)\s*(?:ال)?تجميل|'
    r'تجميل\s*جلد|الجلديه',
  );

  static final _beautyCenter = RegExp(
    r'مراكز?\s*(?:ال)?تجميل|صالون\s*(?:ال)?تجميل',
  );

  static final _noise = RegExp(
    r'(?:^|\s)(?:ابحث|دور|اريد|ابي|وين|اين|افتح|اعرض|اتصل|اتصال|'
    r'واتساب|واتس|وتساب|راسل|دز|موقع|عنوان|تفاصيل|ملف|بطاقه|لي)(?=\s|$)',
  );

  /// null يعني: ليست جملة قسم، وتمر لمسار الأطباء أو الاختصاص.
  static ServiceCenterKind? kindFor(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return null;
    if (_eyeDoctor.hasMatch(n)) return null;
    final center = _beautyCenter.hasMatch(n);
    if (_beautyDoctor.hasMatch(n)) return null;
    if (_optics.hasMatch(n)) return ServiceCenterKind.optics;
    if (center) return ServiceCenterKind.beauty;
    return null;
  }

  /// بقية الاسم بعد حذف كلمات القسم وأفعال الطلب. فارغ إن لم يبقَ اسم.
  static String? nameHint(String raw) {
    if (kindFor(raw) == null) return null;
    var n = ArabicTextUtils.normalize(raw);
    n = n
        .replaceAll(_optics, ' ')
        .replaceAll(_beautyCenter, ' ')
        .replaceAll(_noise, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.length < 2) return null;
    if (RegExp(r'^(?:عن|في|من|على|الى)$').hasMatch(n)) return null;
    return n;
  }
}
