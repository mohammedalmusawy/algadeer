import '../../search/arabic_text_utils.dart';
import 'preventive_guidance_models.dart';

/// تفسير طلبات التوجيه الوقائي — requested فقط.
class PreventiveGuidanceInterpreter {
  const PreventiveGuidanceInterpreter();

  PreventiveInterpretResult interpret(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) {
      return const PreventiveInterpretResult(kind: PreventiveIntent.none);
    }

    if (RegExp(r'(?:أكمل|اكمل|باقي\s*النصائح|كمل\s*النصائح)').hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.moreAdvice,
        topic: PreventiveGuidanceTopic.general,
      );
    }

    if (RegExp(
      r'(?:فحوصات?\s*وقاي|الفحوصات?\s*الوقاي|فحص\s*دوري|'
      r'شنو\s*الفحوصات?\s*الوقاي|الفحوصات?\s*الوقاي\s*المناسبه)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.screeningDiscussion,
        topic: PreventiveGuidanceTopic.screening,
      );
    }

    if (RegExp(
      r'(?:فتره?\s*الامتحان|الامتحانات?\s*ضاغط|امتحانات?\s*ونصائح)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.examPeriodAdvice,
        topic: PreventiveGuidanceTopic.examPeriod,
      );
    }

    if (RegExp(
      r'(?:انا\s*طالب|طالب\s*شنو\s*تنصحني)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.studentAdvice,
        topic: PreventiveGuidanceTopic.student,
      );
    }

    if (RegExp(
      r'(?:شكد\s*أمشي|شكد\s*امشي|كم\s*أمشي|المشي|امشي\s*يوميا)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.walkingAdvice,
        topic: PreventiveGuidanceTopic.walking,
      );
    }

    if (RegExp(
      r'(?:شنو\s*اغير\s*باكل|نصائح?\s*اكل|'
      r'الاكل\s*الصح|التغذيه|التغذية|باكلي|باكل)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.dietAdvice,
        topic: PreventiveGuidanceTopic.diet,
      );
    }

    if (RegExp(
      r'(?:تناسب\s*عمري|بهذا\s*العمر|نصائح?\s*عمري|'
      r'شنو\s*تنصحني\s*بهذا\s*العمر|انطيني\s*نصائح?\s*تناسب\s*عمري)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.ageAppropriateAdvice,
        topic: PreventiveGuidanceTopic.ageAppropriate,
      );
    }

    if (RegExp(
      r'(?:شلون\s*احافظ\s*علي\s*صح|كيف\s*احافظ\s*علي\s*صح|'
      r'نصائح?\s*صح|نصائح?\s*وقاي|وقايه|الوقايه|'
      r'شنو\s*تنصحني|انطيني\s*نصائح?)',
    ).hasMatch(n)) {
      return const PreventiveInterpretResult(
        kind: PreventiveIntent.generalPrevention,
        topic: PreventiveGuidanceTopic.general,
      );
    }

    return const PreventiveInterpretResult(kind: PreventiveIntent.none);
  }

  bool looksLikePreventiveRequest(String raw) {
    return interpret(raw).kind != PreventiveIntent.none;
  }
}

class PreventiveInterpretResult {
  const PreventiveInterpretResult({
    required this.kind,
    this.topic = PreventiveGuidanceTopic.general,
  });

  final PreventiveIntent kind;
  final PreventiveGuidanceTopic topic;
}
