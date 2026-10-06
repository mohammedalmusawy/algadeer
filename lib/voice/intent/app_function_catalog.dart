/// سجل داخلي لوظائف التطبيق التي يفهمها العقل المحلي وينفّذها.
///
/// لا يكتشف تغييرات الكود تلقائيًا — أي وظيفة جديدة تُضاف هنا يدويًا
/// مع صيغ الطلب ومسار التنفيذ والصلاحيات.
class AppFunctionEntry {
  const AppFunctionEntry({
    required this.id,
    required this.descriptionAr,
    required this.examplePhrases,
    required this.executionPath,
    this.requiresPatientAuth = false,
    this.requiresSelection = false,
  });

  final String id;
  final String descriptionAr;
  final List<String> examplePhrases;
  final String executionPath;
  final bool requiresPatientAuth;
  final bool requiresSelection;
}

class AppFunctionCatalog {
  AppFunctionCatalog._();

  static const List<AppFunctionEntry> entries = [
    AppFunctionEntry(
      id: 'specialty_search',
      descriptionAr: 'بحث أطباء حسب الاختصاص',
      examplePhrases: ['أريد طبيب أطفال', 'دورلي أسنان', 'أكو طبيب عظام'],
      executionPath: 'IntentResolver→specialtySearch→runSpecialtySearch',
    ),
    AppFunctionEntry(
      id: 'select_ordinal',
      descriptionAr: 'اختيار نتيجة بالترتيب دون فتح',
      examplePhrases: ['الثاني', 'اختار الأول', 'لا مو الثاني الأول'],
      executionPath: 'selectResult→selectEntity',
      requiresSelection: false,
    ),
    AppFunctionEntry(
      id: 'open_ordinal',
      descriptionAr: 'اختيار وفتح بطاقة بالترتيب',
      examplePhrases: ['افتح الثاني', 'افتح الأول'],
      executionPath: 'selectResult+open→openProfile→_openDoctor',
    ),
    AppFunctionEntry(
      id: 'open_selected_profile',
      descriptionAr: 'فتح بطاقة الكيان المختار',
      examplePhrases: [
        'افتح التفاصيل',
        'افتح بطاقته',
        'ورّيني معلوماته',
        'افتحه',
      ],
      executionPath: 'showProfile→openProfile→نفس مسار زر عرض التفاصيل',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'show_phone',
      descriptionAr: 'عرض رقم الاتصال المسجّل دون الاتصال',
      examplePhrases: ['ورّيني رقمه', 'شنو رقمه'],
      executionPath: 'callDoctor+show_phone→رسالة بالرقم بعد إعادة تحقق حية',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'call_selected',
      descriptionAr: 'الاتصال بالكيان المختار بعد إعادة تحقق حية',
      examplePhrases: ['اتصل بيه', 'كلّمه'],
      executionPath: 'call*→_withLiveEntity→prepareCall',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'availability_question',
      descriptionAr: 'سؤال الدوام/التواجد حسب الجدول المسجّل فقط',
      examplePhrases: ['شنو دوامه', 'هل متواجد اليوم'],
      executionPath: 'doctorAvailability→DoctorTodayAvailability.describe',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'compound_specialty_open',
      descriptionAr: 'بحث اختصاص ثم اختيار/فتح بالترتيب في نفس الطلب',
      examplePhrases: ['دورلي طبيب أطفال وافتح الثاني'],
      executionPath: 'specialtySearch+resultIndex→rememberResults→open/select',
    ),
    AppFunctionEntry(
      id: 'whatsapp_selected',
      descriptionAr: 'واتساب للكيان المختار بعد إعادة تحقق حية',
      examplePhrases: ['دزله واتساب', 'راسله'],
      executionPath: 'message*→_withLiveEntity→prepareWhatsApp',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'booking_guidance',
      descriptionAr: 'إرشاد حجز بدون تأكيد موعد تلقائي وبدون فرض تسجيل دخول',
      examplePhrases: ['احجز عنده', 'شلون أحجز'],
      executionPath: 'bookAppointment→رسالة إرشاد اتصال/واتساب',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'show_location',
      descriptionAr: 'عرض العنوان المسجّل فقط',
      examplePhrases: ['وين عيادته', 'شنو عنوانه'],
      executionPath: 'showLocation→بيانات clinicLocation',
      requiresSelection: true,
    ),
    AppFunctionEntry(
      id: 'patient_health',
      descriptionAr: 'فتح ملفي الصحي / بوابة بطاقة المتابعة',
      examplePhrases: ['ملفي الصحي', 'بطاقة المتابعة'],
      executionPath: 'openPatientHealth→PatientHealthGate',
      requiresPatientAuth: true,
    ),
    AppFunctionEntry(
      id: 'next_step_suggestions',
      descriptionAr: 'اقتراحات خطوة تالية سياقية (0–3) من وظائف مدعومة فقط',
      examplePhrases: [
        'بعد بحث أطفال: 1. اسم الطبيب',
        'بعد الاختيار: التفاصيل / الدوام / الحجز',
      ],
      executionPath:
          'SmartBrainSuggestedActionsBuilder.suggest→executionQuery→_runSearch',
    ),
  ];

  static AppFunctionEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}
