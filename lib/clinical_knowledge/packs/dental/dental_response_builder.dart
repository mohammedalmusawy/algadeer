import 'dental_models.dart';
import 'dental_rule_catalog.dart';

class DentalResponseBuilder {
  const DentalResponseBuilder();

  String acknowledge(DentalSession s) {
    if (s.isOtherPerson) {
      return 'فهمت إن الموضوع يخص ${s.otherPersonLabel.isEmpty ? 'شخص ثاني' : s.otherPersonLabel} — مو عنك.';
    }
    if (s.pregnancyContext) {
      return 'فهمت إنج حامل وعندي شكوى أسنان.';
    }
    if (s.childContext) {
      return 'فهمت إن الشكوى تخص طفل/قاصر.';
    }
    return 'فهمت شكوى الأسنان/الفم.';
  }

  String toothPain(DentalSession s, String ruleText) {
    final night = s.triggers.contains(DentalPainTrigger.night)
        ? ' ذكرت إن الألم يزيد بالليل.'
        : '';
    return '${acknowledge(s)}$night $ruleText '
        'الوجهة المناسبة غالباً طبيب أسنان.';
  }

  String sensitivity() =>
      'الحساسية للبارد/الحار شائعة كملاحظة وما تساوي تلقائياً تسوساً أو التهاب عصب. '
      'إذا الألم عفوي أو مع ورم أو بعد ضربة، راجعِ طبيب الأسنان.';

  String antibiotic(DentalRuleCatalog catalog, {required bool named}) {
    final base = catalog
            .findById('dental_ada_antibiotic_stewardship')
            ?.arabicGuidance ??
        '';
    if (named) {
      return '$base ما أختار مضاداً بالاسم أو الجرعة من هنا.';
    }
    return base;
  }

  String prophylaxisRefuse() =>
      'مضاد وقائي قبل إجراءات/لحالات قلب أو مفصل قرار طبي/سنّي متخصص — '
      'ما أوصي ببروتوكول وقائي تلقائي من المحادثة.';

  String analgesicBoundary({required bool pregnancy, required bool child}) {
    if (child) {
      return 'ما أحسب جرعة مسكن أطفال ولا أفترض وزن أو جرعة بالغ. '
          'اسألي طبيب الأطفال/الأسنان عن مسكن مناسب.';
    }
    if (pregnancy) {
      return 'مع الحمل، أي مسكن يحتاج حذراً وموافقة طبية — ما أوصي بجرعة شخصية من هنا.';
    }
    return 'مسكنات دون وصفة قد تُناقش عموماً، لكن الجرعة الشخصية تعتمد عمرك وأمراضك وأدويتك — '
        'ما أبني محرك وصفات هنا.';
  }

  String facialSwelling() =>
      DentalRuleCatalog().findById('dental_facial_swelling_urgent_path')?.arabicGuidance ??
      '';

  String abscessReported() =>
      'ذكرتِ «خراج» كبلاغ منك — ما أثبّته تشخيصاً من الشات. '
      'عدوى سنية محتملة تحتاج تقييماً وعلاجاً سببياً عند طبيب الأسنان، مو الاعتماد على دواء فقط.';

  String gumBleeding() =>
      DentalRuleCatalog()
          .findById('dental_gum_bleeding_no_stop_brushing')
          ?.arabicGuidance ??
      '';

  String wisdom() =>
      'ألم منطقة ضرس العقل يحتاج فحصاً. ما نشخّص انحشاراً أو تامور اللثة أو خراجاً، '
      'وما نقرر خلع تلقائي من المحادثة.';

  String prevention() =>
      DentalRuleCatalog()
          .findById('dental_prevention_hygiene_fluoride')
          ?.arabicGuidance ??
      '';

  String oralLesion() =>
      DentalRuleCatalog().findById('dental_oral_lesion_persistence')?.arabicGuidance ??
      '';

  String oralUlcer() =>
      'قرحة فم شائعة كملاحظة؛ ما أشخّص قرحاً قلاعية أو فيروساً أو غير ذلك من الشات. '
      'إذا استمرت أو تكررت بشكل مقلق، التقييم المهني مناسب.';

  String pregnancyDental() =>
      DentalRuleCatalog()
          .findById('dental_cdc_pregnancy_dental_care')
          ?.arabicGuidance ??
      '';

  String imaging({
    required bool routinelyIndicated,
    required bool pregnancy,
  }) {
    final base = DentalRuleCatalog()
            .findById('dental_imaging_not_routine_toothache')
            ?.arabicGuidance ??
        '';
    if (pregnancy) {
      return '$base مع الحمل: لا منع مبسّط لكل الأشعة ولا موافقة تلقائية — القرار سريري مشترك.';
    }
    if (!routinelyIndicated) {
      return base;
    }
    return 'قد تكون أشعة موجَّهة من طبيب الأسنان مناسبة حسب السؤال السريري. $base';
  }

  String jawPainDeferMsk() =>
      'ألم الفك مو دائماً سنّي. إذا ماكو سياق سن واضح، التقييم العضلي/الفكي قد يكون أنسب — '
      'بدون محرك مفصل فكي كامل هنا.';

  String fearDentist() =>
      'خوفج من عيادة الأسنان مفهوم. ما أگول إن كلشي سهل بدون فحص. '
      'أكدر أوضّح المسار العملي، والدعم العاطفي العام يبقى ضمن سلطته — مو محرك قلق أسنان.';

  String diabetesContext() =>
      'مع سكري مشخص، صحة الفم قد تكون سياقاً مفيداً — بدون ادعاء إن العدوى تعني سوء ضبط، '
      'وبدون تغيير أدوية السكري.';

  String anticoagulant() =>
      'ما أوقف مميعات الدم قبل زيارة الأسنان من المحادثة. '
      'إدارة الدواء قرار طبيب الأسنان/الطبيب المعالج.';

  String otherPerson() =>
      'معلومة أسنان شخص ثاني ما تنربط بسجلّك. أكدر أعطي توجيهاً عاماً فقط.';

  String education(String hint) {
    if (hint.contains('تسوس')) {
      return 'التسوس تلف بنيوي تدريجي يرتبط بالبلاك والسكريات — شرح تعليمي، مو تشخيص لحالتك.';
    }
    if (hint.contains('عصب') || hint.contains('root')) {
      return 'علاج العصب إجراء يقرره طبيب الأسنان بعد الفحص — مو توصية تلقائية من الشات.';
    }
    if (hint.contains('حساسي')) {
      return 'حساسية الأسنان لها أسباب متعددة؛ الشرح التعليمي لا يثبت السبب عندك.';
    }
    return prevention();
  }

  String postProcedure() =>
      'بعد إجراء سني، اتبعي تعليمات طبيبك. نزف بسيط مذكور يختلف عن نزف مستمر مقلق — '
      'والسلامة العاجلة تبقى أولوية. ما أعطي تعليمات إجرائية خطرة.';

  String serviceDentist() =>
      'الوجهة المناسبة: طب أسنان. أكدر أحولك لمسار اكتشاف أطباء الأسنان الحقيقي بالغدير.';

  String noFakeBooking() =>
      'ما أخترع موعد خلع/حشو. المواعيد من بيانات الحجوزات إن وجدت.';

  String followUpOffer() =>
      'إذا تحب، أگدر أتذكر وياك ترجعون للموضوع بعد زيارة الطبيب — بدون تذكير تلقائي.';

  String looseAdult() =>
      'سن متحرك عند بالغ مو «طبيعي مع العمر» تلقائياً — يستحق تقييماً سنّياً، '
      'بدون تشخيص مرض لثة من الشات.';

  String extractionRequestRefuse() =>
      'طلب الخلع المباشر يحتاج فحصاً. ما أقرر خلعاً أو عصباً أو حشواً من المحادثة.';
}
