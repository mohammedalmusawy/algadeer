import '../search/arabic_text_utils.dart';

/// قسم دليل: بصريات أو تجميل أو تمريض منزلي. ليس اختصاص طبيب.
enum ServiceCenterKind {
  optics,
  beauty,

  /// ممرض أو ممرضة يزورون المريض بالبيت (زرق، مغذي، ضماد، قياس…).
  nursing;

  String get dbValue => name;

  String get sectionTitle => switch (this) {
        ServiceCenterKind.optics => 'العوينات وفحص البصر',
        ServiceCenterKind.beauty => 'مراكز التجميل',
        ServiceCenterKind.nursing => 'التمريض المنزلي',
      };

  String get shortLabel => switch (this) {
        ServiceCenterKind.optics => 'بصريات',
        ServiceCenterKind.beauty => 'تجميل',
        ServiceCenterKind.nursing => 'تمريض منزلي',
      };

  /// عنوان حقل الاسم بالإدارة.
  String get nameFieldLabel => switch (this) {
        ServiceCenterKind.nursing => 'الاسم (الممرض أو الممرضة)',
        _ => 'اسم المركز',
      };

  /// مثال للاسم حتى تبقى التسمية مرتبة مثل بطاقات الأطباء.
  String get nameFieldHint => switch (this) {
        ServiceCenterKind.nursing => 'مثال: الممرض علي حسن / الممرضة زينب كاظم',
        _ => '',
      };

  String get emptyVisitorsMessage => switch (this) {
        ServiceCenterKind.optics =>
          'لا توجد مراكز عوينات أو فحص بصر مضافة بعد.',
        ServiceCenterKind.beauty => 'لا توجد مراكز تجميل مضافة بعد.',
        ServiceCenterKind.nursing => 'لا يوجد ممرضون للزيارات المنزلية مضافون بعد.',
      };

  String get unavailableMessage =>
      'تعذر تحميل المراكز. تأكد من تنفيذ جدول service_centers ثم أعد المحاولة.';

  static ServiceCenterKind? fromDb(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'optics':
        return ServiceCenterKind.optics;
      case 'beauty':
        return ServiceCenterKind.beauty;
      case 'nursing':
        return ServiceCenterKind.nursing;
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
    r'(?:مركز|مراكز)\s*(?:ال)?بصريات',
  );

  static final _beautyDoctor = RegExp(
    r'(?:طبيب|دكتور|دكتوره|طبيبه|جراح|جراحه|اختصاص|اخصائي|استشاري)\s*(?:ال)?تجميل|'
    r'تجميل\s*جلد|الجلديه',
  );

  static final _beautyCenter = RegExp(
    // «مركز» بالمفرد كان لا يُطابق («مراكز?» = مراك/مراكز فقط).
    r'(?:مركز|مراكز)\s*(?:ال)?تجميل|صالون\s*(?:ال)?تجميل',
  );

  static final _noise = RegExp(
    r'(?:^|\s)(?:ابحث|دور|اريد|ابي|وين|اين|افتح|اعرض|اتصل|اتصال|'
    r'واتساب|واتس|وتساب|راسل|دز|موقع|عنوان|تفاصيل|ملف|بطاقه|لي)(?=\s|$)',
  );

  /// حروف/أدوات تبقى بعد حذف كلمة القسم الملتصقة بها (بعوينات، لعوينات…).
  static final _leftoverParticle = RegExp(
    r'(?:^|\s)(?:ب|ل|لل|و|ف|على|علي|الى|الي|عن|في|من|مع|ال)(?=\s|$)',
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
        // «اتصل بعوينات الشطرة» كان يبقى «ب الشطره» فلا يُطابق أي مركز.
        .replaceAll(_leftoverParticle, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.length < 2) return null;
    if (RegExp(r'^(?:عن|في|من|على|الى)$').hasMatch(n)) return null;
    return n;
  }
}
