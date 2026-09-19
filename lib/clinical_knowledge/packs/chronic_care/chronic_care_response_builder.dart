import 'chronic_care_models.dart';
import 'diabetes_rule_catalog.dart';
import 'hypertension_rule_catalog.dart';

class ChronicCareResponseBuilder {
  const ChronicCareResponseBuilder();

  String acknowledge(ChronicClinicalSession s) {
    if (s.hasEstablishedDiabetes && s.hasEstablishedHypertension) {
      return 'فهمت إن عندك سكري وضغط مشخصان.';
    }
    if (s.hasEstablishedDiabetes) return 'فهمت إن عندك سكري مشخص.';
    if (s.hasEstablishedHypertension) return 'فهمت إن عندك ضغط مشخص.';
    if (s.lastSystolic != null) return 'فهمت إن عندك قراءة ضغط.';
    if (s.lastGlucose != null) return 'فهمت إن عندك قراءة سكر.';
    return 'فهمت استفسارك عن المتابعة المزمنة.';
  }

  String buildPriorities(List<AssembledCarePriority> priorities) {
    if (priorities.isEmpty) {
      return 'ما عندي أولوية رعاية مؤكدة من المعلومات الحالية.';
    }
    final buf = StringBuffer();
    for (final p in priorities) {
      final tag = switch (p.status) {
        CareItemStatus.recentlyCompleted => 'مكتمل/حديث',
        CareItemStatus.due => 'مستحق حسب الدليل',
        CareItemStatus.overdue => 'متأخر',
        CareItemStatus.unknown => 'غير معلوم التوقيت',
        CareItemStatus.needsClinicianReview => 'يحتاج مراجعة سريرية',
        CareItemStatus.notYetDue => 'ليس أولوية الآن',
        CareItemStatus.notApplicable => 'غير منطبق',
      };
      buf.writeln('• ${p.arabicLabel} — $tag');
    }
    return buf.toString().trim();
  }

  String singleGlucose({
    required bool establishedDiabetes,
    required bool timingKnown,
  }) {
    if (!establishedDiabetes) {
      return 'هاي قراءة سكر مرتفعة إن كانت كذلك حسب السياق، '
          'لكن قراءة واحدة ما تثبّت تشخيص سكري. '
          'ما أفترض إنك مريض سكري من هالرقم وحده — الأنسب تأكيد سريري.';
    }
    final timing = timingKnown
        ? ''
        : ' وما حددت بعد إن القراءة صيام أو بعد أكل.';
    return 'مع سكري مشخص، القراءة الحالية معلومة مفيدة$timing '
        'وما تعني لوحدها إن السيطرة كاملة أو إن في حالة طارئة. '
        'ما نغيّر جرعة دواء من هنا.';
  }

  String singleBp({
    required bool establishedHtn,
    required bool elevated,
  }) {
    if (!establishedHtn) {
      return elevated
          ? 'قراءة ضغط مرتفعة مرة واحدة ما تكفي عادةً لاعتبار عندك ضغط مزمن. '
              'أعد القياس بهدوء بجهاز عضد مناسب، وراجع طبيبك للتأكيد.'
          : 'سجّلت قراءة ضغط. التشخيص المزمن يحتاج سياقاً سريرياً أوسع.';
    }
    return elevated
        ? 'مع ضغط مشخص، القراءة مرتفعة نسبياً — أعد القياس بجودة جيدة '
            'وراقب الأعراض. ما نغيّر دواء الضغط من هنا.'
        : 'قراءة ضمن سياق متابعتك — الهدف الشخصي يناقشه طبيبك.';
  }

  String education(String hint) {
    if (hint.contains('ضغط') && hint.contains('قيس')) {
      return HypertensionRuleCatalog()
              .findById('htn_home_measurement_technique')
              ?.arabicGuidance ??
          '';
    }
    if (hint.contains('الكلى')) {
      return DiabetesRuleCatalog()
              .forCareItem(DiabetesCareItem.kidneyAssessment)
              ?.arabicGuidance ??
          '';
    }
    if (hint.contains('العين')) {
      return DiabetesRuleCatalog()
              .forCareItem(DiabetesCareItem.eyeAssessment)
              ?.arabicGuidance ??
          '';
    }
    if (hint.contains('تراكمي') || hint.contains('شكد')) {
      return DiabetesRuleCatalog()
              .forCareItem(DiabetesCareItem.glycemicAssessment)
              ?.arabicGuidance ??
          '';
    }
    if (hint.contains('قراءة وحدة') || hint.contains('تشخيص')) {
      return 'قراءة ضغط أو سكر واحدة غالباً ما تكفي وحدها لتشخيص مزمن؛ '
          'التأكيد السريري والمقاييس المتكررة أهم.';
    }
    if (hint.contains('الطبيعي للضغط')) {
      return 'أطر الدليل تصنّف القراءات، لكن هدفك الشخصي قد يختلف حسب عمرك وصحتك '
          'وخطة طبيبك — مو رقم واحد للجميع.';
    }
    return 'معلومة تعليمية عامة — ليست تشخيصاً لحالتك.';
  }

  String whyKidney() =>
      'فحص الكلى مهم بمتابعة السكري لاكتشاف تغيّرات مبكراً عبر UACR و eGFR — '
      'مو للتخويف، وللتخطيط الآمن مع طبيبك.';

  String otherPerson() =>
      'المعلومة تخص شخص ثاني. ما أربطها بعمرك أو تشخيصك. '
      'أكدر أعطي توجيهاً عاماً فقط.';

  String pregnancy() =>
      'مع حمل/سكري حمل، أهداف ومعايير البالغين غير الحوامل ما تنطبق تلقائياً. '
      'المتابعة مع طبيبة التوليد/خطة الحمل هي الأساس — قواعد PC-1.20 غير الحملية لا تُطبَّق عمياء.';

  String refuseSelfDx() =>
      'ما أأكد سكري أو ضغط من الشعور وحده؛ التقييم السريري يوضح.';

  String cuffless() =>
      'قياس الساعة الذكية/بدون كفة مو مكافئ لقياس كفة عضد موثّقة حسب السياسة الحالية.';

  String noFakeBooking() =>
      'ما أحجز موعداً تلقائياً. أكدر أدلّك على مسار الخدمة المتوفر.';

  String noChestXray() =>
      'لا صورة صدر روتينية بسبب السكري أو الضغط وحدهما.';

  String labHandoffHonest({required bool availableKnown}) {
    if (!availableKnown) {
      return 'التوجيه السريري قائم؛ توفر التحليل بخدمات الغدير ما أقدر أأكده من هنا.';
    }
    return 'إذا تحب، أكدر أحولك لمسار اكتشاف المختبر الحقيقي بعد تحديد الاحتياج السريري.';
  }

  bool containsForbidden(String msg) => RegExp(
        r'(?:سكريك\s*مضبوط\s*تماما|كليتك\s*سليمه|'
        r'ابدأ\s*ستاتين|غير\s*جرعة\s*الانسولين|زِد\s*الجرعة|'
        r'ممنوع\s*الرز|اقطع\s*النشويات|أنت\s*مهمل|'
        r'نسبة\s*ASCVD|PREVENT\s*\d+|تم\s*جدولة\s*التذكير)',
      ).hasMatch(msg);
}
