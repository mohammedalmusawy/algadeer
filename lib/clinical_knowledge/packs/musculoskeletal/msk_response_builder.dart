import '../../clinical_knowledge_models.dart';
import 'msk_models.dart';
import 'msk_rule_catalog.dart';

class MskResponseBuilder {
  const MskResponseBuilder();

  String acknowledge(MskSession session) {
    switch (session.region) {
      case MskBodyRegion.lumbarSpine:
        return 'فهمت إن في ألم بمنطقة الظهر.';
      case MskBodyRegion.cervicalSpine:
        return 'فهمت إن في ألم/انزعاج بالرقبة.';
      case MskBodyRegion.knee:
        return 'فهمت إن الموضوع يخص الركبة.';
      case MskBodyRegion.shoulder:
        return 'فهمت إن في ألم بالكتف.';
      case MskBodyRegion.hip:
        return 'فهمت إن في ألم بالورك.';
      case MskBodyRegion.thigh:
        return 'فهمت إن الموضوع يخص عضلة/منطقة الفخذ.';
      default:
        return 'فهمت إن في شكوى عضلية هيكلية.';
    }
  }

  String buildGuidance({
    required MskClinicalRule rule,
    required MskSession session,
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
        'إذا تحب، أكدر أدليك على خدمة الأشعة المناسبة المتوفرة بالغدير.',
      );
    }
    if (question != null) {
      buf.writeln(question);
    }
    buf.write('هذا توجيه عام — مو تشخيص نهائي ولا وصفة دواء.');
    return buf.toString().trim();
  }

  String education(String topicHint) {
    if (topicHint.contains('سوفان') || topicHint.contains('ركبة')) {
      return 'أعراض شائعة قد تترافق مع سوفان الركبة تشمل ألم أو تيبس أو صعوبة حركة، '
          'لكن الأعراض تتداخل مع حالات ثانية. التشخيص يحتاج تقييماً سريرياً — '
          'ما أأكد التشخيص من وصف لوحده.';
    }
    if (topicHint.contains('عضل') || topicHint.contains('شد')) {
      return 'أعراض شائعة لإصابة عضلية قد تشمل ألم موضعي أو شد أو تورم خفيف أو ضعف مؤقت. '
          'هذا وصف شائع وليس تأكيداً لتصنيف تمزق منزلي.';
    }
    if (topicHint.contains('رقب') || topicHint.contains('تشنج')) {
      return 'تشنج الرقبة قد يظهر كألم وتيبس وصعوبة حركة. '
          'الأعراض الشائعة تختلف عن تأكيد سبب معين.';
    }
    return 'الأعراض الشائعة تختلف عن تأكيد تشخيص. التقييم السريري يوضّح أكثر.';
  }

  String refuseSelfDiagnosis() =>
      'ما أقدر أأكد إن عندك سوفان من هذا الشعور وحده؛ '
      'الأعراض تتداخل، والتقييم السريري يوضح أكثر.';

  String otherPersonSafe() =>
      'الشكوى تخص شخص ثاني. ما أستخدم عمرك أو صحتك لبناء مسار فردي له. '
      'أكدر أعطي توجيهاً عاماً حذراً فقط.';

  String pregnancyConservative() =>
      'مع سياق حمل مذكور، نكون أكثر حذراً وما نفترض قواعد البالغين الاعتيادية دائماً. '
      'الأفضل مناقشة الأعراض مع طبيبتك — مع مراعاة سياق الحمل بجانب تقييم العضلي الهيكلي.';

  String noFakeBooking() =>
      'ما أحجز موعداً تلقائياً من هنا. أكدر أدلّك على مسار التواصل/الخدمة المتوفرة.';

  bool containsForbidden(String msg) {
    return RegExp(
      r'(?:عندك\s*ديسك|عندك\s*عرق\s*النسا|تشخيصك\s*سوفان|'
      r'تمزق\s*درجة|Grade\s*[123]|'
      r'جرعة\s*مسكن|ستيرويد|مرخي\s*عضل|حقنة\s*مفصل|'
      r'نقص\s*فيتامين|اكيد\s*بسيطه|أكيد\s*بسيطة|'
      r'تم\s*حجز\s*الموعد)',
    ).hasMatch(msg);
  }
}
