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

/// يميّز جملة القسم عن طبيب العيون وعن اختصاص التجميل، ويلقط التمريض المنزلي.
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

  /// كلمة التمريض الصريحة (مع حروف ملتصقة: بالممرض، للممرضة، ممرضين…).
  static final _nursingWord = RegExp(
    r'\S*ممرض\S*|\S*تمريض\S*(?:\s+(?:ال)?منزلي\S*)?',
  );

  /// خدمة تمريض بالبيت بلا كلمة «ممرض»: «زرق ابره بالبيت»، «مغذي للبيت».
  /// الخدمة وحدها (بلا ذكر البيت) ما تكفي — قد تكون سؤال صيدلية أو عيادة.
  static final _homeService = RegExp(
    // حدود كلمة حتى لا تُلقط أسماء مثل «الازرق» أو «ابراهيم».
    r'(?:^|\s)(?:ي|ت|ن)?زرق\S{0,4}(?=\s|$)|'
    r'(?:^|\s)\S{0,3}ابر(?:ه|ة)?(?=\s|$)|'
    r'(?:^|\s)\S{0,3}(?:مغذي\S{0,2}|كانيول\S{0,2}|تضميد|ضماد|قسطر\S{0,2}|'
    r'سوند\S{0,2})(?=\s|$)|'
    r'غيار\s*(?:ال)?جرح\S{0,2}|قياس\s*(?:ال)?(?:ضغط|سكر)',
  );

  static final _homeVisit = RegExp(
    r'(?:^|\s)(?:بال|لل|ب|ال)?(?:بيت|منزل)(?:نا|ي|كم|هم)?(?=\s|$)|'
    r'منزلي|زياره\s*(?:بيتيه|منزليه)',
  );

  /// كلام طلب شائع بجمل التمريض يبقى بعد حذف «ممرض» ولا يصلح اسماً.
  static final _nursingFiller = RegExp(
    r'(?:^|\s)(?:(?:ي|ت)(?:جي|اتي|زور|زرق|ركب|ضمد|غير|قيس)\S*|'
    r'جرح\S*|جروح|قياس|ضغط|سكر|'
    r'احد|واحد|عدنا|عندنا|عدكم|عندكم|اكو|يوجد|موجود|متوفر\S*|محتاج|احتاج|'
    r'نحتاج|ممكن|حتى|مريض\S*|لمريض\S*|لامي|لابوي|لوالدي|لوالدتي|هسه|هسا|'
    r'اليوم|باجر|باچر|بالليل|الليله|قريب\S*|شنو|منو|زين|رجاء\S*)(?=\s|$)',
  );

  static bool _isNursing(String n) =>
      _nursingWord.hasMatch(n) ||
      (_homeService.hasMatch(n) && _homeVisit.hasMatch(n));

  static final _noise = RegExp(
    r'(?:^|\s)(?:ابحث|دور|اريد|ابي|وين|اين|افتح|اعرض|اتصل|اتصال|'
    r'واتساب|واتس|وتساب|راسل|دز|موقع|عنوان|تفاصيل|ملف|بطاقه|لي)(?=\s|$)',
  );

  /// حروف/أدوات تبقى بعد حذف كلمة القسم الملتصقة بها (بعوينات، لعوينات…).
  static final _leftoverParticle = RegExp(
    r'(?:^|\s)(?:ب|ل|لل|و|ف|على|علي|الى|الي|عن|في|من|مع|ال)(?=\s|$)',
  );

  /// نفس [_leftoverParticle] بدون «علي»: بالتمريض «اتصل بالممرض علي» = اسم.
  static final _nurseNameParticle = RegExp(
    r'(?:^|\s)(?:ب|ل|لل|و|ف|على|الى|الي|عن|في|من|مع|ال)(?=\s|$)',
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
    if (_isNursing(n)) return ServiceCenterKind.nursing;
    return null;
  }

  /// بقية الاسم بعد حذف كلمات القسم وأفعال الطلب. فارغ إن لم يبقَ اسم.
  static String? nameHint(String raw) {
    final kind = kindFor(raw);
    if (kind == null) return null;
    var n = ArabicTextUtils.normalize(raw);
    if (kind == ServiceCenterKind.nursing) {
      // «اريد ممرض يجي للبيت يزرق ابره» → لا اسم؛ «اتصل بالممرض علي» → علي.
      n = n
          .replaceAll(_nursingWord, ' ')
          .replaceAll(_homeVisit, ' ')
          .replaceAll(_nursingFiller, ' ')
          .replaceAll(_homeService, ' ');
    }
    n = n
        .replaceAll(_optics, ' ')
        .replaceAll(_beautyCenter, ' ')
        .replaceAll(_noise, ' ')
        // «اتصل بعوينات الشطرة» كان يبقى «ب الشطره» فلا يُطابق أي مركز.
        .replaceAll(
          kind == ServiceCenterKind.nursing
              ? _nurseNameParticle
              : _leftoverParticle,
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.length < 2) return null;
    if (RegExp(r'^(?:عن|في|من|على|الى)$').hasMatch(n)) return null;
    return n;
  }
}
