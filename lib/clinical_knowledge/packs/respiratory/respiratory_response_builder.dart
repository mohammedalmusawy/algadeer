import '../../clinical_knowledge_models.dart';
import 'respiratory_models.dart';
import 'respiratory_rule_catalog.dart';

class RespiratoryResponseBuilder {
  const RespiratoryResponseBuilder();

  String acknowledge(RespiratorySession session) {
    if (session.hasCoughContext) {
      return 'فهمت إن عندك سعال.';
    }
    if (session.breathlessness == RespiratoryTriState.present) {
      return 'فهمت إن في ضيق نفس.';
    }
    if (session.wheeze == RespiratoryTriState.present) {
      return 'فهمت إن في صفير.';
    }
    return 'فهمت إن في شكوى تنفسية.';
  }

  String buildGuidance({
    required RespiratoryClinicalRule rule,
    required RespiratorySession session,
    String? question,
  }) {
    final buf = StringBuffer()..writeln(acknowledge(session));
    if (rule.arabicGuidance.isNotEmpty) {
      buf.writeln(rule.arabicGuidance);
    }
    final imaging = rule.imaging;
    if (imaging != null && imaging.arabicGuidance.isNotEmpty) {
      buf.writeln(imaging.arabicGuidance);
    }
    if (imaging != null &&
        imaging.allowsServiceHandoff &&
        (imaging.appropriateness ==
                ClinicalImagingAppropriateness.usuallyAppropriate ||
            imaging.appropriateness ==
                ClinicalImagingAppropriateness.mayBeAppropriate)) {
      buf.writeln(
        'إذا تريد، أكدر أدليك على خدمة أشعة الصدر المتوفرة بالغدير.',
      );
    }
    if (rule.investigationType == RespiratoryInvestigationType.spirometry) {
      buf.writeln(
        'مناقشة مقياس التنفس (spirometry) مع الطبيب قد تكون أنسب من الاعتماد على الأشعة وحدها.',
      );
    }
    if (question != null) {
      buf.writeln(question);
    }
    buf.write('هذا توجيه عام — مو تشخيص نهائي ولا وصفة دواء.');
    return buf.toString().trim();
  }

  String education(String topicHint) {
    final n = topicHint;
    if (n.contains('ربو')) {
      return 'أعراض شائعة قد تترافق مع الربو تشمل صفير أو ضيق نفس أو سعال متقطع، '
          'لكن الأعراض تتداخل. القائمة تعليمية وليست تأكيداً أن عندك ربو.';
    }
    if (n.contains('التهاب') && n.contains('صدر')) {
      return 'أعراض شائعة قد تُذكر مع التهابات الصدر تشمل سعال وحرارة وضيق أحياناً. '
          'هذا وصف تعليمي عام وليس تشخيصاً لحالتك.';
    }
    if (n.contains('مستمر') || n.contains('أسباب')) {
      return 'أسباب السعال المستمر متعددة وقد تشمل التهيج التالي لعدوى، '
          'حساسية، ارتجاع، أدوية، أو أسباب أخرى — القائمة غير شاملة '
          'ولا تعني أن عندك أياً منها.';
    }
    if (n.contains('أشعة') || n.contains('اشعه')) {
      return 'صورة الصدر ليست روتينية لكل سعال. '
          'قد تُناقش عند سعال مزمن/سياق مراجَع أو علامات مقلقة — بعد تقييم سريري.';
    }
    return 'المعلومات التعليمية العامة تختلف عن تأكيد تشخيص فردي.';
  }

  String refuseSelfDiagnosis() =>
      'ما أقدر أأكد التهاب صدر من الشعور وحده؛ التقييم السريري يوضّح أكثر.';

  String otherPersonSafe() =>
      'الشكوى تخص شخص ثاني. ما أستخدم عمرك أو صحتك لبناء مسار فردي له. '
      'أكدر أعطي توجيهاً عاماً حذراً فقط.';

  String pregnancyConservative() =>
      'مع سياق حمل مذكور، قرارات التصوير/الدواء تحتاج حذراً إضافياً. '
      'الأفضل مناقشة سريرية/أشعة حسب الحكم المراجَع — مع مراعاة الحمل دون سرقة الشكوى التنفسية.';

  String childFailClosed() =>
      'تمام، فهمت إن الشكوى تخص طفل. '
      'توجيه الأطفال يحتاج حذراً إضافياً — شكد عمره تقريباً؟';

  /// متابعة طبيعية لشكوى طفل بعد دمج الأعراض — بلا لغة حزم داخلية.
  String childCompanionAck({
    required RespiratorySession session,
    String? question,
  }) {
    final buf = StringBuffer();
    if (session.hasCoughContext) {
      if (session.durationBucket == RespiratoryDurationBucket.days) {
        buf.write('تمام، السعال صار له يومين تقريباً. ');
      } else if (session.durationBucket == RespiratoryDurationBucket.weeks) {
        buf.write('تمام، السعال صار له أسابيع تقريباً. ');
      } else if (session.durationBucket == RespiratoryDurationBucket.hours) {
        buf.write('تمام، السعال حديث. ');
      } else {
        buf.write('تمام، فهمت سعال الطفل. ');
      }
    } else {
      buf.write('تمام، فهمت شكوى تنفسية تخص طفل. ');
    }
    if (question != null && question.trim().isNotEmpty) {
      buf.write(question.trim());
    } else {
      buf.write(
        'إذا صار ضيق نفس أو ازرقاق أو رفض رضاعة/أكل بشكل واضح، '
        'المراجعة العاجلة أهم من الانتظار.',
      );
    }
    return buf.toString().trim();
  }

  String noFakeBooking() =>
      'ما أحجز موعداً تلقائياً من هنا. أكدر أدلّك على مسار التواصل/الخدمة المتوفرة.';

  String directXrayHonest(RespiratorySession session, {required bool eligible}) {
    if (eligible) {
      return buildGuidance(
        rule: RespiratoryRuleCatalog().findById(
              'resp_chronic_cough_cxr_eligible_adult',
            ) ??
            RespiratoryRuleCatalog.activeRules.first,
        session: session,
      );
    }
    return '${acknowledge(session)}\n'
        'طلب صورة الصدر وحده ما يجعلها روتينية لهذا السياق. '
        'خلينا نوضّح المدة والأعراض المهمة أولاً — '
        'وبإمكانك لاحقاً الوصول للخدمة إن صارت مؤهلة سريرياً.';
  }

  bool containsForbidden(String msg) {
    return RegExp(
      r'(?:عندك\s*التهاب\s*رئوي|تشخيصك\s*ربو|عندك\s*copd|'
      r'ابدأ\s*مضاد|جرعة\s*مضاد|لون\s*البلغم\s*يعني|'
      r'ستيرويد|بخاخ\s*جديد|غير\s*جرعة\s*البخاخ|'
      r'اشعه\s*الصدر\s*تشخص\s*كل|اعرف\s*رئتك|'
      r'اكيد\s*مجرد\s*التهاب|أكيد\s*مجرد\s*التهاب|'
      r'تم\s*حجز\s*الموعد|مكملات|عشبه\s*علاج)',
    ).hasMatch(msg);
  }
}
