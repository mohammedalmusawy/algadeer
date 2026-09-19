import 'pregnancy_evidence_catalog.dart';
import 'pregnancy_models.dart';

class PregnancyResponseBuilder {
  const PregnancyResponseBuilder();

  String acknowledge(PregnancyCompanionSession s) {
    if (s.status == PregnancyStatus.pregnancyLossReported) {
      return 'آسفة لهذا الخبر. ما أكمل حديث الحمل المعتاد.';
    }
    if (s.isOtherPerson) {
      return 'فهمت إن الموضوع يخص ${s.otherPersonLabel.isEmpty ? 'شخص ثاني' : s.otherPersonLabel} — مو عنج.';
    }
    if (s.status == PregnancyStatus.confirmed) {
      if (s.gestationalWeeks != null) {
        return 'فهمت إنك حامل وذكرتي سياقاً حول الأسبوع ${s.gestationalWeeks}.';
      }
      if (s.stage != PregnancyStage.unknown) {
        return 'فهمت إنك حامل، والمرحلة تقريبية حسب اللي ذكرتيه.';
      }
      return 'فهمت إنك حامل.';
    }
    if (s.status == PregnancyStatus.possible) {
      return 'فهمت إن في احتمال حمل — ما أثبت الحمل من أعراض وحدها.';
    }
    if (s.status == PregnancyStatus.tryingToConceive) {
      return 'فهمت إنكم تخططون للحمل — مو رفيق خصوبة كامل هنا.';
    }
    return 'فهمت سؤالج عن الحمل.';
  }

  String whatsLeft(List<PregnancyCarePriority> priorities) {
    if (priorities.isEmpty) {
      return 'ما عندي أولويات مؤكدة من المعلومات الحالية — '
          'وما أفترض إن شي متأخر إذا ما عرفنا إن تم أو لا.';
    }
    final buf = StringBuffer('حسب اللي أعرفه هسه:\n');
    for (final p in priorities) {
      final tag = switch (p.status) {
        PregnancyCareItemStatus.recentlyCompleted => 'مكتمل/حديث',
        PregnancyCareItemStatus.due => 'قد يكون مستحقاً حسب الدليل',
        PregnancyCareItemStatus.overdue => 'غير معلوم التوقيت', // لا نعرض overdue
        PregnancyCareItemStatus.unknown => 'غير معلوم إن اكتمل',
        PregnancyCareItemStatus.needsClinicianReview => 'يحتاج مراجعة الطبيبة',
        PregnancyCareItemStatus.notYetDue => 'ليس أولوية الآن',
        PregnancyCareItemStatus.notApplicable => 'غير منطبق',
      };
      buf.writeln('• ${p.arabicLabel} — $tag');
    }
    buf.write('خطة الطبيبة لها أولوية على الجدول العام.');
    return buf.toString().trim();
  }

  String fullChecklist(List<PregnancyCarePriority> priorities) =>
      whatsLeft(priorities);

  String educationWeek(int? weeks) {
    if (weeks == null) {
      return 'بدون عمر حملي واضح ما أقدر أقول "شنو يصير بهالأسبوع" بدقة. '
          'بهذه المرحلة عادةً المتابعة والتغذية الآمنة مهمة — بدون ادعاءات عن حجم الجنين.';
    }
    return 'بهذه المرحلة (حوالي الأسبوع $weeks) عادةً تكون متابعة الحمل والتغذية '
        'ومناقشة أي أعراض مع الطبيبة هي الأهم. '
        'ما أقول إن طفلك «أكيد» يسوي شيئاً محدداً الآن.';
  }

  String fetalSexEducational() =>
      'وقت ظهور الجنس بالسونار يختلف وقد ما يكون واضحاً دائماً. '
      'ما أخمّن الجنس من ضربات القلب أو شكل البطن أو الخرافات.';

  String fetalSexFromClinician(String sex) {
    if (sex == 'female') {
      return 'حسب كلام الطبيبة اللي ذكرتيه: بنت. ما أؤكد من صورة أو تخمين.';
    }
    if (sex == 'male') {
      return 'حسب كلام الطبيبة اللي ذكرتيه: ولد. ما أؤكد من صورة أو تخمين.';
    }
    return fetalSexEducational();
  }

  String ultrasound({
    required bool recentlyDone,
    required bool commercialPresent,
  }) {
    // commercialPresent يجب ألا يغيّر النص السريري
    final base = recentlyDone
        ? 'بما إنج ذكرتي سونار حديث، ما أفترض إنج تحتاجين تكرار فوري بدون سبب سريري أو توجيه الطبيبة.'
        : PregnancyEvidenceCatalog()
                .findById('preg_ultrasound_before_24w_purpose')
                ?.arabicGuidance ??
            'السونار له أغراض محددة حسب الدليل وخطة الطبيبة.';
    if (commercialPresent) {
      return '$base توفر الباقة بالغدير لا يزيد الحاجة الطبية.';
    }
    return base;
  }

  String nutrition() =>
      PregnancyEvidenceCatalog().forCareItem(PregnancyCareItem.nutritionReview)?.arabicGuidance ??
      'تغذية متنوعة وآمنة أفضل من قواعد قاسية.';

  String activity({required bool restrictionKnown, required bool warning}) {
    if (warning) {
      return 'مع علامات مقلقة، ما أنصح بنشاط إضافي قبل تقييم سريري.';
    }
    if (restrictionKnown) {
      return 'بما إن الطبيبة طلبت راحة/قيوداً، خلينا نحترم خطتها. '
          'سلطة النشاط العامة تبقى ضمن سياق العافية — مو وصفة خطوات إجبارية.';
    }
    return PregnancyEvidenceCatalog()
            .forCareItem(PregnancyCareItem.physicalActivityReview)
            ?.arabicGuidance ??
        'المشي اللطيف غالباً مناسب إن ماكو قيود — بدون هدف 10 آلاف خطوة.';
  }

  String symptom(String key, PregnancySymptomClass cls) {
    if (cls == PregnancySymptomClass.deferTo10E ||
        cls == PregnancySymptomClass.safetyConcern) {
      return 'هالعَرَض يحتاج تقييماً عاجلاً — ما أطمْئنج بطمأنة عامة.';
    }
    switch (key) {
      case 'nausea':
        return 'الغثيان شائع ممكن بالحمل، لكنه مو معناها إن السبب معروف من الشات. '
            'إذا ترجيع شديد/جفاف راجعِ الطبيبة.';
      case 'backPain':
        return 'وجع الظهر ممكن يرتبط بالحمل أو بسبب ميكانيكي. '
            'ما نصور تلقائياً وما ننسب الألم للحمل تلقائياً — ومع علامات الخطر نرجّح السلامة.';
      case 'heartburn':
        return 'الحرقة شائعة ممكنة؛ خطوات بسيطة أحياناً تساعد، ومع ألم صدري شديد راجعِ فوراً.';
      case 'constipation':
        return 'الإمساك شائع ممكن؛ رطوبة وألياف حسب تحمّلج، وراجعي الطبيبة إذا ألم شديد.';
      case 'fatigue':
        return 'التعب شائع بالحمل، لكن التعب المستمر/الشديد يستحق مراجعة — مو نطبّعه دائماً.';
      case 'headache':
        return 'صداع الحمل يحتاج توضيحاً. مع صداع شديد أو تشوش نظر لا نطمئن — سلامة أولاً.';
      case 'dizziness':
        return 'الدوخة تحتاج سياقاً؛ مع إغماء أو نزيف نرجّح تقييماً عاجلاً.';
      case 'bleeding':
        return 'نزيف الحمل ما يُجاب بطمأنة عامة. يحتاج تقييماً سريرياً مناسباً.';
      default:
        return 'فهمت العرض. ما أحدد السبب من المحادثة وحدها.';
    }
  }

  String gdmEstablished() =>
      'مع سكر حمل مذكور كتشخيص، المتابعة مع الطبيبة/خطة السكري بالحمل هي الأساس. '
      'ما نعدّل إنسولين أو أهدافاً من هنا، وما نطبّق قواعد البالغين غير الحوامل عمياء.';

  String preexistingDiabetesPregnancy() =>
      'مع سكري سابق + حمل، الرعاية متخصصة أكثر. أهداف الجلوكوز/HbA1c الشخصية من الطبيبة — '
      'مو من توصيات عامة غير حملية.';

  String singleHighGlucose() =>
      'قراءة سكر مرتفعة مرة واحدة ما تشخّص سكر حمل. لازم تقييم سريري مناسب.';

  String highBpHint() =>
      'ضغط مرتفع بالحمل يحتاج انتباهاً خاصاً — وما أشخّص تسمم حمل من المحادثة. '
      'مع أعراض مقلقة نرجّح السلامة العاجلة.';

  String clinicianPlan() =>
      'خطة الطبيبة اللي ذكرتيها مهمة شخصياً. أقدر أساعدك تنظّمينها، '
      'وما أناقضها بجدول عام إلا إذا صار تعارض سلامة واضح — وقتها التقييم السريري أولاً.';

  String emotionalFear() =>
      'خوفج مفهوم. ما أعطي ضمانات طبية بدون معلومة سريرية مؤكدة. '
      'أكدر أكون وياج عملياً، وطبيبتج تبقى مرجعج الطبي — مو استبدال.';

  String loss() =>
      'آسفة. ما أكمل تحديثات أسابيع الحمل ولا لغة احتفالية. '
      'إذا تحتاجين دعماً أو مراجعة طبية، ذلك أولوية.';

  String otherPerson() =>
      'حمل شخص ثاني ما ينربط بسجلج أو عمرج الحملي. '
      'أكدر أعطي توجيهاً عاماً فقط بدون تسريب معلومات بين الأشخاص.';

  String possibleNotConfirmed() =>
      'تأخر الدورة أو الغثيان وحدهما ما يثبتان حملاً مؤكداً هنا. '
      'إذا تبين حمل مؤكد من فحص/طبيبة، قوليلي ونكمّل بحذر.';

  String tryingToConceive() =>
      'التخطيط للحمل موضوع واسع. ما أبني محرك خصوبة هنا — '
      'ناقشي مع طبيبة نسائية إذا تحتاجين تقييماً.';

  String postpartumBoundary() =>
      'بعد الولادة جدول ما قبل الولادة ما ينطبق. '
      'أكدر أحولج لمسار آمن عام — رفيق ما بعد الولادة مو مفعّل بهالمرحلة.';

  String medicationBoundary() =>
      'ما أوقف أو أغيّر دواء وصفة لأنج حامل من المحادثة. '
      'راجعي الطبيبة/الصيدلي قبل أي تغيير — خاصة لا توقفين فجأة بدون إرشاد.';

  String noDependency() =>
      // يُستخدم للتحقق فقط — الردود الحقيقية تتجنب لغة الاعتماد
      'useful_trust_not_dependence';

  String birthPrep() =>
      'الاستعداد للولادة يشمل خطة المتابعة، علامات التحذير، وترتيبات عملية حسب تعليمات المستشفى/الطبيبة. '
      'ما أعطي بروتوكول ولادة منزلية غير مدعوم.';

  String laborBoundary() =>
      'أسئلة المخاض تحتاج خدمة توليد/تقييم عاجل حسب السياق. '
      'ما أبني مؤقت تقلصات ولا تشخيص ولادة من الشات.';

  String followUpOffer() =>
      'إذا تحبين، أگدر أتذكر وياج نرجع لهذا الموضوع بعد مراجعتج — '
      'بس ما أسوي تذكيراً تلقائياً بدون موافقتج.';

  String noFakeAppointment() =>
      'ما أخترع موعد يوم الثلاثاء. المواعيد الحقيقية من بيانات الحجوزات إن وجدت.';

  String serviceObgyn() =>
      'الوجهة المناسبة غالباً نسائية وتوليد. أكدر أحولج لمسار اكتشاف الأطباء الحقيقي بالغدير.';

  String mythSexRefuse() =>
      'ما أخمّن جنس الجنين من ضربات القلب أو شكل البطن أو الأكل. '
      'إذا الطبيبة أكدت بالسونار، نعتمد كلامها كبلاغ منج.';

  String monthAmbiguous() =>
      '«دخلت الشهر كذا» تقريبي وما يتحول ليوم حملي دقيق هنا. '
      'إذا يهم التوقيت الدقيق، أسبوع الطبيبة/السونار أوضح.';

  String datingConflict() =>
      'حسب التاريخ اللي ذكرتيه يطلع تقريباً كذا، '
      'لكن إذا الطبيبة مثبتة عمر الحمل بالسونار فاعتمدي العمر اللي حددته.';

  String nextStepOb() => 'الخطوة العملية: ناقشي مع طبيبة المتابعة.';
}
