import 'adolescent_evidence_catalog.dart';
import 'adolescent_models.dart';

class AdolescentResponseBuilder {
  const AdolescentResponseBuilder();

  String acknowledge(AdolescentCompanionSession s) {
    if (s.parentAskingAboutTeen) {
      return 'فهمت إنك تسأل عن مراهق بالعائلة — ما أفترض شنو يحس من جوه.';
    }
    if (s.isOtherPerson) {
      return 'فهمت إن الموضوع يخص ${s.otherPersonLabel.isEmpty ? 'شخص ثاني' : s.otherPersonLabel} — مو عنك.';
    }
    if (s.isConfirmedAdolescent && s.statedAgeYears != null) {
      return 'فهمت إنك بعمر المراهقة.';
    }
    return 'فهمت.';
  }

  String studyHelp() =>
      'خلّينا نبدأ بخطوة صغيرة: مادة وحدة ووقت قصير (مثلاً نحو 20 دقيقة) بدون ضغط إنهاء كل شي. '
      'ما نلصق تسمية طبية على صعوبة التركيز من هالوصف.';

  String examStress() =>
      AdolescentEvidenceCatalog().findById('ado_study_stress_support')?.arabicGuidance ??
      '';

  String concentration() =>
      'صعوبة التركيز لها أسباب كثيرة (نوم، ضغط، بيئة…). '
      'ما تعني تلقائياً اضطراباً معيناً. جرّب تقليل المشتتات وبدء مهمة صغيرة.';

  String motivation() =>
      'ما ألومك. غالباً نحتاج مهمة أصغر من اللي ببالك — ابدأ بسطر/سؤال واحد.';

  String sleep() =>
      AdolescentEvidenceCatalog().findById('ado_who_sleep_wellbeing')?.arabicGuidance ??
      '';

  String activity() =>
      AdolescentEvidenceCatalog().findById('ado_who_activity')?.arabicGuidance ??
      '';

  String bodyImage() =>
      AdolescentEvidenceCatalog().findById('ado_body_image_safe')?.arabicGuidance ??
      '';

  String refuseUnsafeWeightLoss() =>
      'ما أعطي خطة تخسيس قاسية أو حبوب أو صيام متطرف للمراهقين من هنا. '
      'إذا في قلق صحي، الأنسب مختص تغذية/طبيب.';

  String bullying() =>
      AdolescentEvidenceCatalog().findById('ado_bullying_support')?.arabicGuidance ??
      '';

  String cyberbullying() =>
      'بالمضايقات الإلكترونية: لا تصعّد، احفظ دليلاً إذا كان آمناً، استخدم حظر/إبلاغ المنصة، '
      'واطلب دعم شخص موثوق. ما أطلب أسرار الدخول ولا صوراً خاصة.';

  String familyTension() =>
      'خلاف الأهل شائع كملاحظة. أكدر أساعد بصياغة طلب واضح وهادئ — بدون ما آخذ طرفاً تلقائياً، '
      'وبدون دفعك لمواجهة غير آمنة.';

  String friendship() =>
      'الصداقة تحتاج حدوداً واحتراماً. ما أستبدل أصدقاءك وما أدفعك للعزلة عن الكل.';

  String peerPressure() =>
      'ضغط الأقران يُواجه بتأني: توقف، فكّر بالسلامة، وگول لا بحدود واضحة عند الحاجة.';

  String selfConfidence() =>
      'الثقة تنبني بمهارات وخطوات صغيرة واقعية — مو بمديح فارغ مثل «أنت الأفضل» دائماً.';

  String pubertyEducation() =>
      AdolescentEvidenceCatalog().findById('ado_puberty_education')?.arabicGuidance ??
      '';

  String educationWhatIsAdolescence() =>
      AdolescentEvidenceCatalog().findById('ado_who_age_boundary_10_19')?.arabicGuidance ??
      '';

  String parentAboutTeenStudy() =>
      'من كلامك كولي أمر: ساعد ببيئة هادئة، حدود معقولة، وتشجيع خطوة صغيرة — '
      'بدون وصم بالكسل وبدون تشخيص من بعيد.';

  String helpSeeking() =>
      'طلب المساعدة عملي: شخص بالغ موثوق، دعم مدرسي إن توفر، أو مختص عند الحاجة. '
      'ما أخترع توفر خدمة محلية.';

  String noFalseHormones() =>
      'ما أگول «هذا بس هرمونات» لكل شي. السياق النمائي ما يلغي أعراضاً مهمة.';

  String noDependency() =>
      // للتحقق المعماري — الردود الحقيقية تتجنب هذه اللغة
      'agency_not_dependency';

  String noAbsoluteSecrecy() =>
      'أكدر أحترم خصوصيتك، بس ما أعد بسر مطلق إذا صار خطر حقيقي على سلامتك.';

  String planHandoff() =>
      'أكدر أساعدك بترتيب يوم بسيط عبر مخطّط العافية — بلا جدول يملأ كل دقيقة.';

  String youngerChildBoundary() =>
      'العمر المذكور أصغر من نطاق رفيق المراهقة. أكدر أعطي توجيهاً عاماً حذراً فقط.';

  String adultBoundary() =>
      'العمر المذكور خارج نطاق المراهقة التشغيلي هنا. أكدر أساعد بسياق عام بدون افتراض مراهقة.';

  String nextStepSmall() => 'خطوة عملية الآن: اختر مهمة واحدة صغيرة وابدأ بها.';
}
